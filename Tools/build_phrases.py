"""Generates phrases.json. Run: python3 -I Tools/build_phrases.py OhaneoCore/Sources/OhaneoCore/Resources/phrases.json

The list is in presentation order: the phrases you'd hear or say most often
come first, with survival phrases (ordering, getting around) and everyday
conversation mixed together. Idioms and proverbs come later. The order is a
judgment call; there's no open frequency data for Korean phrases.

Each entry is (id, korean, meaning, kind, level, topics, words):
- id: the number in p:<id>. Stable forever: never change or reuse one. New
  phrases take the next unused number, wherever they go in the list.
- words: the dictionary words the phrase is built from, space-separated, as
  they appear in words.json (read from the same folder as the output). A word
  with more than one entry needs a hint: a piece of the meaning you want
  (맞다~correct) or its part of speech (뭐~pronoun). The build stops if a word
  is missing or ambiguous, so the breakdown on the card always comes from the
  word list, never from guesswork. Leave a word out when its word-list meaning
  doesn't fit the phrase (걸리다 is glossed only as "hang", so 얼마나 걸려요
  doesn't list it): the card should never teach the wrong sense.
"""
import json
import sys
from pathlib import Path

E, ID, PR = "expression", "idiom", "proverb"
B, I, A = "beginner", "intermediate", "advanced"

# IDs that were used once and removed. Never reuse them.
RETIRED: set[int] = set()

