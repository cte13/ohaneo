"""Generates grammar.json. Run: python3 -I Tools/build_grammar.py OhaneoCore/Sources/OhaneoCore/Resources/grammar.json"""
import json
import sys

SRC = "Draft. Level and order follow the usual 초급/중급 textbook sequence; verify against 국제 통용 한국어 교육 표준 모형 (2017) and 한국어기초사전."
items = []


def g(id, pattern, meaning, level, order, formation, prereq=(), contrasts=(), register=None, mistake=None, assumed=False):
    items.append({
        "id": "g:" + id,
        "pattern": pattern,
        "meaning": meaning,
        "level": level,
        "order": order,
        "prerequisites": ["g:" + p for p in prereq],
        "contrasts": [{"patternID": "g:" + c, "note": n} for c, n in contrasts],
        "formation": [{"appliesTo": a, "form": f, "example": e} for a, f, e in formation],
        "register": register,
        "commonMistake": mistake,
        "assumedKnown": assumed,
        "checked": False,
        "source": SRC,
    })


B, I = "beginner", "intermediate"

# ---- Assumed known (never shown as daily items) ----
g("ayo", "-아/어요", "polite informal sentence ending (present)", B, 10,
  [("verb", "-아/어요", "가요 / 먹어요"), ("adjective", "-아/어요", "좋아요"), ("noun", "이에요/예요", "학생이에요 / 의사예요"), ("past", "-았/었어요", "갔어요")],
  register="The everyday polite style used with most adults.", assumed=True)
g("seumnida", "-(스)ㅂ니다", "formal polite sentence ending", B, 20,
  [("verb", "-(스)ㅂ니다", "갑니다 / 먹습니다"), ("adjective", "-(스)ㅂ니다", "좋습니다"), ("noun", "입니다", "학생입니다"), ("past", "-았/었습니다", "갔습니다")],
  register="Formal: news, announcements, presentations, the military, first meetings at work.", assumed=True)
g("at", "-았/었-", "past tense", B, 30,
  [("verb", "-았/었-", "갔어요 / 먹었어요"), ("adjective", "-았/었-", "좋았어요"), ("noun", "이었/였-", "학생이었어요 / 의사였어요")],
  assumed=True)
g("go", "-고", "and (links actions or descriptions)", B, 40,
  [("verb", "-고", "먹고"), ("adjective", "-고", "싸고"), ("noun", "이고", "학생이고"), ("past", "-았/었고", "갔고")],
  assumed=True)
g("go-sipda", "-고 싶다", "want to do", B, 50,
  [("verb", "-고 싶다", "가고 싶어요")],
  register="For someone else's wish, use -고 싶어하다: 동생이 가고 싶어해요.", assumed=True)
g("an", "안 / -지 않다", "not (negation)", B, 60,
  [("verb", "안 + verb / -지 않다", "안 가요 / 가지 않아요"), ("adjective", "안 + adjective / -지 않다", "안 좋아요 / 좋지 않아요")],
  assumed=True)
g("mot", "못 / -지 못하다", "can't (lack of ability or circumstances prevent it)", B, 70,
  [("verb", "못 + verb / -지 못하다", "못 가요 / 가지 못해요")],
  assumed=True)
g("euseyo", "-(으)세요", "polite request, or honorific present", B, 80,
  [("verb", "-(으)세요", "가세요 / 읽으세요"), ("adjective", "-(으)세요", "바쁘세요?"), ("noun", "(이)세요", "선생님이세요?")],
  assumed=True)
g("eul-geoyeyo", "-(으)ㄹ 거예요", "future plan or guess", B, 90,
  [("verb", "-(으)ㄹ 거예요", "갈 거예요 / 먹을 거예요"), ("adjective", "-(으)ㄹ 거예요", "좋을 거예요"), ("noun", "일 거예요", "학생일 거예요")],
  assumed=True)
g("go-itda", "-고 있다", "be doing (action in progress)", B, 100,
  [("verb", "-고 있다", "먹고 있어요")], assumed=True)
g("eul-su-itda", "-(으)ㄹ 수 있다/없다", "can / can't", B, 110,
  [("verb", "-(으)ㄹ 수 있다/없다", "갈 수 있어요 / 먹을 수 없어요")], assumed=True)
