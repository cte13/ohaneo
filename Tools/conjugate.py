"""Korean verb and adjective conjugation for the three forms the app shows:
해요체 present (polite), 해요체 past (politePast) and 합니다체 present (formal).

Irregular classes are decided by rules and word lists, and confirmed against
the conjugated forms krdict lists where it has them. When krdict's 아/어 form
disagrees with the default rule, the other plausible classes are tried and
the one that matches krdict wins (this handles homonyms such as 묻다 "ask",
irregular, vs 묻다 "bury", regular).

Run directly for a self-test: python3 -I Tools/conjugate.py
"""

BASE = 0xAC00

# Vowel indices
A, AE, YA, YAE, EO, E, YEO, YE, O, WA, WAE, OE, YO, U, WO, WE, WI, YU, EU, UI, I = range(21)
# Final consonant indices
NONE, T_D, T_L, T_B, T_S, T_H = 0, 7, 8, 17, 19, 27
T_SS = 20
L_IEUNG = 11


def split(syllable):
    code = ord(syllable) - BASE
    if not 0 <= code < 11172:
        return None
    return code // 588, (code % 588) // 28, code % 28


def join(l, v, t=NONE):
    return chr(BASE + (l * 21 + v) * 28 + t)


def is_bright(v):
    return v in (A, O, YA)


def contract(stem_syllable, ending_is_a):
    """Join a vowel-final stem syllable with 아/어, returning the merged text."""
    l, v, t = split(stem_syllable)
    assert t == NONE
    merged = {
        A: A, EO: EO, AE: AE, E: E, YEO: YEO,
        O: WA, U: WO, I: YEO, OE: WAE,
    }.get(v)
    if merged is not None:
        return join(l, merged)
    return stem_syllable + ("아" if ending_is_a else "어")


# Word lists for irregular classes (stems, without 다).
B_IRREGULAR_VERBS = {"돕", "눕", "줍", "굽", "깁"}
B_REGULAR_ADJECTIVES = {"좁", "수줍"}
D_IRREGULAR = {"듣", "걷", "묻", "싣", "깨닫", "붇", "일컫", "긷", "알아듣", "엿듣", "캐묻", "되묻"}
S_IRREGULAR = {"짓", "낫", "붓", "잇", "긋", "젓"}
REU_EU_REGULAR = {"따르", "치르", "들르", "우러르", "다다르"}
REO_IRREGULAR = {"이르", "푸르", "누르"}
HONORIFIC_SI = {"계시", "주무시", "잡수시", "편찮으시"}
WA_B = {"돕", "곱"}
# Forms that don't follow from the stem (shortened from -하다 / -르다 words).
SPECIAL_AE = {"그러": "그래", "이러": "이래", "저러": "저래", "어쩌": "어째", "머물": "머물러"}


def ae_form(stem, cls):
    """The 아/어 form (e.g. 먹어, 가, 해, 어때) for a stem under an irregular class."""
    if stem.endswith("하"):
        return stem[:-1] + "해"
    for short, form in SPECIAL_AE.items():
        if stem.endswith(short):
            return stem[: -len(short)] + form
    *rest, last = stem
    prefix = "".join(rest)
    l, v, t = split(last)

    if cls == "b" and t == T_B:
        if stem in WA_B:
            return prefix + join(l, v) + "와"
        return prefix + join(l, v) + "워"
    if cls == "d" and t == T_D:
        return prefix + join(l, v, T_L) + ("아" if is_bright(v) else "어")
    if cls == "s" and t == T_S:
        return prefix + join(l, v) + ("아" if is_bright(v) else "어")
    if cls == "h" and t == T_H:
        new_v = {A: AE, EO: AE, YA: YAE, YEO: YAE}.get(v, AE)
        return prefix + join(l, new_v)
    if cls == "reu" and last == "르" and rest:
        pl, pv, pt = split(rest[-1])
        return "".join(rest[:-1]) + join(pl, pv, T_L) + ("라" if is_bright(pv) else "러")
    if cls == "reo" and last == "르":
        return stem + "러"
    if cls == "u" and stem == "푸":
        return "퍼"

    if t != NONE:
        return stem + ("아" if is_bright(v) else "어")
    if v == EU:
        # ㅡ drops; 아/어 follows the previous syllable (one syllable: 어).
        bright = bool(rest) and is_bright(split(rest[-1])[1])
        return prefix + join(l, A if bright else EO)
    return prefix + contract(last, is_bright(v))


