--!strict
--!optimize 2

--[[
	Port of src/menu/star_select.c.
]]

const Registry = require("../../groups/registry")

const GroupsTypesHPlus3 = require("../../groups/types_h_plus3")
const BehaviorIds = require("../rom/behavior_ids")
const GroupsIngameMenuPlus1 = require("../../groups/ingame_menu_plus1")
const IncludeCourseTableH = require("../../include/course_table_h")
const IncludeModelIdsH = require("../../include/model_ids_h")
const IncludeObjectFieldsH = require("../../include/object_fields_h")
const IncludeSoundsH = require("../../include/sounds_h")
const IncludePROsH = require("../../include/PR/os_h")
const IncludeTextStringsH = require("../../include/text_strings_h")
const Audio = require("../rom/audio_recorder")
const Gbi = require("../rom/gbi")
const MenuSymbols = require("../rom/menu_symbols")
const Rom = require("../rom/rom")
const Segment2Symbols = require("../rom/segment2_symbols")
const SrcGameArea = require("../game/area")
const SrcGameGameInit = require("../game/game_init")
const SrcGameMemory = require("../game/memory")
const SrcGameObjectHelpers = require("../game/object_helpers")
const SrcGameObjectListProcessor = require("../game/object_list_processor")
const SrcGameSaveFile = require("../game/save_file")
const StarSelectH = require("./star_select_h")

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

const function S8(Value: number): number
	const Wrapped = bit32.band(Value, 0xFF)

	return if Wrapped >= 0x80 then Wrapped - 0x100 else Wrapped
end

const function U8(Value: number): number
	return bit32.band(Value, 0xFF)
end

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

-- from src/menu/star_select.luau:scratch
const Scratch = {
	sSelectableStarIndex = { 0 },
	print_course_number_courseNum = buffer.create(4),
	-- the strings of ROM data the text printers take as a buffer (CopyRomString)
	print_act_selector_strings_currLevelName = buffer.create(64),
	print_act_selector_strings_selectedActName = buffer.create(64),
	-- TEXT_ZERO, of which the first character is each star number
	print_act_selector_strings_starNumbers = buffer.fromstring(buffer.tostring(IncludeTextStringsH.TEXT_ZERO)),
}

-- from src/menu/star_select.c:data
const star_select = {
	-- from src/menu/star_select.c:sStarSelectorModels L31-31
	sStarSelectorModels = { nil, nil, nil, nil, nil, nil, nil, nil } :: { GroupsTypesHPlus3.Object? },
	-- from src/menu/star_select.c:sLoadedActNum L34-34
	sLoadedActNum = 0,
	-- from src/menu/star_select.c:sObtainedStars L37-37
	sObtainedStars = 0,
	-- from src/menu/star_select.c:sVisibleStars L40-40
	sVisibleStars = 0,
	-- from src/menu/star_select.c:sInitSelectedActNum L43-43
	sInitSelectedActNum = 0,
	-- from src/menu/star_select.c:sSelectedActIndex L46-46
	sSelectedActIndex = 0,
	-- from src/menu/star_select.c:sSelectableStarIndex L50-50
	sSelectableStarIndex = 0,
	-- from src/menu/star_select.c:sActSelectorMenuTimer L53-53
	sActSelectorMenuTimer = 0,
	ACT_NAME_X = 163,
}

Registry.Register("src__menu__star_select", star_select)