g("aya-hada", "-아/어야 하다/되다", "have to, must", B, 120,
  [("verb", "-아/어야 하다", "가야 해요 / 먹어야 돼요"), ("adjective", "-아/어야 하다", "커야 해요"), ("noun", "이어야/여야 하다", "학생이어야 해요")],
  assumed=True)
g("jiman", "-지만", "but", B, 130,
  [("verb", "-지만", "가지만"), ("adjective", "-지만", "좋지만"), ("noun", "이지만", "학생이지만"), ("past", "-았/었지만", "갔지만")],
  assumed=True)
g("eureo", "-(으)러 가다/오다", "go/come in order to do", B, 140,
  [("verb", "-(으)러 가다", "먹으러 가요 / 보러 와요")],
  register="Only with movement verbs such as 가다, 오다, 다니다.", assumed=True)
g("eumyeon", "-(으)면", "if, when", B, 150,
  [("verb", "-(으)면", "가면 / 먹으면"), ("adjective", "-(으)면", "좋으면"), ("noun", "(이)면", "학생이면")],
  assumed=True)
g("eulgeyo", "-(으)ㄹ게요", "I'll do it (promise or decision, considering the listener)", B, 160,
  [("verb", "-(으)ㄹ게요", "갈게요 / 먹을게요")], assumed=True)
g("eulkkayo", "-(으)ㄹ까요?", "shall we…? / do you think…?", B, 170,
  [("verb", "-(으)ㄹ까요?", "갈까요? / 먹을까요?"), ("adjective", "-(으)ㄹ까요?", "좋을까요?")], assumed=True)
g("a-juda", "-아/어 주다", "do something for someone", B, 180,
  [("verb", "-아/어 주다", "기다려 주세요 / 써 주세요")], assumed=True)
g("modifier", "-는 / -(으)ㄴ / -(으)ㄹ", "noun modifiers: turn a verb or adjective into a description of a noun", B, 190,
  [("verb", "-는 (present)", "가는 사람"), ("adjective", "-(으)ㄴ", "좋은 사람"), ("noun", "인", "학생인 친구"), ("past", "-(으)ㄴ (verbs)", "간 사람")],
  assumed=True)
g("ji-maseyo", "-지 마세요", "please don't", B, 200,
  [("verb", "-지 마세요", "가지 마세요")], assumed=True)
g("eupsida", "-(으)ㅂ시다", "let's (polite but not for seniors)", B, 210,
  [("verb", "-(으)ㅂ시다", "갑시다 / 먹읍시다")],
  register="Can sound like an order to someone older or senior; use -(으)ㄹ까요? or -(으)시죠 instead.", assumed=True)

# ---- Taught: end of 초급 ----
g("aseo-sequence", "-아/어서", "sequence: do A, then do B (B builds on A: same place or same object)", B, 300,
  [("verb", "-아/어서", "가서 / 만들어서")],
  prereq=["ayo"],
  contrasts=[("go", "-고 simply lists actions; -아/어서 links them so the second happens at the place or with the thing from the first (친구를 만나서 밥을 먹었어요).")],
  register="Neutral; very common in speech and writing.",
  mistake="Tense goes only on the last verb: ✗ 학교에 갔어서 공부했어요 → ✓ 학교에 가서 공부했어요.")
g("aseo-reason", "-아/어서", "reason: because, so (cause leading to a result)", B, 310,
  [("verb", "-아/어서", "늦어서"), ("adjective", "-아/어서", "바빠서"), ("noun", "(이)라서 / 이어서/여서", "학생이라서 / 의사여서")],
  prereq=["ayo"],
  contrasts=[("eunikka", "-(으)니까 can be followed by a request or suggestion; -아/어서 can't.")],
  register="The natural choice for apologies and thanks: 늦어서 죄송합니다, 도와줘서 고마워요.",
  mistake="No past tense before it, and no command after it: ✗ 비가 와서 우산을 가져가세요 → ✓ 비가 오니까 우산을 가져가세요.")
