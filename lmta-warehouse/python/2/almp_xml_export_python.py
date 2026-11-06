# Fabric notebook / pure Python script
# Purpose: Read frozen almp.* submission tables from the LMTA Warehouse through
#          its SQL endpoint, generate ALMP XML, validate it, and write artifacts
#          to the ICT_DL1 Lakehouse Files area.
#
# Fabric notebook libraries:
#   %pip install lxml pyodbc pandas
#
# This module intentionally does not use PySpark or Spark DataFrames.

from __future__ import annotations

import json
import re
import struct
from dataclasses import dataclass, field
from datetime import date, datetime
from decimal import Decimal
from pathlib import Path
from typing import Any, Iterable

import pandas as pd
import pyodbc
from lxml import etree


# -----------------------------------------------------------------------------
# XML namespaces
# -----------------------------------------------------------------------------
ALMP_NS = "http://servicecanada.gc.ca/ALMP/contentExchange"
TYPE_NS = "http://servicecanada.gc.ca/ALMP/contentTypes"
XSI_NS = "http://www.w3.org/2001/XMLSchema-instance"
NSMAP = {"ALMP": ALMP_NS, "p": TYPE_NS, "xsi": XSI_NS}


# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
@dataclass(frozen=True)
class Config:
    submission_id: int

    # Copy these values from the LMTA Warehouse SQL connection settings.
    sql_server: str
    sql_database: str = "LMTA"
    odbc_driver: str = "ODBC Driver 18 for SQL Server"

    # ICT_DL1 must be attached to the notebook as the DEFAULT Lakehouse.
    # The following folders implement the approved LMTA file organization.
    lmta_root: str = "/lakehouse/default/Files/LMTA"
    main_xsd_name: str = "ALMP.xsd"

    # LMDA or WDA, used in the Saskatchewan output file name.
    program_type: str = "LMDA"
    sequence_number: int = 1
    fail_on_validation_error: bool = True

    # Optional exact element ordering taken from the XSD. Use this when SQL
    # physical column order does not equal XSD xs:sequence order.
    table_element_order: dict[str, list[str]] = field(default_factory=dict)

    # Flattened almp.client columns that are serialized under <address>.
    address_columns: tuple[str, ...] = (
        "streetAddress",
        "municipality",
        "province",
        "country",
        "postalZIPCode",
        "contactPhoneNumber",
        "sysComment",
    )

    @property
    def xsd_dir(self) -> Path:
        return Path(self.lmta_root) / "reference" / "xsd" / "current"

    @property
    def generated_dir(self) -> Path:
        return Path(self.lmta_root) / "output" / "xml" / "generated"

    @property
    def rejected_dir(self) -> Path:
        return Path(self.lmta_root) / "output" / "xml" / "rejected"

    @property
    def submitted_dir(self) -> Path:
        return Path(self.lmta_root) / "output" / "xml" / "submitted"

    @property
    def validation_dir(self) -> Path:
        return Path(self.lmta_root) / "output" / "validation"


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

SORT_COLUMNS = (
    "sort_seq", "client_key", "action_plan_key", "followup_key",
    "intervention_key", "support_key", "sys_action_key",
)


# -----------------------------------------------------------------------------
# Fabric Warehouse connection, pure Python/ODBC
# -----------------------------------------------------------------------------
def get_fabric_access_token() -> bytes:
    """Return a SQL access token encoded for the SQL Server ODBC driver."""
    try:
        from notebookutils import mssparkutils
        token = mssparkutils.credentials.getToken("https://database.windows.net/")
    except Exception:
        try:
            from notebookutils import notebookutils
            token = notebookutils.credentials.getToken("https://database.windows.net/")
        except Exception as exc:
            raise RuntimeError(
                "Could not obtain a Fabric SQL access token. Run this from a "
                "Microsoft Fabric notebook under an identity that can read the "
                "LMTA Warehouse."
            ) from exc

    # SQL_COPT_SS_ACCESS_TOKEN expects UTF-16-LE token bytes preceded by length.
    token_bytes = token.encode("utf-16-le")
    return struct.pack(f"<I{len(token_bytes)}s", len(token_bytes), token_bytes)


