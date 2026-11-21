--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/bbh_haunted_bookshelf.inc.c.
]]

const Registry = require("../../../groups/registry")
const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectConstantsH = require("../../../include/object_constants_h")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const IncludeSoundsH = require("../../../include/sounds_h")
const ObjectHelpers = require("../object_helpers")
const ObjectListProcessor = require("../object_list_processor")
const SpawnSound = require("../spawn_sound")

const bbh_haunted_bookshelf_inc = {}

Registry.Register("src__game__behaviors__bbh_haunted_bookshelf_inc", bbh_haunted_bookshelf_inc)

-- from src/game/behaviors/bbh_haunted_bookshelf.inc.c:bhv_haunted_bookshelf_loop L11-49
function bbh_haunted_bookshelf_inc.bhv_haunted_bookshelf_loop()
	const o = ObjectListProcessor.gCurrentObject :: GroupsTypesHPlus3.Object

	-- oDistanceToMario is unused by this object.
	-- This may have been used for revealing the books when Mario comes near,
	-- but in the final game this is done by bhvHauntedBookshelfManager.
	buffer.writef32(o.rawData, IncludeObjectFieldsH.oDistanceToMario, ObjectHelpers.dist_between_objects(o, ObjectListProcessor.gMarioObject :: GroupsTypesHPlus3.Object))

	buffer.writei32(o.rawData, IncludeObjectFieldsH.oFaceAngleYaw, 0)

	const action = buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction)

	if action == IncludeObjectConstantsH.HAUNTED_BOOKSHELF_ACT_IDLE then
		-- ???
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) == 0 then
			-- Empty in the C source of this branch.
		end

		-- This code never runs, since the action is set to 1 directly
		-- by bhvHauntedBookshelfManager. Maybe this was
		-- intended to be used to set the action instead?
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oHauntedBookshelfShouldOpen) ~= IncludePRUltratypesH.FALSE then
			buffer.writei32(o.rawData, IncludeObjectFieldsH.oAction, buffer.readi32(o.rawData, IncludeObjectFieldsH.oAction) + 1)
		end
	elseif action == IncludeObjectConstantsH.HAUNTED_BOOKSHELF_ACT_RECEDE then
		-- Move the bookshelf and play the sound
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oPosX, buffer.readf32(o.rawData, IncludeObjectFieldsH.oPosX) + 5.0)
		SpawnSound.cur_obj_play_sound_1(IncludeSoundsH.SOUND_ENV_ELEVATOR4_2)

		-- Delete the object after 102 frames
		if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 101 then
			ObjectHelpers.obj_mark_for_deletion(o)
		end
	end
end

return bbh_haunted_bookshelf_inc