g("eunikka", "-(으)니까", "because, since (often a reason the speaker wants to stress)", B, 320,
  [("verb", "-(으)니까", "가니까 / 먹으니까"), ("adjective", "-(으)니까", "바쁘니까"), ("noun", "(이)니까", "학생이니까"), ("past", "-았/었으니까", "갔으니까")],
  prereq=["aseo-reason"],
  contrasts=[("aseo-reason", "-아/어서 states a cause neutrally and can't take a command after it; -(으)니까 can (추우니까 창문 닫으세요).")],
  register="With a verb of action it can also mean 'when I did A, I found B': 집에 가니까 아무도 없었어요.",
  mistake="Avoid it in apologies: ✗ 늦었으니까 죄송합니다 → ✓ 늦어서 죄송합니다.")
g("gi-jeone", "-기 전에", "before doing", B, 330,
  [("verb", "-기 전에", "자기 전에"), ("noun", "전에", "수업 전에")],
  prereq=["ayo"],
  contrasts=[("eun-hue", "-(으)ㄴ 후에 is the opposite: after doing.")],
  mistake="No tense before -기: ✗ 잤기 전에 → ✓ 자기 전에.")
g("eun-hue", "-(으)ㄴ 후에", "after doing", B, 340,
  [("verb", "-(으)ㄴ 후에", "먹은 후에 / 간 후에"), ("noun", "후에", "수업 후에")],
  prereq=["modifier"],
  contrasts=[("gi-jeone", "-기 전에 is the opposite: before doing."), ("go-naseo", "-고 나서 means much the same but stresses finishing A first.")],
  register="-(으)ㄴ 다음에 and -(으)ㄴ 뒤에 mean the same.")
g("go-naseo", "-고 나서", "after finishing A, then B", B, 345,
  [("verb", "-고 나서", "먹고 나서")],
  prereq=["go"],
  contrasts=[("eun-hue", "-(으)ㄴ 후에 is a neutral 'after'; -고 나서 stresses that A is completely done.")])
g("a-boda", "-아/어 보다", "try doing; in the past, have done (experience)", B, 350,
  [("verb", "-아/어 보다", "먹어 보세요 / 가 봤어요")],
  prereq=["ayo"],
  register="Very common in polite suggestions: 한번 입어 보세요.",
  mistake="In the past it means experience, not just an attempt: 가 봤어요 = I've been there.")
g("eun-jeogi-itda", "-(으)ㄴ 적이 있다/없다", "have (never) done something before", B, 360,
  [("verb", "-(으)ㄴ 적이 있다", "먹은 적이 있어요 / 가 본 적이 없어요")],
  prereq=["modifier", "a-boda"],
  contrasts=[("a-boda", "Often combined: -아/어 본 적이 있다 is the most natural way to say 'have tried'.")],
  mistake="Not for routine things: ✗ 밥을 먹은 적이 있어요 sounds like eating rice is a rare event.")
g("neyo", "-네요", "oh, …! (reacting to something you just noticed)", B, 370,
  [("verb", "-네요", "비가 오네요"), ("adjective", "-네요", "좋네요"), ("noun", "(이)네요", "학생이네요"), ("past", "-았/었네요", "왔네요")],
  prereq=["ayo"],
  contrasts=[("gunyo", "-군요 also marks realization but sounds more formal or written; -네요 is the everyday spoken choice.")],
  mistake="ㄹ drops before ㄴ: ✗ 멀네요 → ✓ 머네요; ✗ 살네요 → ✓ 사네요.")
g("jiyo", "-지요 (-죠)", "…, right? (checking or stating something the listener should agree with)", B, 380,
  [("verb", "-지요", "가죠?"), ("adjective", "-지요", "좋죠?"), ("noun", "(이)지요", "학생이죠?"), ("past", "-았/었지요", "갔죠?")],
  prereq=["ayo"],
  register="In speech it is almost always shortened to -죠.")
g("ryeogo", "-(으)려고 (하다)", "in order to; intend to, be about to", B, 390,
  [("verb", "-(으)려고", "가려고 / 먹으려고 해요 / 만들려고")],
  prereq=["ayo"],
  contrasts=[("eureo", "-(으)러 only goes with movement verbs (가다, 오다); -(으)려고 works with any verb."), ("eul-kka-hada", "-(으)ㄹ까 하다 is a vaguer 'thinking of maybe doing'.")],
  mistake="ㄹ-stem verbs take -려고 directly: ✗ 만들으려고 → ✓ 만들려고.")
