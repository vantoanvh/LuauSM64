--!strict
--!optimize 2

--[[
	Port of src/game/obj_behaviors.c.
]]

const Registry = require("../../groups/registry")

const GroupsTypesHPlus3 = require("../../groups/types_h_plus3")

const ObjectListProcessor = require("./object_list_processor")
const BehaviorIds = require("../rom/behavior_ids")
const IncludeModelIdsH = require("../../include/model_ids_h")
const IncludeObjectConstantsH = require("../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../include/object_fields_h")
const IncludePRUltratypesH = require("../../include/PR/ultratypes_h")
const IncludeSurfaceTerrainsH = require("../../include/surface_terrains_h")
const ObjectHelpers = require("./object_helpers")
const SrcEngineBehaviorScript = require("../engine/behavior_script")
const Camera = require("./camera")
const GroupsIngameMenuPlus1 = require("../../groups/ingame_menu_plus1")
const MarioActionsCutscene = require("./mario_actions_cutscene")
const MarioActionsCutsceneH = require("./mario_actions_cutscene_h")
const SrcEngineMathUtil = require("../engine/math_util")
const GameInit = require("./game_init")
const IncludeSoundsH = require("../../include/sounds_h")
const Memory = require("./memory")
const SrcEngineSurfaceCollisionH = require("../engine/surface_collision_h")

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

const function S16(Value: number): number
	const Wrapped = bit32.band(Value, 0xFFFF)

	return if Wrapped >= 0x8000 then Wrapped - 0x10000 else Wrapped
end

const function S8(Value: number): number
	const Wrapped = bit32.band(Value, 0xFF)

	return if Wrapped >= 0x80 then Wrapped - 0x100 else Wrapped
end

const function U16(Value: number): number
	return bit32.band(Value, 0xFFFF)
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

-- from src/game/obj_behaviors.luau:scratch
const WallHitbox = SrcEngineSurfaceCollisionH.new_WallCollisionData()
-- from src/game/obj_behaviors.luau:scratch
const ObjYawX = table.create(1, 0)
-- from src/game/obj_behaviors.luau:scratch
const ObjYawZ = table.create(1, 0)
-- from src/game/obj_behaviors.luau:scratch
const VisualPosition = table.create(3, 0)
-- from src/game/obj_behaviors.luau:scratch
const SurfaceNormals = table.create(3, 0)
-- from src/game/obj_behaviors.luau:scratch
const ObjFriction = table.create(1, 0)
-- from src/game/obj_behaviors.luau:scratch
const ObjectStepFloor: { GroupsTypesHPlus3.Surface? } = {}

-- from src/game/obj_behaviors.c:data
const obj_behaviors = {
	o = ObjectListProcessor.gCurrentObject,
	OBJ_COL_FLAG_GROUNDED = 1,
	OBJ_COL_FLAG_HIT_WALL = 2,
	OBJ_COL_FLAG_UNDERWATER = 4,
	OBJ_COL_FLAG_NO_Y_VEL = 8,
	OBJ_COL_FLAGS_LANDED = 9, -- (OBJ_COL_FLAG_GROUNDED | OBJ_COL_FLAG_NO_Y_VEL)
	-- from src/game/obj_behaviors.c:sObjFloor L53-53
	sObjFloor = nil :: GroupsTypesHPlus3.Surface?,
	-- from src/game/obj_behaviors.c:sOrientObjWithFloor L59-59
	sOrientObjWithFloor = 1,
	-- from src/game/obj_behaviors.c:sPrevCheckMarioRoom L65-65
	sPrevCheckMarioRoom = 0,
	-- from src/game/obj_behaviors.c:sYoshiDead L70-70
	sYoshiDead = 0,
	-- from src/game/obj_behaviors.c:sDebugSequenceTracker L769-769
	sDebugSequenceTracker = 0,
	-- from src/game/obj_behaviors.c:sDebugTimer L770-770
	sDebugTimer = 0,
}

Registry.Register("src__game__obj_behaviors", obj_behaviors)

-- from src/game/obj_behaviors.c:set_yoshi_as_not_dead L79-81
function obj_behaviors.set_yoshi_as_not_dead()
	obj_behaviors.sYoshiDead = S8(IncludePRUltratypesH.FALSE)
end

-- from src/game/obj_behaviors.c:geo_obj_transparency_something L88-118
function obj_behaviors.geo_obj_transparency_something(callContext: number, node: GroupsTypesHPlus3.GraphNode, mtx: { { { number } } }): { unknown }?
	local gfxHead: { unknown }? = nil

	if callContext == GroupsTypesHPlus3.GEO_CONTEXT_RENDER then
		const obj = node :: GroupsTypesHPlus3.Object

		gfxHead = Memory.alloc_display_list(3 * 8) :: { unknown }
		obj.header.gfx.node.flags = S16(bit32.bor(bit32.band(obj.header.gfx.node.flags, 0xFF), bit32.bor(GroupsTypesHPlus3.GRAPH_NODE_TYPE_FUNCTIONAL, GroupsTypesHPlus3.GRAPH_NODE_TYPE_400)))
		-- gDPSetEnvColor, gSPEndDisplayList: no call (gfx-display-lists-noop); the held object only supplies their opacity argument
	end

	return gfxHead
