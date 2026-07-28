"""Shared helpers: extract real KiCad symbol blocks + parse pin geometry.
Used by the ISLKey schematic generator and by test/render harnesses.
"""
import os, re, uuid

KICAD_SYM = r"C:\Program Files\KiCad\10.0\share\kicad\symbols"
LOCAL_SYM = r"C:\src\islkey\kicad\lib"   # project-local symbol libs (e.g. ISLKey.kicad_sym)
_cache = {}

def U():
    return str(uuid.uuid4())

def _read(lib):
    if lib not in _cache:
        for base in (LOCAL_SYM, KICAD_SYM):
            p = os.path.join(base, lib)
            if os.path.exists(p):
                with open(p, encoding="utf-8") as f:
                    _cache[lib] = f.read()
                break
        else:
            raise FileNotFoundError(lib)
    return _cache[lib]

def extract_symbol(lib, name):
    """Return the exact top-level (symbol \"name\" ...) block from a .kicad_sym."""
    txt = _read(lib)
    key = f'(symbol "{name}"'
    i = txt.find(key)
    if i < 0:
        raise ValueError(f"{name} not found in {lib}")
    depth = 0
    j = i
    while j < len(txt):
        c = txt[j]
        if c == '(':
            depth += 1
        elif c == ')':
            depth -= 1
            if depth == 0:
                break
        j += 1
    return txt[i:j + 1]

def rename_symbol(block, lib_id):
    """Rename the top symbol id to a full 'Lib:Name' id for embedding in a schematic."""
    return re.sub(r'^\(symbol "[^"]+"', f'(symbol "{lib_id}"', block, count=1)

def parse_pins(block):
    """Return list of dicts: number, name, x, y, angle, length (symbol-space mm)."""
    pins = []
    for m in re.finditer(
            r'\(pin\s+(\S+)\s+(\S+)\s+\(at\s+([-\d.]+)\s+([-\d.]+)\s+([-\d.]+)\)\s+'
            r'\(length\s+([-\d.]+)\)(.*?\(number\s+"([^"]*)")',
            block, re.DOTALL):
        typ, shape, x, y, a, l, tail, num = m.groups()
        nm = re.search(r'\(name\s+"([^"]*)"', tail)
        pins.append(dict(number=num, name=nm.group(1) if nm else "",
                         type=typ, x=float(x), y=float(y),
                         angle=float(a), length=float(l)))
    return pins
