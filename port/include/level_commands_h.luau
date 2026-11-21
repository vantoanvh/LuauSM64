--!strict
--!optimize 2

--[[
	Port of include/level_commands.h.
]]

-- from include/level_commands.h:data
const level_commands_h = {
	OP_AND = 0,
	OP_NAND = 1,
	OP_EQ = 2,
	OP_NEQ = 3,
	OP_LT = 4,
	OP_LEQ = 5,
	OP_GT = 6,
	OP_GEQ = 7,
	OP_SET = 0,
	OP_GET = 1,
	VAR_CURR_SAVE_FILE_NUM = 0,
	VAR_CURR_COURSE_NUM = 1,
	VAR_CURR_ACT_NUM = 2,
	VAR_CURR_LEVEL_NUM = 3,
	VAR_CURR_AREA_INDEX = 4,
	WARP_CHECKPOINT = 0x80,
	WARP_NO_CHECKPOINT = 0x00,
	WHIRLPOOL_COND_ALWAYS = 0,
	WHIRLPOOL_COND_BOWSER2_BEATEN = 2,
	WHIRLPOOL_COND_AT_LEAST_SECOND_STAR = 3,
	REGULAR_FACE = 0x0002,
	DIZZY_FACE = 0x0003,
}

-- from include/level_commands.h:EXECUTE L50-54
function level_commands_h.EXECUTE(seg: number, script: number, scriptEnd: number, entry: number): number
	error("stale")
end

-- from include/level_commands.h:EXIT_AND_EXECUTE L56-60
function level_commands_h.EXIT_AND_EXECUTE(seg: number, script: number, scriptEnd: number, entry: number): number
	error("stale")
end

-- from include/level_commands.h:EXIT L63-64
function level_commands_h.EXIT(): number
	error("stale")
end

-- from include/level_commands.h:SLEEP L66-67
function level_commands_h.SLEEP(frames: number): number
	error("stale")
end

-- from include/level_commands.h:SLEEP_BEFORE_EXIT L69-70
function level_commands_h.SLEEP_BEFORE_EXIT(frames: number): number
	error("stale")
end

-- from include/level_commands.h:JUMP L72-74
function level_commands_h.JUMP(target: number): number
	error("stale")
end

-- from include/level_commands.h:JUMP_LINK L76-78
function level_commands_h.JUMP_LINK(target: number): number
	error("stale")
end

-- from include/level_commands.h:RETURN L80-81
function level_commands_h.RETURN(): number
	error("stale")
end

-- from include/level_commands.h:JUMP_LINK_PUSH_ARG L83-84
function level_commands_h.JUMP_LINK_PUSH_ARG(arg: number): number
	error("stale")
end

-- from include/level_commands.h:JUMP_N_TIMES L86-87
function level_commands_h.JUMP_N_TIMES(): number
	error("stale")
end

-- from include/level_commands.h:LOOP_BEGIN L89-90
function level_commands_h.LOOP_BEGIN(): number
	error("stale")
end

-- from include/level_commands.h:LOOP_UNTIL L92-94
function level_commands_h.LOOP_UNTIL(op: number, arg: number): number
	error("stale")
end

-- from include/level_commands.h:JUMP_IF L96-99
function level_commands_h.JUMP_IF(op: number, arg: number, target: number): number
	error("stale")
end

-- from include/level_commands.h:JUMP_LINK_IF L101-104
function level_commands_h.JUMP_LINK_IF(op: number, arg: number, target: number): number
	error("stale")
end

-- from include/level_commands.h:SKIP_IF L107-109
function level_commands_h.SKIP_IF(op: number, arg: number): number
	error("stale")
end

-- from include/level_commands.h:SKIP L111-112
function level_commands_h.SKIP(): number
	error("stale")
end

-- from include/level_commands.h:SKIP_NOP L114-115
function level_commands_h.SKIP_NOP(): number
	error("stale")
end

-- from include/level_commands.h:CALL L117-119
function level_commands_h.CALL(arg: number, func: number): number
	error("stale")
end

-- from include/level_commands.h:CALL_LOOP L122-124
function level_commands_h.CALL_LOOP(arg: number, func: number): number
	error("stale")
end

-- from include/level_commands.h:SET_REG L126-127
function level_commands_h.SET_REG(value: number): number
	error("stale")
end

-- from include/level_commands.h:PUSH_POOL L129-130
function level_commands_h.PUSH_POOL(): number
	error("stale")
end

-- from include/level_commands.h:POP_POOL L132-133
function level_commands_h.POP_POOL(): number
	error("stale")
end

-- from include/level_commands.h:FIXED_LOAD L152-156
function level_commands_h.FIXED_LOAD(loadAddr: number, romStart: number, romEnd: number): number
	error("stale")
end

-- from include/level_commands.h:LOAD_RAW L158-161
function level_commands_h.LOAD_RAW(seg: number, romStart: number, romEnd: number): number
	error("stale")
end

-- from include/level_commands.h:LOAD_MIO0 L163-166
function level_commands_h.LOAD_MIO0(seg: number, romStart: number, romEnd: number): number
	error("stale")
end

-- from include/level_commands.h:LOAD_MARIO_HEAD L169-170
function level_commands_h.LOAD_MARIO_HEAD(sethead: number): number
	error("stale")
end

-- from include/level_commands.h:LOAD_MIO0_TEXTURE L178-181
function level_commands_h.LOAD_MIO0_TEXTURE(seg: number, romStart: number, romEnd: number): number
	error("stale")
end

-- from include/level_commands.h:INIT_LEVEL L184-185
function level_commands_h.INIT_LEVEL(): number
	error("stale")
end

-- from include/level_commands.h:CLEAR_LEVEL L187-188
function level_commands_h.CLEAR_LEVEL(): number
	error("stale")