end

-- from src/game/obj_behaviors.c:absf_2 L123-128
function obj_behaviors.absf_2(f: number): number
	f = F32(f)
	if f < 0 then
		f = F32(f * -1.0)
	end

	return f
end

-- from src/game/obj_behaviors.c:turn_obj_away_from_surface L133-140
function obj_behaviors.turn_obj_away_from_surface(velX: number, velZ: number, nX: number, nY: number, nZ: number, objYawX: { number }, objYawZ: { number })
	velX = F32(velX)
	velZ = F32(velZ)
	nX = F32(nX)
	nY = F32(nY)
	nZ = F32(nZ)
	const NormalSquaredX = F32(nX * nX)
	const NormalSquaredZ = F32(nZ * nZ)
	const Denominator = F32(NormalSquaredX + NormalSquaredZ)
	const Cross = F32(nX * nZ)

	objYawX[1] = F32(F32(F32(F32(NormalSquaredZ - NormalSquaredX) * velX) / Denominator) - F32(F32(F32(2 * velZ) * Cross) / Denominator))
	objYawZ[1] = F32(F32(F32(F32(NormalSquaredX - NormalSquaredZ) * velZ) / Denominator) - F32(F32(F32(2 * velX) * Cross) / Denominator))
end

-- from src/game/obj_behaviors.c:obj_find_wall L145-175
function obj_behaviors.obj_find_wall(objNewX: number, objY: number, objNewZ: number, objVelX: number, objVelZ: number): number
	objNewX = F32(objNewX)
	objY = F32(objY)
	objNewZ = F32(objNewZ)
	objVelX = F32(objVelX)
	objVelZ = F32(objVelZ)
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	WallHitbox.x = objNewX
	WallHitbox.y = objY
	WallHitbox.z = objNewZ
	WallHitbox.offsetY = F32(o.hitboxHeight / 2)
	WallHitbox.radius = o.hitboxRadius

	const Hit: number = Registry.Members.src__engine__surface_collision.find_wall_collisions(WallHitbox)

	if Hit ~= 0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, WallHitbox.x)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, WallHitbox.y)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, WallHitbox.z)

		const WallNormal = (WallHitbox.walls[1] :: GroupsTypesHPlus3.Surface).normal

		obj_behaviors.turn_obj_away_from_surface(objVelX, objVelZ, WallNormal.x, WallNormal.y, WallNormal.z, ObjYawX, ObjYawZ)

		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, SrcEngineMathUtil.atan2s(ObjYawZ[1], ObjYawX[1]))
		return IncludePRUltratypesH.FALSE
	end

	return IncludePRUltratypesH.TRUE
end

-- from src/game/obj_behaviors.c:turn_obj_away_from_steep_floor L180-204
function obj_behaviors.turn_obj_away_from_steep_floor(objFloor: GroupsTypesHPlus3.Surface?, floorY: number, objVelX: number, objVelZ: number): number
	floorY = F32(floorY)
	objVelX = F32(objVelX)
	objVelZ = F32(objVelZ)
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if objFloor == nil then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, S32(TruncS32(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw) + 32767.999200000002)))
		return IncludePRUltratypesH.FALSE
	end

	const FloorNormal = objFloor.normal

	if FloorNormal.y < 0.5 and floorY > buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) then
		obj_behaviors.turn_obj_away_from_surface(objVelX, objVelZ, FloorNormal.x, FloorNormal.y, FloorNormal.z, ObjYawX, ObjYawZ)
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, SrcEngineMathUtil.atan2s(ObjYawZ[1], ObjYawX[1]))
		return IncludePRUltratypesH.FALSE
	end

	return IncludePRUltratypesH.TRUE
end

