#!/usr/bin/env python3
"""Erzeugt BananaCraft_DeNames.lua: englischer Rezeptname -> deutscher Itemname.

Aufruf:  python3 -I tools/gen_denames.py <BananaCraft_ItemDB_deDE.lua> BananaCraft_DeNames.lua

Die ItemDB (ID -> {Englisch, Deutsch}, Quelle wowhead.com/classic/de) ist ~1,8 MB gross und wird
nicht ausgeliefert. Hier wird nur der Teil uebernommen, der zu Zeilen des Katalogs gehoert
(Items, die ein Beruf herstellt).
"""
import re, sys

item_db, out = sys.argv[1], sys.argv[2]
names = {}
for ln in open(item_db, encoding="utf-8"):
    m = re.match(r'^\s*\[(\d+)\] = \{ "((?:[^"\\]|\\.)*)", "((?:[^"\\]|\\.)*)" \},$', ln)
    if m and not m.group(2).startswith("OLD") and m.group(2) != m.group(3):
        names[int(m.group(1))] = m.group(3)

craft = {}
section = None
rows = []   # (kind, id, name)
for ln in open("BananaCraft_Catalog.lua", encoding="utf-8"):
    if ln.startswith("BCRAFT_CraftSpells"): section = "spells"
    elif ln.startswith("BCRAFT_Enchants"): section = "enchants"
    elif ln.startswith("BCRAFT_Catalog"): section = "catalog"
    m = re.match(r'^\[(\d+)\]=\{(\d+),', ln)
    if section == "spells" and m: craft[int(m.group(1))] = int(m.group(2))
    m = re.match(r'^\{"([sei])",(\d+),"[^"]*",\d+,"((?:[^"\\]|\\.)*)"', ln)
    if section == "catalog" and m: rows.append((m.group(1), int(m.group(2)), m.group(3)))

res = {}
for kind, num, name in rows:
    item = craft.get(num, 0) if kind == "s" else (num if kind == "i" else 0)
    de = names.get(item)
    if de and de != name and name not in res: res[name] = de

def q(s): return '"%s"' % s.replace("\\", "\\\\").replace('"', '\\"')
with open(out, "w", encoding="utf-8", newline="\n") as f:
    f.write("-- BananaCraft -- deutsche Namen der Katalog-Rezepte (generiert von tools/gen_denames.py, nicht von Hand aendern)\n")
    f.write("-- Quelle der Namen: wowhead.com/classic/de. [englischer Katalogname] = deutscher Itemname\n")
    f.write("BCRAFT_DeNames = {\n")
    for k in sorted(res): f.write("[%s]=%s,\n" % (q(k), q(res[k])))
    f.write("}\n")
print("Namen:", len(res), "von", len(set(r[2] for r in rows)), "Katalogzeilen")
