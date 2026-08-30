#!/usr/bin/env python3
"""merge_ksystemstats.py — merge the @title (short label) translations from
ksystemstats_plugins.mo into the conky .po files, for all available languages.

Usage: python3 merge_ksystemstats.py
"""
import os
import subprocess
import sys
import re

LANG_DIR = "/usr/share/locale"
PO_DIR = os.path.expanduser("~/.conky/language")

# our languages that have a ksystemstats_plugins.mo counterpart
LANGS = ["ar","cs","da","de","es","fi","fr","hu","it","ja","ko",
         "nl","pl","pt","ro","ru","sv","tr","uk","zh_CN"]

def parse_mo_title_entries(mo_path):
    """Return list of (msgid, msgstr) for entries whose msgctxt is exactly '@title'."""
    raw = subprocess.run(
        ["msgunfmt", mo_path], capture_output=True, text=True
    ).stdout
    lines = raw.splitlines()
    entries = []
    i = 0
    n = len(lines)
    while i < n:
        line = lines[i]
        if line.startswith("msgctxt "):
            # determine the context string (could be multi-line)
            ctx = ""
            j = i
            while j < n:
                m = re.match(r'msgctxt "(.*)"', lines[j])
                if m:
                    ctx = m.group(1)
                elif re.match(r'"[^"]*"$', lines[j].strip()) and j > i:
                    inner = re.match(r'"([^"]*)"', lines[j].strip())
                    if inner:
                        ctx += inner.group(1)
                else:
                    break
                j += 1
            if ctx == "@title":
                # parse following msgid / msgstr (could be multi-line)
                msgid, msgstr = "", ""
                k = j
                while k < n:
                    km = re.match(r'msgid "(.*)"', lines[k])
                    if km:
                        msgid = km.group(1)
                        k += 1
                        while k < n and re.match(r'"[^"]*"$', lines[k].strip()):
                            inner = re.match(r'"[^"]*"', lines[k].strip())
                            msgid += inner.group(1)
                            k += 1
                        break
                    k += 1
                while k < n:
                    ks = re.match(r'msgstr "(.*)"', lines[k])
                    if ks:
                        msgstr = ks.group(1)
                        k += 1
                        while k < n and re.match(r'"[^"]*"$', lines[k].strip()):
                            inner = re.match(r'"[^"]*"', lines[k].strip())
                            msgstr += inner.group(1)
                            k += 1
                        break
                    k += 1
                entries.append((msgid, msgstr))
                i = k
                continue
            else:
                # advance past this entry
                i = j
                continue
        i += 1
    return entries

def existing_msgids(po_path):
    """Return set of msgids in an existing po file."""
    if not os.path.exists(po_path):
        return set()
    ids = set()
    with open(po_path, encoding="utf-8") as f:
        for line in f:
            m = re.match(r'msgid "(.*)"', line)
            if m:
                ids.add(m.group(1))
    return ids

def append_section(po_path, lang, entries):
    """Append the KDE System Stats section to the po file, skipping dupes."""
    existing = existing_msgids(po_path)
    added = 0
    with open(po_path, "a", encoding="utf-8") as f:
        f.write("\n############################################\n")
        f.write("# KDE SYSTEM STATS (short labels)\n")
        f.write("############################################\n\n")
        for msgid, msgstr in entries:
            if msgid in existing:
                continue
            if msgstr == "":
                msgstr = msgid
            f.write(f'msgid "{msgid}"\n')
            f.write(f'msgstr "{msgstr}"\n\n')
            existing.add(msgid)
            added += 1
    return added

def compile_mo(po_path):
    mo_path = os.path.splitext(po_path)[0] + ".mo"
    subprocess.run(
        ["msgfmt", po_path, "-o", mo_path], capture_output=True
    )
    return mo_path

def main():
    total = 0
    for lang in LANGS:
        mo = os.path.join(LANG_DIR, lang, "LC_MESSAGES", "ksystemstats_plugins.mo")
        if not os.path.exists(mo):
            print(f"[skip] {lang}: no ksystemstats_plugins.mo")
            continue
        entries = parse_mo_title_entries(mo)
        po = os.path.join(PO_DIR, f"{lang}.po")
        if not os.path.exists(po):
            print(f"[skip] {lang}: no {lang}.po")
            continue
        added = append_section(po, lang, entries)
        mo_out = compile_mo(po)
        total += added
        print(f"[ok] {lang}: +{added} new strings ({len(entries)} @title total) -> {os.path.basename(mo_out)}")
    print(f"\nDone. {total} strings merged total.")

if __name__ == "__main__":
    main()
