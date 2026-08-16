class_name CharSets
extends RefCounted
## The character-set catalog: the single source of truth for which characters
## exist, in what order, under which set id, and how they are labelled.
##
## Set ids match the stroke-file names in data/strokes/<id>.json and the "set"
## field inside every entry there. The Stroke Recorder (Step 3) iterates these
## sets; the character-select menu (Step 7) and the dataset work (Step 8) reuse
## the same catalog, so a character only ever has to be added here.
##
## Set shape (as returned by get_set()):
## { "id": String, "label": String, "font": FONT_THAI | FONT_LATIN,
##   "combining": bool, "numeric": bool,
##   "chars": PackedStringArray, "names": PackedStringArray }
##
## "combining" marks sets whose glyphs cannot stand alone (Thai vowels and tone
## marks); they are displayed on a dotted placeholder circle.
##
## "numeric" marks the sets whose characters stand for a quantity — the digits
## and the Thai numerals, which are the same ten quantities written twice. Step
## 10's counting activity asks here (value_of) before every character: a numeral
## is counted out in objects before it is written, and nothing else is.

const FONT_THAI := "thai"
const FONT_LATIN := "latin"

const STROKE_DIR := "res://data/strokes"

## Where path_of() looks for stroke files. Only the recorder test changes this,
## pointing it at a scratch directory under user:// so a test run can never
## touch — or depend on the contents of — the real hand-recorded dataset.
static var stroke_dir: String = STROKE_DIR

## Set ids in menu / recorder order.
const SET_IDS: PackedStringArray = [
	"thai_consonants",
	"english_upper",
	"english_lower",
	"digits",
	"thai_numerals",
	"thai_vowels",
]

const THAI_CONSONANT_CHARS := "กขฃคฅฆงจฉชซฌญฎฏฐฑฒณดตถทธนบปผฝพฟภมยรลวศษสหฬอฮ"

## Acrophony names, in the same order as THAI_CONSONANT_CHARS.
const THAI_CONSONANT_NAMES: PackedStringArray = [
	"ก ไก่", "ข ไข่", "ฃ ขวด", "ค ควาย", "ฅ คน", "ฆ ระฆัง", "ง งู", "จ จาน",
	"ฉ ฉิ่ง", "ช ช้าง", "ซ โซ่", "ฌ เฌอ", "ญ หญิง", "ฎ ชฎา", "ฏ ปฏัก", "ฐ ฐาน",
	"ฑ มณโฑ", "ฒ ผู้เฒ่า", "ณ เณร", "ด เด็ก", "ต เต่า", "ถ ถุง", "ท ทหาร", "ธ ธง",
	"น หนู", "บ ใบไม้", "ป ปลา", "ผ ผึ้ง", "ฝ ฝา", "พ พาน", "ฟ ฟัน", "ภ สำเภา",
	"ม ม้า", "ย ยักษ์", "ร เรือ", "ล ลิง", "ว แหวน", "ศ ศาลา", "ษ ฤๅษี", "ส เสือ",
	"ห หีบ", "ฬ จุฬา", "อ อ่าง", "ฮ นกฮูก",
]

const DIGIT_CHARS := "0123456789"

const DIGIT_NAMES: PackedStringArray = [
	"zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
]

const THAI_NUMERAL_CHARS := "๐๑๒๓๔๕๖๗๘๙"

const THAI_NUMERAL_NAMES: PackedStringArray = [
	"ศูนย์", "หนึ่ง", "สอง", "สาม", "สี่", "ห้า", "หก", "เจ็ด", "แปด", "เก้า",
]

## Thai vowel signs and tone marks, in the order they are taught: the fifteen
## สระ in recital order, then the four tone marks, then ไม้ไต่คู้ and การันต์.
##
## Listed one quoted character per line rather than as a single string the way
## the other sets are: every one of these code points combines with whatever
## precedes it, so a run of them stacks into an unreadable blob and cannot be
## edited safely. The comment on each line shows the mark on a dotted
## placeholder — exactly how the recorder, the grid and the tracing scene draw
## it — so the character, its position and its name can be checked by eye.
const THAI_VOWEL_CHARS: PackedStringArray = [
	"ะ",  # ◌ะ  sara a
	"ั",  # ◌ั  mai han akat
	"า",  # ◌า  sara aa
	"ำ",  # ◌ำ  sara am
	"ิ",  # ◌ิ  sara i
	"ี",  # ◌ี  sara ii
	"ึ",  # ◌ึ  sara ue
	"ื",  # ◌ื  sara uee
	"ุ",  # ◌ุ  sara u
	"ู",  # ◌ู  sara uu
	"เ",  # เ◌  sara e
	"แ",  # แ◌  sara ae
	"โ",  # โ◌  sara o
	"ใ",  # ใ◌  sara ai mai muan
	"ไ",  # ไ◌  sara ai mai malai
	"่",  # ◌่  mai ek
	"้",  # ◌้  mai tho
	"๊",  # ◌๊  mai tri
	"๋",  # ◌๋  mai chattawa
	"็",  # ◌็  mai taikhu
	"์",  # ◌์  karan (thanthakhat)
]

