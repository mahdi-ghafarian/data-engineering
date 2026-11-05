# Fabric notebook / Python script
# Purpose: Read frozen almp.* submission tables from the LMTA Warehouse,
#          generate ALMP XML, validate well-formedness, validate against XSD,
#          run selected content checks, and write accepted output to ICT_DL1.
#
# Required library in a Fabric notebook:
#   %pip install lxml
# Restart the Python session after installation if Fabric requests it.

from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from datetime import date, datetime
from decimal import Decimal
from pathlib import Path
from typing import Any, Iterable

from lxml import etree

try:
    from pyspark.sql import SparkSession
except ImportError:  # Allows local linting/testing of XML-only functions.
    SparkSession = Any


# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

ALMP_NS = "http://servicecanada.gc.ca/ALMP/contentExchange"
TYPE_NS = "http://servicecanada.gc.ca/ALMP/contentTypes"
XSI_NS = "http://www.w3.org/2001/XMLSchema-instance"
NSMAP = {"ALMP": ALMP_NS, "p": TYPE_NS, "xsi": XSI_NS}


@dataclass(frozen=True)
class Config:
    submission_id: int

    # spark.read.synapsesql identifier. Change if your Warehouse is qualified
    # differently in the notebook, for example "WorkspaceName.LMTA".
    warehouse_name: str = "LMTA"

    # Put both XSDs in this ICT_DL1 folder. ALMP.xsd must be able to resolve
    # ALMPTypes.xsd through its xs:include/xs:import schemaLocation.
    xsd_dir: str = "/lakehouse/ICT_DL1/Files/LMTA/xsd"
    main_xsd_name: str = "ALMP.xsd"

    # Accepted XML, rejected XML and validation reports are separated.
    output_root: str = "/lakehouse/ICT_DL1/Files/LMTA/xml"

    # Set to LMDA or WDA. Used only for the Saskatchewan file name.
    program_type: str = "LMDA"
    sequence_number: int = 1

    # If True, an invalid XML file is written only to rejected/, never accepted/.
    fail_on_validation_error: bool = True

    # Element order overrides. Add exact XSD names here if information_schema
    # order does not match the XSD. Technical columns are excluded separately.
    table_element_order: dict[str, list[str]] = field(default_factory=dict)

    # Flattened almp.client address columns are grouped into <address>.
    address_columns: tuple[str, ...] = (
        "streetAddress",
        "municipality",
        "province",
        "country",
        "postalZIPCode",
        "contactPhoneNumber",
        "sysComment",  # Remove if client has its own sysComment column.
    )


TECHNICAL_COLUMNS = {
    "submission_id", "batch_id", "client_key", "action_plan_key",
    "followup_key", "intervention_key", "support_key", "sys_action_key",
    "sort_seq", "source_system", "source_key", "load_id",
    "source_as_of_date", "created_at", "updated_at", "loaded_at",
    "status", "period_start", "period_end", "reporting_frequency",
    "xml_file_name", "xml_path", "xsd_valid", "validation_status",
    "validation_message", "validated_at", "exported_at",
}

TABLES = {
    "submission": "almp.submission",
    "sys_action": "almp.sys_action",
    "client": "almp.client",
    "action_plan": "almp.action_plan",
    "followup": "almp.action_plan_followup",
    "intervention": "almp.intervention",
    "support": "almp.intervention_support",
}


# -----------------------------------------------------------------------------
# General helpers
# -----------------------------------------------------------------------------

def is_null(value: Any) -> bool:
    return value is None


def xml_text(value: Any) -> str:
    """Convert SQL/Spark values to XSD-friendly lexical text."""
    if isinstance(value, datetime):
        return value.isoformat(timespec="seconds")
    if isinstance(value, date):
        return value.isoformat()
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, Decimal):
        return format(value, "f")
    if isinstance(value, float):
        # Avoid identifiers such as 123.0 when values came through a float.
        return str(int(value)) if value.is_integer() else format(value, ".15g")
    return str(value).strip()


def add_element(parent: etree._Element, tag: str, value: Any) -> etree._Element | None:
    if is_null(value) or xml_text(value) == "":
        return None
    child = etree.SubElement(parent, tag)
    child.text = xml_text(value)
    return child


def local_name(name: str) -> str:
    return name.split("}")[-1] if "}" in name else name


