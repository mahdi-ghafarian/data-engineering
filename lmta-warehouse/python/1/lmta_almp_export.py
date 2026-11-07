"""LMTA ALMP XML exporter for Microsoft Fabric.

Run from a Fabric PySpark notebook with ICT_DL1 attached as the default
Lakehouse. This module uses ordinary Python, pyodbc, and lxml. It does not use
Spark DataFrames.
"""
from __future__ import annotations

import json
import re
import struct
from datetime import date, datetime
from decimal import Decimal
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence

import pyodbc
from lxml import etree

MODULE_VERSION = "2026.11.06-6"

ALMP_NS = "http://servicecanada.gc.ca/ALMP/contentExchange"
TYPE_NS = "http://servicecanada.gc.ca/ALMP/contentTypes"
XSI_NS = "http://www.w3.org/2001/XMLSchema-instance"
NSMAP = {"ALMP": ALMP_NS, "p": TYPE_NS, "xsi": XSI_NS}

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
    "sort_seq", "client_key", "client_id", "action_plan_key", "action_plan_id",
    "followup_key", "action_plan_followup_id", "intervention_key",
    "intervention_id", "support_key", "intervention_support_id",
    "sys_action_key", "sys_action_id",
)

TECHNICAL_COLUMNS = {
    "submission_id", "batch_id", "client_key", "client_id",
    "action_plan_key", "action_plan_id", "followup_key",
    "action_plan_followup_id", "intervention_key", "intervention_id",
    "support_key", "intervention_support_id", "sys_action_key",
    "sys_action_id", "sort_seq", "source_system", "source_key", "load_id",
    "source_as_of_date", "created_at", "updated_at", "loaded_at", "status",
    "period_start", "period_end", "reporting_frequency", "xml_file_name",
    "xml_path", "xsd_valid", "validation_status", "validation_message",
    "validated_at", "exported_at",
}


class ExportConfig:
    def __init__(
        self,
        submission_id: int,
        sql_server: str,
        sql_database: str = "LMTA",
        odbc_driver: str = "ODBC Driver 18 for SQL Server",
        lmta_root: str = "/lakehouse/default/Files/LMTA",
        main_xsd_name: str = "ALMP.xsd",
        program_type: str = "LMDA",
        sequence_number: int = 1,
        fail_on_validation_error: bool = True,
        table_element_order: Mapping[str, Sequence[str]] | None = None,
        address_columns: Sequence[str] | None = None,
    ) -> None:
        self.submission_id = int(submission_id)
        self.sql_server = sql_server.strip()
        self.sql_database = sql_database.strip()
        self.odbc_driver = odbc_driver
        self.lmta_root = lmta_root.rstrip("/")
        self.main_xsd_name = main_xsd_name
        self.program_type = program_type.upper()
        self.sequence_number = int(sequence_number)
        self.fail_on_validation_error = bool(fail_on_validation_error)
        self.table_element_order = dict(table_element_order or {})
        self.address_columns = tuple(address_columns or (
            "streetAddress", "municipality", "province", "country",
            "postalZIPCode", "contactPhoneNumber", "addressSysComment",
        ))
        if not self.sql_server or "REPLACE-" in self.sql_server.upper():
            raise ValueError("Enter the actual LMTA Warehouse SQL server endpoint.")
        if self.program_type not in {"LMDA", "WDA"}:
            raise ValueError("program_type must be LMDA or WDA")

    @property
    def xsd_dir(self) -> Path:
        return Path(self.lmta_root) / "reference" / "xsd" / "current"

    @property
    def valid_dir(self) -> Path:
        return Path(self.lmta_root) / "output" / "xml" / "valid"

    @property
    def invalid_dir(self) -> Path:
        return Path(self.lmta_root) / "output" / "xml" / "invalid"

    @property
    def validation_dir(self) -> Path:
        return Path(self.lmta_root) / "output" / "validation"


def _fabric_token() -> str:
    errors = []
    try:
        from notebookutils import mssparkutils
        return mssparkutils.credentials.getToken("https://database.windows.net/")
    except Exception as exc:
        errors.append(f"mssparkutils: {exc}")
    try:
        from notebookutils import notebookutils
        return notebookutils.credentials.getToken("https://database.windows.net/")
    except Exception as exc:
        errors.append(f"notebookutils: {exc}")
    raise RuntimeError("Could not obtain Fabric SQL token. " + " | ".join(errors))


def _odbc_token_bytes(token: str) -> bytes:
    encoded = token.encode("utf-16-le")
    return struct.pack(f"<I{len(encoded)}s", len(encoded), encoded)