PHRASES = [
    # --- Every day, from the first week ---
    (129, "안녕하세요", "Hello (polite; any time of day)", E, B, ["daily"], "안녕하다"),
    (130, "감사합니다", "Thank you (polite)", E, B, ["daily"], "감사하다~thankful"),
    (13, "괜찮아요", "It's okay / I'm fine / No thank you (declining politely)", E, B, ["daily"], "괜찮다"),
    (131, "네, 알겠습니다", "Okay, understood (polite)", E, B, ["daily", "work"], "네~yes 알다"),
    (132, "죄송합니다", "I'm sorry (polite, formal)", E, B, ["daily"], "죄송하다"),
    (3, "잠깐만요", "Just a moment / Excuse me (to get past or to pause someone)", E, B, ["daily"], "잠깐~noun"),
    (133, "저기요", "Excuse me (to get a stranger's attention; literally 'over there')", E, B, ["daily"], "저기~place"),
    (24, "진짜요?", "Really?", E, B, ["daily"], "진짜~really"),
    (134, "맞아요", "That's right / Yes, exactly", E, B, ["daily"], "맞다~correct"),
    (135, "고마워요", "Thanks (polite, warmer than 감사합니다)", E, B, ["daily", "relationships"], "고맙다"),
    (136, "아니에요", "No / Not at all (also the usual reply to thanks or an apology)", E, B, ["daily"], "아니다"),
    (36, "여기요", "Excuse me! (calling staff in a restaurant)", E, B, ["food"], "여기"),
    (139, "이거 주세요", "This one, please (pointing at a menu or item)", E, B, ["food", "shopping"], "이거 주다"),
    (137, "미안해요", "Sorry (polite, less formal than 죄송합니다)", E, B, ["daily", "relationships"], "미안하다"),
    (138, "잘 모르겠어요", "I'm not sure / I don't really know", E, B, ["daily"], "잘~well 모르다"),
    (140, "그래요?", "Really? / Is that so?", E, B, ["daily"], "그렇다"),
    (15, "글쎄요", "Well… / I'm not sure (hesitating)", E, B, ["daily"], "글쎄"),
    (42, "이거 얼마예요?", "How much is this?", E, B, ["shopping"], "이거 얼마"),
    (141, "좋아요", "Sounds good / I like it", E, B, ["daily"], "좋다"),
    (25, "그렇죠", "That's right / Exactly (agreeing)", E, B, ["daily"], "그렇다"),
    (142, "안녕히 가세요", "Goodbye (to someone who is leaving while you stay)", E, B, ["daily"], "안녕히 가다"),
    (143, "안녕히 계세요", "Goodbye (when you leave and the other person stays)", E, B, ["daily"], "안녕히 계시다"),
    (46, "화장실이 어디예요?", "Where is the restroom?", E, B, ["travel"], "화장실 어디~where"),
    (144, "뭐라고요?", "Sorry, what did you say? / What?! (surprised)", E, B, ["daily"], "뭐~pronoun"),
    (145, "밥 먹었어요?", "Have you eaten? (a friendly greeting, like 'how are you?')", E, B, ["daily", "food"], "밥 먹다~eat"),
    (37, "계산해 주세요", "The bill, please", E, B, ["food", "shopping"], "계산 하다 주다"),
    (146, "실례합니다", "Excuse me (before interrupting, squeezing past or entering)", E, B, ["daily"], "실례 하다"),
    (1, "그러게요", "I know, right? / Exactly (agreeing with what was just said)", E, B, ["daily"], ""),
    (32, "잘 먹겠습니다", "Said before eating, thanking whoever made or paid for the meal", E, B, ["food"], "잘~well 먹다~eat"),
    (33, "잘 먹었습니다", "Said after eating, thanking whoever made or paid for the meal", E, B, ["food"], "잘~well 먹다~eat"),
    (147, "저도요", "Me too", E, B, ["daily"], "저~humble"),
    (148, "카드 돼요?", "Can I pay by card?", E, B, ["shopping", "food"], "카드 되다"),
    (149, "한국어 잘 못해요", "I don't speak Korean well", E, B, ["daily", "travel"], "한국어 잘~well 못하다~verb"),
    (5, "그렇군요", "I see (accepting new information)", E, B, ["daily"], "그렇다"),
    (150, "어떻게 지내요?", "How are you doing? / How have you been?", E, B, ["relationships"], "어떻다 지내다"),
    (151, "잘 지내요", "I'm doing well", E, B, ["relationships"], "잘~well 지내다"),
    (28, "어서 오세요", "Welcome (said by staff when customers come in)", E, B, ["shopping", "food"], "어서 오다"),
    (152, "물 좀 주세요", "Some water, please", E, B, ["food"], "물~water 좀 주다"),
    (153, "만나서 반갑습니다", "Nice to meet you", E, B, ["relationships"], "만나다 반갑다"),
    (154, "다음에 봐요", "See you next time", E, B, ["relationships"], "다음 보다~see"),
    (6, "그럼요", "Of course", E, B, ["daily"], "그럼~course"),
    (155, "무슨 뜻이에요?", "What does it mean?", E, B, ["daily", "school"], "무슨 뜻"),
    (156, "이게 뭐예요?", "What is this?", E, B, ["daily", "food", "shopping"], "이것 뭐~pronoun"),
    (157, "아직이요", "Not yet", E, B, ["daily"], "아직"),
    (158, "왜요?", "Why? / What is it? (when someone calls you)", E, B, ["daily"], "왜"),
    (159, "잘 자요", "Good night / Sleep well", E, B, ["relationships"], "잘~well 자다"),
    (160, "이따 봐요", "See you later (later today)", E, B, ["relationships"], "이따가 보다~see"),
    (14, "그냥요", "Just because / No particular reason", E, B, ["daily"], "그냥"),
    (161, "어때요?", "How is it? / How about it?", E, B, ["daily"], "어떻다"),
    (162, "몇 분이세요?", "How many people? (heard at a restaurant door)", E, B, ["food"], ""),
    (163, "두 명이요", "Two people (answering 몇 분이세요?)", E, B, ["food"], "둘"),
    (17, "역시", "As expected / I knew it", E, B, ["daily"], "역시"),

    # --- Getting around and getting things done ---
    (164, "도와주세요", "Please help me / Help!", E, B, ["daily", "travel"], "돕다 주다"),
    (41, "천천히 말해 주세요", "Please speak slowly", E, B, ["daily", "travel"], "천천히 말하다 주다"),
    (40, "한 번 더 말씀해 주시겠어요?", "Could you say that once more?", E, B, ["daily", "travel"], "한번 더~more 말씀 하다 주다"),
    (165, "이해가 안 돼요", "I don't understand", E, B, ["daily", "school"], "이해~understanding 안~not 되다"),
    (166, "이걸로 할게요", "I'll take this one / I'll have this", E, B, ["shopping", "food"], "이것 하다"),
    (38, "포장해 주세요", "To go, please / Please wrap it up", E, B, ["food", "shopping"], "포장 하다 주다"),
    (167, "드시고 가세요?", "For here? (literally 'will you eat and go?'; the other choice is 포장)", E, B, ["food"], "가다"),
    (168, "영수증 주세요", "A receipt, please", E, B, ["shopping", "food"], "주다"),
    (169, "봉투 필요하세요?", "Do you need a bag? (heard at a checkout)", E, B, ["shopping"], "봉투 필요하다"),
    (170, "여기로 가 주세요", "Please take me here (to a taxi driver, showing an address)", E, B, ["travel"], "여기 가다 주다"),
    (47, "여기서 내려 주세요", "Please let me off here (to a taxi driver)", E, B, ["travel"], "여기 내리다 주다"),
    (171, "얼마나 걸려요?", "How long does it take?", E, B, ["travel"], "얼마나"),
    (172, "어떻게 가요?", "How do I get there?", E, B, ["travel"], "어떻다 가다"),
    (173, "내릴게요", "I'm getting off (to get past people on a crowded bus or subway)", E, B, ["travel"], "내리다"),
    (174, "몇 시까지 해요?", "What time do you close? (literally 'until what time do you do it?')", E, B, ["shopping", "food"], "하다"),
    (175, "예약했어요", "I have a reservation", E, B, ["travel", "food"], "예약 하다"),
    (176, "추천해 주세요", "What do you recommend? (literally 'please recommend')", E, B, ["food", "shopping"], "추천 하다 주다"),
    (177, "하나 더 주세요", "One more, please", E, B, ["food", "shopping"], "하나~numeral 더~more 주다"),
    (178, "반찬 좀 더 주세요", "Could we have more side dishes? (refills are usually free)", E, B, ["food"], "반찬 좀 더~more 주다"),
    (179, "따로 계산해 주세요", "Separate checks, please", E, B, ["food", "shopping"], "따로 계산 하다 주다"),
    (39, "덜 맵게 해 주세요", "Please make it less spicy", E, B, ["food"], "덜 맵다 하다 주다"),
    (180, "사진 좀 찍어 주시겠어요?", "Could you take a picture of us?", E, B, ["travel"], "사진 좀 찍다 주다"),
    (181, "여기 앉아도 돼요?", "Can I sit here? / Is this seat free?", E, B, ["daily", "travel"], "여기 앉다 되다"),
    (182, "카드로 할게요", "I'll pay by card", E, B, ["shopping", "food"], "카드 하다"),
    (183, "일시불로 해 주세요", "In one payment, please (the card terminal asks 일시불 or 할부, installments)", E, I, ["shopping"], "하다 주다"),
    (43, "좀 깎아 주세요", "Please give me a discount", E, B, ["shopping"], "좀 깎다 주다"),
    (44, "그냥 구경하는 거예요", "I'm just looking", E, B, ["shopping"], "그냥 구경 하다"),
    (45, "입어 봐도 돼요?", "Can I try it on?", E, B, ["shopping"], "입다 보다~see 되다"),
    (184, "다른 색 있어요?", "Do you have it in another color?", E, B, ["shopping"], "다른 색 있다~adjective"),
    (185, "환불 돼요?", "Can I get a refund?", E, B, ["shopping"], "되다"),
    (48, "길을 잃었어요", "I'm lost", E, B, ["travel"], "길~road 잃다"),
    (186, "어디서 갈아타요?", "Where do I transfer? (bus or subway)", E, B, ["travel"], "어디~where 갈아타다"),
    (187, "지나갈게요", "Coming through (excuse me, I need to get past)", E, B, ["daily", "travel"], "지나가다"),
    (188, "몸이 안 좋아요", "I don't feel well", E, B, ["health"], "몸 안~not 좋다"),
    (189, "머리가 아파요", "I have a headache", E, B, ["health"], "머리~head 아프다"),
    (190, "감기에 걸렸어요", "I caught a cold", E, B, ["health"], "감기"),
    (191, "약국이 어디예요?", "Where is a pharmacy?", E, B, ["health", "travel"], "약국 어디~where"),
    (192, "여보세요", "Hello? (answering the phone)", E, B, ["daily"], ""),
    (193, "지금 어디예요?", "Where are you now? (on the phone)", E, B, ["daily", "relationships"], "지금~noun 어디~where"),
    (194, "금방 갈게요", "I'll be right there", E, B, ["daily", "relationships"], "가다"),
    (195, "좀 늦을 것 같아요", "I think I'll be a little late", E, B, ["daily", "work"], "좀 늦다~verb"),
    (196, "늦어서 죄송해요", "Sorry I'm late", E, B, ["daily", "work"], "늦다~verb 죄송하다"),

    # --- Conversation: reactions and replies ---
    (197, "그러니까요", "That's what I'm saying / Exactly", E, B, ["daily"], ""),
    (23, "대박", "Awesome / Wow (casual slang for something amazing)", E, B, ["daily", "kdrama"], ""),
    (16, "설마", "No way… / Surely not (expecting it isn't true)", E, I, ["daily", "kdrama"], ""),
    (10, "말도 안 돼", "No way / That makes no sense (casual)", E, B, ["daily", "kdrama"], "말~speech 안~not 되다"),
    (198, "아이고", "Oh dear / Oof (sympathy, tiredness or surprise)", E, B, ["daily", "feelings"], "아이고"),
    (199, "어머", "Oh my! (surprise)", E, B, ["daily", "kdrama"], "어머"),
    (200, "헐", "Whoa / OMG (casual slang for shock)", E, B, ["daily", "kdrama"], ""),
    (18, "어떡해", "What do I do? / Oh no (casual; polite: 어떡해요)", E, B, ["feelings", "kdrama"], ""),
    (201, "재미있었어요", "That was fun", E, B, ["feelings"], "재미있다"),
    (202, "진짜 웃겨요", "That's so funny", E, B, ["daily", "feelings"], "진짜~really 웃기다"),
    (27, "잘됐네요", "That's great / I'm glad it worked out", E, B, ["feelings"], "잘되다"),
    (20, "다행이다", "What a relief / That's lucky", E, B, ["feelings"], "다행"),
    (203, "아쉽네요", "What a shame / Too bad", E, B, ["feelings"], ""),
    (204, "별로예요", "Not great / Meh", E, B, ["daily", "food"], ""),
    (205, "그저 그래요", "So-so", E, B, ["daily"], "그저 그렇다"),
    (206, "맛있어요", "It's delicious", E, B, ["food"], "맛있다"),
    (207, "배불러요", "I'm full", E, B, ["food"], "배부르다"),
    (208, "배고파요", "I'm hungry", E, B, ["food", "feelings"], "배고프다"),
    (209, "피곤해요", "I'm tired", E, B, ["feelings", "health"], "피곤하다"),
    (210, "바빠요", "I'm busy", E, B, ["daily", "work"], "바쁘다"),
    (211, "저는 괜찮아요", "I'm fine / I'm good (often a polite no to an offer)", E, B, ["daily"], "저~humble 괜찮다"),
    (26, "아무거나요", "Anything is fine", E, B, ["daily", "food"], "아무것"),
    (86, "상관없어요", "It doesn't matter / I don't mind", E, B, ["daily"], "상관없다"),
    (212, "좋은 생각이에요", "Good idea", E, B, ["daily"], "좋다 생각"),
    (213, "그렇게 해요", "Let's do that / Sure, go ahead", E, B, ["daily"], "그렇다 하다"),
    (214, "생각해 볼게요", "I'll think about it (often a soft no)", E, B, ["daily", "shopping"], "생각 하다 보다~see"),
    (215, "다음에요", "Next time (a soft way to say no)", E, B, ["daily", "relationships"], "다음"),
    (216, "안 돼요", "No / You can't / It doesn't work", E, B, ["daily"], "안~not 되다"),
    (217, "벌써요?", "Already?", E, B, ["daily"], "벌써"),
    (218, "저 왔어요", "I'm here! (arriving to meet someone)", E, B, ["relationships"], "저~humble 오다"),
    (219, "걱정하지 마세요", "Don't worry", E, B, ["daily", "feelings"], "걱정 하다"),
    (12, "신경 쓰지 마세요", "Don't worry about it / Never mind", E, B, ["daily"], "신경 쓰다~use"),
    (220, "무슨 일이에요?", "What's going on? / What's wrong?", E, B, ["daily"], "무슨 일~work"),
    (221, "괜찮으세요?", "Are you okay? (polite)", E, B, ["daily", "health"], "괜찮다"),
    (222, "무슨 말이에요?", "What do you mean?", E, B, ["daily"], "무슨 말~speech"),
    (223, "알아요", "I know", E, B, ["daily"], "알다"),
    (224, "몰랐어요", "I didn't know", E, B, ["daily"], "모르다"),
    (72, "어떻게 알았어요?", "How did you know?", E, B, ["daily"], "어떻다 알다"),
    (225, "농담이에요", "Just kidding", E, B, ["daily", "relationships"], "농담"),
    (226, "진심이에요", "I mean it / I'm serious", E, I, ["feelings", "relationships"], "진심"),
    (2, "아, 맞다", "Oh, right! (suddenly remembering something)", E, B, ["daily"], "맞다~correct"),
    (4, "어쩐지", "No wonder / That explains it", E, I, ["daily"], "어쩐지"),
    (9, "어쩔 수 없죠", "It can't be helped", E, B, ["daily", "feelings"], "없다"),
    (227, "그럴 수도 있죠", "That can happen / Fair enough", E, B, ["daily"], "그렇다 있다~adjective"),
    (228, "맞는 말이에요", "That's true / You have a point", E, B, ["daily"], "맞다~correct 말~speech"),
    (229, "그럴게요", "Will do / I will", E, B, ["daily", "work"], ""),

    # --- Getting to know people ---
    (230, "이름이 뭐예요?", "What's your name?", E, B, ["relationships"], "이름 뭐~pronoun"),
    (231, "성함이 어떻게 되세요?", "May I have your name? (very polite)", E, B, ["relationships", "work"], "성함 어떻다 되다"),
    (232, "어디에서 왔어요?", "Where are you from?", E, B, ["relationships", "travel"], "어디~where 오다"),
    (233, "무슨 일 하세요?", "What do you do (for work)?", E, B, ["relationships", "work"], "무슨 일~work 하다"),
    (234, "나이가 어떻게 되세요?", "How old are you? (polite; age decides how people talk to each other)", E, B, ["relationships"], "나이 어떻다 되다"),
    (235, "한국어 공부하고 있어요", "I'm studying Korean", E, B, ["school", "relationships"], "한국어 공부 하다 있다~verb"),
    (236, "이걸 한국어로 뭐라고 해요?", "How do you say this in Korean?", E, B, ["school", "daily"], "이것 한국어 뭐~pronoun 하다"),
    (237, "영어 할 줄 아세요?", "Do you speak English?", E, B, ["travel"], "영어 하다 알다"),
    (55, "오랜만이에요", "Long time no see", E, B, ["relationships"], "오랜만"),
    (56, "잘 지냈어요?", "How have you been?", E, B, ["relationships"], "잘~well 지내다"),
    (238, "요즘 어떻게 지내요?", "How are things these days?", E, B, ["relationships"], "요즘 어떻다 지내다"),
    (239, "주말에 뭐 했어요?", "What did you do on the weekend?", E, B, ["relationships", "work"], "주말 뭐~pronoun 하다"),
    (240, "시간 있어요?", "Do you have time? / Are you free?", E, B, ["relationships"], "시간 있다~adjective"),
    (241, "언제 시간 돼요?", "When are you free?", E, B, ["relationships"], "언제~adverb 시간 되다"),
    (242, "몇 시에 만날까요?", "What time shall we meet?", E, B, ["relationships"], "만나다"),
    (243, "어디서 만날까요?", "Where shall we meet?", E, B, ["relationships"], "어디~where 만나다"),
    (244, "같이 가요", "Let's go together / Come with me", E, B, ["relationships"], "같이 가다"),
    (245, "뭐 먹을래요?", "What do you want to eat?", E, B, ["food", "relationships"], "뭐~pronoun 먹다~eat"),
    (59, "연락할게요", "I'll get in touch", E, B, ["relationships", "work"], "연락 하다"),
    (246, "카톡 할게요", "I'll message you on KakaoTalk (Korea's main messaging app)", E, B, ["relationships"], "하다"),
    (60, "나중에 밥 한번 먹어요", "Let's grab a meal sometime (often a friendly goodbye, not a firm plan)", E, B, ["relationships", "food"], "나중 밥 한번 먹다~eat"),
    (247, "잘 들어가세요", "Get home safely (said when parting in the evening)", E, B, ["relationships"], "잘~well 들어가다"),
    (248, "조심히 가세요", "Take care getting home / Travel safely", E, B, ["relationships", "travel"], "조심하다 가다"),
    (249, "먼저 갈게요", "I'll head off first (leaving before others)", E, B, ["relationships", "work"], "먼저 가다"),
    (250, "내일 봐요", "See you tomorrow", E, B, ["relationships", "work"], "내일~adverb 보다~see"),
    (52, "좋은 하루 보내세요", "Have a nice day", E, B, ["daily"], "좋다 하루 보내다"),
    (53, "주말 잘 보내세요", "Have a good weekend", E, B, ["daily", "work"], "주말 잘~well 보내다"),
    (251, "잘 다녀오세요", "Have a good trip / See you when you're back (to someone going out)", E, B, ["relationships", "travel"], "잘~well 다녀오다"),
    (252, "다녀오겠습니다", "I'm off! (said when leaving home or the office for a while)", E, B, ["daily"], "다녀오다"),
    (253, "다녀왔습니다", "I'm back! (said when coming home)", E, B, ["daily"], "다녀오다"),
    (254, "들어오세요", "Come in", E, B, ["daily"], "들어오다"),
    (255, "앉으세요", "Please have a seat", E, B, ["daily"], "앉다"),
    (256, "편하게 하세요", "Make yourself comfortable / Relax", E, B, ["daily", "relationships"], "편하다 하다"),
    (35, "맛있게 드세요", "Enjoy your meal (often said by restaurant staff)", E, B, ["food"], "맛있다"),
    (34, "많이 드세요", "Please eat a lot / Enjoy your meal (said by the host)", E, B, ["food"], "많이"),
    (257, "입에 맞으세요?", "Is the food to your taste? (literally 'does it fit your mouth?')", E, I, ["food", "relationships"], "입"),
    (62, "처음 뵙겠습니다", "Nice to meet you (formal, first meeting)", E, B, ["work", "relationships"], "처음 뵙다"),
    (61, "잘 부탁드립니다", "I look forward to working with you / Please take care of this (said when starting something together)", E, B, ["work", "relationships"], "잘~well 부탁 드리다"),

    # --- Everyday feelings ---
    (19, "깜짝이야", "You scared me! / What a surprise", E, B, ["feelings"], "깜짝"),
    (21, "큰일 났다", "I'm in big trouble / This is a disaster", E, B, ["feelings", "kdrama"], "큰일 나다"),
    (22, "아깝다", "What a waste / So close (regret over a missed chance or waste)", E, B, ["feelings"], "아깝다"),
    (258, "기분이 좋아요", "I'm in a good mood", E, B, ["feelings"], "기분 좋다"),
    (259, "속상해요", "I'm upset / That hurts (disappointed or sad)", E, I, ["feelings"], "속상하다"),
    (260, "짜증 나", "So annoying / I'm annoyed (casual)", E, B, ["feelings"], "짜증 나다"),
    (261, "스트레스 받아요", "I'm stressed", E, B, ["feelings", "work"], "스트레스 받다"),
    (262, "긴장돼요", "I'm nervous", E, B, ["feelings"], "긴장 되다"),
    (263, "부러워요", "I'm jealous / I envy you (usually friendly)", E, B, ["feelings", "relationships"], "부럽다"),
    (264, "대단해요", "That's amazing / Impressive", E, B, ["feelings", "relationships"], ""),
    (265, "잘 어울려요", "It suits you / They go well together", E, B, ["shopping", "relationships"], "잘~well 어울리다"),
    (266, "귀여워요", "It's cute / You're cute", E, B, ["feelings"], "귀엽다"),
    (267, "신기하다", "How cool / That's fascinating (something new or surprising)", E, B, ["feelings"], "신기하다~amazing"),
    (268, "어색해요", "It's awkward", E, B, ["feelings", "relationships"], "어색하다"),
    (269, "귀찮아요", "It's a hassle / I can't be bothered", E, B, ["feelings"], "귀찮다"),
    (270, "힘들어요", "It's hard / I'm worn out", E, B, ["feelings"], "힘들다"),
    (79, "기대돼요", "I'm looking forward to it", E, B, ["feelings"], "기대 되다"),
    (80, "심심해요", "I'm bored", E, B, ["feelings"], "심심하다"),
    (85, "마음에 들어요", "I like it (it suits my taste)", E, B, ["shopping", "feelings"], "마음 들다~enter"),
    (76, "힘내세요", "Cheer up / Keep going (encouragement)", E, B, ["feelings", "relationships"], "힘 내다"),
    (77, "파이팅", "You can do it! / Let's go! (encouragement)", E, B, ["daily", "school"], ""),
    (75, "잘했어요", "Well done", E, B, ["daily", "school"], "잘하다"),
    (78, "축하해요", "Congratulations", E, B, ["relationships"], "축하 하다"),
    (271, "생일 축하해요", "Happy birthday", E, B, ["relationships"], "생일 축하 하다"),
    (272, "보고 싶어요", "I miss you (literally 'I want to see you')", E, B, ["relationships", "kdrama"], "보다~see"),
    (273, "사랑해요", "I love you", E, B, ["relationships", "kdrama"], "사랑 하다"),
    (274, "괜찮아질 거예요", "It'll be okay / Things will get better", E, B, ["feelings", "relationships"], "괜찮다"),
    (49, "몸조심하세요", "Take care of yourself (often when someone is ill or travelling)", E, B, ["health", "relationships"], "몸 조심하다"),
    (50, "빨리 나으세요", "Get well soon", E, B, ["health"], "빨리 낫다~recover"),
    (51, "푹 쉬세요", "Get plenty of rest", E, B, ["health"], "푹 쉬다~rest"),
    (29, "수고하세요", "Said when leaving people who are still working (shop staff, colleagues)", E, B, ["daily", "work"], "수고 하다"),
    (30, "수고하셨습니다", "Thank you for your hard work (said at the end of work or a task)", E, B, ["work"], "수고 하다"),
    (275, "고생했어요", "Good work / You must be tired (after something hard)", E, B, ["work", "relationships"], "고생 하다"),
    (31, "고생 많으셨어요", "You've been through a lot / Thank you for all your effort", E, I, ["work", "relationships"], "고생 많다"),

    # --- Linking words and softeners ---
    (64, "실례지만", "Excuse me, but… (before a personal question or request)", E, B, ["daily"], "실례"),
    (65, "죄송한데요", "Sorry, but… (softening a request or interruption)", E, B, ["daily"], "죄송하다"),
    (66, "혹시", "By any chance… (softens a question)", E, B, ["daily"], "혹시"),
    (67, "일단", "First of all / For now", E, B, ["daily"], "일단"),
    (68, "아무튼", "Anyway", E, B, ["daily"], "아무튼"),
    (69, "그건 그렇고", "By the way / Anyway (changing the subject)", E, I, ["daily"], "그렇다"),
    (70, "솔직히 말하면", "To be honest", E, I, ["daily"], "솔직히 말하다"),
    (71, "제 말이요", "That's what I'm saying / Exactly", E, I, ["daily"], "말~speech"),
    (11, "그럴 리가요", "That can't be / There's no way that's true", E, I, ["daily"], "그렇다"),
    (87, "어디 보자", "Let me see…", E, I, ["daily"], "보다~see"),
    (276, "그렇긴 하죠", "That's true, I suppose", E, I, ["daily"], "그렇다 하다"),
    (277, "뭐 어때요", "So what? / What's the harm?", E, I, ["daily"], "어떻다"),
    (7, "별말씀을요", "Don't mention it (polite reply to thanks or praise)", E, I, ["daily"], "말씀"),
    (8, "덕분에요", "Thanks to you (polite reply when asked how things went)", E, B, ["daily", "relationships"], "덕분"),
    (73, "그럴 줄 알았어", "I knew it (casual)", E, I, ["daily", "kdrama"], "그렇다 알다"),
    (74, "됐어요", "That's enough / Never mind / No thanks (can sound cold)", E, I, ["daily"], "되다"),

    # --- Work and school ---
    (278, "확인해 볼게요", "I'll check", E, B, ["work"], "확인 하다 보다~see"),
    (279, "회의 중이에요", "I'm in a meeting", E, B, ["work"], "회의~meeting"),
    (280, "질문 있어요", "I have a question", E, B, ["school", "work"], "질문 있다~adjective"),
    (281, "잠깐 얘기 좀 해요", "Can we talk for a minute?", E, B, ["work", "relationships"], "잠깐~adverb 얘기 좀 하다"),
    (282, "열심히 하겠습니다", "I'll do my best (literally 'I'll work hard')", E, B, ["work", "school"], "열심히 하다"),
    (283, "먼저 들어가 보겠습니다", "I'll be leaving first (polite, leaving the office before others)", E, I, ["work"], "먼저 들어가다 보다~see"),
    (54, "새해 복 많이 받으세요", "Happy New Year (literally: receive many blessings)", E, B, ["daily"], "새해 복 많이 받다"),

    # --- Food and drinks with people ---
    (88, "오늘은 제가 살게요", "Today is on me (I'll pay)", E, B, ["food", "relationships"], "오늘~noun 사다"),
    (284, "한잔해요", "Let's have a drink", E, B, ["food", "relationships"], "한잔 하다"),
    (90, "건배", "Cheers!", E, B, ["food"], ""),
    (285, "취했어요", "I'm drunk", E, B, ["food"], "취하다~drunk"),
    (286, "서비스예요", "It's on the house (a free extra from the restaurant or shop)", E, B, ["food", "shopping"], "서비스"),
    (287, "양파 빼 주세요", "No onions, please (swap in any ingredient)", E, B, ["food"], "양파 빼다 주다"),
    (288, "많이 파세요", "Sell a lot! (a friendly goodbye to a shop owner)", E, I, ["shopping"], "많이 팔다"),
    (89, "한턱낼게요", "I'll treat you (usually to celebrate good news)", E, I, ["food", "relationships"], ""),
    (91, "원샷", "Bottoms up (drink it all in one go)", E, I, ["food"], ""),
    (92, "2차 가요", "Let's go to a second place (another bar or restaurant after the first)", E, I, ["food", "work"], "가다"),
    (93, "회식", "A team dinner or drinks with colleagues", E, I, ["work", "food"], ""),
    (81, "배고파 죽겠어요", "I'm starving (literally: so hungry I could die)", E, I, ["food", "feelings"], "배고프다 죽다"),
    (82, "피곤해 죽겠어요", "I'm exhausted", E, I, ["feelings", "health"], "피곤하다 죽다"),
    (83, "정신이 없어요", "I'm swamped / My head is all over the place", E, I, ["work", "feelings"], "정신 없다"),
    (84, "시간 가는 줄 몰랐어요", "I lost track of time", E, I, ["feelings"], "시간 가다 모르다"),
    (94, "칼퇴근", "Leaving work exactly on time", E, I, ["work"], "퇴근"),
    (95, "야근", "Working late / overtime at night", E, I, ["work"], ""),
    (57, "말 놓으세요", "Please speak casually to me (inviting someone to drop polite speech)", E, I, ["relationships"], "말~speech 놓다"),
    (58, "말 놓아도 돼요?", "Can I speak casually with you?", E, I, ["relationships"], "말~speech 놓다 되다"),
    (63, "말씀 많이 들었어요", "I've heard a lot about you", E, I, ["relationships", "work"], "말씀 많이 듣다"),
    (289, "신세 많이 졌습니다", "I owe you a lot (thanks for help or hospitality)", E, I, ["relationships"], "신세 많이 지다~carry"),

    # --- Casual Korean and K-drama lines ---
    (290, "그치?", "Right? (casual, looking for agreement)", E, B, ["daily", "kdrama"], ""),
    (291, "세상에", "Oh my goodness (literally 'in the world')", E, B, ["feelings", "kdrama"], "세상"),
    (292, "장난 아니다", "It's no joke / It's insane (very good or very bad, casual)", E, I, ["daily", "kdrama"], "장난 아니다"),
    (293, "미치겠다", "It's driving me crazy (casual)", E, I, ["feelings", "kdrama"], "미치다~mad"),
    (294, "정신 차려", "Snap out of it / Get a grip (casual)", E, I, ["kdrama"], "정신"),
    (295, "가지 마", "Don't go (casual)", E, B, ["kdrama", "relationships"], "가다"),
    (296, "내 말 들어 봐", "Listen to me (casual)", E, B, ["kdrama"], "말~speech 듣다 보다~see"),
    (297, "아싸", "Yes! / Woohoo! (casual, when something goes your way)", E, B, ["daily"], ""),
    (298, "내가 뭐랬어", "What did I tell you? / Told you so (casual)", E, I, ["kdrama"], ""),
    (96, "밀당", "Push and pull in dating (playing hard to get)", E, I, ["relationships", "kdrama"], ""),
    (97, "썸 타다", "To be in a 'something' — mutual interest before officially dating", E, I, ["relationships", "kdrama"], "타다~ride"),
    (98, "첫눈에 반하다", "To fall in love at first sight", E, I, ["relationships", "kdrama"], "눈~eye"),

    # --- Idioms (관용구) ---
    (102, "눈치를 보다", "To watch others' reactions and act carefully around them", ID, I, ["relationships", "work"], "보다~see"),
    (101, "눈치가 빠르다", "To be quick to read the room / pick up on unspoken cues", ID, I, ["relationships"], "빠르다"),
    (299, "말이 통하다", "To understand each other / click (literally 'words get through')", ID, I, ["relationships"], "말~speech 통하다"),
    (300, "정이 들다", "To grow attached (to a person, place or thing over time)", ID, I, ["relationships", "feelings"], "정 들다~enter"),
    (301, "바가지를 쓰다", "To get ripped off / overcharged", ID, I, ["shopping", "travel"], "바가지 쓰다~wear"),
    (302, "손이 많이 가다", "To take a lot of work (literally 'hands go to it a lot')", ID, I, ["food", "work"], "손 많이 가다"),
    (303, "기가 막히다", "To be stunning (amazingly good) or dumbfounding (unbelievably bad)", ID, I, ["feelings", "food"], "기~spirit 막히다"),
    (100, "발이 넓다", "To know a lot of people; literally 'feet are wide'", ID, I, ["relationships"], "발~foot 넓다"),
    (108, "눈이 높다", "To have high standards (in partners, products…)", ID, I, ["relationships", "shopping"], "눈~eye 높다"),
    (104, "입이 무겁다", "To be good at keeping secrets; literally 'mouth is heavy'", ID, I, ["relationships"], "입 무겁다"),
    (105, "입이 가볍다", "To be unable to keep secrets; literally 'mouth is light'", ID, I, ["relationships"], "입 가볍다"),
    (103, "입이 짧다", "To be a picky or light eater; literally 'mouth is short'", ID, I, ["food"], "입 짧다"),
    (99, "손이 크다", "To be generous (especially cooking or giving too much); literally 'hand is big'", ID, I, ["food", "relationships"], "손 크다~adjective"),
    (110, "배가 아프다", "To be jealous of someone's success (also literally 'stomach hurts')", ID, I, ["feelings"], "배~belly 아프다"),
    (112, "머리를 식히다", "To clear one's head / take a break", ID, I, ["feelings", "health"], "머리~head 식히다"),
    (113, "바람맞다", "To be stood up", ID, I, ["relationships"], "바람~wind 맞다~receive"),
    (106, "귀가 얇다", "To be easily persuaded; literally 'ears are thin'", ID, I, ["relationships"], "귀 얇다"),
    (109, "마음이 넓다", "To be generous and understanding", ID, I, ["relationships"], "마음 넓다"),
    (107, "얼굴이 두껍다", "To be shameless / thick-skinned", ID, I, ["relationships"], "얼굴 두껍다"),
    (117, "가슴이 뛰다", "Heart races (excitement or nerves)", ID, I, ["feelings"], "가슴 뛰다~jump"),
    (118, "어깨가 무겁다", "To feel a heavy responsibility", ID, I, ["work", "feelings"], "어깨 무겁다"),
    (120, "뒤통수를 맞다", "To be betrayed; literally 'get hit on the back of the head'", ID, I, ["relationships", "kdrama"], "맞다~hit"),
    (122, "손발이 맞다", "To work well together", ID, I, ["work"], "손발 맞다~correct"),
    (111, "손을 떼다", "To quit / wash one's hands of something", ID, I, ["work"], "손 떼다"),
    (114, "미역국을 먹다", "To fail (an exam or application); literally 'eat seaweed soup'", ID, I, ["school"], "미역 국 먹다~eat"),
    (115, "시치미를 떼다", "To pretend not to know / play innocent", ID, A, ["kdrama"], "떼다"),
    (116, "발 벗고 나서다", "To actively step in to help", ID, A, ["relationships"], "발~foot 벗다 나서다"),
    (119, "코가 납작해지다", "To be humbled / have one's pride crushed", ID, A, ["feelings"], "코"),
    (121, "눈에 밟히다", "Can't stop thinking about someone or something (worry or longing)", ID, A, ["feelings", "kdrama"], "눈~eye 밟다"),
    (123, "발등에 불이 떨어지다", "To be in an urgent situation; literally 'fire falls on the top of your foot'", ID, A, ["work"], "발등 불 떨어지다"),

    # --- Proverbs (속담) ---
    (128, "누워서 떡 먹기", "A piece of cake; literally 'eating rice cake lying down'", PR, I, ["daily"], "눕다 떡 먹다~eat"),
    (304, "식은 죽 먹기", "Easy as pie; literally 'eating cooled porridge'", PR, I, ["daily"], "식다 죽~noun 먹다~eat"),
    (126, "금강산도 식후경", "Eat first, then everything else; literally 'even Mt. Geumgang is sightseeing after a meal'", PR, I, ["food", "travel"], ""),
    (305, "김칫국부터 마시지 마", "Don't count your chickens before they hatch; literally 'don't drink the kimchi soup first'", PR, I, ["daily"], "김치 국 마시다"),
    (306, "그림의 떡", "Pie in the sky / Something you can't have; literally 'rice cake in a picture'", PR, I, ["daily"], "그림 떡"),
    (124, "세 살 버릇 여든까지 간다", "Old habits die hard; literally 'habits at three last until eighty'", PR, I, ["daily"], "버릇 여든 가다"),
    (125, "가는 말이 고와야 오는 말이 곱다", "Be kind to others and they'll be kind to you; literally 'outgoing words must be nice for incoming words to be nice'", PR, I, ["relationships"], "가다 말~speech 곱다 오다"),
    (307, "티끌 모아 태산", "Every little bit adds up; literally 'gather dust and make a great mountain'", PR, I, ["daily"], "모으다"),
    (308, "원숭이도 나무에서 떨어진다", "Even experts make mistakes; literally 'even monkeys fall from trees'", PR, I, ["daily", "work"], "원숭이 나무 떨어지다"),
    (309, "고생 끝에 낙이 온다", "After hardship comes happiness", PR, I, ["feelings"], "고생 끝 오다"),
    (310, "백문이 불여일견", "Seeing is believing; literally 'hearing a hundred times is not as good as seeing once'", PR, A, ["daily"], ""),
    (127, "백지장도 맞들면 낫다", "Many hands make light work; literally 'even a sheet of paper is easier lifted together'", PR, A, ["work"], "낫다~better"),
]