def safe_file_component(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9_.-]+", "_", value)


def dbfs_to_driver_path(path: str) -> str:
    """Fabric lakehouse paths normally work directly; abfss paths use Hadoop APIs."""
    return path


# -----------------------------------------------------------------------------
# Warehouse access
# -----------------------------------------------------------------------------

def read_warehouse_table(spark: SparkSession, cfg: Config, object_name: str):
    identifier = f"{cfg.warehouse_name}.{object_name}"
    return spark.read.synapsesql(identifier)


def collect_submission_rows(spark: SparkSession, cfg: Config) -> dict[str, list[dict[str, Any]]]:
    data: dict[str, list[dict[str, Any]]] = {}

    for logical_name, object_name in TABLES.items():
        df = read_warehouse_table(spark, cfg, object_name)
        id_col = "submission_id" if "submission_id" in df.columns else "batch_id"
        if id_col not in df.columns:
            raise ValueError(f"{object_name} has neither submission_id nor batch_id")

        filtered = df.where(df[id_col] == cfg.submission_id)
        sort_columns = [
            c for c in ("sort_seq", "client_key", "action_plan_key",
                        "followup_key", "intervention_key", "support_key")
            if c in filtered.columns
        ]
        if sort_columns:
            filtered = filtered.orderBy(*sort_columns)

        data[logical_name] = [row.asDict(recursive=True) for row in filtered.collect()]

    if len(data["submission"]) != 1:
        raise ValueError(
            f"Expected exactly one almp.submission row for submission_id="
            f"{cfg.submission_id}; found {len(data['submission'])}."
        )
    return data


# -----------------------------------------------------------------------------
# XML generation
# -----------------------------------------------------------------------------

def business_columns(row: dict[str, Any], cfg: Config, logical_table: str) -> list[str]:
    override = cfg.table_element_order.get(logical_table)
    if override:
        return [c for c in override if c in row]
    return [c for c in row.keys() if c.lower() not in TECHNICAL_COLUMNS]


def append_row_elements(
    parent: etree._Element,
    row: dict[str, Any],
    cfg: Config,
    logical_table: str,
    excluded: Iterable[str] = (),
) -> None:
    excluded_set = set(excluded)
    for column in business_columns(row, cfg, logical_table):
        if column not in excluded_set:
            add_element(parent, column, row.get(column))


def rows_by(rows: list[dict[str, Any]], key: str) -> dict[Any, list[dict[str, Any]]]:
    grouped: dict[Any, list[dict[str, Any]]] = {}
    for row in rows:
        grouped.setdefault(row.get(key), []).append(row)
    return grouped


def build_xml(data: dict[str, list[dict[str, Any]]], cfg: Config) -> etree._ElementTree:
    root = etree.Element(etree.QName(ALMP_NS, "contentALMP"), nsmap=NSMAP)
    submission = data["submission"][0]

    # Root/header values. Only columns present and non-null are emitted.
    append_row_elements(root, submission, cfg, "submission")

    # Optional root sysAction blocks.
    for row in data["sys_action"]:
        node = etree.SubElement(root, "sysAction")
        append_row_elements(node, row, cfg, "sys_action")

    plans_by_client = rows_by(data["action_plan"], "client_key")
    followups_by_plan = rows_by(data["followup"], "action_plan_key")
    interventions_by_plan = rows_by(data["intervention"], "action_plan_key")
    supports_by_intervention = rows_by(data["support"], "intervention_key")

    for client in data["client"]:
        client_node = etree.SubElement(root, "client")
        address_cols = [c for c in cfg.address_columns if c in client]
        append_row_elements(client_node, client, cfg, "client", excluded=address_cols)

        if any(not is_null(client.get(c)) and xml_text(client.get(c)) != "" for c in address_cols):
            address_node = etree.SubElement(client_node, "address")
            for column in address_cols:
                add_element(address_node, column, client.get(column))

        client_key = client.get("client_key")
        for plan in plans_by_client.get(client_key, []):
            plan_node = etree.SubElement(client_node, "actionPlan")

            # Child blocks must be placed at the exact location required by XSD.
            # If the XSD puts children between scalar fields, populate
            # table_element_order and split this function accordingly.
            append_row_elements(plan_node, plan, cfg, "action_plan")

            plan_key = plan.get("action_plan_key")
            for followup in followups_by_plan.get(plan_key, []):
                followup_node = etree.SubElement(plan_node, "actionPlanFollowUp")
                append_row_elements(followup_node, followup, cfg, "followup")

            for intervention in interventions_by_plan.get(plan_key, []):
                intervention_node = etree.SubElement(plan_node, "intervention")
                append_row_elements(intervention_node, intervention, cfg, "intervention")

                intervention_key = intervention.get("intervention_key")
                for support in supports_by_intervention.get(intervention_key, []):
                    support_node = etree.SubElement(intervention_node, "interventionSupport")
                    append_row_elements(support_node, support, cfg, "support")

    return etree.ElementTree(root)