-- from src/menu/star_select.c:bhv_act_selector_star_type_loop L59-86
function star_select.bhv_act_selector_star_type_loop()
	const o = SrcGameObjectListProcessor.gCurrentObject
	const starType = buffer.readi32(o.rawData, IncludeObjectFieldsH.oStarSelectorType)

	if starType == StarSelectH.STAR_SELECTOR_NOT_SELECTED then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oStarSelectorSize, buffer.readf32(o.rawData, IncludeObjectFieldsH.oStarSelectorSize) - 0.1)

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oStarSelectorSize) < 1.0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oStarSelectorSize, 1.0)
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, 0)
	elseif starType == StarSelectH.STAR_SELECTOR_SELECTED then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oStarSelectorSize, buffer.readf32(o.rawData, IncludeObjectFieldsH.oStarSelectorSize) + 0.1)

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oStarSelectorSize) > 1.3 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oStarSelectorSize, 1.3)
		end

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) + 0x800))
	elseif starType == StarSelectH.STAR_SELECTOR_100_COINS then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) + 0x800))
	end

	-- Scale act selector stars depending of the type selected
	SrcGameObjectHelpers.cur_obj_scale(buffer.readf32(o.rawData, IncludeObjectFieldsH.oStarSelectorSize))

	-- Unused timer, only referenced here. Probably replaced by sActSelectorMenuTimer
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oStarSelectorTimer, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oStarSelectorTimer) + 1))
end

-- from src/menu/star_select.c:render_100_coin_star L91-99
function star_select.render_100_coin_star(stars: number)
	stars = U8(TruncS32(stars))
	if bit32.btest(stars, bit32.lshift(1, 6)) then
		-- If the 100 coin star has been collected, create a new star selector next to the coin score.
		const selector = SrcGameObjectHelpers.spawn_object_abs_with_rot(SrcGameObjectListProcessor.gCurrentObject, 0, IncludeModelIdsH.MODEL_STAR, BehaviorIds.bhvActSelectorStarType, 370, 24, -300, 0, 0, 0)

		star_select.sStarSelectorModels[7] = selector
		buffer.writef32(selector.rawData, IncludeObjectFieldsH.oStarSelectorSize, 0.8)
		buffer.writei32(selector.rawData, IncludeObjectFieldsH.oStarSelectorType, StarSelectH.STAR_SELECTOR_100_COINS)
	end
end

-- from src/menu/star_select.c:bhv_act_selector_init L107-158
function star_select.bhv_act_selector_init()
	local i = 0
	const selectorModelIDs = table.create(10, 0)
	const stars = U8(SrcGameSaveFile.save_file_get_star_flags(SrcGameArea.gCurrSaveFileNum - 1, IncludeCourseTableH.COURSE_NUM_TO_INDEX(SrcGameArea.gCurrCourseNum)))

	star_select.sVisibleStars = 0

	while i ~= star_select.sObtainedStars do
		if bit32.btest(stars, bit32.lshift(1, star_select.sVisibleStars)) then
			-- Star has been collected
			selectorModelIDs[star_select.sVisibleStars + 1] = IncludeModelIdsH.MODEL_STAR
			i = S16(i + 1)
		else
			-- Star has not been collected
			selectorModelIDs[star_select.sVisibleStars + 1] = IncludeModelIdsH.MODEL_TRANSPARENT_STAR

			-- If this is the first star that has not been collected, set
			-- the default selection to this star.
			if star_select.sInitSelectedActNum == 0 then
				star_select.sInitSelectedActNum = U8(star_select.sVisibleStars + 1)
				star_select.sSelectableStarIndex = star_select.sVisibleStars
			end
		end

		star_select.sVisibleStars = S8(star_select.sVisibleStars + 1)
	end

	-- If the stars have been collected in order so far, show the next star.
	if star_select.sVisibleStars == star_select.sObtainedStars and star_select.sVisibleStars ~= 6 then
		selectorModelIDs[star_select.sVisibleStars + 1] = IncludeModelIdsH.MODEL_TRANSPARENT_STAR
		star_select.sInitSelectedActNum = U8(star_select.sVisibleStars + 1)
		star_select.sSelectableStarIndex = star_select.sVisibleStars
		star_select.sVisibleStars = S8(star_select.sVisibleStars + 1)
	end

	-- If all stars have been collected, set the default selection to the last star.
	if star_select.sObtainedStars == 6 then
		star_select.sInitSelectedActNum = U8(star_select.sVisibleStars)
	end

	--! Useless, since sInitSelectedActNum has already been set in this
	--! scenario by the code that shows the next uncollected star.
	if star_select.sObtainedStars == 0 then
		star_select.sInitSelectedActNum = 1
	end

	-- Render star selector objects
	i = 0

	while i < star_select.sVisibleStars do
		const starModel = SrcGameObjectHelpers.spawn_object_abs_with_rot(SrcGameObjectListProcessor.gCurrentObject, 0, selectorModelIDs[i + 1], BehaviorIds.bhvActSelectorStarType, S16((star_select.sVisibleStars - 1) * -75 + i * 152), 248, -300, 0, 0, 0)

		star_select.sStarSelectorModels[i + 1] = starModel
		buffer.writef32(starModel.rawData, IncludeObjectFieldsH.oStarSelectorSize, 1.0)
		i = S16(i + 1)
	end

	star_select.render_100_coin_star(stars)
