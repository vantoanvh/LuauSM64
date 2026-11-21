--!strict
--!optimize 2

--[[
	Port of include/text_strings.h.in (US build): the strings of the file select, the pause and course complete menus and the end
	cutscene, as the byte strings the C text macros expand to. A string is a buffer of the dialog character encoding the font
	tables are indexed by, ended by 0xFF.

	Design Notes
		Encode is the `_("...")` text macro of the C: every character becomes its byte of charmap.txt. The multi-character
		tokens of the charmap ('the' and 'you' of the dialog text) are not applied; none of these strings has them in the form
		the C writes with `_`, and the ones written with `__` are exactly the ones that must not have them.
]]

const ParenthesisPair = { 0xE2 }
const Bytes: { [string]: { number } } = {}

Bytes["'"] = { 0x3E }
Bytes["."] = { 0x3F }
Bytes["☺"] = { 0x40, 0x41 }
Bytes[","] = { 0x6F }
Bytes[" "] = { 0x9E }
Bytes["-"] = { 0x9F }
Bytes["("] = { 0xE1 }
Bytes[")"] = { 0xE3 }
Bytes["+"] = { 0xE4 }
Bytes["&"] = { 0xE5 }
Bytes[":"] = { 0xE6 }
Bytes["!"] = { 0xF2 }
Bytes["%"] = { 0xF3 }
Bytes["?"] = { 0xF4 }
Bytes["~"] = { 0xF7 }
Bytes["$"] = { 0xF9 }
Bytes["★"] = { 0xFA }
Bytes["×"] = { 0xFB }
Bytes["☆"] = { 0xFD }
Bytes["/"] = { 0xD0 }

for Digit = 0, 9 do
	Bytes[string.char(48 + Digit)] = { Digit }
end

for Letter = 0, 25 do
	Bytes[string.char(65 + Letter)] = { 10 + Letter }
	Bytes[string.char(97 + Letter)] = { 36 + Letter }
end

