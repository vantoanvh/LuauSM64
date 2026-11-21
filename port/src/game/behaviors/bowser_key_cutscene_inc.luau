--!strict
--!optimize 2

--[[
	Port of src/game/behaviors/bowser_key_cutscene.inc.c.
]]

const Registry = require("../../../groups/registry")

const GroupsTypesHPlus3 = require("../../../groups/types_h_plus3")
const IncludeObjectFieldsH = require("../../../include/object_fields_h")
const IncludePRUltratypesH = require("../../../include/PR/ultratypes_h")
const ObjectHelpers = require("../object_helpers")
const RenderingGraphNode = require("../rendering_graph_node")

const bowser_key_cutscene_inc = {}

Registry.Register("src__game__behaviors__bowser_key_cutscene_inc", bowser_key_cutscene_inc)

const function F32(Value: number): number
	return vector.create(Value, 0, 0).x
end

-- from src/game/behaviors/bowser_key_cutscene.inc.c:geo_scale_bowser_key L3-9
function bowser_key_cutscene_inc.geo_scale_bowser_key(run: number, node: GroupsTypesHPlus3.GraphNode, mtx: { { number } }): { unknown }?
	if run == IncludePRUltratypesH.TRUE then
		const obj = RenderingGraphNode.gCurGraphNodeObject :: GroupsTypesHPlus3.Object
		const scaleNode = node.next :: GroupsTypesHPlus3.GraphNodeScale

		scaleNode.scale = buffer.readf32(obj.rawData, IncludeObjectFieldsH.oBowserKeyScale)
	end

	return nil
end

-- from src/game/behaviors/bowser_key_cutscene.inc.c:bhv_bowser_key_unlock_door_loop L11-33
function bowser_key_cutscene_inc.bhv_bowser_key_unlock_door_loop()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const animFrame: number = o.header.gfx.animInfo.animFrame

	ObjectHelpers.cur_obj_init_animation_with_sound(0)

	if animFrame < 38 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oBowserKeyScale, 0.0)
	elseif animFrame < 49 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oBowserKeyScale, 0.2)
	elseif animFrame < 58 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oBowserKeyScale, F32((animFrame - 53) * F32(0.11875)) + 0.2)
	elseif animFrame < 59 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oBowserKeyScale, 1.1)
	elseif animFrame < 60 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oBowserKeyScale, 1.05)
	else
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oBowserKeyScale, 1.0)
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 150 then
		ObjectHelpers.obj_mark_for_deletion(o)
	end
end

-- from src/game/behaviors/bowser_key_cutscene.inc.c:bhv_bowser_key_course_exit_loop L35-55
function bowser_key_cutscene_inc.bhv_bowser_key_course_exit_loop()
	const o: GroupsTypesHPlus3.Object = Registry.Members.src__game__object_list_processor.gCurrentObject
	const animFrame: number = o.header.gfx.animInfo.animFrame

	ObjectHelpers.cur_obj_init_animation_with_sound(1)

	if animFrame < 38 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oBowserKeyScale, 0.2)
	elseif animFrame < 52 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oBowserKeyScale, F32((animFrame - 42) * F32(0.042857)) + 0.2)
	elseif animFrame < 94 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oBowserKeyScale, 0.8)
	elseif animFrame < 101 then
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oBowserKeyScale, F32((101 - animFrame) * F32(0.085714)) + 0.2)
	else
		buffer.writef32(o.rawData, IncludeObjectFieldsH.oBowserKeyScale, 0.2)
	end

	if buffer.readi32(o.rawData, IncludeObjectFieldsH.oTimer) > 138 then
		ObjectHelpers.obj_mark_for_deletion(o)
	end
end

return bowser_key_cutscene_inc