# -----------------------------------------------------------------------------
# Validation
# -----------------------------------------------------------------------------

def validate_well_formed(xml_bytes: bytes) -> list[dict[str, Any]]:
    try:
        etree.fromstring(xml_bytes)
        return []
    except etree.XMLSyntaxError as exc:
        return [{
            "validation_type": "XML_WELL_FORMEDNESS",
            "severity": "ERROR",
            "line": exc.lineno,
            "column": exc.position[1] if exc.position else None,
            "message": str(exc),
        }]


def validate_xsd(xml_bytes: bytes, xsd_path: str) -> list[dict[str, Any]]:
    parser = etree.XMLParser(remove_blank_text=True, resolve_entities=False)
    xsd_doc = etree.parse(xsd_path, parser)
    schema = etree.XMLSchema(xsd_doc)
    xml_doc = etree.fromstring(xml_bytes, parser)

    if schema.validate(xml_doc):
        return []

    return [{
        "validation_type": "XSD",
        "severity": "ERROR",
        "line": error.line,
        "column": error.column,
        "domain": error.domain_name,
        "type": error.type_name,
        "message": error.message,
    } for error in schema.error_log]


def luhn_valid(sin: str) -> bool:
    if not re.fullmatch(r"\d{9}", sin or ""):
        return False
    digits = [int(c) for c in sin]
    total = 0
    for index, digit in enumerate(digits):
        if index % 2 == 1:
            doubled = digit * 2
            total += doubled // 10 + doubled % 10
        else:
            total += digit
    return total % 10 == 0


def validate_content(data: dict[str, list[dict[str, Any]]]) -> list[dict[str, Any]]:
    """Checks business rules not fully expressible in XSD.

    Extend this function with approved LMTA/ESDC conditional rules. XSD remains
    the authoritative validation for structure, data types, enumeration values,
    patterns, min/max lengths and cardinality.
    """
    errors: list[dict[str, Any]] = []

    plans_by_client = rows_by(data["action_plan"], "client_key")
    interventions_by_plan = rows_by(data["intervention"], "action_plan_key")
    followups_by_plan = rows_by(data["followup"], "action_plan_key")
    supports_by_intervention = rows_by(data["support"], "intervention_key")

    def issue(rule: str, entity: str, key: Any, column: str | None, message: str):
        errors.append({
            "validation_type": "CONTENT",
            "severity": "ERROR",
            "rule_code": rule,
            "entity_name": entity,
            "entity_key": key,
            "column_name": column,
            "message": message,
        })

    for client in data["client"]:
        key = client.get("client_key")
        sin = xml_text(client.get("socialInsuranceNumber")) if client.get("socialInsuranceNumber") is not None else ""
        if sin and not luhn_valid(sin):
            issue("CLIENT_SIN_MOD10", "client", key, "socialInsuranceNumber",
                  "SIN must contain nine digits and pass the MOD 10 check.")
        if not plans_by_client.get(key):
            issue("CLIENT_ACTION_PLAN_MIN_1", "client", key, None,
                  "Each client must contain at least one actionPlan.")

    for plan in data["action_plan"]:
        key = plan.get("action_plan_key")
        if not interventions_by_plan.get(key):
            issue("ACTION_PLAN_INTERVENTION_MIN_1", "action_plan", key, None,
                  "Each actionPlan must contain at least one intervention.")
        if len(followups_by_plan.get(key, [])) > 5:
            issue("ACTION_PLAN_FOLLOWUP_MAX_5", "action_plan", key, None,
                  "An actionPlan can contain no more than five follow-ups.")

    for intervention in data["intervention"]:
        key = intervention.get("intervention_key")
        if len(supports_by_intervention.get(key, [])) > 10:
            issue("INTERVENTION_SUPPORT_MAX_10", "intervention", key, None,
                  "An intervention can contain no more than ten support rows.")

        start = intervention.get("interventionStartDate")
        end = intervention.get("interventionEndDate")
        if start and end and end < start:
            issue("INTERVENTION_DATE_ORDER", "intervention", key,
                  "interventionEndDate", "Intervention end date is before start date.")

    return errors


