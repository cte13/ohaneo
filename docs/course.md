# Class tab: textbook lessons

The Class tab shows the lessons of the textbook used in a class you're taking
(currently 「바로 배워 바로 쓰는 세종학당 한국어 1」, lessons 11–20), so you can
prepare for the next class, do homework and review.

## The lesson files are not in git

The textbook is copyrighted and this repo is public, so the transcribed lessons
stay on your machine. Put one file per lesson in `Ohaneo/Resources/Course/`
(gitignored), named `sejong1-chNN.json`, then run `xcodegen generate` and build.
Without the files the tab says no textbook is loaded.

## How a lesson is made

Each file is a page-by-page transcription of the lesson: words, expressions,
grammar (meaning, form, conjugation table, sample dialogue), the listening
script and answers from the appendix, the reading text, the speaking and
writing tasks, and every exercise with its answer. Nothing is written by the
AI or invented: missing English stays empty. Items that depend on a picture
carry a short description of it.

`OhaneoCore/Sources/OhaneoCore/Course.swift` defines the format. The full
field-by-field transcription guide is below.

## Using it

- **Next class** (picker at the top) sorts lessons into Prepare for class,
  Homework (the lesson before), Review (earlier ones) and Coming up.
- A lesson has four parts: **Words** (topic words, glossary words and
  expressions, each with 🔊), **Grammar**, **Practice** (every exercise, tap to
  check the answer) and **Texts** (goals, dialogue, reading, speaking and
  writing tasks).
- **Drill words** runs flashcards over all of the lesson's words. "Again" puts a
  card at the back; the round ends when every card has been "Got it" once, then
  offers to drill just the missed ones.

## Transcription guide

Transcribe EXACTLY what the textbook prints. Do not invent, translate, or "improve"
anything: when the book gives no English, use null. Keep Korean spelling,
punctuation and spacing exactly as printed. Use "___" for a blank in an exercise.

{
  "number": 11,
  "title": "떡볶이는 매워서 잘 못 먹어요",              // chapter opener, big title
  "titleEnglish": "I can't eat tteokbokki because it's too spicy",
  "goals": ["식당에서 메뉴를 정하는 대화를 듣고 말할 수 있다.", "..."],  // 학습목표
  "thinkAbout": ["여러분은 어떤 한국 음식을 좋아해요?", "..."],          // 생각하기 questions
  "vocabulary": [                                   // 어휘 및 표현 page(s), one entry per topic box
    {"topic": "음식", "topicEnglish": "Foods", "words": [
      {"korean": "떡볶이", "english": "tteokbokki",
       "example": "점심 메뉴는 떡볶이가 어때요?", "exampleEnglish": "How about tteokbokki for lunch?"}
    ]}
  ],
  "glossary": [{"korean": "벗다", "english": "take off"}],   // every magnifier-icon word box in the chapter EXCEPT the reading one, in order
  "expressions": [                                  // 표현 page
    {"pattern": "(명사)는 어때요?", "english": "How about?",
     "examples": [{"korean": "김밥은 어때요?", "english": "How about gimbap?"}],
     "note": "..."}                                 // the lightbulb tip box text if attached to it, else null
  ],
  "grammar": [                                      // 문법 boxes
    {"pattern": "-어서",
     "meaning": "동사나 형용사에 붙어 ...",          // 의미, Korean
     "meaningEnglish": "It is attached after a verb or an adjective to indicate ...",
     "form": "동사, 형용사 + -어서/-아서",           // 형태
     "formEnglish": "Verb, Adjective + -어서/-아서",
     "table": [["'ㅏ', 'ㅗ' ×", "먹다", "먹어서"], ["'ㅏ', 'ㅗ' ○", "찾다", "찾아서"], ["하다", "하다", "해서"]],
     "dialogue": [{"speaker": "가", "text": "지훈 씨, 지금 어디에 가요?"}, {"speaker": "나", "text": "배가 고파서 식당에 가요."}],
     "note": null}                                  // tip box text if any
  ],
  "listening": {                                    // 듣고 말하기 section
    "intro": "지훈 씨와 나타샤 씨의 대화를 잘 들으세요.",
    "script": [{"speaker": "지훈", "text": "..."}]  // from the appendix 듣기 지문 for THIS chapter, verbatim
  },
  "reading": {"text": "저는 한국 음식 중에서 ...", "glossary": [{"korean": "김치", "english": "Kimchi"}]},  // 읽고 쓰기 text + its magnifier box
  "speaking": ["뭘 먹을까요? 저는 김치찌개가 먹고 싶어요.", "그럼 비빔밥을 먹을까요? 어때요?"],  // 말하기 과제 prompts
  "writing": {"task": "여러분은 한국 음식을 좋아합니까? 〈보기〉와 같이 ...", "taskEnglish": "Do you like Korean food? ...",
              "example": "저는 한국 음식 중에서 ..."},
  "exercises": [                                    // every exercise in the chapter, in page order
    {"section": "문법 연습 I",                     // the name the ANSWER KEY uses: 문법 연습 I/II/III, 어휘 및 문법 연습, 듣고 말하기 연습, 읽고 쓰기 연습
     "number": 1,                                   // exercise number within the section (1, 2, 3...); null if the section has one unnumbered list
     "instruction": "빈칸에 알맞은 말을 쓰세요.", "instructionEnglish": "Fill in the blanks.",
     "choices": ["가다", "좋아하다", "먹다", "-어서", "-여서", "-고 싶다", "-고 싶지 않다"],   // 보기 box or shared choices, else null
     "items": [
       {"prompt": "가: 쯔엉 씨, 오늘 저녁에 뭐 해요?\n나: 숙제가 ___ 숙제해요. (많다)",
        "options": null,                            // per-item choices (①② or the two highlighted options), else null
        "picture": null,                            // if the item depends on a picture, a SHORT neutral description: "a man adding salt to soup"
        "answer": "많아서"}                         // from the answer key, verbatim; null if the key has none
     ]}
  ]
}

Notes
- The page header "Part 01/02" and decorative text are not content.
- For ①②③④ choice items, put the options in "options" without the circled numbers, and the answer as
  the key prints it (e.g. "②") PLUS the option text: "② 싱거워요". For O/X items the answer is "O" or "X".
- Order items as the book does. If an item has 가/나 lines, join them with "\n".
- Lines in tables: copy cell text exactly, including ○ × and quotes.
- Output must be valid JSON (no comments). Write it with a script or the Write tool, then validate with
  python3 -c "import json,sys; json.load(open(sys.argv[1]))" <file>.
