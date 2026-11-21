--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/bowser_puzzle_piece.inc.c.
]]

const Registry = require("../../../groups/registry")

const IncludeModelIdsH = require("../../../include/model_ids_h")
const BehaviorIds = require("../../rom/behavior_ids")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")

-- from src/game/behaviors/bowser_puzzle_piece.inc.c:BowserPuzzlePiece
export type BowserPuzzlePiece = {
	model: number,
	xOffset: number,
	zOffset: number,
	initialAction: number,
	actionList: { number }?,
}

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

const function S8(Value: number): number
	const Wrapped = bit32.band(Value, 0xFF)

	return if Wrapped >= 0x80 then Wrapped - 0x100 else Wrapped
end

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

-- from src/game/behaviors/bowser_puzzle_piece.inc.c:data
const bowser_puzzle_piece_inc = {
	-- from src/game/behaviors/bowser_puzzle_piece.inc.c:sPieceActions01 L16-17
	sPieceActions01 = { 2, 3, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 4, 2, -1 },
	-- from src/game/behaviors/bowser_puzzle_piece.inc.c:sPieceActions02 L18-19
	sPieceActions02 = { 2, 2, 3, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 4, 2, 2, -1 },
	-- from src/game/behaviors/bowser_puzzle_piece.inc.c:sPieceActions05 L20-21
	sPieceActions05 = { 2, 2, 2, 5, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 6, 2, 2, 2, -1 },
	-- from src/game/behaviors/bowser_puzzle_piece.inc.c:sPieceActions06 L22-23
	sPieceActions06 = { 2, 2, 2, 2, 3, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 4, 2, 2, 2, 2, -1 },
	-- from src/game/behaviors/bowser_puzzle_piece.inc.c:sPieceActions10 L24-25
	sPieceActions10 = { 2, 2, 2, 2, 2, 5, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 6, 2, 2, 2, 2, 2, -1 },
	-- from src/game/behaviors/bowser_puzzle_piece.inc.c:sPieceActions09 L26-27
	sPieceActions09 = { 2, 2, 2, 2, 2, 2, 4, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 3, 2, 2, 2, 2, 2, 2, -1 },
	-- from src/game/behaviors/bowser_puzzle_piece.inc.c:sPieceActions13 L28-29
	sPieceActions13 = { 2, 2, 2, 2, 2, 2, 2, 5, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 6, 2, 2, 2, 2, 2, 2, 2, -1 },
	-- from src/game/behaviors/bowser_puzzle_piece.inc.c:sPieceActions12 L30-31
	sPieceActions12 = { 2, 2, 2, 2, 2, 2, 2, 2, 4, 2, 2, 2, 2, 2, 2, 2, 2, 3, 2, 2, 2, 2, 2, 2, 2, 2, -1 },
	-- from src/game/behaviors/bowser_puzzle_piece.inc.c:sPieceActions08 L32-33
	sPieceActions08 = { 2, 2, 2, 2, 2, 2, 2, 2, 2, 6, 2, 2, 2, 2, 2, 2, 5, 2, 2, 2, 2, 2, 2, 2, 2, 2, -1 },
	-- from src/game/behaviors/bowser_puzzle_piece.inc.c:sPieceActions07 L34-35
	sPieceActions07 = { 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 4, 2, 2, 2, 2, 3, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, -1 },
	-- from src/game/behaviors/bowser_puzzle_piece.inc.c:sPieceActions03 L36-37
	sPieceActions03 = { 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 6, 2, 2, 5, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, -1 },
	-- from src/game/behaviors/bowser_puzzle_piece.inc.c:sPieceActions04 L38-39
	sPieceActions04 = { 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 3, 4, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, -1 },
	-- from src/game/behaviors/bowser_puzzle_piece.inc.c:sPieceActions11 L40-41
	sPieceActions11 = { 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, -1 },
	-- from src/game/behaviors/bowser_puzzle_piece.inc.c:sPieceActions14 L42-43
	sPieceActions14 = { 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, -1 },
}

Registry.Register("src__game__behaviors__bowser_puzzle_piece_inc", bowser_puzzle_piece_inc)

-- from src/game/behaviors/bowser_puzzle_piece.inc.c:BowserPuzzlePiece (zero-filled constructor)
function bowser_puzzle_piece_inc.new_BowserPuzzlePiece(): BowserPuzzlePiece
	return { model = 0, xOffset = 0, zOffset = 0, initialAction = 0, actionList = nil } :: BowserPuzzlePiece
end

