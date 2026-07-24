from pathlib import Path
from lxml import etree
import re
import sys

XML_FILE = "input.xml"
XSD_FILE = "schema/ALMP.xsd" # or None if you want to skip schema validation
XSD_NAMESPACE = "http://www.w3.org/2001/XMLSchema"
XSD_NS = {"xsd": XSD_NAMESPACE}


def validate_well_formed(xml_path):
    try:
        doc = etree.parse(str(xml_path))
        print("OK: XML is well-formed")
        return doc
    except etree.XMLSyntaxError as e:
        print("ERROR: XML is not well-formed:", e)
        return None


def _gather_xsd_documents(xsd_path, visited=None):
    if visited is None:
        visited = set()

    xsd_path = Path(xsd_path).resolve()
    if xsd_path in visited:
        return []
    visited.add(xsd_path)

    try:
        xdoc = etree.parse(str(xsd_path))
    except Exception:
        return []

    docs = [(xsd_path, xdoc)]
    root = xdoc.getroot()
    if root is None:
        return docs

    for imp in root.xpath(
        ".//xsd:import | .//xsd:include | .//xsd:redefine",
        namespaces=XSD_NS,
    ):
        schema_location = imp.get('schemaLocation')
        if not schema_location:
            continue
        try:
            child_path = (xsd_path.parent / schema_location).resolve()
            docs.extend(_gather_xsd_documents(child_path, visited))
        except Exception:
            pass

    return docs


def load_schema(xsd_path):
    try:
        xdoc = etree.parse(str(xsd_path))
        schema = etree.XMLSchema(xdoc)
        xsd_docs = _gather_xsd_documents(xsd_path)
        return schema, xsd_docs
    except Exception as e:
        msg = str(e)
        print("ERROR: Failed to load XSD:", msg)
        # try to show reported XSD line number
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
        return None, None


def _extract_xsd_name_from_path(path):
    if not path:
        return None
    part = path.strip().split('/')[-1]
    if not part:
        return None
    part = part.split('[')[0]
    return part.split(':', 1)[-1]


def _find_xsd_nodes_by_name(xsd_doc, name):
    if not name:
        return []
    name = name.split(':', 1)[-1]
    root = xsd_doc.getroot()
    return root.xpath(
        ".//xsd:element[@name=$n] | .//xsd:attribute[@name=$n] | .//xsd:simpleType[@name=$n] | .//xsd:complexType[@name=$n] | .//xsd:group[@name=$n] | .//xsd:attributeGroup[@name=$n]",
        namespaces=XSD_NS,
        n=name,
    )


def _find_xsd_type_nodes(xsd_doc, type_name):
    if not type_name:
        return []
    type_name = type_name.split(':', 1)[-1]
    root = xsd_doc.getroot()
    return root.xpath(
        ".//xsd:simpleType[@name=$t] | .//xsd:complexType[@name=$t] | .//xsd:element[@type=$t] | .//xsd:attribute[@type=$t] | .//xsd:union[@memberTypes and contains(., $t)]",
        namespaces=XSD_NS,
        t=type_name,
    )


def _find_xsd_in_docs_by_name(xsd_docs, name):
    for path, doc in xsd_docs:
        found = _find_xsd_nodes_by_name(doc, name)
        if found:
            return path, found
    return None, []


def _find_xsd_in_docs_by_type(xsd_docs, type_name):
    for path, doc in xsd_docs:
        found = _find_xsd_type_nodes(doc, type_name)
        if found:
            return path, found
    return None, []


def _schema_origin(doc_path):
    name = Path(doc_path).name
    if name.lower() == 'almp.xsd':
        return 'ALMP'
    if name.lower() == 'almptypes.xsd':
        return 'ALMPTypes'
    return name


def find_xsd_reference(xsd_docs, error):
    candidates = []
    path_name = _extract_xsd_name_from_path(getattr(error, 'path', None))
    if path_name:
        candidates.append(path_name)

    message = getattr(error, 'message', '') or ''
    for pattern in [r"Element '([^']+)'", r"Attribute '([^']+)'", r"Type '([^']+)'", r"'([^']+)'"]:
        for match in re.findall(pattern, message):
            candidates.append(match)

    results = []
    seen = set()
    for name in dict.fromkeys(candidates):
        doc_path, found = _find_xsd_in_docs_by_name(xsd_docs, name)
        if found:
            first = found[0]
            if (doc_path, first) not in seen:
                results.append((doc_path, first))
                seen.add((doc_path, first))
            if first.tag.endswith('element') or first.tag.endswith('attribute'):
                type_attr = first.get('type')
                if type_attr:
                    type_doc_path, type_found = _find_xsd_in_docs_by_type(xsd_docs, type_attr)
                    if type_found and (type_doc_path, type_found[0]) not in seen:
                        results.append((type_doc_path, type_found[0]))
                        seen.add((type_doc_path, type_found[0]))
                child_type = first.find('.//xsd:simpleType', namespaces=XSD_NS)
                if child_type is not None and (doc_path, child_type) not in seen:
                    results.append((doc_path, child_type))
                    seen.add((doc_path, child_type))
            break

    if not results:
        for name in dict.fromkeys(candidates):
            doc_path, found = _find_xsd_in_docs_by_type(xsd_docs, name)
            if found and (doc_path, found[0]) not in seen:
                results.append((doc_path, found[0]))
                break

    return results


def show_error_context(xml_path, error, xml_doc, xsd_docs):
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
        line = xml_lines[src_line-1].strip()
        print(f"  XML Line {src_line}: {line}")
    else:
        print("  (No XML line available for this error)")

    if xsd_docs is None:
        return

    xsd_nodes = find_xsd_reference(xsd_docs, error)
    if not xsd_nodes:
        return

    sections = {'ALMP': [], 'ALMPTypes': [], 'OTHER': []}
    for doc_path, node in xsd_nodes:
        origin = _schema_origin(doc_path)
        if origin not in sections:
            origin = 'OTHER'
        sections[origin].append((doc_path, node))

    for section_name in ['ALMP', 'ALMPTypes', 'OTHER']:
        entries = sections[section_name]
        if not entries:
            continue

        for doc_path, node in entries:
            if node is None:
                continue

            line = getattr(node, 'sourceline', None)
            if line is not None:
                try:
                    with open(doc_path, 'r', encoding='utf-8') as f:
                        xsd_lines = f.readlines()
                    if 1 <= line <= len(xsd_lines):
                        xl = xsd_lines[line-1].strip()
                        print(f"  {doc_path.name} Line {line}: {xl}")
                except Exception:
                    pass


def validate_against_schema(xml_path, schema, xsd_path, xsd_docs):
    xml_doc = etree.parse(str(xml_path))
    if schema.validate(xml_doc):
        print("\nOK: XML validates against XSD")
        return True

    print("\nERROR: XML does not validate against XSD\n")
    for index, err in enumerate(schema.error_log, start=1):
        print(f"- {err.message} (line={err.line}, column={err.column})")
        show_error_context(xml_path, err, xml_doc, xsd_docs)
        if index < len(schema.error_log):
            print()
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

    schema, xsd_docs = load_schema(xsd_path)
    if not schema:
        sys.exit(1)

    ok = validate_against_schema(xml_path, schema, xsd_path, xsd_docs)
    sys.exit(0 if ok else 1)