g("gi-ro-hada", "-기로 하다", "decide to; agree to (with someone)", B, 400,
  [("verb", "-기로 하다", "가기로 했어요")],
  prereq=["at"],
  register="Usually in the past (했어요) because the decision is already made.")
g("eumyeonseo", "-(으)면서", "while (doing two things at once)", B, 410,
  [("verb", "-(으)면서", "먹으면서 / 걸으면서"), ("adjective", "-(으)면서", "싸면서"), ("noun", "(이)면서", "학생이면서")],
  prereq=["eumyeon"],
  contrasts=[("neun-dongan", "-는 동안 marks a period of time and the two subjects can differ; -(으)면서 needs the same subject.")],
  mistake="Same subject for both parts: ✗ 제가 요리하면서 동생이 청소했어요 → ✓ 제가 요리하는 동안 동생이 청소했어요.")
g("eul-ttae", "-(으)ㄹ 때", "when (at the time of)", B, 420,
  [("verb", "-(으)ㄹ 때", "갈 때 / 먹을 때"), ("adjective", "-(으)ㄹ 때", "바쁠 때"), ("noun", "때", "학생 때"), ("past", "-았/었을 때", "갔을 때")],
  prereq=["modifier"],
  register="With nouns, just add 때: 방학 때, 학생 때.",
  mistake="갈 때 is before or on the way; 갔을 때 is after arriving: ✓ 한국에 갔을 때 친구를 만났어요.")
g("eul-jul-alda", "-(으)ㄹ 줄 알다/모르다", "know / not know how to do", B, 430,
  [("verb", "-(으)ㄹ 줄 알다", "수영할 줄 알아요 / 운전할 줄 몰라요")],
  prereq=["modifier"],
  contrasts=[("eul-su-itda", "-(으)ㄹ 수 있다 is about being able (including circumstances); -(으)ㄹ 줄 알다 is about having learned the skill.")])
g("a-do-doeda", "-아/어도 되다", "may, it's okay to", B, 440,
  [("verb", "-아/어도 되다", "가도 돼요 / 먹어도 돼요"), ("adjective", "-아/어도 되다", "작아도 돼요"), ("noun", "이어도/여도 되다", "내일이어도 돼요")],
  prereq=["ayo"],
  contrasts=[("eumyeon-an-doeda", "-(으)면 안 되다 is the opposite: must not.")],
  register="As a question it asks permission: 들어가도 돼요?")
g("eumyeon-an-doeda", "-(으)면 안 되다", "must not, not allowed", B, 450,
  [("verb", "-(으)면 안 되다", "가면 안 돼요 / 먹으면 안 돼요")],
  prereq=["eumyeon"],
  contrasts=[("a-do-doeda", "-아/어도 되다 is the opposite: may.")])
g("eun-geot-gatda", "-(으)ㄴ/는 것 같다", "it seems (that); I think (softens an opinion)", B, 460,
  [("verb", "-는 것 같다", "비가 오는 것 같아요"), ("adjective", "-(으)ㄴ 것 같다", "좋은 것 같아요"), ("noun", "인 것 같다", "학생인 것 같아요"), ("past", "-(으)ㄴ 것 같다 (verbs)", "간 것 같아요")],
  prereq=["modifier"],
  contrasts=[("eul-geot-gatda", "-(으)ㄹ 것 같다 is a guess about what will happen or what you can't see; -는 것 같다 is based on what is happening now.")],
  register="Koreans use it a lot to sound less blunt, even about their own opinions: 이게 더 예쁜 것 같아요.")
g("eul-geot-gatda", "-(으)ㄹ 것 같다", "I think it will…; it looks like it'll…", B, 470,
  [("verb", "-(으)ㄹ 것 같다", "비가 올 것 같아요"), ("adjective", "-(으)ㄹ 것 같다", "맛있을 것 같아요"), ("noun", "일 것 같다", "학생일 것 같아요"), ("past", "-았/었을 것 같다", "갔을 것 같아요")],
  prereq=["modifier", "eul-geoyeyo"],
  contrasts=[("eun-geot-gatda", "-는 것 같다 is based on present evidence; -(으)ㄹ 것 같다 is a prediction or a guess."), ("eul-geoyeyo", "-(으)ㄹ 거예요 sounds more certain.")])