-- from src/game/obj_behaviors.c:obj_orient_graph L209-240
function obj_behaviors.obj_orient_graph(obj: GroupsTypesHPlus3.Object, normalX: number, normalY: number, normalZ: number)
	normalX = F32(normalX)
	normalY = F32(normalY)
	normalZ = F32(normalZ)
	if obj_behaviors.sOrientObjWithFloor == 0 then
		return
	end

	if bit32.btest(obj.header.gfx.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_BILLBOARD) then
		return
	end

	const ThrowMatrix = Memory.alloc_display_list(64) :: { { { number } } }?

	if ThrowMatrix == nil then
		return
	end

	VisualPosition[1] = buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosX)
	VisualPosition[2] = F32(buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosY) + buffer.readf32(obj.rawData, IncludeObjectFieldsH.oGraphYOffset))
	VisualPosition[3] = buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosZ)

	SurfaceNormals[1] = normalX
	SurfaceNormals[2] = normalY
	SurfaceNormals[3] = normalZ

	SrcEngineMathUtil.mtxf_align_terrain_normal(ThrowMatrix[1], SurfaceNormals, VisualPosition, buffer.readi32(obj.rawData, IncludeObjectFieldsH.oFaceAngleYaw))
	obj.header.gfx.throwMatrix = ThrowMatrix
end

-- from src/game/obj_behaviors.c:calc_obj_friction L245-251
function obj_behaviors.calc_obj_friction(objFriction: { number }, floor_nY: number)
	floor_nY = F32(floor_nY)
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if floor_nY < 0.2 and buffer.readf32(o.rawData, IncludeObjectFieldsH.oFriction) < 0.9999 then
		objFriction[1] = 0
	else
		objFriction[1] = buffer.readf32(o.rawData, IncludeObjectFieldsH.oFriction)
	end
end

-- from src/game/obj_behaviors.c:calc_new_obj_vel_and_pos_y L256-311
function obj_behaviors.calc_new_obj_vel_and_pos_y(objFloor: GroupsTypesHPlus3.Surface, objFloorY: number, objVelX: number, objVelZ: number)
	objFloorY = F32(objFloorY)
	objVelX = F32(objVelX)
	objVelZ = F32(objVelZ)
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const FloorNormalX = objFloor.normal.x
	const FloorNormalY = objFloor.normal.y
	const FloorNormalZ = objFloor.normal.z

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) - buffer.readf32(o.rawData, IncludeObjectFieldsH.oGravity))

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) > 75.0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 75.0)
	end

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) < -75.0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, -75.0)
	end

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY))

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < objFloorY then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, objFloorY)

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) < -17.5 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, -(buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) / 2))
		else
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0)
		end
	end

	if TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY)) >= TruncS32(objFloorY) and TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY)) < TruncS32(objFloorY) + 37 then
		obj_behaviors.obj_orient_graph(o, FloorNormalX, FloorNormalY, FloorNormalZ)

		const NormalSquaredX = F32(FloorNormalX * FloorNormalX)
		const NormalSquaredY = F32(FloorNormalY * FloorNormalY)
		const NormalSquaredZ = F32(FloorNormalZ * FloorNormalZ)
		const HorizontalSum = F32(NormalSquaredX + NormalSquaredZ)
		const NormalSquaredSum = F32(F32(NormalSquaredX + NormalSquaredY) + NormalSquaredZ)
		const Gravity = buffer.readf32(o.rawData, IncludeObjectFieldsH.oGravity)

		objVelX = F32(objVelX + F32(F32(F32(F32(FloorNormalX * HorizontalSum) / NormalSquaredSum) * Gravity) * 2))
		objVelZ = F32(objVelZ + F32(F32(F32(F32(FloorNormalZ * HorizontalSum) / NormalSquaredSum) * Gravity) * 2))

		if objVelX < 0.000001 and objVelX > -0.000001 then
			objVelX = 0
		end

		if objVelZ < 0.000001 and objVelZ > -0.000001 then
			objVelZ = 0
		end

		if objVelX ~= 0 or objVelZ ~= 0 then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, SrcEngineMathUtil.atan2s(objVelZ, objVelX))
		end

		obj_behaviors.calc_obj_friction(ObjFriction, FloorNormalY)
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, F32(math.sqrt(F32(F32(objVelX * objVelX) + F32(objVelZ * objVelZ)))) * ObjFriction[1])
	end
end