def resolve_words(words_path):
    """Maps each word token to a words.json ID, collecting every problem."""
    entries = json.loads(Path(words_path).read_text(encoding="utf-8"))["items"]
    by_korean = {}
    for e in entries:
        by_korean.setdefault(e["korean"], []).append(e)

    def resolve(token):
        korean, _, hint = token.partition("~")
        hits = by_korean.get(korean, [])
        if hint:
            hits = [h for h in hits if hint == h["partOfSpeech"] or hint.lower() in h["meaning"].lower()]
        if len(hits) == 1:
            return hits[0]["id"], None
        if not hits:
            return None, f"{token}: not in words.json" + (" with that hint" if hint else "")
        options = "; ".join(f"{h['meaning']}" for h in hits)
        return None, f"{token}: ambiguous, add a hint ({options})"

    return resolve


def main():
    out = Path(sys.argv[1])
    resolve = resolve_words(out.with_name("words.json"))

    ids = [p[0] for p in PHRASES]
    duplicates = sorted({i for i in ids if ids.count(i) > 1})
    assert not duplicates, f"duplicate ids {duplicates}"
    assert not set(ids) & RETIRED, "a retired id is back in use"
    expected = set(range(1, max(ids) + 1)) - RETIRED
    assert set(ids) == expected, f"missing ids {sorted(expected - set(ids))}"
    koreans = [p[1] for p in PHRASES]
    assert len(set(koreans)) == len(koreans), "duplicate phrase"

    items, problems = [], []
    for rank, (n, korean, meaning, kind, level, topics, words) in enumerate(PHRASES, start=1):
        word_ids = []
        for token in words.split():
            word_id, problem = resolve(token)
            if problem:
                problems.append(f"p:{n} {korean}: {problem}")
            elif word_id not in word_ids:
                word_ids.append(word_id)
        items.append({
            "id": f"p:{n}",
            "korean": korean,
            "kind": "phrase",
            "meaning": meaning,
            "definition": None,
            "partOfSpeech": kind,
            "hanja": None,
            "level": level,
            "rank": rank,
            "topics": topics,
            "wordIDs": word_ids,
        })

    if problems:
        sys.exit("\n".join(problems))

    data = {"version": 2, "source": "Curated for Ohaneo", "items": items}
    with out.open("w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print(len(items), "phrases")


if __name__ == "__main__":
    main()