# ---- Taught: 중급 ----
g("ge-doeda", "-게 되다", "come to, end up (a change caused by circumstances, not your own choice)", I, 500,
  [("verb", "-게 되다", "알게 됐어요 / 가게 됐어요")],
  prereq=["at"],
  contrasts=[("a-jida", "-아/어지다 goes with adjectives for a change of state; -게 되다 goes with verbs for a change in situation."), ("ge-hada", "-게 하다 means making someone else do it.")],
  register="Common when announcing news politely: 다음 달에 서울로 가게 됐어요.")
g("a-jida", "-아/어지다", "become, get (change of state, with adjectives)", I, 510,
  [("adjective", "-아/어지다", "좋아졌어요 / 추워졌어요")],
  prereq=["ayo"],
  contrasts=[("ge-doeda", "-게 되다 is for verbs and situations; -아/어지다 for adjectives.")],
  mistake="ㅂ-irregular adjectives: ✗ 춥어졌어요 → ✓ 추워졌어요.")
g("a-isseo", "-아/어 있다", "be in a state (the result of an action remains)", I, 520,
  [("verb", "-아/어 있다", "앉아 있어요 / 문이 열려 있어요")],
  prereq=["ayo", "go-itda"],
  contrasts=[("go-itda", "-고 있다 is an action in progress; -아/어 있다 is the state left after it (앉고 있어요 = sitting down, 앉아 있어요 = seated).")],
  register="Used with verbs that don't take an object (앉다, 서다, 열리다, 붙다…).",
  mistake="✗ 문이 열고 있어요 → ✓ 문이 열려 있어요.")
g("ge", "-게", "adverb form: in a … way", I, 530,
  [("adjective", "-게", "맛있게 / 예쁘게")],
  prereq=["ayo"],
  register="Very common in set phrases: 맛있게 드세요, 즐겁게 보내세요.")
g("ge-hada", "-게 하다", "make or let someone do", I, 540,
  [("verb", "-게 하다", "동생을 웃게 했어요 / 일찍 자게 해요")],
  prereq=["ge"],
  contrasts=[("ge-doeda", "-게 되다 is something that happens to you; -게 하다 is causing someone else to do it.")])
g("janayo", "-잖아요", "you know…, as you know (reminding the listener of something they know)", I, 550,
  [("verb", "-잖아요", "가잖아요"), ("adjective", "-잖아요", "좋잖아요"), ("noun", "(이)잖아요", "학생이잖아요"), ("past", "-았/었잖아요", "갔잖아요")],
  prereq=["ayo"],
  contrasts=[("geodeunyo", "-거든요 gives a reason the listener didn't know; -잖아요 points to something they already know.")],
  register="Friendly in conversation, but can sound like 'obviously!' — careful with seniors.")
g("geodeunyo", "-거든요", "because, you see (giving a reason or background the listener didn't know)", I, 560,
  [("verb", "-거든요", "가거든요"), ("adjective", "-거든요", "바쁘거든요"), ("noun", "(이)거든요", "학생이거든요"), ("past", "-았/었거든요", "갔거든요")],
  prereq=["ayo"],
  contrasts=[("janayo", "-잖아요 is for things the listener already knows.")],
  register="Spoken only. Also used to set up a story before the main point: 어제 명동에 갔거든요. 그런데…")
g("gunyo", "-군요", "I see…, so … (realizing something, often from what you've just heard)", I, 570,
  [("verb", "-는군요", "가는군요"), ("adjective", "-군요", "좋군요"), ("noun", "(이)군요", "학생이군요"), ("past", "-았/었군요", "갔군요")],
  prereq=["neyo"],
  contrasts=[("neyo", "-네요 is the everyday spoken reaction; -군요 sounds a bit more formal or written.")],
  mistake="Present-tense verbs take -는군요: ✗ 가군요 → ✓ 가는군요.")
g("deorago", "-더라고요", "I noticed / I found that… (reporting something you saw or felt in the past)", I, 580,
  [("verb", "-더라고요", "비가 오더라고요"), ("adjective", "-더라고요", "맛있더라고요"), ("noun", "(이)더라고요", "학생이더라고요"), ("past", "-았/었더라고요", "벌써 갔더라고요")],
  prereq=["at"],
  register="Conversational. Sounds natural when sharing impressions: 그 식당 정말 맛있더라고요.",
  mistake="Not for your own actions: ✗ (제가) 어제 영화를 보더라고요 → ✓ 어제 영화를 봤어요.")