def default_class(stem, is_adjective):
    *_, last = stem
    _, _, t = split(last)
    if stem.endswith("하"):
        return "regular"
    if t == T_B:
        if is_adjective:
            return "regular" if stem in B_REGULAR_ADJECTIVES else "b"
        return "b" if stem in B_IRREGULAR_VERBS else "regular"
    if t == T_D:
        return "d" if stem in D_IRREGULAR or any(stem.endswith(s) for s in ("듣",)) else "regular"
    if t == T_S:
        return "s" if any(stem.endswith(x) for x in S_IRREGULAR) else "regular"
    if t == T_H:
        return "h" if is_adjective and stem != "좋" and not stem.endswith("좋") else "regular"
    if last == "르" and len(stem) > 1:
        if stem in REO_IRREGULAR:
            return "reo"
        return "regular" if stem in REU_EU_REGULAR or any(stem.endswith(s) for s in REU_EU_REGULAR) else "reu"
    if stem == "푸":
        return "u"
    return "regular"


def add_batchim(text, t):
    l, v, old = split(text[-1])
    assert old == NONE, text
    return text[:-1] + join(l, v, t)


def formal(stem):
    l, v, t = split(stem[-1])
    if t == NONE:
        return stem[:-1] + join(l, v, T_B) + "니다"
    if t == T_L:
        return stem[:-1] + join(l, v, T_B) + "니다"
    return stem + "습니다"


def normalize_krdict(form):
    """Contract krdict's uncontracted 아/어 forms (어기어 → 어겨, 어색하여 → 어색해)."""
    if form.endswith("하여"):
        return form[:-2] + "해"
    if len(form) >= 2 and form[-1] in ("아", "어"):
        prev = split(form[-2])
        if prev and prev[2] == NONE:
            l, v, _ = prev
            if v == EU:
                return form[:-2] + join(l, A if form[-1] == "아" else EO)
            return form[:-2] + contract(form[-2], form[-1] == "아")
    return form


def krdict_ae(krdict_forms):
    """Pick krdict's 아/어 form from its list of conjugated forms."""
    for f in krdict_forms:
        if f.endswith("하여"):
            return f
        last = split(f[-1]) if f else None
        if not last or f.endswith("니") or f.endswith("니다"):
            continue
        _, v, t = last
        if t == NONE and v in (A, EO, AE, YEO, WA, WO, WAE, YAE, E):
            return f
    return None


def forms(word, is_adjective, krdict_forms=()):
    """Returns {"forms": {...}, "checked": True/False/None} or None."""
    if not word.endswith("다") or len(word) < 2:
        return None
    stem = word[:-1]
    if any(split(ch) is None for ch in stem):
        return None

    if word == "아니다":
        return {"forms": {"polite": "아니에요", "politePast": "아니었어요", "formal": "아닙니다"}, "checked": None}
    if stem in HONORIFIC_SI:
        base = stem[:-1]
        return {"forms": {"polite": base + "세요", "politePast": base + "셨어요", "formal": base + "십니다"}, "checked": None}

    cls = default_class(stem, is_adjective)
    ae = ae_form(stem, cls)
    checked = None
    reference = krdict_ae(krdict_forms)
    if reference:
        expected = normalize_krdict(reference)
        if ae == expected or normalize_krdict(ae) == expected:
            checked = True
        else:
            for other in ("regular", "b", "d", "s", "h", "reu", "reo", "u"):
                try:
                    candidate = ae_form(stem, other)
                except (AssertionError, TypeError):
                    continue
                if candidate == expected:
                    ae, checked = candidate, True
                    break
            else:
                checked = False

    return {
        "forms": {
            "polite": ae + "요",
            "politePast": add_batchim(ae, T_SS) + "어요",
            "formal": formal(stem),
        },
        "checked": checked,
    }