def connect_to_warehouse(cfg: Config) -> pyodbc.Connection:
    """Open a token-authenticated connection to the LMTA Warehouse SQL endpoint."""
    connection_string = (
        f"Driver={{{cfg.odbc_driver}}};"
        f"Server={cfg.sql_server};"
        f"Database={cfg.sql_database};"
        "Encrypt=yes;TrustServerCertificate=no;"
    )
    sql_copt_ss_access_token = 1256
    return pyodbc.connect(
        connection_string,
        attrs_before={sql_copt_ss_access_token: get_fabric_access_token()},
        autocommit=True,
    )


def quote_object_name(object_name: str) -> str:
    """Safely quote a fixed schema.object name."""
    parts = object_name.split(".")
    if len(parts) != 2 or not all(re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", p) for p in parts):
        raise ValueError(f"Invalid SQL object name: {object_name}")
    return ".".join(f"[{p}]" for p in parts)


def table_columns(connection: pyodbc.Connection, object_name: str) -> list[str]:
    schema_name, table_name = object_name.split(".")
    sql = """
        SELECT COLUMN_NAME
        FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ?
        ORDER BY ORDINAL_POSITION;
    """
    rows = connection.cursor().execute(sql, schema_name, table_name).fetchall()
    return [row[0] for row in rows]


def read_submission_rows(
    connection: pyodbc.Connection,
    cfg: Config,
    object_name: str,
) -> list[dict[str, Any]]:
    columns = table_columns(connection, object_name)
    id_column = "submission_id" if "submission_id" in columns else "batch_id" if "batch_id" in columns else None
    if id_column is None:
        raise ValueError(f"{object_name} has neither submission_id nor batch_id")

    order_columns = [column for column in SORT_COLUMNS if column in columns]
    order_sql = " ORDER BY " + ", ".join(f"[{c}]" for c in order_columns) if order_columns else ""
    sql = (
        f"SELECT * FROM {quote_object_name(object_name)} "
        f"WHERE [{id_column}] = ?{order_sql};"
    )
    frame = pd.read_sql_query(sql, connection, params=[cfg.submission_id])
    frame = frame.astype(object).where(pd.notna(frame), None)
    return frame.to_dict(orient="records")


def collect_submission_rows(
    connection: pyodbc.Connection,
    cfg: Config,
) -> dict[str, list[dict[str, Any]]]:
    data = {
        logical_name: read_submission_rows(connection, cfg, object_name)
        for logical_name, object_name in TABLES.items()
    }
    if len(data["submission"]) != 1:
        raise ValueError(
            f"Expected exactly one almp.submission row for submission_id="
            f"{cfg.submission_id}; found {len(data['submission'])}."
        )
    return data


# -----------------------------------------------------------------------------
# General helpers
# -----------------------------------------------------------------------------
def is_null(value: Any) -> bool:
    return value is None or value is pd.NA


def xml_text(value: Any) -> str:
    if isinstance(value, pd.Timestamp):
        value = value.to_pydatetime()
    if isinstance(value, datetime):
        return value.isoformat(timespec="seconds")
    if isinstance(value, date):
        return value.isoformat()
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, Decimal):
        return format(value, "f")
    if isinstance(value, float):
        return str(int(value)) if value.is_integer() else format(value, ".15g")
    return str(value).strip()


def add_element(parent: etree._Element, tag: str, value: Any) -> etree._Element | None:
    if is_null(value) or xml_text(value) == "":
        return None
    child = etree.SubElement(parent, tag)
    child.text = xml_text(value)
    return child