end

-- from src/menu/star_select.c:bhv_act_selector_loop L167-202
function star_select.bhv_act_selector_loop()
	const stars = U8(SrcGameSaveFile.save_file_get_star_flags(SrcGameArea.gCurrSaveFileNum - 1, IncludeCourseTableH.COURSE_NUM_TO_INDEX(SrcGameArea.gCurrCourseNum)))

	if star_select.sObtainedStars ~= 6 then
		star_select.sSelectedActIndex = 0
		Scratch.sSelectableStarIndex[1] = star_select.sSelectableStarIndex
		GroupsIngameMenuPlus1.handle_menu_scrolling(GroupsIngameMenuPlus1.MENU_SCROLL_HORIZONTAL, Scratch.sSelectableStarIndex, 0, S8(star_select.sObtainedStars))
		star_select.sSelectableStarIndex = Scratch.sSelectableStarIndex[1]

		local starIndexCounter = U8(star_select.sSelectableStarIndex)

		for i = 0, star_select.sVisibleStars - 1 do
			-- Can the star be selected (is it either already completed or the first non-completed mission)
			if bit32.btest(stars, bit32.lshift(1, i)) or i == star_select.sInitSelectedActNum - 1 then
				if starIndexCounter == 0 then
					-- We have reached the sSelectableStarIndex-th selectable star.
					star_select.sSelectedActIndex = i
					break
				end

				starIndexCounter = U8(starIndexCounter - 1)
			end
		end
	else
		-- If all stars are collected then they are all selectable.
		Scratch.sSelectableStarIndex[1] = star_select.sSelectableStarIndex
		GroupsIngameMenuPlus1.handle_menu_scrolling(GroupsIngameMenuPlus1.MENU_SCROLL_HORIZONTAL, Scratch.sSelectableStarIndex, 0, S8(star_select.sVisibleStars - 1))
		star_select.sSelectableStarIndex = Scratch.sSelectableStarIndex[1]
		star_select.sSelectedActIndex = star_select.sSelectableStarIndex
	end

	-- Star selector type handler
	for i = 0, star_select.sVisibleStars - 1 do
		const starModel = star_select.sStarSelectorModels[i + 1] :: GroupsTypesHPlus3.Object

		if star_select.sSelectedActIndex == i then
			buffer.writei32(starModel.rawData, IncludeObjectFieldsH.oStarSelectorType, StarSelectH.STAR_SELECTOR_SELECTED)
		else
			buffer.writei32(starModel.rawData, IncludeObjectFieldsH.oStarSelectorType, StarSelectH.STAR_SELECTOR_NOT_SELECTED)
		end
	end
end