-- from src/game/behaviors/bowser_puzzle_piece.inc.c:bhv_lll_bowser_puzzle_spawn_piece L88-98
function bowser_puzzle_piece_inc.bhv_lll_bowser_puzzle_spawn_piece(model: number, behavior: number, xOffset: number, zOffset: number, initialAction: number, actionList: { number })
	model = S16(TruncS32(model))
	xOffset = F32(xOffset)
	zOffset = F32(zOffset)
	initialAction = S8(TruncS32(initialAction))
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const puzzlePiece: GroupsTypesHPlus3.Object = ObjectHelpers.spawn_object(o, model, behavior)

	buffer.writef32(puzzlePiece.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(puzzlePiece.rawData, IncludeObjectFieldsH.oPosX) + xOffset)
	buffer.writef32(puzzlePiece.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(puzzlePiece.rawData, IncludeObjectFieldsH.oPosY) + 50.0)
	buffer.writef32(puzzlePiece.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(puzzlePiece.rawData, IncludeObjectFieldsH.oPosZ) + zOffset)
	buffer.writei32(puzzlePiece.rawData, IncludeObjectFieldsH.oAction, initialAction)
	puzzlePiece.ptrData[IncludeObjectFieldsH.oBowserPuzzlePieceActionList + 1] = { Base = actionList, Offset = 0 }
	puzzlePiece.ptrData[IncludeObjectFieldsH.oBowserPuzzlePieceNextAction + 1] = { Base = actionList, Offset = 0 }
end

-- from src/game/behaviors/bowser_puzzle_piece.inc.c:bhv_lll_bowser_puzzle_spawn_pieces L103-117
function bowser_puzzle_piece_inc.bhv_lll_bowser_puzzle_spawn_pieces(pieceWidth: number)
	pieceWidth = F32(pieceWidth)
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	for i = 1, 14 do
		const piece = bowser_puzzle_piece_inc.sBowserPuzzlePieces[i]

		bowser_puzzle_piece_inc.bhv_lll_bowser_puzzle_spawn_piece(piece.model, BehaviorIds.bhvLLLBowserPuzzlePiece, F32(F32(piece.xOffset * pieceWidth) / 10.0), F32(F32(piece.zOffset * pieceWidth) / 10.0), piece.initialAction, piece.actionList)
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1))
end

-- from src/game/behaviors/bowser_puzzle_piece.inc.c:bhv_lll_bowser_puzzle_loop L122-150
function bowser_puzzle_piece_inc.bhv_lll_bowser_puzzle_loop()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == IncludeObjectConstantsH.BOWSER_PUZZLE_ACT_SPAWN_PIECES then
		bowser_puzzle_piece_inc.bhv_lll_bowser_puzzle_spawn_pieces(480.0)
	elseif action == IncludeObjectConstantsH.BOWSER_PUZZLE_ACT_WAIT_FOR_COMPLETE then
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBowserPuzzleCompletionFlags) == 3 and buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 1000.0 then
			for i = 0, 4 do
				ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_YELLOW_COIN, BehaviorIds.bhvSingleCoinGetsSpawned)
			end

			buffer.writei32(o.rawData, IncludeObjectFieldsH.oBowserPuzzleCompletionFlags, 0)
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1))
		end
	elseif action == IncludeObjectConstantsH.BOWSER_PUZZLE_ACT_DONE then
		-- Done: nothing to do.
	end
end

-- from src/game/behaviors/bowser_puzzle_piece.inc.c:bhv_lll_bowser_puzzle_piece_action_0 L155-156
function bowser_puzzle_piece_inc.bhv_lll_bowser_puzzle_piece_action_0()
	-- Empty in the C source.
end

-- from src/game/behaviors/bowser_puzzle_piece.inc.c:bhv_lll_bowser_puzzle_piece_action_1 L161-164
function bowser_puzzle_piece_inc.bhv_lll_bowser_puzzle_piece_action_1()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + 50.0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 3)
end

-- from src/game/behaviors/bowser_puzzle_piece.inc.c:bhv_lll_bowser_puzzle_piece_update L169-198
function bowser_puzzle_piece_inc.bhv_lll_bowser_puzzle_piece_update()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const nextAction = o.ptrData[IncludeObjectFieldsH.oBowserPuzzlePieceNextAction + 1] :: { Base: { number }, Offset: number }

	-- If Mario is standing on this puzzle piece, set a flag in the parent.
	if (ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object).platform == o then
		const parent = o.parentObj :: GroupsTypesHPlus3.Object

		buffer.writei32(parent.rawData, IncludeObjectFieldsH.oBowserPuzzleCompletionFlags, 1)
	end

	-- If we should advance to the next action...
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oBowserPuzzlePieceContinuePerformingAction) == 0 then
		-- Start doing the next action.
		ObjectHelpers.cur_obj_change_action(nextAction.Base[nextAction.Offset + 1])

		-- Advance the pointer to the next action.
		nextAction.Offset += 1
		o.ptrData[IncludeObjectFieldsH.oBowserPuzzlePieceNextAction + 1] = nextAction

		-- If we're at the end of the list...
		if nextAction.Base[nextAction.Offset + 1] == -1 then
			const parent = o.parentObj :: GroupsTypesHPlus3.Object

			-- Set the other completion flag in the parent.
			buffer.writei32(parent.rawData, IncludeObjectFieldsH.oBowserPuzzleCompletionFlags, S32(bit32.bor(buffer.readi32(parent.rawData, IncludeObjectFieldsH.oBowserPuzzleCompletionFlags), 2)))

			-- The next action is the first action in the list again.
			nextAction.Offset = 0
		end

		-- Keep doing this action until it's complete.
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oBowserPuzzlePieceContinuePerformingAction, 1)
	end