## Names, in the same order as THAI_VOWEL_CHARS. Each one is written on อ so it
## reads as itself: a bare combining mark has nothing to sit on.
const THAI_VOWEL_NAMES: PackedStringArray = [
	"สระอะ", "ไม้หันอากาศ", "สระอา", "สระอำ", "สระอิ", "สระอี", "สระอึ", "สระอือ",
	"สระอุ", "สระอู", "สระเอ", "สระแอ", "สระโอ", "สระใอ ไม้ม้วน", "สระไอ ไม้มลาย",
	"ไม้เอก", "ไม้โท", "ไม้ตรี", "ไม้จัตวา", "ไม้ไต่คู้", "การันต์",
]

const UPPER_CHARS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

const LOWER_CHARS := "abcdefghijklmnopqrstuvwxyz"

static var _sets: Dictionary = {}


## Every set, keyed by id, in SET_IDS order.
static func all() -> Dictionary:
	if _sets.is_empty():
		_sets = _build()
	return _sets


## A single set, or {} when `id` is unknown.
static func get_set(id: String) -> Dictionary:
	return all().get(id, {})


static func has_set(id: String) -> bool:
	return all().has(id)


## Ids of sets that have characters to record (skips not-yet-filled stubs).
static func recordable_ids() -> PackedStringArray:
	var out := PackedStringArray()
	for id in SET_IDS:
		if not chars_of(id).is_empty():
			out.append(id)
	return out


static func chars_of(id: String) -> PackedStringArray:
	return get_set(id).get("chars", PackedStringArray())


## Display name of a character ("ก ไก่"); falls back to the character itself.
static func name_of(id: String, chr: String) -> String:
	var set_def := get_set(id)
	if set_def.is_empty():
		return chr
	var index: int = Array(set_def["chars"]).find(chr)
	if index == -1:
		return chr
	return set_def["names"][index]


static func label_of(id: String) -> String:
	return get_set(id).get("label", id)


static func font_of(id: String) -> String:
	return get_set(id).get("font", FONT_LATIN)


static func is_combining(id: String) -> bool:
	return get_set(id).get("combining", false)


## True for the sets whose characters are quantities: "digits" and
## "thai_numerals".
static func is_numeric(id: String) -> bool:
	return get_set(id).get("numeric", false)


## The quantity a character stands for, or -1 when it does not stand for one —
## every character of a non-numeric set, and anything not in the set at all.
## The tracing scene counts objects out before a character with a value ≥ 0 and
## goes straight to the demo for everything else, so -1 is the ordinary answer.
static func value_of(id: String, chr: String) -> int:
	if not is_numeric(id):
		return -1
	if Array(chars_of(id)).find(chr) == -1:
		return -1
	return numeral_value(chr)


## Code point of "0" in each numeral system the catalog uses.
const ZERO_CODES: PackedInt32Array = [0x0030, 0x0E50]  ## ASCII "0", Thai "๐".

## The value of a single numeral character, read from its code point rather than
## from its position in the set: ๓ is three because it is U+0E53, not because it
## is the fourth thing in a list. A numeral typed into the wrong slot is then a
## validate() error rather than a child counting four apples for ๓.
static func numeral_value(chr: String) -> int:
	if chr.length() != 1:
		return -1
	var code := chr.unicode_at(0)
	for zero in ZERO_CODES:
		if code >= zero and code <= zero + 9:
			return code - zero
	return -1


## The dotted circle a mark that cannot stand alone is shown on.
const PLACEHOLDER := "◌"

## The five Thai vowels written *before* the consonant they belong to. Every
## other mark in the set is written after, above or below it. Text is stored in
## the order it is written, so a leading vowel put after the placeholder comes
## out as "◌เ" — the mirror image of how a child is taught to write it.
const THAI_LEADING_VOWELS := "เแโใไ"