-- from src/game/obj_behaviors.c:calc_new_obj_vel_and_pos_y_underwater L313-378
function obj_behaviors.calc_new_obj_vel_and_pos_y_underwater(objFloor: GroupsTypesHPlus3.Surface, floorY: number, objVelX: number, objVelZ: number, waterY: number)
	floorY = F32(floorY)
	objVelX = F32(objVelX)
	objVelZ = F32(objVelZ)
	waterY = F32(waterY)
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const FloorNormalX = objFloor.normal.x
	const FloorNormalY = objFloor.normal.y
	const FloorNormalZ = objFloor.normal.z

	const NetYAccel = F32(F32(1.0 - buffer.readf32(o.rawData, IncludeObjectFieldsH.oBuoyancy)) * F32(-1.0 * buffer.readf32(o.rawData, IncludeObjectFieldsH.oGravity)))

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) - NetYAccel)

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) > 75.0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 75.0)
	end

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) < -75.0 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, -75.0)
	end

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY))

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) < floorY then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, floorY)

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) < -17.5 then
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, -(buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) / 2))
		else
			buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0)
		end
	end

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) > 12.5 and F32(waterY + 30.0) > buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) and F32(waterY - 30.0) < buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, -buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY))
	end

	if TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY)) >= TruncS32(floorY) and TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY)) < TruncS32(floorY) + 37 then
		obj_behaviors.obj_orient_graph(o, FloorNormalX, FloorNormalY, FloorNormalZ)

		const NormalSquaredX = F32(FloorNormalX * FloorNormalX)
		const NormalSquaredY = F32(FloorNormalY * FloorNormalY)
		const NormalSquaredZ = F32(FloorNormalZ * FloorNormalZ)
		const HorizontalSum = F32(NormalSquaredX + NormalSquaredZ)
		const NormalSquaredSum = F32(F32(NormalSquaredX + NormalSquaredY) + NormalSquaredZ)

		objVelX = F32(objVelX + F32(F32(F32(F32(FloorNormalX * HorizontalSum) / NormalSquaredSum) * NetYAccel) * 2))
		objVelZ = F32(objVelZ + F32(F32(F32(F32(FloorNormalZ * HorizontalSum) / NormalSquaredSum) * NetYAccel) * 2))
	end

	if objVelX < 0.000001 and objVelX > -0.000001 then
		objVelX = 0
	end

	if objVelZ < 0.000001 and objVelZ > -0.000001 then
		objVelZ = 0
	end

	if buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) < 0.000001 and buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) > -0.000001 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, 0)
	end

	if objVelX ~= 0 or objVelZ ~= 0 then
		buffer.writei32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw, SrcEngineMathUtil.atan2s(objVelZ, objVelX))
	end

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oForwardVel, F32(math.sqrt(F32(F32(objVelX * objVelX) + F32(objVelZ * objVelZ)))) * 0.8)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) * 0.8)
end

-- from src/game/obj_behaviors.c:obj_update_pos_vel_xz L383-389
function obj_behaviors.obj_update_pos_vel_xz()
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const ForwardVel = buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel)
	const Sin: number = Registry.Members.src__engine__math_util_h.sins(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)))
	const Cos: number = Registry.Members.src__engine__math_util_h.coss(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)))
	const XVel = F32(ForwardVel * Sin)
	const ZVel = F32(ForwardVel * Cos)

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + XVel)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ) + ZVel)
end

-- from src/game/obj_behaviors.c:obj_splash L395-411
function obj_behaviors.obj_splash(waterY: number, objY: number)
	const globalTimer = GameInit.gGlobalTimer
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if F32(waterY + 30) > buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) and buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) > F32(waterY - 30) then
		ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_IDLE_WATER_WAVE, BehaviorIds.bhvObjectWaterWave)

		if buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY) < -20.0 then
			Registry.Members.src__game__spawn_sound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_DIVING_INTO_WATER)
		end
	end

	if objY + 50 < waterY and bit32.band(globalTimer, 31) == 0 then
		ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_WHITE_PARTICLE_SMALL, BehaviorIds.bhvObjectBubble)
	end
end

-- from src/game/obj_behaviors.c:object_step L417-462
function obj_behaviors.object_step(): number
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const ObjX = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX)
	const ObjY = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY)
	const ObjZ = buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ)
	const Sin: number = Registry.Members.src__engine__math_util_h.sins(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)))
	const Cos: number = Registry.Members.src__engine__math_util_h.coss(S16(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw)))
	const ObjVelX = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) * Sin)
	const ObjVelZ = F32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oForwardVel) * Cos)

	local WaterY = SrcEngineSurfaceCollisionH.FLOOR_LOWER_LIMIT_MISC
	local CollisionFlags = 0

	if obj_behaviors.obj_find_wall(F32(ObjX + ObjVelX), ObjY, F32(ObjZ + ObjVelZ), ObjVelX, ObjVelZ) == 0 then
		CollisionFlags = S16(CollisionFlags + obj_behaviors.OBJ_COL_FLAG_HIT_WALL)
	end

	ObjectStepFloor[1] = obj_behaviors.sObjFloor
	const FloorY: number = Registry.Members.src__engine__surface_collision.find_floor(F32(ObjX + ObjVelX), ObjY, F32(ObjZ + ObjVelZ), ObjectStepFloor)
	obj_behaviors.sObjFloor = ObjectStepFloor[1]

	if obj_behaviors.turn_obj_away_from_steep_floor(obj_behaviors.sObjFloor, FloorY, ObjVelX, ObjVelZ) == IncludePRUltratypesH.TRUE then
		WaterY = Registry.Members.src__engine__surface_collision.find_water_level(F32(ObjX + ObjVelX), F32(ObjZ + ObjVelZ))

		if WaterY > ObjY then
			obj_behaviors.calc_new_obj_vel_and_pos_y_underwater(obj_behaviors.sObjFloor :: GroupsTypesHPlus3.Surface, FloorY, ObjVelX, ObjVelZ, WaterY)
			CollisionFlags = S16(CollisionFlags + obj_behaviors.OBJ_COL_FLAG_UNDERWATER)
		else
			obj_behaviors.calc_new_obj_vel_and_pos_y(obj_behaviors.sObjFloor :: GroupsTypesHPlus3.Surface, FloorY, ObjVelX, ObjVelZ)
		end
	else
		CollisionFlags = S16(CollisionFlags + bit32.bxor(bit32.band(CollisionFlags, obj_behaviors.OBJ_COL_FLAG_HIT_WALL), obj_behaviors.OBJ_COL_FLAG_HIT_WALL))
	end

	obj_behaviors.obj_update_pos_vel_xz()

	if TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY)) == TruncS32(FloorY) then
		CollisionFlags = S16(CollisionFlags + obj_behaviors.OBJ_COL_FLAG_GROUNDED)
	end

	if TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelY)) == 0 then
		CollisionFlags = S16(CollisionFlags + obj_behaviors.OBJ_COL_FLAG_NO_Y_VEL)
	end

	obj_behaviors.obj_splash(TruncS32(WaterY), TruncS32(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY)))

	return CollisionFlags