g("daga", "-다가", "while doing A, switch to B (A is interrupted or left)", I, 590,
  [("verb", "-다가", "가다가 / 공부하다가"), ("past", "-았/었다가", "갔다가 (went and came back)")],
  prereq=["ayo"],
  register="With the past form it means A was completed, then B: 학교에 갔다가 집에 왔어요.",
  mistake="Same subject for both parts: ✗ 제가 자다가 동생이 왔어요.")
g("neunde", "-(으)ㄴ/는데", "sets up background or a soft contrast (\"…, so\" / \"…, but\")", I, 600,
  [("verb", "-는데", "가는데"), ("adjective", "-(으)ㄴ데", "좋은데"), ("noun", "인데", "학생인데"), ("past", "-았/었는데", "갔는데")],
  prereq=["jiman", "modifier"],
  contrasts=[("jiman", "-지만 is a plain 'but'; -는데 is softer and often just gives background before the main point.")],
  register="Very common in speech. Ending a sentence with -는데요 softly invites a response or signals hesitation.",
  mistake="Action verbs take -는데: ✗ 가은데 → ✓ 가는데. Adjectives take -(으)ㄴ데: ✗ 좋는데 → ✓ 좋은데.")
g("neun-dongan", "-는 동안", "while, during (a period of time)", I, 610,
  [("verb", "-는 동안", "자는 동안"), ("noun", "동안", "방학 동안")],
  prereq=["modifier"],
  contrasts=[("eumyeonseo", "-(으)면서 is one person doing two things at once; with -는 동안 the subjects can differ.")])
g("gi-ttaemune", "-기 때문에", "because (a firmer, more formal reason)", I, 620,
  [("verb", "-기 때문에", "가기 때문에"), ("adjective", "-기 때문에", "바쁘기 때문에"), ("noun", "때문에", "일 때문에"), ("past", "-았/었기 때문에", "갔기 때문에")],
  prereq=["aseo-reason"],
  contrasts=[("aseo-reason", "-아/어서 is the everyday spoken reason; -기 때문에 sounds firmer and more formal."), ("eunikka", "-(으)니까 can be followed by a request; -기 때문에 can't.")],
  mistake="No command or suggestion after it: ✗ 비가 오기 때문에 우산을 가져가세요 → ✓ 비가 오니까 우산을 가져가세요.")
g("eul-tende", "-(으)ㄹ 텐데", "it must be / it would be … (a strong guess, often followed by concern or a suggestion)", I, 630,
  [("verb", "-(으)ㄹ 텐데", "갈 텐데"), ("adjective", "-(으)ㄹ 텐데", "배고플 텐데"), ("noun", "일 텐데", "학생일 텐데"), ("past", "-았/었을 텐데", "갔을 텐데")],
  prereq=["neunde", "eul-geoyeyo"],
  register="Often caring: 배고플 텐데 먹어요. Also regret with -았/었으면 … -았/었을 텐데: 일찍 왔으면 좋았을 텐데.")
g("neun-baramne", "-는 바람에", "because of (something unexpected that led to a bad result)", I, 640,
  [("verb", "-는 바람에", "늦게 일어나는 바람에")],
  prereq=["modifier", "aseo-reason"],
  contrasts=[("aseo-reason", "-아/어서 is a neutral reason; -는 바람에 stresses that the cause was sudden and the result unwanted.")],
  register="The result part is in the past tense.",
  mistake="Verbs only, and no command after it: ✗ 바쁜 바람에 → ✓ 갑자기 일이 생기는 바람에.")
g("eul-ppunmanaanira", "-(으)ㄹ 뿐만 아니라", "not only … but also", I, 650,
  [("verb", "-(으)ㄹ 뿐만 아니라", "잘할 뿐만 아니라"), ("adjective", "-(으)ㄹ 뿐만 아니라", "쌀 뿐만 아니라"), ("noun", "뿐만 아니라", "한국어뿐만 아니라"), ("past", "-았/었을 뿐만 아니라", "갔을 뿐만 아니라")],
  prereq=["modifier"],
  register="The second part usually has -도: 쌀 뿐만 아니라 맛도 있어요.")
