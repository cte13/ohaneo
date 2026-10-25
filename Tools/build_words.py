#!/usr/bin/env python3
"""Build OhaneoCore/Resources/words.json from two NIKL sources.

Inputs (download once, not committed):
  1. NIKL 한국어 학습용 어휘 목록 (2003), KOGL Type 1.
     https://www.korean.go.kr/front_eng/down/down_02V.do?etc_seq=70
     Tab-separated, CP949: 순위, 단어, 품사, 풀이, 등급 (A/B/C).
  2. NIKL 한국어기초사전 (krdict) XML dump, CC BY-SA 2.0 KR.
     https://krdict.korean.go.kr (mirror: github.com/spellcheck-ko/korean-dict-nikl-krdict)

The NIKL list picks the words and their order (level, then frequency).
krdict supplies the English meaning and definition, Hanja, and a stable entry ID.

Usage:
  python3 -I Tools/build_words.py --nikl nikl.txt --krdict-dir xml/ --out words.json
"""

import argparse
import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

POS_MAP = {
    "명": "명사",
    "동": "동사",
    "형": "형용사",
    "부": "부사",
    "대": "대명사",
    "수": "수사",
    "관": "관형사",
    "감": "감탄사",
}
POS_ENGLISH = {
    "명사": "noun",
    "동사": "verb",
    "형용사": "adjective",
    "부사": "adverb",
    "대명사": "pronoun",
    "수사": "numeral",
    "관형사": "determiner",
    "감탄사": "interjection",
}
GRADE_LEVEL = {"A": "beginner", "B": "intermediate", "C": "advanced"}
GRADE_ORDER = {"A": 0, "B": 1, "C": 2}
CJK = re.compile(r"[㐀-鿿豈-﫿]")


def feats(elem):
    """Direct <feat att=... val=...> children as a dict (first value wins)."""
    out = {}
    for f in elem.findall("feat"):
        out.setdefault(f.get("att"), f.get("val"))
    return out


def load_krdict(directory):
    """Map (writtenForm, partOfSpeech) -> list of entries."""
    index = {}
    files = sorted(Path(directory).glob("*.xml"), key=lambda p: int(p.stem))
    for path in files:
        # Some dump chunks contain unescaped "<" or ">" inside attribute values.
        text = Path(path).read_text(encoding="utf-8")
        text = re.sub(
            r'val="([^"]*)"',
            lambda m: 'val="' + m.group(1).replace("<", "&lt;").replace(">", "&gt;") + '"',
            text,
        )
        parser = ET.XMLPullParser(events=("end",))
        parser.feed(text)
        parser.close()
        for _, elem in parser.read_events():
            if elem.tag != "LexicalEntry":
                continue
            f = feats(elem)
            lemma = elem.find("Lemma")
            form = feats(lemma).get("writtenForm") if lemma is not None else None
            if form and f.get("lexicalUnit") == "단어":
                senses = []
                for sense in elem.findall("Sense"):
                    for eq in sense.findall("Equivalent"):
                        ef = feats(eq)
                        if ef.get("language") == "영어" and ef.get("lemma"):
                            senses.append((ef["lemma"], ef.get("definition")))
                            break
                entry = {
                    "id": elem.get("val"),
                    "form": form,
                    "pos": f.get("partOfSpeech"),
                    "homonym": int(f.get("homonym_number") or 0),
                    "level": f.get("vocabularyLevel"),
                    "origin": f.get("origin"),
                    "category": f.get("semanticCategory"),
                    "senses": senses,
                }
                index.setdefault((form, entry["pos"]), []).append(entry)
            elem.clear()
    return index


def load_nikl(path):
    raw = Path(path).read_bytes()
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError:
        text = raw.decode("cp949")
    rows = []
    for line in text.splitlines()[1:]:
        parts = line.split("\t")
        if len(parts) < 5 or not parts[0].strip().isdigit():
            continue
        freq, word, pos, note, grade = (p.strip() for p in parts[:5])
        rows.append(
            {
                "freq": int(freq),
                "word": re.sub(r"\d+$", "", word),
                "pos": pos,
                "hanja": note if CJK.search(note or "") else None,
                "grade": grade,
            }
        )
    return rows


def pick(candidates, hanja):
    """Choose the krdict entry for one NIKL row."""
    with_english = [c for c in candidates if c["senses"]]
    if not with_english:
        return None
    if hanja:
        key = re.sub(r"[^㐀-鿿豈-﫿]", "", hanja)
        matches = [
            c for c in with_english
            if c["origin"] and re.sub(r"[^㐀-鿿豈-﫿]", "", c["origin"]) == key
        ]
        if matches:
            with_english = matches
    leveled = [c for c in with_english if c["level"] in ("초급", "중급", "고급")]
    pool = leveled or with_english
    return min(pool, key=lambda c: c["homonym"])


def clean_meaning(lemma):
    parts = [p.strip() for p in lemma.split(";") if p.strip()]
    return ", ".join(dict.fromkeys(parts))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--nikl", required=True)
    ap.add_argument("--krdict-dir", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    index = load_krdict(args.krdict_dir)
    rows = load_nikl(args.nikl)
    rows.sort(key=lambda r: (GRADE_ORDER.get(r["grade"], 9), r["freq"]))

    items, seen, unmatched = [], set(), []
    for row in rows:
        pos = POS_MAP.get(row["pos"])
        if not pos or row["grade"] not in GRADE_LEVEL:
            continue
        entry = pick(index.get((row["word"], pos), []), row["hanja"])
        if entry is None:
            unmatched.append(f'{row["word"]} ({row["pos"]})')
            continue
        seed_id = f'w:{entry["id"]}'
        if seed_id in seen:
            continue
        seen.add(seed_id)
        meaning_lemma, definition = entry["senses"][0]
        origin = entry["origin"] if entry["origin"] and CJK.search(entry["origin"]) else None
        items.append(
            {
                "id": seed_id,
                "korean": row["word"],
                "kind": "word",
                "meaning": clean_meaning(meaning_lemma),
                "definition": definition,
                "partOfSpeech": POS_ENGLISH[pos],
                "hanja": origin,
                "level": GRADE_LEVEL[row["grade"]],
                "rank": len(items) + 1,
                "topics": [],
                "category": entry["category"],
            }
        )

    out = {
        "version": 1,
        "source": (
            "Word list and levels: 국립국어원 「한국어 학습용 어휘 목록」 (2003), KOGL Type 1. "
            "Meanings, definitions and Hanja: 국립국어원 「한국어기초사전」, CC BY-SA 2.0 KR."
        ),
        "license": "CC BY-SA 2.0 KR",
        "items": items,
    }
    Path(args.out).write_text(json.dumps(out, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print(f"wrote {len(items)} words; {len(unmatched)} unmatched", file=sys.stderr)
    if unmatched:
        print("unmatched sample: " + ", ".join(unmatched[:40]), file=sys.stderr)


if __name__ == "__main__":
    main()