def safe_file_component(value: str) -> str:
    return re.sub(r"[^A-Za-z0-9_.-]+", "_", value)


def ensure_directories(cfg: Config) -> None:
    for directory in (
        cfg.xsd_dir,
        cfg.generated_dir,
        cfg.rejected_dir,
        cfg.submitted_dir,
        cfg.validation_dir,
    ):
        directory.mkdir(parents=True, exist_ok=True)


# -----------------------------------------------------------------------------
# XML generation
# -----------------------------------------------------------------------------
def business_columns(row: dict[str, Any], cfg: Config, logical_table: str) -> list[str]:
    override = cfg.table_element_order.get(logical_table)
    if override:
        return [column for column in override if column in row]
    return [column for column in row if column.lower() not in TECHNICAL_COLUMNS]


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
    append_row_elements(root, data["submission"][0], cfg, "submission")

    for row in data["sys_action"]:
        node = etree.SubElement(root, "sysAction")
        append_row_elements(node, row, cfg, "sys_action")

    plans_by_client = rows_by(data["action_plan"], "client_key")
    followups_by_plan = rows_by(data["followup"], "action_plan_key")
    interventions_by_plan = rows_by(data["intervention"], "action_plan_key")
    supports_by_intervention = rows_by(data["support"], "intervention_key")

    for client in data["client"]:
        client_node = etree.SubElement(root, "client")
        address_columns = [c for c in cfg.address_columns if c in client]
        append_row_elements(client_node, client, cfg, "client", excluded=address_columns)

        if any(not is_null(client.get(c)) and xml_text(client.get(c)) for c in address_columns):
            address_node = etree.SubElement(client_node, "address")
            for column in address_columns:
                add_element(address_node, column, client.get(column))

        for plan in plans_by_client.get(client.get("client_key"), []):
            plan_node = etree.SubElement(client_node, "actionPlan")
            append_row_elements(plan_node, plan, cfg, "action_plan")
            plan_key = plan.get("action_plan_key")

            for followup in followups_by_plan.get(plan_key, []):
                node = etree.SubElement(plan_node, "actionPlanFollowUp")
                append_row_elements(node, followup, cfg, "followup")

            for intervention in interventions_by_plan.get(plan_key, []):
                intervention_node = etree.SubElement(plan_node, "intervention")
                append_row_elements(intervention_node, intervention, cfg, "intervention")
                for support in supports_by_intervention.get(intervention.get("intervention_key"), []):
                    node = etree.SubElement(intervention_node, "interventionSupport")
                    append_row_elements(node, support, cfg, "support")

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


def validate_xsd(xml_bytes: bytes, xsd_path: Path) -> list[dict[str, Any]]:
    if not xsd_path.exists():
        return [{
            "validation_type": "XSD",
            "severity": "ERROR",
            "message": f"XSD file not found: {xsd_path}",
        }]
    parser = etree.XMLParser(remove_blank_text=True, resolve_entities=False, no_network=True)
    xsd_doc = etree.parse(str(xsd_path), parser)
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
    total = 0
    for index, digit in enumerate(int(c) for c in sin):
        if index % 2 == 1:
            doubled = digit * 2
            total += doubled // 10 + doubled % 10
        else:
            total += digit
    return total % 10 == 0


def validate_content(data: dict[str, list[dict[str, Any]]]) -> list[dict[str, Any]]:
    errors: list[dict[str, Any]] = []
    plans_by_client = rows_by(data["action_plan"], "client_key")
    interventions_by_plan = rows_by(data["intervention"], "action_plan_key")
    followups_by_plan = rows_by(data["followup"], "action_plan_key")
    supports_by_intervention = rows_by(data["support"], "intervention_key")

    def issue(rule: str, entity: str, key: Any, column: str | None, message: str) -> None:
        errors.append({
            "validation_type": "CONTENT", "severity": "ERROR",
            "rule_code": rule, "entity_name": entity, "entity_key": key,
            "column_name": column, "message": message,
        })

    for client in data["client"]:
        key = client.get("client_key")
        sin_value = client.get("socialInsuranceNumber")
        sin = xml_text(sin_value) if not is_null(sin_value) else ""
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
# Output
# -----------------------------------------------------------------------------
def output_file_name(cfg: Config) -> str:
    prefix = "sklmda" if cfg.program_type.upper() == "LMDA" else "skwda"
    timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
    return f"{prefix}_{cfg.sequence_number:03d}_{timestamp}.xml"


