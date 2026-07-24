from pathlib import Path
from lxml import etree
import sys

XML_FILE = "input.xml"
XSD_FILE = "schema/ALMP.xsd" # or None if you want to skip schema validation


def validate_well_formed(xml_path):
    try:
        doc = etree.parse(str(xml_path))
        print("OK: XML is well-formed")
        return doc
    except etree.XMLSyntaxError as e:
        print("ERROR: XML is not well-formed:", e)
        return None


def load_schema(xsd_path):
    try:
        xdoc = etree.parse(str(xsd_path))
        schema = etree.XMLSchema(xdoc)
        return schema
    except Exception as e:
        msg = str(e)
        print("ERROR: Failed to load XSD:", msg)
        # try to show reported XSD line number
        import re
        m = re.search(r"line\s+(\d+)", msg)
        if m:
            try:
                ln = int(m.group(1))
                with open(xsd_path, "r", encoding="utf-8") as f:
                    lines = f.readlines()
                if 1 <= ln <= len(lines):
                    print(f"XSD Line {ln}: {lines[ln-1].rstrip()} ")
            except Exception:
                pass
        return None


def show_error_context(xml_path, error, xml_doc, xsd_path):
    # Read xml lines
    try:
        with open(xml_path, "r", encoding="utf-8") as f:
            xml_lines = f.readlines()
    except Exception:
        xml_lines = []

    # Determine source line
    src_line = getattr(error, 'line', None)
    if src_line is None and hasattr(error, 'path') and error.path:
        try:
            found = xml_doc.xpath(error.path)
            if found:
                src_line = getattr(found[0], 'sourceline', None)
        except Exception:
            pass

    if src_line and 1 <= src_line <= len(xml_lines):
        line = xml_lines[src_line-1].rstrip('\n')
        print(f"XML Line {src_line}: {line}")
        if getattr(error, 'column', None):
            col = int(error.column)
            caret_pos = min(len(line.expandtabs(4)), max(0, col-1))
            print(' ' * (len(f"XML Line {src_line}: ")) + ' ' * caret_pos + '^')
            print()  # blank line after caret
    else:
        print("(No XML line available for this error)")

    # Try to show a matching XSD line by looking for quoted names in message
    if not xsd_path:
        return

    try:
        with open(xsd_path, "r", encoding="utf-8") as f:
            xsd_lines = f.readlines()
    except Exception:
        xsd_lines = []

    import re
    tokens = set(re.findall(r"'([^']+)'", error.message))
    # also try localname from QName forms {ns}local
    tokens.update(re.findall(r"\}([A-Za-z0-9_\.-]+)", error.message))

    for t in tokens:
        for i, xl in enumerate(xsd_lines):
            if f'name="{t}"' in xl or f'type="{t}"' in xl or f':{t}"' in xl or f'"{t}"' in xl:
                print(f"XSD Line {i+1}: {xl.rstrip()}")
                idx = xl.find(t)
                if idx != -1:
                    print(' ' * (len(f"XSD Line {i+1}: ")) + ' ' * idx + '^')
                print()  # blank line after XSD reference
                return


def validate_against_schema(xml_path, schema, xsd_path):
    xml_doc = etree.parse(str(xml_path))
    if schema.validate(xml_doc):
        print("\nOK: XML validates against XSD")
        return True

    print("\nERROR: XML does not validate against XSD\n")
    for err in schema.error_log:
        print(f"- {err.message} (line={err.line}, column={err.column})")
        show_error_context(xml_path, err, xml_doc, xsd_path)
        print()  # blank line between errors
    return False


if __name__ == '__main__':
    xml_path = Path(XML_FILE)
    xsd_path = Path(XSD_FILE) if XSD_FILE else None

    if not xml_path.exists():
        print("\nERROR: XML file not found", xml_path)
        sys.exit(1)

    doc = validate_well_formed(xml_path)
    if not doc:
        sys.exit(1)

    # If no XSD file provided, validation is complete
    if not xsd_path:
        print("\nINFO: No XSD file provided, skipping schema validation")
        sys.exit(0)

    if not xsd_path.exists():
        print("WARNING: XSD file not found", xsd_path)
        print("INFO: Skipping schema validation")
        sys.exit(0)

    schema = load_schema(xsd_path)
    if not schema:
        sys.exit(1)

    ok = validate_against_schema(xml_path, schema, xsd_path)
    sys.exit(0 if ok else 1)