end

-- from src/game/obj_behaviors.c:object_step_without_floor_orient L468-475
function obj_behaviors.object_step_without_floor_orient(): number
	obj_behaviors.sOrientObjWithFloor = S8(IncludePRUltratypesH.FALSE)
	const CollisionFlags = obj_behaviors.object_step()
	obj_behaviors.sOrientObjWithFloor = S8(IncludePRUltratypesH.TRUE)

	return CollisionFlags
end

-- from src/game/obj_behaviors.c:obj_move_xyz_using_fvel_and_yaw L484-491
function obj_behaviors.obj_move_xyz_using_fvel_and_yaw(obj: GroupsTypesHPlus3.Object)
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const Sin: number = Registry.Members.src__engine__math_util_h.sins(S16(buffer.readi32(obj.rawData, IncludeObjectFieldsH.oMoveAngleYaw)))
	const Cos: number = Registry.Members.src__engine__math_util_h.coss(S16(buffer.readi32(obj.rawData, IncludeObjectFieldsH.oMoveAngleYaw)))

	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelX, buffer.readf32(obj.rawData, IncludeObjectFieldsH.oForwardVel) * Sin)
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oVelZ, buffer.readf32(obj.rawData, IncludeObjectFieldsH.oForwardVel) * Cos)
	buffer.writef32(obj.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosX) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelX))
	buffer.writef32(obj.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosY) + buffer.readf32(obj.rawData, IncludeObjectFieldsH.oVelY))
	buffer.writef32(obj.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosZ) + buffer.readf32(o.rawData, IncludeObjectFieldsH.oVelZ))
end

-- from src/game/obj_behaviors.c:is_point_within_radius_of_mario L496-507
function obj_behaviors.is_point_within_radius_of_mario(x: number, y: number, z: number, dist: number): number
	x = F32(x)
	y = F32(y)
	z = F32(z)
	const marioObject: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gMarioObject
	const MarioX = marioObject.header.gfx.pos[1]
	const MarioY = marioObject.header.gfx.pos[2]
	const MarioZ = marioObject.header.gfx.pos[3]

	const DeltaX = F32(x - MarioX)
	const DeltaY = F32(y - MarioY)
	const DeltaZ = F32(z - MarioZ)

	if F32(F32(F32(DeltaX * DeltaX) + F32(DeltaY * DeltaY)) + F32(DeltaZ * DeltaZ)) < F32(dist * dist) then
		return IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/obj_behaviors.c:is_point_close_to_object L512-523
function obj_behaviors.is_point_close_to_object(obj: GroupsTypesHPlus3.Object, x: number, y: number, z: number, dist: number): number
	x = F32(x)
	y = F32(y)
	z = F32(z)
	const ObjX = buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosX)
	const ObjY = buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosY)
	const ObjZ = buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosZ)

	const DeltaX = F32(x - ObjX)
	const DeltaY = F32(y - ObjY)
	const DeltaZ = F32(z - ObjZ)

	if F32(F32(F32(DeltaX * DeltaX) + F32(DeltaY * DeltaY)) + F32(DeltaZ * DeltaZ)) < F32(dist * dist) then
		return IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/obj_behaviors.c:set_object_visibility L528-538