-- The `_("...")` macro of text_strings.h.in
const function Encode(Text: string): buffer
	const Characters: { string } = {}
	const Encoded: { number } = {}
	local Index = 1

	for _, Code in utf8.codes(Text) do
		table.insert(Characters, utf8.char(Code))
	end

	while Index <= #Characters do
		const Pair = Characters[Index] == ")" and Characters[Index + 1] == "("
		const Mapped = if Pair then ParenthesisPair else Bytes[Characters[Index]]

		if Mapped == nil then
			error(`no charmap entry for {Characters[Index]}`)
		end

		if Pair then
			Index += 1
		end

		for _, Byte in Mapped do
			table.insert(Encoded, Byte)
		end

		Index += 1
	end

	table.insert(Encoded, 0xFF)

	const Result = buffer.create(#Encoded)

	for Position, Byte in Encoded do
		buffer.writeu8(Result, Position - 1, Byte)
	end

	return Result
end

-- from include/text_strings.h.in:data
const text_strings_h = {
	TEXT_EMPTY_STRING = Encode(""),
	TEXT_ZERO = Encode("0"),
	TEXT_COIN = Encode("$"),
	TEXT_STAR = Encode("★"),
	TEXT_COIN_X = Encode("$×"),
	TEXT_STAR_X = Encode("★×"),
	TEXT_VARIABLE_X = Encode("×"),
	TEXT_STAR_DIFF = Encode("★"),
	TEXT_UNFILLED_STAR = Encode("☆"),
	TEXT_4DASHES = Encode("----"),
	TEXT_NEW = Encode("NEW"),
	TEXT_PAUSE = Encode("PAUSE"),
	TEXT_HUD_CONGRATULATIONS = Encode("CONGRATULATIONS"),
	TEXT_MARIO = Encode("MARIO"),
	TEXT_SELECT_FILE = Encode("SELECT FILE"),
	TEXT_CHECK_FILE = Encode("CHECK FILE"),
	TEXT_COPY_FILE = Encode("COPY FILE"),
	TEXT_ERASE_FILE = Encode("ERASE FILE"),
	TEXT_SOUND_SELECT = Encode("SOUND SELECT"),
	TEXT_FILE_MARIO_A = Encode("MARIO A"),
	TEXT_FILE_MARIO_B = Encode("MARIO B"),
	TEXT_FILE_MARIO_C = Encode("MARIO C"),
	TEXT_FILE_MARIO_D = Encode("MARIO D"),
	TEXT_SCORE = Encode("SCORE"),
	TEXT_COPY = Encode("COPY"),
	TEXT_ERASE = Encode("ERASE"),
	TEXT_STEREO = Encode("STEREO"),
	TEXT_MONO = Encode("MONO"),
	TEXT_HEADSET = Encode("HEADSET"),
	TEXT_SAVED_DATA_EXISTS = Encode("SAVED DATA EXITS"),
	TEXT_NO_SAVED_DATA_EXISTS = Encode("NO SAVED DATA EXISTS"),
	TEXT_RETURN = Encode("RETURN"),
	TEXT_CHECK_SCORE = Encode("CHECK SCORE"),
	TEXT_COPY_FILE_BUTTON = Encode("COPY FILE"),
	TEXT_ERASE_FILE_BUTTON = Encode("ERASE FILE"),
	TEXT_HI_SCORE = Encode("HI SCORE"),
	TEXT_MY_SCORE = Encode("MY SCORE"),
	TEXT_SCORE_MARIO_A = Encode("☺A"),
	TEXT_SCORE_MARIO_B = Encode("☺B"),
	TEXT_SCORE_MARIO_C = Encode("☺C"),
	TEXT_SCORE_MARIO_D = Encode("☺D"),
	TEXT_COPY_IT_TO_WHERE = Encode("COPY IT TO WHERE?"),
	TEXT_COPYING_COMPLETED = Encode("COPYING COMPLETED"),
	TEXT_NO_FILE_TO_COPY_FROM = Encode("NO EMPTY FILE"),
	TEXT_SURE = Encode("SURE?"),
	TEXT_YES = Encode("YES"),
	TEXT_NO = Encode("NO"),
	TEXT_FILE_MARIO_A_JUST_ERASED = Encode("MARIO A JUST ERASED"),
	TEXT_COURSE = Encode("COURSE"),
	TEXT_MYSCORE = Encode("MYSCORE"),
	TEXT_CONTINUE = Encode("CONTINUE"),
	TEXT_EXIT_COURSE = Encode("EXIT COURSE"),
	TEXT_CAMERA_ANGLE_R = Encode("SET CAMERA ANGLE WITH R"),
	TEXT_LAKITU_MARIO = Encode("LAKITU + MARIO"),
	TEXT_LAKITU_STOP = Encode("LAKITU + STOP"),
	TEXT_NORMAL_UPCLOSE = Encode("(NORMAL)(UP-CLOSE)"),
	TEXT_NORMAL_FIXED = Encode("(NORMAL)(FIXED)"),
	TEXT_CATCH = Encode("CATCH"),
	TEXT_CLEAR = Encode("CLEAR"),
	TEXT_HUD_HI_SCORE = Encode("HI SCORE"),
	TEXT_SAVE_AND_CONTINUE = Encode("SAVE & CONTINUE"),
	TEXT_SAVE_AND_QUIT = Encode("SAVE & QUIT"),
	TEXT_CONTINUE_WITHOUT_SAVING = Encode("CONTINUE, DON'T SAVE"),
	TEXT_FILE_MARIO_EXCLAMATION = Encode("Mario!"),
	TEXT_POWER_STARS_RESTORED = Encode("The power of the Stars is restored to the castle..."),
	TEXT_THANKS_TO_YOU = Encode("...and it's all thanks to you!"),
	TEXT_THANK_YOU_MARIO = Encode("Thank you, Mario!"),
	TEXT_SOMETHING_SPECIAL = Encode("We have to do something special for you..."),
	TEXT_LISTEN_EVERYBODY = Encode("Listen, everybody,"),
	TEXT_LETS_HAVE_CAKE = Encode("let's bake a delicious cake..."),
	TEXT_FOR_MARIO = Encode("...for Mario..."),
	TEXT_FILE_MARIO_QUESTION = Encode("Mario!"),
}

return text_strings_h