end

-- from src/game/behaviors/bowser_puzzle_piece.inc.c:bhv_lll_bowser_puzzle_piece_move L200-228
function bowser_puzzle_piece_inc.bhv_lll_bowser_puzzle_piece_move(xOffset: number, zOffset: number, duration: number, unused: number)
	xOffset = F32(xOffset)
	zOffset = F32(zOffset)
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	-- For the first 20 frames, shake the puzzle piece up and down.
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 20 then
		if math.fmod(buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer), 2) ~= 0 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oBowserPuzzlePieceOffsetY, 0.0)
		else
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oBowserPuzzlePieceOffsetY, -6.0)
		end
	else
		-- On frame 20, play the shifting sound.
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 20 then
			SpawnSound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ2_BOWSER_PUZZLE_PIECE_MOVE)
		end

		-- For the number of frames specified by duration, move the piece.
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < duration + 20 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oBowserPuzzlePieceOffsetX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oBowserPuzzlePieceOffsetX) + xOffset)
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oBowserPuzzlePieceOffsetZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oBowserPuzzlePieceOffsetZ) + zOffset)
		else
			-- This doesn't actually accomplish anything since
			-- cur_obj_change_action is going to be called before the
			-- next action is performed anyway.
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, 2)

			-- Advance to the next action.
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oBowserPuzzlePieceContinuePerformingAction, 0)
		end
	end
end

-- from src/game/behaviors/bowser_puzzle_piece.inc.c:bhv_lll_bowser_puzzle_piece_idle L230-240
function bowser_puzzle_piece_inc.bhv_lll_bowser_puzzle_piece_idle()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	-- For the first 24 frames, do nothing.
	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) < 24 then
		-- Nothing to do: the first 24 frames are a wait.
	else
		-- Then advance to the next action.
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oBowserPuzzlePieceContinuePerformingAction, 0)
	end
end

-- from src/game/behaviors/bowser_puzzle_piece.inc.c:bhv_lll_bowser_puzzle_piece_move_left L242-244
function bowser_puzzle_piece_inc.bhv_lll_bowser_puzzle_piece_move_left()
	bowser_puzzle_piece_inc.bhv_lll_bowser_puzzle_piece_move(-120.0, 0.0, 4, 4)
end

-- from src/game/behaviors/bowser_puzzle_piece.inc.c:bhv_lll_bowser_puzzle_piece_move_right L246-248
function bowser_puzzle_piece_inc.bhv_lll_bowser_puzzle_piece_move_right()
	bowser_puzzle_piece_inc.bhv_lll_bowser_puzzle_piece_move(120.0, 0.0, 4, 5)
end

-- from src/game/behaviors/bowser_puzzle_piece.inc.c:bhv_lll_bowser_puzzle_piece_move_up L250-252
function bowser_puzzle_piece_inc.bhv_lll_bowser_puzzle_piece_move_up()
	bowser_puzzle_piece_inc.bhv_lll_bowser_puzzle_piece_move(0.0, -120.0, 4, 6)
end

-- from src/game/behaviors/bowser_puzzle_piece.inc.c:bhv_lll_bowser_puzzle_piece_move_down L254-256
function bowser_puzzle_piece_inc.bhv_lll_bowser_puzzle_piece_move_down()
	bowser_puzzle_piece_inc.bhv_lll_bowser_puzzle_piece_move(0.0, 120.0, 4, 3)
end

-- from src/game/behaviors/bowser_puzzle_piece.inc.c:bhv_lll_bowser_puzzle_piece_loop L268-276
function bowser_puzzle_piece_inc.bhv_lll_bowser_puzzle_piece_loop()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject

	bowser_puzzle_piece_inc.bhv_lll_bowser_puzzle_piece_update()

	ObjectHelpers.cur_obj_call_action_function(bowser_puzzle_piece_inc.sBowserPuzzlePieceActions)

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oBowserPuzzlePieceOffsetX) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeX))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oBowserPuzzlePieceOffsetY) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeY))
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oBowserPuzzlePieceOffsetZ) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oHomeZ))
end