function obj_behaviors.set_object_visibility(obj: GroupsTypesHPlus3.Object, dist: number)
	const ObjX = buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosX)
	const ObjY = buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosY)
	const ObjZ = buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosZ)

	if obj_behaviors.is_point_within_radius_of_mario(ObjX, ObjY, ObjZ, dist) == IncludePRUltratypesH.TRUE then
		obj.header.gfx.node.flags = S16(bit32.band(obj.header.gfx.node.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_INVISIBLE)))
	else
		obj.header.gfx.node.flags = S16(bit32.bor(obj.header.gfx.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_INVISIBLE))
	end
end

-- from src/game/obj_behaviors.c:obj_return_home_if_safe L543-555
function obj_behaviors.obj_return_home_if_safe(obj: GroupsTypesHPlus3.Object, homeX: number, y: number, homeZ: number, dist: number): number
	homeX = F32(homeX)
	y = F32(y)
	homeZ = F32(homeZ)
	const HomeDistX = F32(homeX - buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosX))
	const HomeDistZ = F32(homeZ - buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosZ))
	const AngleTowardsHome = SrcEngineMathUtil.atan2s(HomeDistZ, HomeDistX)

	if obj_behaviors.is_point_within_radius_of_mario(homeX, y, homeZ, dist) == IncludePRUltratypesH.TRUE then
		return IncludePRUltratypesH.TRUE
	else
		buffer.writei32(obj.rawData, IncludeObjectFieldsH.oMoveAngleYaw, ObjectHelpers.approach_s16_symmetric(buffer.readi32(obj.rawData, IncludeObjectFieldsH.oMoveAngleYaw), AngleTowardsHome, 320))
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/obj_behaviors.c:obj_return_and_displace_home L560-573
function obj_behaviors.obj_return_and_displace_home(obj: GroupsTypesHPlus3.Object, homeX: number, homeY: number, homeZ: number, baseDisp: number)
	homeX = F32(homeX)
	homeY = F32(homeY)
	homeZ = F32(homeZ)
	if TruncS32(F32(SrcEngineBehaviorScript.random_float() * 50.0)) == 0 then
		buffer.writef32(obj.rawData, IncludeObjectFieldsH.oHomeX, F32(F32(F32(baseDisp * 2) * SrcEngineBehaviorScript.random_float()) - baseDisp) + homeX)
		buffer.writef32(obj.rawData, IncludeObjectFieldsH.oHomeZ, F32(F32(F32(baseDisp * 2) * SrcEngineBehaviorScript.random_float()) - baseDisp) + homeZ)
	end

	const HomeDistX = F32(buffer.readf32(obj.rawData, IncludeObjectFieldsH.oHomeX) - buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosX))
	const HomeDistZ = F32(buffer.readf32(obj.rawData, IncludeObjectFieldsH.oHomeZ) - buffer.readf32(obj.rawData, IncludeObjectFieldsH.oPosZ))
	const AngleToNewHome = SrcEngineMathUtil.atan2s(HomeDistZ, HomeDistX)

	buffer.writei32(obj.rawData, IncludeObjectFieldsH.oMoveAngleYaw, ObjectHelpers.approach_s16_symmetric(buffer.readi32(obj.rawData, IncludeObjectFieldsH.oMoveAngleYaw), AngleToNewHome, 320))
end

-- from src/game/obj_behaviors.c:obj_check_if_facing_toward_angle L579-588
function obj_behaviors.obj_check_if_facing_toward_angle(base: number, goal: number, range: number): number
	range = S16(TruncS32(range))
	const DAngle = S16(U16(goal) - U16(base))
	const SinNegRange: number = Registry.Members.src__engine__math_util_h.sins(-range)
	const SinAngle: number = Registry.Members.src__engine__math_util_h.sins(DAngle)
	const SinRange: number = Registry.Members.src__engine__math_util_h.sins(range)
	const Cos: number = Registry.Members.src__engine__math_util_h.coss(DAngle)

	if SinNegRange < SinAngle and SinAngle < SinRange and Cos > 0 then
		return IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/obj_behaviors.c:obj_find_wall_displacement L593-611
function obj_behaviors.obj_find_wall_displacement(dist: { number }, x: number, y: number, z: number, radius: number): number
	x = F32(x)
	y = F32(y)
	z = F32(z)
	radius = F32(radius)
	WallHitbox.x = x
	WallHitbox.y = y
	WallHitbox.z = z
	WallHitbox.offsetY = 10.0
	WallHitbox.radius = radius

	if Registry.Members.src__engine__surface_collision.find_wall_collisions(WallHitbox) ~= 0 then
		dist[1] = F32(WallHitbox.x - x)
		dist[2] = F32(WallHitbox.y - y)
		dist[3] = F32(WallHitbox.z - z)
		return IncludePRUltratypesH.TRUE
	else
		return IncludePRUltratypesH.FALSE
	end