def write_new_text(path: Path, text: str) -> None:
    """Create a new UTF-8 file and refuse accidental overwrites."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("x", encoding="utf-8", newline="\n") as handle:
        handle.write(text)


def run(cfg: Config) -> dict[str, Any]:
    """Run warehouse extraction, XML transformation, validation, and filing."""
    ensure_directories(cfg)
    connection = connect_to_warehouse(cfg)
    try:
        data = collect_submission_rows(connection, cfg)
    finally:
        connection.close()

    content_errors = validate_content(data)
    xml_tree = build_xml(data, cfg)
    xml_bytes = etree.tostring(
        xml_tree, pretty_print=True, xml_declaration=True,
        encoding="UTF-8", standalone=False,
    )

    validation_errors = validate_well_formed(xml_bytes)
    xsd_path = cfg.xsd_dir / cfg.main_xsd_name
    if not validation_errors:
        validation_errors.extend(validate_xsd(xml_bytes, xsd_path))
    validation_errors.extend(content_errors)

    is_valid = not validation_errors
    file_name = output_file_name(cfg)

    # First preserve the generated artifact. Then classify it by validation result.
    generated_path = cfg.generated_dir / file_name
    write_new_text(generated_path, xml_bytes.decode("utf-8"))

    final_dir = cfg.submitted_dir if is_valid else cfg.rejected_dir
    final_path = final_dir / file_name
    if final_path.exists():
        raise FileExistsError(f"Refusing to overwrite output: {final_path}")
    generated_path.replace(final_path)

    report_path = cfg.validation_dir / f"{file_name}.validation.json"
    report = {
        "submission_id": cfg.submission_id,
        "file_name": file_name,
        "xml_path": str(final_path),
        "classification": "submitted" if is_valid else "rejected",
        "xsd_path": str(xsd_path),
        "valid": is_valid,
        "validated_at": datetime.now().isoformat(timespec="seconds"),
        "row_counts": {name: len(rows) for name, rows in data.items()},
        "errors": validation_errors,
    }
    write_new_text(report_path, json.dumps(report, indent=2, default=str))

    if cfg.fail_on_validation_error and not is_valid:
        raise ValueError(
            f"ALMP XML validation failed with {len(validation_errors)} error(s). "
            f"Rejected XML: {final_path}; report: {report_path}"
        )
    return report


# -----------------------------------------------------------------------------
# Example Fabric notebook entry point
# -----------------------------------------------------------------------------
# 1. Attach ICT_DL1 as the notebook's DEFAULT Lakehouse.
# 2. Put ALMP.xsd and imported/included XSDs in:
#       Files/LMTA/reference/xsd/current/
# 3. Copy this script to:
#       Files/LMTA/code/python/almp_xml_export.py
# 4. In a notebook cell, load it with:
#       %run /lakehouse/default/Files/LMTA/code/python/almp_xml_export.py
# 5. Run:
#
# config = Config(
#     submission_id=101,
#     sql_server="<server copied from LMTA Warehouse SQL connection settings>",
#     sql_database="LMTA",
#     program_type="LMDA",
#     sequence_number=1,
#     table_element_order={
#         # Populate exact XSD xs:sequence order when required.
#         # "submission": ["SchemaVersion", "agreementHolderName", "sysComment"],
#     },
# )
# result = run(config)
# print(json.dumps(result, indent=2, default=str))