-- from src/menu/star_select.c:print_course_number L210-249
function star_select.print_course_number()
	const courseNum = Scratch.print_course_number_courseNum

	GroupsIngameMenuPlus1.create_dl_translation_matrix(GroupsIngameMenuPlus1.MENU_MTX_PUSH, 158.0, 81.0, 0.0)

	-- Full wood texture in JP & US, lower part of it on EU
	Gbi.gSPDisplayList(MenuSymbols.dl_menu_rgba16_wood_course)
	Gbi.gSPPopMatrix(Gbi.G_MTX_MODELVIEW)
	Gbi.gSPDisplayList(Segment2Symbols.dl_rgba16_text_begin)
	Gbi.gDPSetEnvColor(255, 255, 255, 255)
	GroupsIngameMenuPlus1.int_to_str(SrcGameArea.gCurrCourseNum, courseNum)

	if SrcGameArea.gCurrCourseNum < 10 then -- 1 digit number
		GroupsIngameMenuPlus1.print_hud_lut_string(GroupsIngameMenuPlus1.HUD_LUT_GLOBAL, 152, 158, courseNum)
	else -- 2 digit number
		GroupsIngameMenuPlus1.print_hud_lut_string(GroupsIngameMenuPlus1.HUD_LUT_GLOBAL, 143, 158, courseNum)
	end

	Gbi.gSPDisplayList(Segment2Symbols.dl_rgba16_text_end)
end

-- from src/menu/star_select.c:print_act_selector_strings L260-380
function star_select.print_act_selector_strings()
	const myScore = IncludeTextStringsH.TEXT_MYSCORE
	const starNumbers = Scratch.print_act_selector_strings_starNumbers
	const levelNameTbl = SrcGameMemory.segmented_to_virtual(Segment2Symbols.seg2_course_name_table)
	const currLevelName = SrcGameMemory.segmented_to_virtual(Rom.ReadU32(levelNameTbl + 4 * IncludeCourseTableH.COURSE_NUM_TO_INDEX(SrcGameArea.gCurrCourseNum)))
	const actNameTbl = SrcGameMemory.segmented_to_virtual(Segment2Symbols.seg2_act_name_table)

	GroupsIngameMenuPlus1.create_dl_ortho_matrix()

	-- Print the coin highscore.
	Gbi.gSPDisplayList(Segment2Symbols.dl_rgba16_text_begin)
	Gbi.gDPSetEnvColor(255, 255, 255, 255)
	GroupsIngameMenuPlus1.print_hud_my_score_coins(1, SrcGameArea.gCurrSaveFileNum - 1, IncludeCourseTableH.COURSE_NUM_TO_INDEX(SrcGameArea.gCurrCourseNum), 155, 106)
	Gbi.gSPDisplayList(Segment2Symbols.dl_rgba16_text_end)

	Gbi.gSPDisplayList(Segment2Symbols.dl_ia_text_begin)
	Gbi.gDPSetEnvColor(0, 0, 0, 255)

	-- Print the "MY SCORE" text if the coin score is more than 0
	if SrcGameSaveFile.save_file_get_course_coin_score(SrcGameArea.gCurrSaveFileNum - 1, IncludeCourseTableH.COURSE_NUM_TO_INDEX(SrcGameArea.gCurrCourseNum)) ~= 0 then
		-- TODO: Macros for all these hardcoded positions would be nice
		GroupsIngameMenuPlus1.print_generic_string(102, 118, myScore)
	end

	GroupsIngameMenuPlus1.CopyRomString(Scratch.print_act_selector_strings_currLevelName, currLevelName + 3)

	const lvlNameX = GroupsIngameMenuPlus1.get_str_x_pos_from_center(160, Scratch.print_act_selector_strings_currLevelName, 10.0)

	GroupsIngameMenuPlus1.print_generic_string(lvlNameX, 33, Scratch.print_act_selector_strings_currLevelName)
	Gbi.gSPDisplayList(Segment2Symbols.dl_ia_text_end)
	star_select.print_course_number()
	Gbi.gSPDisplayList(MenuSymbols.dl_menu_ia8_text_begin)
	Gbi.gDPSetEnvColor(0, 0, 0, 255)

	-- Print the name of the selected act.
	if star_select.sVisibleStars ~= 0 then
		const selectedActName = SrcGameMemory.segmented_to_virtual(Rom.ReadU32(actNameTbl + 4 * (IncludeCourseTableH.COURSE_NUM_TO_INDEX(SrcGameArea.gCurrCourseNum) * 6 + star_select.sSelectedActIndex)))

		GroupsIngameMenuPlus1.CopyRomString(Scratch.print_act_selector_strings_selectedActName, selectedActName)

		const actNameX = GroupsIngameMenuPlus1.get_str_x_pos_from_center(star_select.ACT_NAME_X, Scratch.print_act_selector_strings_selectedActName, 8.0)

		GroupsIngameMenuPlus1.print_menu_generic_string(actNameX, 81, Scratch.print_act_selector_strings_selectedActName)
	end

	-- Print the numbers above each star.
	for i = 1, star_select.sVisibleStars do
		buffer.writeu8(starNumbers, 0, i)
		GroupsIngameMenuPlus1.print_menu_generic_string(122 - (star_select.sVisibleStars - 1) * 17 + i * 34, 38, starNumbers)
	end

	Gbi.gSPDisplayList(MenuSymbols.dl_menu_ia8_text_end)
