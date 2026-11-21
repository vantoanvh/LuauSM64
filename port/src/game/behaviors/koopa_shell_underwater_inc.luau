--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/koopa_shell_underwater.inc.c.
]]

const Registry = require("../../../groups/registry")

const InteractionH = require("../interaction_h")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")

-- from src/game/behaviors/koopa_shell_underwater.inc.c:data
const koopa_shell_underwater_inc = {
	-- from src/game/behaviors/koopa_shell_underwater.inc.c:sKoopaShellUnderwaterHitbox L3-13
	sKoopaShellUnderwaterHitbox = {
		interactType = InteractionH.INTERACT_GRABBABLE,
		downOffset = 0,
		damageOrCoinValue = 0,
		health = 1,
		numLootCoins = 0,
		radius = 80,
		height = 50,
		hurtboxRadius = 0,
		hurtboxHeight = 0,
	},
}

Registry.Register("src__game__behaviors__koopa_shell_underwater_inc", koopa_shell_underwater_inc)

-- from src/game/behaviors/koopa_shell_underwater.inc.c:set_koopa_shell_underwater_hitbox L15-17
function koopa_shell_underwater_inc.set_koopa_shell_underwater_hitbox()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	ObjectHelpers.obj_set_hitbox(o, koopa_shell_underwater_inc.sKoopaShellUnderwaterHitbox)
end

-- from src/game/behaviors/koopa_shell_underwater.inc.c:bhv_koopa_shell_underwater_loop L19-40
function koopa_shell_underwater_inc.bhv_koopa_shell_underwater_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object
	const heldState = buffer.readu32(o.rawData, IncludeObjectFieldsH.oHeldState)

	if heldState == IncludeObjectConstantsH.HELD_FREE then
		koopa_shell_underwater_inc.set_koopa_shell_underwater_hitbox()
	elseif heldState == IncludeObjectConstantsH.HELD_HELD then
		ObjectHelpers.cur_obj_unrender_set_action_and_anim(-1, 0)
	elseif heldState == IncludeObjectConstantsH.HELD_THROWN or heldState == IncludeObjectConstantsH.HELD_DROPPED then
		ObjectHelpers.obj_mark_for_deletion(o)
		ObjectHelpers.spawn_mist_particles()
	end

	if bit32.btest(buffer.readi32(o.rawData, IncludeObjectFieldsH.oInteractStatus), InteractionH.INT_STATUS_STOP_RIDING) then
		ObjectHelpers.obj_mark_for_deletion(o)
		ObjectHelpers.spawn_mist_particles()
	end

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oInteractStatus, 0)
end

return koopa_shell_underwater_inc
