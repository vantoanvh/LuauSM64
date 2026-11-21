--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/whirlpool.inc.c.
]]

const Registry = require("../../../groups/registry")

const InteractionH = require("../interaction_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjBehaviors = require("../obj_behaviors")
const ObjectHelpers = require("../object_helpers")
const SrcEngineMathUtilH = require("../../engine/math_util_h")
const EnvfxBubbles = require("../envfx_bubbles")
const EnvfxBubblesH = require("../envfx_bubbles_h")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeSoundsH = require("../../../include/sounds_h")
const SpawnSound = require("../spawn_sound")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

const function S32(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFFFFFF)

	return if Wrapped >= 0x80000000 then Wrapped - 0x100000000 else Wrapped
end

-- C float to s32 conversion; like the x86-64 `cvttss2si`, a value outside the s32 range gives INT_MIN
const function TruncS32(Value: number): number
	if not (Value > -2147483649 and Value < 2147483648) then
		return -2147483648
	end

	const Whole = math.modf(Value)

	return if Whole == 0 then 0 else Whole
end

-- from src/game/behaviors/whirlpool.inc.c:data
const whirlpool_inc = {
	-- from src/game/behaviors/whirlpool.inc.c:sWhirlpoolHitbox L3-13
	sWhirlpoolHitbox = {
		interactType = InteractionH.INTERACT_WHIRLPOOL,
		downOffset = 0,
		damageOrCoinValue = 0,
		health = 0,
		numLootCoins = 0,
		radius = 200,
		height = 500,
		hurtboxRadius = 0,
		hurtboxHeight = 0,
	},
}

Registry.Register("src__game__behaviors__whirlpool_inc", whirlpool_inc)

-- from src/game/behaviors/whirlpool.inc.c:bhv_whirlpool_init L15-20
function whirlpool_inc.bhv_whirlpool_init()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oWhirlpoolInitFacePitch, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oWhirlpoolInitFaceRoll, buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll))
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch, 0)
	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll, 0)
end

-- from src/game/behaviors/whirlpool.inc.c:whirlpool_set_hitbox L22-24
function whirlpool_inc.whirlpool_set_hitbox()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	ObjectHelpers.obj_set_hitbox(o, whirlpool_inc.sWhirlpoolHitbox)
end

-- from src/game/behaviors/whirlpool.inc.c:whirpool_orient_graph L26-35
function whirlpool_inc.whirpool_orient_graph()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const CosPitch = SrcEngineMathUtilH.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch))
	const SinPitch = SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAnglePitch))
	const CosRoll = SrcEngineMathUtilH.coss(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll))
	const SinRoll = SrcEngineMathUtilH.sins(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleRoll))
	const NormalX = F32(SinRoll * CosPitch)
	const NormalY = F32(CosPitch * CosRoll)
	const NormalZ = SinPitch

	ObjBehaviors.obj_orient_graph(o, NormalX, NormalY, NormalZ)
end

-- from src/game/behaviors/whirlpool.inc.c:bhv_whirlpool_loop L37-63
function whirlpool_inc.bhv_whirlpool_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const config = EnvfxBubbles.gEnvFxBubbleConfig

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 5000.0 then
		o.header.gfx.node.flags = S16(bit32.band(o.header.gfx.node.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_INVISIBLE)))

		-- not sure if actually an array
		config[EnvfxBubblesH.ENVFX_STATE_PARTICLECOUNT + 1] = 60
		config[EnvfxBubblesH.ENVFX_STATE_SRC_X + 1] = S16(TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX)))
		config[EnvfxBubblesH.ENVFX_STATE_SRC_Z + 1] = S16(TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ)))
		config[EnvfxBubblesH.ENVFX_STATE_DEST_X + 1] = S16(TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX)))
		config[EnvfxBubblesH.ENVFX_STATE_DEST_Y + 1] = S16(TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY)))
		config[EnvfxBubblesH.ENVFX_STATE_DEST_Z + 1] = S16(TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ)))
		config[EnvfxBubblesH.ENVFX_STATE_SRC_Y + 1] = S16(TruncS32(F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + 800.0)))
		config[EnvfxBubblesH.ENVFX_STATE_PITCH + 1] = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oWhirlpoolInitFacePitch))
		config[EnvfxBubblesH.ENVFX_STATE_YAW + 1] = S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oWhirlpoolInitFaceRoll))

		whirlpool_inc.whirpool_orient_graph()

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, S32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw) + 8000))
	else
		o.header.gfx.node.flags = S16(bit32.bor(o.header.gfx.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_INVISIBLE))
		config[EnvfxBubblesH.ENVFX_STATE_PARTICLECOUNT + 1] = 0
	end

	SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_ENV_WATER)

	whirlpool_inc.whirlpool_set_hitbox()
end

-- from src/game/behaviors/whirlpool.inc.c:bhv_jet_stream_loop L65-76
function whirlpool_inc.bhv_jet_stream_loop()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const config = EnvfxBubbles.gEnvFxBubbleConfig

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oDistanceToMario) < 5000.0 then
		config[EnvfxBubblesH.ENVFX_STATE_PARTICLECOUNT + 1] = 60
		config[EnvfxBubblesH.ENVFX_STATE_SRC_X + 1] = S16(TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX)))
		config[EnvfxBubblesH.ENVFX_STATE_SRC_Y + 1] = S16(TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY)))
		config[EnvfxBubblesH.ENVFX_STATE_SRC_Z + 1] = S16(TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ)))
	else
		config[EnvfxBubblesH.ENVFX_STATE_PARTICLECOUNT + 1] = 0
	end

	SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_ENV_WATER)
end

return whirlpool_inc