# -----------------------------------------------------------------------------
# Lakehouse writing
# -----------------------------------------------------------------------------

def write_text(spark: SparkSession, path: str, text: str) -> None:
    """Write a single file to a Fabric Lakehouse path or ABFSS URI."""
    if path.startswith("abfss://"):
        jvm = spark._jvm
        hadoop_path = jvm.org.apache.hadoop.fs.Path(path)
        fs = hadoop_path.getFileSystem(spark._jsc.hadoopConfiguration())
        stream = fs.create(hadoop_path, True)
        stream.write(bytearray(text.encode("utf-8")))
        stream.close()
    else:
        target = Path(dbfs_to_driver_path(path))
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8")


def output_file_name(cfg: Config) -> str:
    prefix = "sklmda" if cfg.program_type.upper() == "LMDA" else "skwda"
    timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
    return f"{prefix}_{cfg.sequence_number:03d}_{timestamp}.xml"


def run(spark: SparkSession, cfg: Config) -> dict[str, Any]:
    data = collect_submission_rows(spark, cfg)
    content_errors = validate_content(data)

    xml_tree = build_xml(data, cfg)
    xml_bytes = etree.tostring(
        xml_tree,
        pretty_print=True,
        xml_declaration=True,
        encoding="UTF-8",
        standalone=False,
    )

    validation_errors = []
    validation_errors.extend(validate_well_formed(xml_bytes))

    xsd_path = str(Path(cfg.xsd_dir) / cfg.main_xsd_name)
    if not validation_errors:
        validation_errors.extend(validate_xsd(xml_bytes, xsd_path))
    validation_errors.extend(content_errors)

    is_valid = len(validation_errors) == 0
    file_name = output_file_name(cfg)
    bucket = "accepted" if is_valid else "rejected"
    xml_path = f"{cfg.output_root}/{bucket}/{file_name}"
    report_path = f"{cfg.output_root}/validation/{file_name}.validation.json"

    write_text(spark, xml_path, xml_bytes.decode("utf-8"))

    report = {
        "submission_id": cfg.submission_id,
        "file_name": file_name,
        "xml_path": xml_path,
        "xsd_path": xsd_path,
        "valid": is_valid,
        "validated_at": datetime.now().isoformat(timespec="seconds"),
        "row_counts": {name: len(rows) for name, rows in data.items()},
        "errors": validation_errors,
    }
    write_text(spark, report_path, json.dumps(report, indent=2, default=str))

    if cfg.fail_on_validation_error and not is_valid:
        raise ValueError(
            f"ALMP XML validation failed with {len(validation_errors)} error(s). "
            f"Rejected XML: {xml_path}; report: {report_path}"
        )

    return report


# -----------------------------------------------------------------------------
# Fabric notebook entry point
# -----------------------------------------------------------------------------
# In a Fabric notebook, attach or otherwise grant access to:
#   1. LMTA Warehouse for spark.read.synapsesql
#   2. ICT_DL1 Lakehouse for /lakehouse/ICT_DL1/Files paths
# Then run:
#
# spark = SparkSession.builder.getOrCreate()
# config = Config(
#     submission_id=101,
#     warehouse_name="LMTA",
#     xsd_dir="/lakehouse/ICT_DL1/Files/LMTA/xsd",
#     output_root="/lakehouse/ICT_DL1/Files/LMTA/xml",
#     program_type="LMDA",
#     sequence_number=1,
#     table_element_order={
#         # Populate these lists from the XSD if physical column order differs.
#         # "submission": ["SchemaVersion", "agreementHolderName", "sysComment"],
#         # "client": ["clientID", "socialInsuranceNumber", "lastName", ...],
#     },
# )
# result = run(spark, config)
# display(result)