g("neun-pyeonida", "-(으)ㄴ/는 편이다", "tend to be, be on the … side", I, 660,
  [("verb", "-는 편이다", "많이 먹는 편이에요"), ("adjective", "-(으)ㄴ 편이다", "바쁜 편이에요")],
  prereq=["modifier"],
  register="Softens a description of yourself or others: 저는 키가 큰 편이에요.")
g("neun-daesine", "-는 대신에", "instead of; in exchange for", I, 670,
  [("verb", "-는 대신에", "가는 대신에"), ("noun", "대신에", "커피 대신에")],
  prereq=["modifier"])
g("eul-manhada", "-(으)ㄹ 만하다", "worth doing; good enough to", I, 680,
  [("verb", "-(으)ㄹ 만하다", "볼 만해요 / 먹을 만해요")],
  prereq=["modifier"],
  register="먹을 만해요 can mean 'it's decent' rather than 'it's great' — tone matters.")
g("na-boda", "-나 보다 / -(으)ㄴ가 보다", "it seems (a guess from what you observe)", I, 690,
  [("verb", "-나 보다", "비가 오나 봐요"), ("adjective", "-(으)ㄴ가 보다", "바쁜가 봐요"), ("noun", "인가 보다", "학생인가 봐요"), ("past", "-았/었나 보다", "갔나 봐요")],
  prereq=["eun-geot-gatda"],
  contrasts=[("eun-geot-gatda", "-는 것 같다 can describe your own feelings or opinions; -나 보다 is only a guess about others or situations you observe.")],
  mistake="Not about yourself: ✗ 제가 피곤한가 봐요 (unless you just realized it).")
g("dorok", "-도록", "so that; to the point that", I, 700,
  [("verb", "-도록", "늦지 않도록 / 밤새도록")],
  prereq=["ryeogo"],
  register="Often in polite instructions: 늦지 않도록 하세요 (Make sure you're not late).")
g("eun-ji", "-(으)ㄴ 지", "since (time passed since doing)", I, 710,
  [("verb", "-(으)ㄴ 지 + time + 되다", "한국에 온 지 1년 됐어요")],
  prereq=["modifier"],
  mistake="Spaced as 온 지, and followed by a length of time: ✗ 온지 → ✓ 온 지.")
g("eul-kka-hada", "-(으)ㄹ까 하다", "be thinking of (maybe) doing", I, 720,
  [("verb", "-(으)ㄹ까 하다", "주말에 쉴까 해요")],
  prereq=["eulkkayo"],
  contrasts=[("ryeogo", "-(으)려고 하다 is a firmer intention; -(으)ㄹ까 하다 is still undecided.")])
g("eumyeon-joketda", "-았/었으면 좋겠다", "I wish, I hope", I, 730,
  [("verb", "-았/었으면 좋겠다", "갔으면 좋겠어요"), ("adjective", "-았/었으면 좋겠다", "날씨가 좋았으면 좋겠어요"), ("noun", "이었/였으면 좋겠다", "주말이었으면 좋겠어요")],
  prereq=["eumyeon", "at"],
  register="The past form is the most common, even for future wishes.")
g("a-beorida", "-아/어 버리다", "do completely (often with relief or regret)", I, 740,
  [("verb", "-아/어 버리다", "다 먹어 버렸어요 / 잊어버렸어요")],
  prereq=["ayo"],
  register="The feeling comes from context: relief (숙제를 끝내 버렸어요) or regret (잊어버렸어요).")
g("neun-gire", "-는 길에", "on the way (to/from)", I, 750,
  [("verb", "-는 길에", "집에 가는 길에 / 오는 길에")],
  prereq=["modifier"],
  register="Only with movement verbs like 가다, 오다, 나가다.")
g("gi-swipda", "-기 쉽다", "easy to; likely to", I, 760,
  [("verb", "-기 쉽다", "잊기 쉬워요")],
  prereq=["ayo"],
  register="Opposite: -기 어렵다 (hard to).")

out = {"version": 1, "items": items}
with open(sys.argv[1], "w", encoding="utf-8") as f:
    json.dump(out, f, ensure_ascii=False, indent=1)
    f.write("\n")
print(len(items), "patterns;", sum(1 for i in items if i["assumedKnown"]), "assumed known")