end

-- from src/game/obj_behaviors.c:obj_spawn_yellow_coins L617-627
function obj_behaviors.obj_spawn_yellow_coins(obj: GroupsTypesHPlus3.Object, nCoins: number)
	nCoins = S8(TruncS32(nCoins))
	local Count = 0

	while Count < nCoins do
		const coin = ObjectHelpers.spawn_object(obj, IncludeModelIdsH.MODEL_YELLOW_COIN, BehaviorIds.bhvMovingYellowCoin)

		buffer.writef32(coin.rawData, IncludeObjectFieldsH.oForwardVel, SrcEngineBehaviorScript.random_float() * 20)
		buffer.writef32(coin.rawData, IncludeObjectFieldsH.oVelY, F32(SrcEngineBehaviorScript.random_float() * 40) + 20)
		buffer.writei32(coin.rawData, IncludeObjectFieldsH.oMoveAngleYaw, SrcEngineBehaviorScript.random_u16())

		Count = S8(Count + 1)
	end
end

-- from src/game/obj_behaviors.c:obj_flicker_and_disappear L632-649
function obj_behaviors.obj_flicker_and_disappear(obj: GroupsTypesHPlus3.Object, lifeSpan: number): number
	lifeSpan = S16(TruncS32(lifeSpan))
	const Timer = buffer.readi32(obj.rawData, IncludeObjectFieldsH.oTimer)

	if Timer < lifeSpan then
		return IncludePRUltratypesH.FALSE
	end

	if Timer < lifeSpan + 40 then
		if Timer % 2 ~= 0 then
			obj.header.gfx.node.flags = S16(bit32.bor(obj.header.gfx.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_INVISIBLE))
		else
			obj.header.gfx.node.flags = S16(bit32.band(obj.header.gfx.node.flags, bit32.bnot(GroupsTypesHPlus3.GRAPH_RENDER_INVISIBLE)))
		end
	else
		obj.activeFlags = S16(IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED)
		return IncludePRUltratypesH.TRUE
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/obj_behaviors.c:current_mario_room_check L654-676
function obj_behaviors.current_mario_room_check(room: number): number
	room = S16(TruncS32(room))
	const MarioCurrentRoom: number = Registry.Members.src__game__object_list_processor.gMarioCurrentRoom
	local Result: number

	if MarioCurrentRoom == 0 then
		if room == obj_behaviors.sPrevCheckMarioRoom then
			return IncludePRUltratypesH.TRUE
		else
			return IncludePRUltratypesH.FALSE
		end
	else
		if room == MarioCurrentRoom then
			Result = S16(IncludePRUltratypesH.TRUE)
		else
			Result = S16(IncludePRUltratypesH.FALSE)
		end

		obj_behaviors.sPrevCheckMarioRoom = MarioCurrentRoom
	end

	return Result
end

-- from src/game/obj_behaviors.c:trigger_obj_dialog_when_facing L681-700
function obj_behaviors.trigger_obj_dialog_when_facing(inDialog: { number }, dialogID: number, dist: number, actionArg: number): number
	dialogID = S16(TruncS32(dialogID))
	dist = F32(dist)
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const MarioObject: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gMarioObject

	if (obj_behaviors.is_point_within_radius_of_mario(buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY), buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosZ), TruncS32(dist)) == IncludePRUltratypesH.TRUE and obj_behaviors.obj_check_if_facing_toward_angle(buffer.readi32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw), MarioObject.header.gfx.angle[2] + 0x8000, S16(0x1000)) == IncludePRUltratypesH.TRUE and obj_behaviors.obj_check_if_facing_toward_angle(buffer.readi32(o.rawData, IncludeObjectFieldsH.oMoveAngleYaw), buffer.readi32(o.rawData, IncludeObjectFieldsH.oAngleToMario), S16(0x1000)) == IncludePRUltratypesH.TRUE) or inDialog[1] == IncludePRUltratypesH.TRUE then
		inDialog[1] = IncludePRUltratypesH.TRUE

		if MarioActionsCutscene.set_mario_npc_dialog(actionArg) == MarioActionsCutsceneH.MARIO_DIALOG_STATUS_SPEAK then
			const DialogResponse = Camera.cutscene_object_with_dialog(GroupsTypesHPlus3.CUTSCENE_DIALOG, o, dialogID)

			if DialogResponse ~= GroupsIngameMenuPlus1.DIALOG_RESPONSE_NONE then
				MarioActionsCutscene.set_mario_npc_dialog(MarioActionsCutsceneH.MARIO_DIALOG_STOP)
				inDialog[1] = IncludePRUltratypesH.FALSE

				return DialogResponse
			end

			return 0
		end
	end

	return 0
