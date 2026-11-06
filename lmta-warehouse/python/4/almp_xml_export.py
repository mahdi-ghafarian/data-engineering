"""ALMP XML generation, validation, and ICT_DL1 file output.

Hybrid Fabric design:
- Fabric notebook/PySpark reads one frozen submission from the LMTA Warehouse.
- This module receives ordinary Python rows and handles XML generation,
  XSD/content validation, and Lakehouse file output.
- This module intentionally contains no Spark or ODBC Warehouse access.
"""
from __future__ import annotations

import json
import re
from collections import defaultdict
from dataclasses import dataclass, field
from datetime import date, datetime
from decimal import Decimal
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence

from lxml import etree

ALMP_NS = "http://servicecanada.gc.ca/ALMP/contentExchange"
TYPE_NS = "http://servicecanada.gc.ca/ALMP/contentTypes"
XSI_NS = "http://www.w3.org/2001/XMLSchema-instance"
NSMAP = {"ALMP": ALMP_NS, "p": TYPE_NS, "xsi": XSI_NS}

TECHNICAL_COLUMNS = {
    "submission_id", "batch_id", "client_key", "action_plan_key",
    "followup_key", "intervention_key", "support_key", "sys_action_key",
    "sort_seq", "source_system", "source_key", "load_id",
    "source_as_of_date", "created_at", "updated_at", "loaded_at",
    "status", "period_start", "period_end", "reporting_frequency",
    "xml_file_name", "xml_path", "xsd_valid", "validation_status",
    "validation_message", "validated_at", "exported_at",
}

REQUIRED_DATASETS = (
    "submission", "sys_action", "client", "action_plan", "followup",
    "intervention", "support",
)


@dataclass(frozen=True)
class ExportConfig:
    submission_id: int
    program_type: str = "LMDA"
    sequence_number: int = 1
    lakehouse_root: str = "/lakehouse/default/Files/LMTA"
    main_xsd_name: str = "ALMP.xsd"
    fail_on_validation_error: bool = True
    table_element_order: Mapping[str, Sequence[str]] = field(default_factory=dict)
    address_columns: tuple[str, ...] = (
        "streetAddress", "municipality", "province", "country",
        "postalZIPCode", "contactPhoneNumber",
    )

    @property
    def root(self) -> Path:
        return Path(self.lakehouse_root)

    @property
    def xsd_dir(self) -> Path:
        return self.root / "reference" / "xsd" / "current"

    @property
    def generated_dir(self) -> Path:
        return self.root / "output" / "xml" / "generated"

    @property
    def rejected_dir(self) -> Path:
        return self.root / "output" / "xml" / "rejected"

    @property
    def submitted_dir(self) -> Path:
        return self.root / "output" / "xml" / "submitted"

    @property
    def validation_dir(self) -> Path:
        return self.root / "output" / "validation"


def xml_text(value: Any) -> str:
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
    if value is None:
        return None
    text = xml_text(value)
    if text == "":
        return None
    child = etree.SubElement(parent, tag)
    child.text = text
    return child


def business_columns(row: Mapping[str, Any], cfg: ExportConfig, dataset: str) -> list[str]:
    configured = cfg.table_element_order.get(dataset)
    if configured:
        return [column for column in configured if column in row]
    return [column for column in row if column.lower() not in TECHNICAL_COLUMNS]


def append_row_elements(parent: etree._Element, row: Mapping[str, Any], cfg: ExportConfig,
                        dataset: str, excluded: Iterable[str] = ()) -> None:
    excluded_set = set(excluded)
    for column in business_columns(row, cfg, dataset):
        if column not in excluded_set:
            add_element(parent, column, row.get(column))


def group_rows(rows: Sequence[Mapping[str, Any]], key: str) -> dict[Any, list[Mapping[str, Any]]]:
    grouped: dict[Any, list[Mapping[str, Any]]] = defaultdict(list)
    for row in rows:
        grouped[row.get(key)].append(row)
    return dict(grouped)


def validate_input(data: Mapping[str, Sequence[Mapping[str, Any]]], cfg: ExportConfig) -> None:
    missing = [name for name in REQUIRED_DATASETS if name not in data]
    if missing:
        raise ValueError(f"Missing input datasets: {', '.join(missing)}")
    if len(data["submission"]) != 1:
        raise ValueError(
            f"Expected exactly one submission row for submission_id={cfg.submission_id}; "
            f"found {len(data['submission'])}."
        )


def build_xml(data: Mapping[str, Sequence[Mapping[str, Any]]], cfg: ExportConfig) -> etree._ElementTree:
    validate_input(data, cfg)
    root = etree.Element(etree.QName(ALMP_NS, "contentALMP"), nsmap=NSMAP)
    append_row_elements(root, data["submission"][0], cfg, "submission")

    for row in data["sys_action"]:
        node = etree.SubElement(root, "sysAction")
        append_row_elements(node, row, cfg, "sys_action")

    plans_by_client = group_rows(data["action_plan"], "client_key")
    followups_by_plan = group_rows(data["followup"], "action_plan_key")
    interventions_by_plan = group_rows(data["intervention"], "action_plan_key")
    supports_by_intervention = group_rows(data["support"], "intervention_key")

    for client in data["client"]:
        client_node = etree.SubElement(root, "client")
        address_columns = [c for c in cfg.address_columns if c in client]
        append_row_elements(client_node, client, cfg, "client", excluded=address_columns)

        if any(client.get(c) is not None and xml_text(client.get(c)) for c in address_columns):
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