## How a character should be drawn: itself for a set that stands alone, and the
## mark on its placeholder — on the side it is actually written — for one that
## does not. The recorder, the character grid and the tracing scene all ask
## here, so the guide glyph, the recorded strokes and the child's copy agree.
static func display_form(id: String, chr: String) -> String:
	if not is_combining(id):
		return chr
	if THAI_LEADING_VOWELS.contains(chr):
		return chr + PLACEHOLDER
	return PLACEHOLDER + chr


## Path of the stroke file backing a set.
static func path_of(id: String) -> String:
	return "%s/%s.json" % [stroke_dir, id]


## Catalog integrity check — used by the test suite and cheap enough to call
## at recorder start-up. Returns { "ok": true } or { "ok": false, "error": … }.
static func validate() -> Dictionary:
	var seen_chars: Dictionary = {}
	for id in SET_IDS:
		if not all().has(id):
			return {"ok": false, "error": "set \"%s\" listed in SET_IDS but not built" % id}
		var set_def: Dictionary = all()[id]
		var chars: PackedStringArray = set_def["chars"]
		var names: PackedStringArray = set_def["names"]
		if chars.size() != names.size():
			return {"ok": false, "error": "set \"%s\": %d chars but %d names"
					% [id, chars.size(), names.size()]}
		if not (set_def["font"] in [FONT_THAI, FONT_LATIN]):
			return {"ok": false, "error": "set \"%s\": unknown font \"%s\"" % [id, set_def["font"]]}
		for i in chars.size():
			var chr := chars[i]
			if chr.is_empty():
				return {"ok": false, "error": "set \"%s\": empty character at index %d" % [id, i]}
			if names[i].is_empty():
				return {"ok": false, "error": "set \"%s\": empty name for \"%s\"" % [id, chr]}
			var key := "%s/%s" % [id, chr]
			if seen_chars.has(key):
				return {"ok": false, "error": "set \"%s\": duplicate character \"%s\"" % [id, chr]}
			seen_chars[key] = true
		if set_def["numeric"]:
			var problem := _check_numeric(id, chars)
			if not problem.is_empty():
				return {"ok": false, "error": problem}
	if all().size() != SET_IDS.size():
		return {"ok": false, "error": "built %d sets but SET_IDS lists %d"
				% [all().size(), SET_IDS.size()]}
	return {"ok": true}


## A numeric set must be the ten quantities 0–9, each written once: the counting
## activity draws value_of() objects for whatever it is given, so a character
## that maps to nothing (or to eleven) would show a child the wrong number of
## apples — quietly, and only for that one numeral. Returns "" when all is well.
static func _check_numeric(id: String, chars: PackedStringArray) -> String:
	var seen_values: Dictionary = {}
	for chr in chars:
		var value := numeral_value(chr)
		if value < 0:
			return "set \"%s\" is numeric but \"%s\" is not a numeral 0–9" % [id, chr]
		if seen_values.has(value):
			return "set \"%s\": two characters stand for %d" % [id, value]
		seen_values[value] = true
	if seen_values.size() != 10:
		return "set \"%s\" is numeric but covers %d of the ten quantities" % [id, seen_values.size()]
	return ""


static func _build() -> Dictionary:
	return {
		"thai_consonants": _make_set("thai_consonants", "Thai consonants", FONT_THAI,
				_split(THAI_CONSONANT_CHARS), THAI_CONSONANT_NAMES),
		"english_upper": _make_set("english_upper", "English capitals", FONT_LATIN,
				_split(UPPER_CHARS), _split(UPPER_CHARS)),
		"english_lower": _make_set("english_lower", "English small letters", FONT_LATIN,
				_split(LOWER_CHARS), _split(LOWER_CHARS)),
		"digits": _make_set("digits", "Digits", FONT_LATIN,
				_split(DIGIT_CHARS), DIGIT_NAMES, false, true),
		"thai_numerals": _make_set("thai_numerals", "Thai numerals", FONT_THAI,
				_split(THAI_NUMERAL_CHARS), THAI_NUMERAL_NAMES, false, true),
		"thai_vowels": _make_set("thai_vowels", "Thai vowels & tone marks", FONT_THAI,
				THAI_VOWEL_CHARS, THAI_VOWEL_NAMES, true),
	}


static func _make_set(id: String, label: String, font: String, chars: PackedStringArray,
		names: PackedStringArray, combining: bool = false, numeric: bool = false) -> Dictionary:
	return {
		"id": id,
		"label": label,
		"font": font,
		"combining": combining,
		"numeric": numeric,
		"chars": chars,
		"names": names,
	}


## Split a string into its individual characters (all catalog characters are
## single code points, so per-character indexing is safe here).
static func _split(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	for i in text.length():
		out.append(text[i])
	return out