end

-- from src/game/obj_behaviors.c:obj_check_floor_death L705-723
function obj_behaviors.obj_check_floor_death(collisionFlags: number, floor: GroupsTypesHPlus3.Surface?)
	collisionFlags = S16(TruncS32(collisionFlags))
	if floor == nil then
		return
	end

	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if bit32.band(collisionFlags, obj_behaviors.OBJ_COL_FLAG_GROUNDED) == obj_behaviors.OBJ_COL_FLAG_GROUNDED then
		if floor.type_ == IncludeSurfaceTerrainsH.SURFACE_BURNING then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.OBJ_ACT_LAVA_DEATH)
		elseif floor.type_ == IncludeSurfaceTerrainsH.SURFACE_DEATH_PLANE then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, IncludeObjectConstantsH.OBJ_ACT_DEATH_PLANE_DEATH)
		end
	end
end

-- from src/game/obj_behaviors.c:obj_lava_death L729-750
function obj_behaviors.obj_lava_death(): number
	const o = Registry.Members.src__game__object_list_processor.gCurrentObject

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 30 then
		o.activeFlags = S16(IncludeObjectConstantsH.ACTIVE_FLAG_DEACTIVATED)
		return IncludePRUltratypesH.TRUE
	else
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosY) - 10.0)
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) % 8 == 0 then
		Registry.Members.src__game__spawn_sound.cur_obj_play_sound_2(IncludeSoundsH.SOUND_OBJ_BULLY_EXPLODE_2)

		const DeathSmoke = ObjectHelpers.spawn_object(o, IncludeModelIdsH.MODEL_SMOKE, BehaviorIds.bhvBobombBullyDeathSmoke)

		buffer.writef32(DeathSmoke.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(DeathSmoke.rawData, IncludeObjectFieldsH.oPosX) + F32(SrcEngineBehaviorScript.random_float() * 20.0))
		buffer.writef32(DeathSmoke.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(DeathSmoke.rawData, IncludeObjectFieldsH.oPosY) + F32(SrcEngineBehaviorScript.random_float() * 20.0))
		buffer.writef32(DeathSmoke.rawData, IncludeObjectFieldsH.oPosZ, buffer.readf32(DeathSmoke.rawData, IncludeObjectFieldsH.oPosZ) + F32(SrcEngineBehaviorScript.random_float() * 20.0))
		buffer.writef32(DeathSmoke.rawData, IncludeObjectFieldsH.oForwardVel, SrcEngineBehaviorScript.random_float() * 10.0)
	end

	return IncludePRUltratypesH.FALSE
end

-- from src/game/obj_behaviors.c:spawn_orange_number L755-764
function obj_behaviors.spawn_orange_number(bhvParam: number, relX: number, relY: number, relZ: number)
	bhvParam = S8(TruncS32(bhvParam))
	relX = S16(TruncS32(relX))
	relY = S16(TruncS32(relY))
	relZ = S16(TruncS32(relZ))
	if bhvParam >= 10 then
		return
	end

	const o = Registry.Members.src__game__object_list_processor.gCurrentObject
	const OrangeNumber = ObjectHelpers.spawn_object_relative(bhvParam, relX, relY, relZ, o, IncludeModelIdsH.MODEL_NUMBER, BehaviorIds.bhvOrangeNumber)

	buffer.writef32(OrangeNumber.rawData, IncludeObjectFieldsH.oPosY, buffer.readf32(OrangeNumber.rawData, IncludeObjectFieldsH.oPosY) + 25.0)
end

-- from src/game/obj_behaviors.c:debug_sequence_tracker L775-795
function obj_behaviors.debug_sequence_tracker(debugInputSequence: { number }): number
	if debugInputSequence[obj_behaviors.sDebugSequenceTracker + 1] == 0 then
		obj_behaviors.sDebugSequenceTracker = S8(0)
		return IncludePRUltratypesH.TRUE
	end

	if bit32.btest(debugInputSequence[obj_behaviors.sDebugSequenceTracker + 1], GameInit.gPlayer3Controller.buttonPressed) then
		obj_behaviors.sDebugSequenceTracker = S8(obj_behaviors.sDebugSequenceTracker + 1)
		obj_behaviors.sDebugTimer = S8(0)
	elseif obj_behaviors.sDebugTimer == 10 or GameInit.gPlayer3Controller.buttonPressed ~= 0 then
		obj_behaviors.sDebugSequenceTracker = S8(0)
		obj_behaviors.sDebugTimer = S8(0)
		return IncludePRUltratypesH.FALSE
	end

	obj_behaviors.sDebugTimer = S8(obj_behaviors.sDebugTimer + 1)

	return IncludePRUltratypesH.FALSE
end

return obj_behaviors