-- from src/game/behaviors/bowser_puzzle_piece.inc.c:sBowserPuzzlePieces L68-83
bowser_puzzle_piece_inc.sBowserPuzzlePieces = {
	{
		model = IncludeModelIdsH.MODEL_LLL_BOWSER_PIECE_1,
		xOffset = -5,
		zOffset = -15,
		initialAction = 1,
		actionList = bowser_puzzle_piece_inc.sPieceActions01,
	},
	{
		model = IncludeModelIdsH.MODEL_LLL_BOWSER_PIECE_2,
		xOffset = 5,
		zOffset = -15,
		initialAction = 0,
		actionList = bowser_puzzle_piece_inc.sPieceActions02,
	},
	{
		model = IncludeModelIdsH.MODEL_LLL_BOWSER_PIECE_3,
		xOffset = -15,
		zOffset = -5,
		initialAction = 0,
		actionList = bowser_puzzle_piece_inc.sPieceActions03,
	},
	{
		model = IncludeModelIdsH.MODEL_LLL_BOWSER_PIECE_4,
		xOffset = -5,
		zOffset = -5,
		initialAction = 0,
		actionList = bowser_puzzle_piece_inc.sPieceActions04,
	},
	{
		model = IncludeModelIdsH.MODEL_LLL_BOWSER_PIECE_5,
		xOffset = 5,
		zOffset = -5,
		initialAction = 0,
		actionList = bowser_puzzle_piece_inc.sPieceActions05,
	},
	{
		model = IncludeModelIdsH.MODEL_LLL_BOWSER_PIECE_6,
		xOffset = 15,
		zOffset = -5,
		initialAction = 0,
		actionList = bowser_puzzle_piece_inc.sPieceActions06,
	},
	{
		model = IncludeModelIdsH.MODEL_LLL_BOWSER_PIECE_7,
		xOffset = -15,
		zOffset = 5,
		initialAction = 0,
		actionList = bowser_puzzle_piece_inc.sPieceActions07,
	},
	{
		model = IncludeModelIdsH.MODEL_LLL_BOWSER_PIECE_8,
		xOffset = -5,
		zOffset = 5,
		initialAction = 0,
		actionList = bowser_puzzle_piece_inc.sPieceActions08,
	},
	{
		model = IncludeModelIdsH.MODEL_LLL_BOWSER_PIECE_9,
		xOffset = 5,
		zOffset = 5,
		initialAction = 0,
		actionList = bowser_puzzle_piece_inc.sPieceActions09,
	},
	{
		model = IncludeModelIdsH.MODEL_LLL_BOWSER_PIECE_10,
		xOffset = 15,
		zOffset = 5,
		initialAction = 0,
		actionList = bowser_puzzle_piece_inc.sPieceActions10,
	},
	{
		model = IncludeModelIdsH.MODEL_LLL_BOWSER_PIECE_11,
		xOffset = -15,
		zOffset = 15,
		initialAction = 0,
		actionList = bowser_puzzle_piece_inc.sPieceActions11,
	},
	{
		model = IncludeModelIdsH.MODEL_LLL_BOWSER_PIECE_12,
		xOffset = -5,
		zOffset = 15,
		initialAction = 0,
		actionList = bowser_puzzle_piece_inc.sPieceActions12,
	},
	{
		model = IncludeModelIdsH.MODEL_LLL_BOWSER_PIECE_13,
		xOffset = 5,
		zOffset = 15,
		initialAction = 0,
		actionList = bowser_puzzle_piece_inc.sPieceActions13,
	},
	{
		model = IncludeModelIdsH.MODEL_LLL_BOWSER_PIECE_14,
		xOffset = 15,
		zOffset = 15,
		initialAction = 0,
		actionList = bowser_puzzle_piece_inc.sPieceActions14,
	},
}

-- from src/game/behaviors/bowser_puzzle_piece.inc.c:sBowserPuzzlePieceActions L258-266
bowser_puzzle_piece_inc.sBowserPuzzlePieceActions = {
	bowser_puzzle_piece_inc.bhv_lll_bowser_puzzle_piece_action_0,
	bowser_puzzle_piece_inc.bhv_lll_bowser_puzzle_piece_action_1,
	bowser_puzzle_piece_inc.bhv_lll_bowser_puzzle_piece_idle,
	bowser_puzzle_piece_inc.bhv_lll_bowser_puzzle_piece_move_left,
	bowser_puzzle_piece_inc.bhv_lll_bowser_puzzle_piece_move_right,
	bowser_puzzle_piece_inc.bhv_lll_bowser_puzzle_piece_move_up,
	bowser_puzzle_piece_inc.bhv_lll_bowser_puzzle_piece_move_down,
}

return bowser_puzzle_piece_inc