end

-- from src/menu/star_select.c:geo_act_selector_strings L387-396
function star_select.geo_act_selector_strings(callContext: number, node: GroupsTypesHPlus3.GraphNode, context: unknown): { unknown }?
	callContext = S16(TruncS32(callContext))
	if callContext == GroupsTypesHPlus3.GEO_CONTEXT_RENDER then
		star_select.print_act_selector_strings()
	end

	return nil
end

-- from src/menu/star_select.c:lvl_init_act_selector_values_and_stars L402-421
function star_select.lvl_init_act_selector_values_and_stars(arg: number, unused: number): number
	const stars = U8(SrcGameSaveFile.save_file_get_star_flags(SrcGameArea.gCurrSaveFileNum - 1, IncludeCourseTableH.COURSE_NUM_TO_INDEX(SrcGameArea.gCurrCourseNum)))

	star_select.sLoadedActNum = 0
	star_select.sInitSelectedActNum = 0
	star_select.sVisibleStars = 0
	star_select.sActSelectorMenuTimer = 0
	star_select.sObtainedStars = U8(SrcGameSaveFile.save_file_get_course_star_count(SrcGameArea.gCurrSaveFileNum - 1, IncludeCourseTableH.COURSE_NUM_TO_INDEX(SrcGameArea.gCurrCourseNum)))

	-- Don't count 100 coin star
	if bit32.btest(stars, bit32.lshift(1, 6)) then
		star_select.sObtainedStars = U8(star_select.sObtainedStars - 1)
	end

	return 0
end

-- from src/menu/star_select.c:lvl_update_obj_and_load_act_button_actions L427-459
function star_select.lvl_update_obj_and_load_act_button_actions(arg: number, unused: number): number
	if star_select.sActSelectorMenuTimer > 10 then
		-- If any of these buttons are pressed, play sound and go to course act
		if bit32.btest(SrcGameGameInit.gPlayer3Controller.buttonPressed, bit32.bor(IncludePROsH.A_BUTTON, IncludePROsH.START_BUTTON, IncludePROsH.B_BUTTON)) then
			Audio.play_sound(IncludeSoundsH.SOUND_MENU_STAR_SOUND_LETS_A_GO, Audio.gGlobalSoundSource)

			if star_select.sInitSelectedActNum >= star_select.sSelectedActIndex + 1 then
				star_select.sLoadedActNum = S8(star_select.sSelectedActIndex + 1)
			else
				star_select.sLoadedActNum = S8(star_select.sInitSelectedActNum)
			end

			GroupsIngameMenuPlus1.gDialogCourseActNum = S8(star_select.sSelectedActIndex + 1)
		end
	end

	SrcGameArea.area_update_objects()
	star_select.sActSelectorMenuTimer = S32(star_select.sActSelectorMenuTimer + 1)

	return star_select.sLoadedActNum
end

return star_select