if __name__ == "__main__":
    cases = {
        ("가다", False): ("가요", "갔어요", "갑니다"),
        ("먹다", False): ("먹어요", "먹었어요", "먹습니다"),
        ("하다", False): ("해요", "했어요", "합니다"),
        ("공부하다", False): ("공부해요", "공부했어요", "공부합니다"),
        ("오다", False): ("와요", "왔어요", "옵니다"),
        ("보다", False): ("봐요", "봤어요", "봅니다"),
        ("마시다", False): ("마셔요", "마셨어요", "마십니다"),
        ("되다", False): ("돼요", "됐어요", "됩니다"),
        ("주다", False): ("줘요", "줬어요", "줍니다"),
        ("배우다", False): ("배워요", "배웠어요", "배웁니다"),
        ("쓰다", False): ("써요", "썼어요", "씁니다"),
        ("바쁘다", True): ("바빠요", "바빴어요", "바쁩니다"),
        ("예쁘다", True): ("예뻐요", "예뻤어요", "예쁩니다"),
        ("살다", False): ("살아요", "살았어요", "삽니다"),
        ("만들다", False): ("만들어요", "만들었어요", "만듭니다"),
        ("춥다", True): ("추워요", "추웠어요", "춥습니다"),
        ("돕다", False): ("도와요", "도왔어요", "돕습니다"),
        ("입다", False): ("입어요", "입었어요", "입습니다"),
        ("좁다", True): ("좁아요", "좁았어요", "좁습니다"),
        ("듣다", False): ("들어요", "들었어요", "듣습니다"),
        ("받다", False): ("받아요", "받았어요", "받습니다"),
        ("짓다", False): ("지어요", "지었어요", "짓습니다"),
        ("웃다", False): ("웃어요", "웃었어요", "웃습니다"),
        ("모르다", False): ("몰라요", "몰랐어요", "모릅니다"),
        ("부르다", False): ("불러요", "불렀어요", "부릅니다"),
        ("따르다", False): ("따라요", "따랐어요", "따릅니다"),
        ("어떻다", True): ("어때요", "어땠어요", "어떻습니다"),
        ("그렇다", True): ("그래요", "그랬어요", "그렇습니다"),
        ("하얗다", True): ("하얘요", "하얬어요", "하얗습니다"),
        ("좋다", True): ("좋아요", "좋았어요", "좋습니다"),
        ("넣다", False): ("넣어요", "넣었어요", "넣습니다"),
        ("쉬다", False): ("쉬어요", "쉬었어요", "쉽니다"),
        ("기다리다", False): ("기다려요", "기다렸어요", "기다립니다"),
        ("보내다", False): ("보내요", "보냈어요", "보냅니다"),
        ("켜다", False): ("켜요", "켰어요", "켭니다"),
        ("서다", False): ("서요", "섰어요", "섭니다"),
        ("아니다", True): ("아니에요", "아니었어요", "아닙니다"),
        ("계시다", False): ("계세요", "계셨어요", "계십니다"),
        ("있다", False): ("있어요", "있었어요", "있습니다"),
        ("아름답다", True): ("아름다워요", "아름다웠어요", "아름답습니다"),
        ("푸르다", True): ("푸르러요", "푸르렀어요", "푸릅니다"),
        ("크다", True): ("커요", "컸어요", "큽니다"),
        ("아프다", True): ("아파요", "아팠어요", "아픕니다"),
        ("걷다", False): ("걸어요", "걸었어요", "걷습니다"),
        ("낫다", True): ("나아요", "나았어요", "낫습니다"),
        ("푸다", False): ("퍼요", "펐어요", "풉니다"),
        ("그러다", False): ("그래요", "그랬어요", "그럽니다"),
        ("머물다", False): ("머물러요", "머물렀어요", "머뭅니다"),
        ("농사짓다", False): ("농사지어요", "농사지었어요", "농사짓습니다"),
        ("씻다", False): ("씻어요", "씻었어요", "씻습니다"),
    }
    failures = 0
    for (word, adj), expected in cases.items():
        got = forms(word, adj)["forms"]
        got = (got["polite"], got["politePast"], got["formal"])
        if got != expected:
            failures += 1
            print(f"FAIL {word}: {got} != {expected}")
    # krdict disambiguation: 묻다 "bury" is regular, krdict lists 묻어.
    assert forms("묻다", False, ["묻는", "묻어", "묻으니"])["forms"]["polite"] == "묻어요"
    assert forms("묻다", False)["forms"]["polite"] == "물어요"
    assert forms("어떻다", True, ["어떤", "어때", "어떠니", "어떻습니다"])["checked"] is True
    print(f"{len(cases) - failures}/{len(cases)} passed")
    raise SystemExit(1 if failures else 0)