def connect_to_warehouse(cfg: ExportConfig) -> pyodbc.Connection:
    connection_string = (
        f"Driver={{{cfg.odbc_driver}}};Server={cfg.sql_server};"
        f"Database={cfg.sql_database};Encrypt=yes;TrustServerCertificate=no;"
        "Connection Timeout=30;"
    )
    return pyodbc.connect(
        connection_string,
        attrs_before={1256: _odbc_token_bytes(_fabric_token())},
        autocommit=True,
    )


def test_connection(cfg: ExportConfig) -> dict[str, Any]:
    connection = connect_to_warehouse(cfg)
    try:
        row = connection.cursor().execute(
            "SELECT TOP (1) submission_id FROM almp.submission ORDER BY submission_id DESC;"
        ).fetchone()
        return {
            "connected": True,
            "driver": connection.getinfo(pyodbc.SQL_DRIVER_NAME),
            "database": cfg.sql_database,
            "latest_submission_id": row[0] if row else None,
        }
    finally:
        connection.close()


def _quote_object_name(object_name: str) -> str:
    parts = object_name.split(".")
    if len(parts) != 2 or not all(re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", p) for p in parts):
        raise ValueError(f"Invalid SQL object name: {object_name}")
    return ".".join(f"[{part}]" for part in parts)


def _table_columns(connection: pyodbc.Connection, object_name: str) -> list[str]:
    schema_name, table_name = object_name.split(".")
    cursor = connection.cursor()
    try:
        rows = cursor.execute(
            """SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
               WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ?
               ORDER BY ORDINAL_POSITION;""",
            schema_name, table_name,
        ).fetchall()
        return [row[0] for row in rows]
    finally:
        cursor.close()


def _read_submission_rows(
    connection: pyodbc.Connection,
    cfg: ExportConfig,
    object_name: str,
) -> list[dict[str, Any]]:
    columns = _table_columns(connection, object_name)
    if not columns:
        raise ValueError(f"Warehouse object not found or not visible: {object_name}")
    if "submission_id" in columns:
        id_column = "submission_id"
    elif "batch_id" in columns:
        id_column = "batch_id"
    else:
        raise ValueError(f"{object_name} has neither submission_id nor batch_id")

    ordering = [column for column in SORT_COLUMNS if column in columns]
    order_clause = " ORDER BY " + ", ".join(f"[{c}]" for c in ordering) if ordering else ""
    sql = (
        f"SELECT * FROM {_quote_object_name(object_name)} "
        f"WHERE [{id_column}] = ?{order_clause};"
    )
    cursor = connection.cursor()
    try:
        cursor.execute(sql, cfg.submission_id)
        names = [description[0] for description in cursor.description]
        return [dict(zip(names, row)) for row in cursor.fetchall()]
    finally:
        cursor.close()


def read_submission(cfg: ExportConfig) -> dict[str, list[dict[str, Any]]]:
    connection = connect_to_warehouse(cfg)
    try:
        data = {
            logical_name: _read_submission_rows(connection, cfg, object_name)
            for logical_name, object_name in TABLES.items()
        }
    finally:
        connection.close()
    if len(data["submission"]) != 1:
        raise ValueError(
            f"Expected exactly one almp.submission row for submission_id={cfg.submission_id}; "
            f"found {len(data['submission'])}."
        )
    return data


def _xml_text(value: Any) -> str:
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


def _add_element(parent: etree._Element, tag: str, value: Any) -> None:
    if value is None:
        return
    text = _xml_text(value)
    if text == "":
        return
    child = etree.SubElement(parent, tag)
    child.text = text


def _business_columns(row: Mapping[str, Any], cfg: ExportConfig, dataset: str) -> list[str]:
    configured = cfg.table_element_order.get(dataset)
    if configured:
        return [column for column in configured if column in row]
    return [column for column in row if column.lower() not in TECHNICAL_COLUMNS]


def _append_row(
    parent: etree._Element,
    row: Mapping[str, Any],
    cfg: ExportConfig,
    dataset: str,
    excluded: Iterable[str] = (),
) -> None:
    excluded_set = set(excluded)
    columns = _business_columns(row, cfg, dataset)
    ordered_columns = (
        [column for column in columns if column != "sysComment"]
        + [column for column in columns if column == "sysComment"]
    )
    for column in ordered_columns:
        if column not in excluded_set:
            _add_element(parent, column, row.get(column))


def _first_present(row: Mapping[str, Any], candidates: Sequence[str]) -> Any:
    for column in candidates:
        if column in row:
            return row.get(column)
    return None


def _group_by_candidates(
    rows: Sequence[Mapping[str, Any]], candidates: Sequence[str]
) -> dict[Any, list[Mapping[str, Any]]]:
    grouped: dict[Any, list[Mapping[str, Any]]] = {}
    for row in rows:
        grouped.setdefault(_first_present(row, candidates), []).append(row)
    return grouped


def build_xml(
    data: Mapping[str, Sequence[Mapping[str, Any]]], cfg: ExportConfig
) -> etree._ElementTree:
    root = etree.Element(etree.QName(ALMP_NS, "contentALMP"), nsmap=NSMAP)
    _append_row(root, data["submission"][0], cfg, "submission")

    for row in data["sys_action"]:
        _append_row(etree.SubElement(root, "sysAction"), row, cfg, "sys_action")

    plans_by_client = _group_by_candidates(data["action_plan"], ("client_key", "client_id"))
    followups_by_plan = _group_by_candidates(data["followup"], ("action_plan_key", "action_plan_id"))
    interventions_by_plan = _group_by_candidates(data["intervention"], ("action_plan_key", "action_plan_id"))
    supports_by_intervention = _group_by_candidates(data["support"], ("intervention_key", "intervention_id"))

    for client in data["client"]:
        client_node = etree.SubElement(root, "client")
        address_columns = [column for column in cfg.address_columns if column in client]

        # The client sysComment follows its action plans; the address comment
        # remains nested inside address.
        excluded_client_columns = set(address_columns) | {"sysComment"}
        _append_row(client_node, client, cfg, "client", excluded=excluded_client_columns)

        if any(
            client.get(column) is not None and _xml_text(client.get(column))
            for column in address_columns
        ):
            address_node = etree.SubElement(client_node, "address")
            for column in address_columns:
                xml_name = "sysComment" if column == "addressSysComment" else column
                _add_element(address_node, xml_name, client.get(column))

        client_relation_id = _first_present(client, ("client_key", "client_id"))
        for plan in plans_by_client.get(client_relation_id, []):
            plan_node = etree.SubElement(client_node, "actionPlan")
            _append_row(plan_node, plan, cfg, "action_plan", excluded={"sysComment"})
            plan_relation_id = _first_present(plan, ("action_plan_key", "action_plan_id"))

            for followup in followups_by_plan.get(plan_relation_id, []):
                _append_row(
                    etree.SubElement(plan_node, "actionPlanFollowUp"),
                    followup, cfg, "followup",
                )

            for intervention in interventions_by_plan.get(plan_relation_id, []):
                intervention_node = etree.SubElement(plan_node, "intervention")
                post_support_columns = {
                    "interventionRelatedNOC",
                    "interventionRelatedNOCVersion",
                    "interventionLanguageOfService",
                    "interventionEssentialSkills",
                    "interventionCredential",
                    "sysComment",
                }
                intervention_columns = set(
                    _business_columns(intervention, cfg, "intervention")
                )
                _append_row(
                    intervention_node, intervention, cfg, "intervention",
                    excluded=post_support_columns,
                )
                intervention_relation_id = _first_present(
                    intervention, ("intervention_key", "intervention_id")
                )
                for support in supports_by_intervention.get(intervention_relation_id, []):
                    _append_row(
                        etree.SubElement(intervention_node, "interventionSupport"),
                        support, cfg, "support",
                    )
                _append_row(
                    intervention_node, intervention, cfg, "intervention",
                    excluded=(intervention_columns - post_support_columns) | {"sysComment"},
                )
                _add_element(intervention_node, "sysComment", intervention.get("sysComment"))
            _add_element(plan_node, "sysComment", plan.get("sysComment"))
        _add_element(client_node, "sysComment", client.get("sysComment"))
    return etree.ElementTree(root)


def _luhn_valid(value: str) -> bool:
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


def validate_content(
    data: Mapping[str, Sequence[Mapping[str, Any]]]
) -> list[dict[str, Any]]:
    errors: list[dict[str, Any]] = []
    plans = _group_by_candidates(data["action_plan"], ("client_key", "client_id"))
    followups = _group_by_candidates(data["followup"], ("action_plan_key", "action_plan_id"))
    interventions = _group_by_candidates(data["intervention"], ("action_plan_key", "action_plan_id"))
    supports = _group_by_candidates(data["support"], ("intervention_key", "intervention_id"))

    def issue(rule: str, entity: str, key: Any, column: str | None, message: str) -> None:
        errors.append({
            "validation_type": "CONTENT", "severity": "ERROR",
            "rule_code": rule, "entity_name": entity, "entity_key": key,
            "column_name": column, "message": message,
        })

    for client in data["client"]:
        key = _first_present(client, ("client_key", "client_id", "clientID"))
        relation_key = _first_present(client, ("client_key", "client_id"))
        sin_value = client.get("socialInsuranceNumber")
        sin = _xml_text(sin_value) if sin_value is not None else ""
        if sin and not _luhn_valid(sin):
            issue("CLIENT_SIN_MOD10", "client", key, "socialInsuranceNumber",
                  "SIN must contain nine digits and pass MOD 10.")
        if not plans.get(relation_key):
            issue("CLIENT_ACTION_PLAN_MIN_1", "client", key, None,
                  "Each client must contain at least one actionPlan.")

    for plan in data["action_plan"]:
        key = _first_present(plan, ("action_plan_key", "action_plan_id", "actionPlanID"))
        relation_key = _first_present(plan, ("action_plan_key", "action_plan_id"))
        if not interventions.get(relation_key):
            issue("ACTION_PLAN_INTERVENTION_MIN_1", "action_plan", key, None,
                  "Each actionPlan must contain at least one intervention.")
        if len(followups.get(relation_key, [])) > 5:
            issue("ACTION_PLAN_FOLLOWUP_MAX_5", "action_plan", key, None,
                  "An actionPlan can contain no more than five follow-ups.")

    for intervention in data["intervention"]:
        key = _first_present(
            intervention, ("intervention_key", "intervention_id", "interventionID")
        )
        relation_key = _first_present(intervention, ("intervention_key", "intervention_id"))
        if len(supports.get(relation_key, [])) > 10:
            issue("INTERVENTION_SUPPORT_MAX_10", "intervention", key, None,
                  "An intervention can contain no more than ten support rows.")
    return errors


def validate_xsd(xml_bytes: bytes, xsd_path: Path) -> list[dict[str, Any]]:
    if not xsd_path.exists():
        return [{"validation_type": "XSD", "severity": "ERROR",
                 "message": f"XSD file not found: {xsd_path}"}]
    parser = etree.XMLParser(remove_blank_text=True, resolve_entities=False, no_network=True)
    try:
        schema = etree.XMLSchema(etree.parse(str(xsd_path), parser))
        xml_document = etree.fromstring(xml_bytes, parser)
    except (etree.XMLSyntaxError, etree.XMLSchemaParseError) as exc:
        return [{"validation_type": "XSD", "severity": "ERROR", "message": str(exc)}]
    if schema.validate(xml_document):
        return []
    return [{
        "validation_type": "XSD", "severity": "ERROR",
        "line": error.line, "column": error.column,
        "domain": error.domain_name, "type": error.type_name,
        "message": error.message,
    } for error in schema.error_log]


def _ensure_directories(cfg: ExportConfig) -> None:
    for path in (cfg.xsd_dir, cfg.valid_dir, cfg.invalid_dir, cfg.validation_dir):
        path.mkdir(parents=True, exist_ok=True)


def _output_name(cfg: ExportConfig) -> str:
    prefix = "sklmda" if cfg.program_type == "LMDA" else "skwda"
    return f"{prefix}_{cfg.sequence_number:03d}_{datetime.now():%Y%m%d%H%M%S}.xml"


def _write_new(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("x", encoding="utf-8", newline="\n") as handle:
        handle.write(content)


def run_export(cfg: ExportConfig) -> dict[str, Any]:
    _ensure_directories(cfg)
    data = read_submission(cfg)
    xml_tree = build_xml(data, cfg)
    xml_bytes = etree.tostring(
        xml_tree, pretty_print=True, xml_declaration=True,
        encoding="UTF-8", standalone=False,
    )
    errors = validate_xsd(xml_bytes, cfg.xsd_dir / cfg.main_xsd_name)
    errors.extend(validate_content(data))
    valid = not errors

    file_name = _output_name(cfg)
    final_path = (cfg.valid_dir if valid else cfg.invalid_dir) / file_name
    if final_path.exists():
        raise FileExistsError(f"Refusing to overwrite: {final_path}")
    _write_new(final_path, xml_bytes.decode("utf-8"))

    report = {
        "module_version": MODULE_VERSION,
        "submission_id": cfg.submission_id,
        "file_name": file_name,
        "xml_path": str(final_path),
        "classification": "valid" if valid else "invalid",
        "xsd_path": str(cfg.xsd_dir / cfg.main_xsd_name),
        "valid": valid,
        "validated_at": datetime.now().isoformat(timespec="seconds"),
        "row_counts": {name: len(rows) for name, rows in data.items()},
        "errors": errors,
    }
    report_path = cfg.validation_dir / f"{file_name}.validation.json"
    _write_new(report_path, json.dumps(report, indent=2, default=str))
    report["validation_report_path"] = str(report_path)

    if cfg.fail_on_validation_error and not valid:
        raise ValueError(
            f"XML validation failed with {len(errors)} error(s). "
            f"Invalid XML: {final_path}; report: {report_path}"
        )
    return report