end

-- from include/level_commands.h:ALLOC_LEVEL_POOL L190-191
function level_commands_h.ALLOC_LEVEL_POOL(): number
	error("stale")
end

-- from include/level_commands.h:FREE_LEVEL_POOL L193-194
function level_commands_h.FREE_LEVEL_POOL(): number
	error("stale")
end

-- from include/level_commands.h:AREA L196-198
function level_commands_h.AREA(index: number, geo: number): number
	error("stale")
end

-- from include/level_commands.h:END_AREA L200-201
function level_commands_h.END_AREA(): number
	error("stale")
end

-- from include/level_commands.h:LOAD_MODEL_FROM_DL L203-205
function level_commands_h.LOAD_MODEL_FROM_DL(model: number, dl: number, layer: number): number
	error("stale")
end

-- from include/level_commands.h:LOAD_MODEL_FROM_GEO L207-209
function level_commands_h.LOAD_MODEL_FROM_GEO(model: number, geo: number): number
	error("stale")
end

-- from include/level_commands.h:CMD23 L212-215
function level_commands_h.CMD23(model: number, unk4: number, unk8: number): number
	error("stale")
end

-- from include/level_commands.h:OBJECT_WITH_ACTS L217-221
function level_commands_h.OBJECT_WITH_ACTS(model: number, posX: number, posY: number, posZ: number, angleX: number, angleY: number, angleZ: number, bhvParam: number, bhv: number, acts: number): number
	error("stale")
end

-- from include/level_commands.h:OBJECT L223-224
function level_commands_h.OBJECT(model: number, posX: number, posY: number, posZ: number, angleX: number, angleY: number, angleZ: number, bhvParam: number, bhv: number): number
	error("stale")
end

-- from include/level_commands.h:MARIO L226-229
function level_commands_h.MARIO(model: number, bhvArg: number, bhv: number): number
	error("stale")
end

-- from include/level_commands.h:WARP_NODE L231-233
function level_commands_h.WARP_NODE(id: number, destLevel: number, destArea: number, destNode: number, flags: number): number
	error("stale")
end

-- from include/level_commands.h:PAINTING_WARP_NODE L235-237
function level_commands_h.PAINTING_WARP_NODE(id: number, destLevel: number, destArea: number, destNode: number, flags: number): number
	error("stale")
end

-- from include/level_commands.h:INSTANT_WARP L239-242
function level_commands_h.INSTANT_WARP(index: number, destArea: number, displaceX: number, displaceY: number, displaceZ: number): number
	error("stale")
end

-- from include/level_commands.h:LOAD_AREA L244-245
function level_commands_h.LOAD_AREA(area: number): number
	error("stale")
end

-- from include/level_commands.h:CMD2A L247-248
function level_commands_h.CMD2A(unk2: number): number
	error("stale")
end

-- from include/level_commands.h:MARIO_POS L250-253
function level_commands_h.MARIO_POS(area: number, yaw: number, posX: number, posY: number, posZ: number): number
	error("stale")
end

-- from include/level_commands.h:CMD2C L256-257
function level_commands_h.CMD2C(): number
	error("stale")
end

-- from include/level_commands.h:CMD2D L260-261
function level_commands_h.CMD2D(): number
	error("stale")
end

-- from include/level_commands.h:TERRAIN L263-265
function level_commands_h.TERRAIN(terrainData: number): number
	error("stale")
end

-- from include/level_commands.h:ROOMS L267-269
function level_commands_h.ROOMS(surfaceRooms: number): number
	error("stale")
end

-- from include/level_commands.h:SHOW_DIALOG L271-272
function level_commands_h.SHOW_DIALOG(index: number, dialogID: number): number
	error("stale")
end

-- from include/level_commands.h:TERRAIN_TYPE L274-275
function level_commands_h.TERRAIN_TYPE(terrainType: number): number
	error("stale")
end

-- from include/level_commands.h:NOP L277-278
function level_commands_h.NOP(): number
	error("stale")
end

-- from include/level_commands.h:TRANSITION L280-282
function level_commands_h.TRANSITION(transType: number, time: number, colorR: number, colorG: number, colorB: number): number
	error("stale")
end

-- from include/level_commands.h:BLACKOUT L284-285
function level_commands_h.BLACKOUT(active: number): number
	error("stale")
end

-- from include/level_commands.h:GAMMA L287-288
function level_commands_h.GAMMA(enabled: number): number
	error("stale")
end

-- from include/level_commands.h:SET_BACKGROUND_MUSIC L290-292
function level_commands_h.SET_BACKGROUND_MUSIC(settingsPreset: number, seq: number): number
	error("stale")
end

-- from include/level_commands.h:SET_MENU_MUSIC L294-295
function level_commands_h.SET_MENU_MUSIC(seq: number): number
	error("stale")
end

-- from include/level_commands.h:STOP_MUSIC L297-298
function level_commands_h.STOP_MUSIC(fadeOutTime: number): number
	error("stale")
end

-- from include/level_commands.h:MACRO_OBJECTS L300-302
function level_commands_h.MACRO_OBJECTS(objList: number): number
	error("stale")
end

-- from include/level_commands.h:CMD3A L305-308
function level_commands_h.CMD3A(unk2: number, unk4: number, unk6: number, unk8: number, unk10: number): number
	error("stale")
end

-- from include/level_commands.h:WHIRLPOOL L310-313
function level_commands_h.WHIRLPOOL(index: number, condition: number, posX: number, posY: number, posZ: number, strength: number): number
	error("stale")
end

-- from include/level_commands.h:GET_OR_SET L315-316
function level_commands_h.GET_OR_SET(op: number, var: number): number
	error("stale")
end

return level_commands_h