def luhn_valid(value: str) -> bool:
    if not re.fullmatch(r"\d{9}", value or ""):
        return False
    total = 0
    for index, digit in enumerate(int(c) for c in value):
        if index % 2:
            digit *= 2
            total += digit // 10 + digit % 10
        else:
            total += digit
    return total % 10 == 0


def validate_content(data: Mapping[str, Sequence[Mapping[str, Any]]]) -> list[dict[str, Any]]:
    errors: list[dict[str, Any]] = []
    plans_by_client = group_rows(data["action_plan"], "client_key")
    followups_by_plan = group_rows(data["followup"], "action_plan_key")
    interventions_by_plan = group_rows(data["intervention"], "action_plan_key")
    supports_by_intervention = group_rows(data["support"], "intervention_key")

    def issue(rule: str, entity: str, key: Any, column: str | None, message: str) -> None:
        errors.append({"validation_type": "CONTENT", "severity": "ERROR",
                       "rule_code": rule, "entity_name": entity, "entity_key": key,
                       "column_name": column, "message": message})

    for client in data["client"]:
        key = client.get("client_key")
        sin_value = client.get("socialInsuranceNumber")
        sin = xml_text(sin_value) if sin_value is not None else ""
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
            issue("INTERVENTION_DATE_ORDER", "intervention", key, "interventionEndDate",
                  "Intervention end date is before start date.")
    return errors


def validate_xsd(xml_bytes: bytes, xsd_path: Path) -> list[dict[str, Any]]:
    if not xsd_path.exists():
        return [{"validation_type": "XSD", "severity": "ERROR",
                 "message": f"XSD file not found: {xsd_path}"}]
    parser = etree.XMLParser(remove_blank_text=True, resolve_entities=False, no_network=True)
    try:
        xsd_document = etree.parse(str(xsd_path), parser)
        schema = etree.XMLSchema(xsd_document)
        xml_document = etree.fromstring(xml_bytes, parser)
    except (etree.XMLSyntaxError, etree.XMLSchemaParseError) as exc:
        return [{"validation_type": "XSD", "severity": "ERROR", "message": str(exc)}]
    if schema.validate(xml_document):
        return []
    return [{"validation_type": "XSD", "severity": "ERROR",
             "line": error.line, "column": error.column,
             "domain": error.domain_name, "type": error.type_name,
             "message": error.message} for error in schema.error_log]


def ensure_directories(cfg: ExportConfig) -> None:
    for path in (cfg.xsd_dir, cfg.generated_dir, cfg.rejected_dir,
                 cfg.submitted_dir, cfg.validation_dir):
        path.mkdir(parents=True, exist_ok=True)


def output_file_name(cfg: ExportConfig) -> str:
    program = cfg.program_type.upper()
    if program not in {"LMDA", "WDA"}:
        raise ValueError("program_type must be LMDA or WDA")
    prefix = "sklmda" if program == "LMDA" else "skwda"
    timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
    return f"{prefix}_{cfg.sequence_number:03d}_{timestamp}.xml"


def write_new(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("x", encoding="utf-8", newline="\n") as handle:
        handle.write(content)


def export_submission(data: Mapping[str, Sequence[Mapping[str, Any]]],
                      cfg: ExportConfig) -> dict[str, Any]:
    """Generate, validate, classify, and archive one ALMP XML submission."""
    ensure_directories(cfg)
    content_errors = validate_content(data)
    xml_tree = build_xml(data, cfg)
    xml_bytes = etree.tostring(xml_tree, pretty_print=True, xml_declaration=True,
                               encoding="UTF-8", standalone=False)

    xsd_path = cfg.xsd_dir / cfg.main_xsd_name
    validation_errors = validate_xsd(xml_bytes, xsd_path)
    validation_errors.extend(content_errors)
    valid = not validation_errors

    file_name = output_file_name(cfg)
    generated_path = cfg.generated_dir / file_name
    write_new(generated_path, xml_bytes.decode("utf-8"))

    destination = (cfg.submitted_dir if valid else cfg.rejected_dir) / file_name
    if destination.exists():
        raise FileExistsError(f"Refusing to overwrite: {destination}")
    generated_path.replace(destination)

    report = {
        "submission_id": cfg.submission_id,
        "file_name": file_name,
        "xml_path": str(destination),
        "classification": "submitted" if valid else "rejected",
        "xsd_path": str(xsd_path),
        "valid": valid,
        "validated_at": datetime.now().isoformat(timespec="seconds"),
        "row_counts": {name: len(data[name]) for name in REQUIRED_DATASETS},
        "errors": validation_errors,
    }
    report_path = cfg.validation_dir / f"{file_name}.validation.json"
    write_new(report_path, json.dumps(report, indent=2, default=str))
    report["validation_report_path"] = str(report_path)

    if cfg.fail_on_validation_error and not valid:
        raise ValueError(
            f"XML validation failed with {len(validation_errors)} error(s). "
            f"Rejected XML: {destination}; report: {report_path}"
        )
    return report
