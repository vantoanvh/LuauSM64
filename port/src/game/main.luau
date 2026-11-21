--!strict
--!optimize 2

--[[
	Port of src/game/main.c.
]]

const Registry = require("../../groups/registry")

const GroupsTypesHPlus3 = require("../../groups/types_h_plus3")

const IncludePROsH = require("../../include/PR/os_h")
const IncludePROsMessageH = require("../../include/PR/os_message_h")
const IncludePROsPiH = require("../../include/PR/os_pi_h")
const IncludePROsThreadH = require("../../include/PR/os_thread_h")

-- from src/game/main.c:data
const main = {
	MESG_SP_COMPLETE = 100,
	MESG_DP_COMPLETE = 101,
	MESG_VI_VBLANK = 102,
	MESG_START_GFX_SPTASK = 103,
	MESG_NMI_REQUEST = 104,
	-- from src/game/main.c:D_80339210 L23-23
	D_80339210 = {
		next = nil,
		priority = 0,
		queue = nil,
		tlnext = nil,
		state = 0,
		flags = 0,
		id = 0,
		fp = 0,
		thprof = nil,
		context = {
			at = 0,
			v0 = 0,
			v1 = 0,
			a0 = 0,
			a1 = 0,
			a2 = 0,
			a3 = 0,
			t0 = 0,
			t1 = 0,
			t2 = 0,
			t3 = 0,
			t4 = 0,
			t5 = 0,
			t6 = 0,
			t7 = 0,
			s0 = 0,
			s1 = 0,
			s2 = 0,
			s3 = 0,
			s4 = 0,
			s5 = 0,
			s6 = 0,
			s7 = 0,
			t8 = 0,
			t9 = 0,
			gp = 0,
			sp = 0,
			s8 = 0,
			ra = 0,
			lo = 0,
			hi = 0,
			sr = 0,
			pc = 0,
			cause = 0,
			badvaddr = 0,
			rcp = 0,
			fpcsr = 0,
			fp0 = { f = { f_odd = 0, f_even = 0 } },
			fp2 = { f = { f_odd = 0, f_even = 0 } },
			fp4 = { f = { f_odd = 0, f_even = 0 } },
			fp6 = { f = { f_odd = 0, f_even = 0 } },
			fp8 = { f = { f_odd = 0, f_even = 0 } },
			fp10 = { f = { f_odd = 0, f_even = 0 } },
			fp12 = { f = { f_odd = 0, f_even = 0 } },
			fp14 = { f = { f_odd = 0, f_even = 0 } },
			fp16 = { f = { f_odd = 0, f_even = 0 } },
			fp18 = { f = { f_odd = 0, f_even = 0 } },
			fp20 = { f = { f_odd = 0, f_even = 0 } },
			fp22 = { f = { f_odd = 0, f_even = 0 } },
			fp24 = { f = { f_odd = 0, f_even = 0 } },
			fp26 = { f = { f_odd = 0, f_even = 0 } },
			fp28 = { f = { f_odd = 0, f_even = 0 } },
			fp30 = { f = { f_odd = 0, f_even = 0 } },
		},
	} :: IncludePROsThreadH.OSThread_s,
	-- from src/game/main.c:gIdleThread L24-24
	gIdleThread = {
		next = nil,
		priority = 0,
		queue = nil,
		tlnext = nil,
		state = 0,
		flags = 0,
		id = 0,
		fp = 0,
		thprof = nil,
		context = {
			at = 0,
			v0 = 0,
			v1 = 0,
			a0 = 0,
			a1 = 0,
			a2 = 0,
			a3 = 0,
			t0 = 0,
			t1 = 0,
			t2 = 0,
			t3 = 0,
			t4 = 0,
			t5 = 0,
			t6 = 0,
			t7 = 0,
			s0 = 0,
			s1 = 0,
			s2 = 0,
			s3 = 0,
			s4 = 0,
			s5 = 0,
			s6 = 0,
			s7 = 0,
			t8 = 0,
			t9 = 0,
			gp = 0,
			sp = 0,
			s8 = 0,
			ra = 0,
			lo = 0,
			hi = 0,
			sr = 0,
			pc = 0,
			cause = 0,
			badvaddr = 0,
			rcp = 0,
			fpcsr = 0,
			fp0 = { f = { f_odd = 0, f_even = 0 } },
			fp2 = { f = { f_odd = 0, f_even = 0 } },
			fp4 = { f = { f_odd = 0, f_even = 0 } },
			fp6 = { f = { f_odd = 0, f_even = 0 } },
			fp8 = { f = { f_odd = 0, f_even = 0 } },
			fp10 = { f = { f_odd = 0, f_even = 0 } },
			fp12 = { f = { f_odd = 0, f_even = 0 } },
			fp14 = { f = { f_odd = 0, f_even = 0 } },
			fp16 = { f = { f_odd = 0, f_even = 0 } },
			fp18 = { f = { f_odd = 0, f_even = 0 } },
			fp20 = { f = { f_odd = 0, f_even = 0 } },
			fp22 = { f = { f_odd = 0, f_even = 0 } },
			fp24 = { f = { f_odd = 0, f_even = 0 } },
			fp26 = { f = { f_odd = 0, f_even = 0 } },
			fp28 = { f = { f_odd = 0, f_even = 0 } },
			fp30 = { f = { f_odd = 0, f_even = 0 } },
		},
	} :: IncludePROsThreadH.OSThread_s,
	-- from src/game/main.c:gMainThread L25-25
	gMainThread = {
		next = nil,
		priority = 0,
		queue = nil,
		tlnext = nil,
		state = 0,
		flags = 0,
		id = 0,
		fp = 0,
		thprof = nil,
		context = {
			at = 0,
			v0 = 0,
			v1 = 0,
			a0 = 0,
			a1 = 0,
			a2 = 0,
			a3 = 0,
			t0 = 0,
			t1 = 0,
			t2 = 0,
			t3 = 0,
			t4 = 0,
			t5 = 0,
			t6 = 0,
			t7 = 0,
			s0 = 0,
			s1 = 0,
			s2 = 0,
			s3 = 0,
			s4 = 0,
			s5 = 0,
			s6 = 0,
			s7 = 0,
			t8 = 0,
			t9 = 0,
			gp = 0,
			sp = 0,
			s8 = 0,
			ra = 0,
			lo = 0,
			hi = 0,
			sr = 0,
			pc = 0,
			cause = 0,
			badvaddr = 0,
			rcp = 0,
			fpcsr = 0,
			fp0 = { f = { f_odd = 0, f_even = 0 } },
			fp2 = { f = { f_odd = 0, f_even = 0 } },
			fp4 = { f = { f_odd = 0, f_even = 0 } },
			fp6 = { f = { f_odd = 0, f_even = 0 } },
			fp8 = { f = { f_odd = 0, f_even = 0 } },
			fp10 = { f = { f_odd = 0, f_even = 0 } },
			fp12 = { f = { f_odd = 0, f_even = 0 } },
			fp14 = { f = { f_odd = 0, f_even = 0 } },
			fp16 = { f = { f_odd = 0, f_even = 0 } },
			fp18 = { f = { f_odd = 0, f_even = 0 } },
			fp20 = { f = { f_odd = 0, f_even = 0 } },
			fp22 = { f = { f_odd = 0, f_even = 0 } },
			fp24 = { f = { f_odd = 0, f_even = 0 } },
			fp26 = { f = { f_odd = 0, f_even = 0 } },
			fp28 = { f = { f_odd = 0, f_even = 0 } },
			fp30 = { f = { f_odd = 0, f_even = 0 } },
		},
	} :: IncludePROsThreadH.OSThread_s,
	-- from src/game/main.c:gGameLoopThread L26-26
	gGameLoopThread = {
		next = nil,
		priority = 0,
		queue = nil,
		tlnext = nil,
		state = 0,
		flags = 0,
		id = 0,
		fp = 0,
		thprof = nil,
		context = {
			at = 0,
			v0 = 0,
			v1 = 0,
			a0 = 0,
			a1 = 0,
			a2 = 0,
			a3 = 0,
			t0 = 0,
			t1 = 0,
			t2 = 0,
			t3 = 0,
			t4 = 0,
			t5 = 0,
			t6 = 0,
			t7 = 0,
			s0 = 0,
			s1 = 0,
			s2 = 0,
			s3 = 0,
			s4 = 0,
			s5 = 0,
			s6 = 0,
			s7 = 0,
			t8 = 0,
			t9 = 0,
			gp = 0,
			sp = 0,
			s8 = 0,
			ra = 0,
			lo = 0,
			hi = 0,
			sr = 0,
			pc = 0,
			cause = 0,
			badvaddr = 0,
			rcp = 0,
			fpcsr = 0,
			fp0 = { f = { f_odd = 0, f_even = 0 } },
			fp2 = { f = { f_odd = 0, f_even = 0 } },
			fp4 = { f = { f_odd = 0, f_even = 0 } },
			fp6 = { f = { f_odd = 0, f_even = 0 } },
			fp8 = { f = { f_odd = 0, f_even = 0 } },
			fp10 = { f = { f_odd = 0, f_even = 0 } },
			fp12 = { f = { f_odd = 0, f_even = 0 } },
			fp14 = { f = { f_odd = 0, f_even = 0 } },
			fp16 = { f = { f_odd = 0, f_even = 0 } },
			fp18 = { f = { f_odd = 0, f_even = 0 } },
			fp20 = { f = { f_odd = 0, f_even = 0 } },
			fp22 = { f = { f_odd = 0, f_even = 0 } },
			fp24 = { f = { f_odd = 0, f_even = 0 } },
			fp26 = { f = { f_odd = 0, f_even = 0 } },
			fp28 = { f = { f_odd = 0, f_even = 0 } },
			fp30 = { f = { f_odd = 0, f_even = 0 } },
		},
	} :: IncludePROsThreadH.OSThread_s,
	-- from src/game/main.c:gSoundThread L27-27
	gSoundThread = {
		next = nil,
		priority = 0,
		queue = nil,
		tlnext = nil,
		state = 0,
		flags = 0,
		id = 0,
		fp = 0,
		thprof = nil,
		context = {
			at = 0,
			v0 = 0,
			v1 = 0,
			a0 = 0,
			a1 = 0,
			a2 = 0,
			a3 = 0,
			t0 = 0,
			t1 = 0,
			t2 = 0,
			t3 = 0,
			t4 = 0,
			t5 = 0,
			t6 = 0,
			t7 = 0,
			s0 = 0,
			s1 = 0,
			s2 = 0,
			s3 = 0,
			s4 = 0,
			s5 = 0,
			s6 = 0,
			s7 = 0,
			t8 = 0,
			t9 = 0,
			gp = 0,
			sp = 0,
			s8 = 0,
			ra = 0,
			lo = 0,
			hi = 0,
			sr = 0,
			pc = 0,
			cause = 0,
			badvaddr = 0,
			rcp = 0,
			fpcsr = 0,
			fp0 = { f = { f_odd = 0, f_even = 0 } },
			fp2 = { f = { f_odd = 0, f_even = 0 } },
			fp4 = { f = { f_odd = 0, f_even = 0 } },
			fp6 = { f = { f_odd = 0, f_even = 0 } },
			fp8 = { f = { f_odd = 0, f_even = 0 } },
			fp10 = { f = { f_odd = 0, f_even = 0 } },
			fp12 = { f = { f_odd = 0, f_even = 0 } },
			fp14 = { f = { f_odd = 0, f_even = 0 } },
			fp16 = { f = { f_odd = 0, f_even = 0 } },
			fp18 = { f = { f_odd = 0, f_even = 0 } },
			fp20 = { f = { f_odd = 0, f_even = 0 } },
			fp22 = { f = { f_odd = 0, f_even = 0 } },
			fp24 = { f = { f_odd = 0, f_even = 0 } },
			fp26 = { f = { f_odd = 0, f_even = 0 } },
			fp28 = { f = { f_odd = 0, f_even = 0 } },
			fp30 = { f = { f_odd = 0, f_even = 0 } },
		},
	} :: IncludePROsThreadH.OSThread_s,
	-- from src/game/main.c:gDmaIoMesg L29-29
	gDmaIoMesg = IncludePROsPiH.new_OSIoMesg(),
	-- from src/game/main.c:gMainReceivedMesg L30-30
	gMainReceivedMesg = nil,
	-- from src/game/main.c:gDmaMesgQueue L32-32
	gDmaMesgQueue = { mtqueue = nil, fullqueue = nil, validCount = 0, first = 0, msgCount = 0, msg = nil } :: IncludePROsMessageH.OSMesgQueue_s,
	-- from src/game/main.c:gSIEventMesgQueue L33-33
	gSIEventMesgQueue = { mtqueue = nil, fullqueue = nil, validCount = 0, first = 0, msgCount = 0, msg = nil } :: IncludePROsMessageH.OSMesgQueue_s,
	-- from src/game/main.c:gPIMesgQueue L34-34
	gPIMesgQueue = { mtqueue = nil, fullqueue = nil, validCount = 0, first = 0, msgCount = 0, msg = nil } :: IncludePROsMessageH.OSMesgQueue_s,
	-- from src/game/main.c:gIntrMesgQueue L35-35
	gIntrMesgQueue = { mtqueue = nil, fullqueue = nil, validCount = 0, first = 0, msgCount = 0, msg = nil } :: IncludePROsMessageH.OSMesgQueue_s,
	-- from src/game/main.c:gSPTaskMesgQueue L36-36
	gSPTaskMesgQueue = { mtqueue = nil, fullqueue = nil, validCount = 0, first = 0, msgCount = 0, msg = nil } :: IncludePROsMessageH.OSMesgQueue_s,
	-- from src/game/main.c:gDmaMesgBuf L38-38
	gDmaMesgBuf = { nil },
	-- from src/game/main.c:gPIMesgBuf L39-39
	gPIMesgBuf = {
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
		nil,
	},
	-- from src/game/main.c:gSIEventMesgBuf L40-40
	gSIEventMesgBuf = { nil },
	-- from src/game/main.c:gIntrMesgBuf L41-41
	gIntrMesgBuf = { nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil },
	-- from src/game/main.c:gUnknownMesgBuf L42-42
	gUnknownMesgBuf = { nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil },
	-- from src/game/main.c:gVblankHandler1 L44-44
	gVblankHandler1 = nil :: GroupsTypesHPlus3.VblankHandler?,
	-- from src/game/main.c:gVblankHandler2 L45-45
	gVblankHandler2 = nil :: GroupsTypesHPlus3.VblankHandler?,
	-- from src/game/main.c:gActiveSPTask L46-46
	gActiveSPTask = nil :: GroupsTypesHPlus3.SPTask?,
	-- from src/game/main.c:sCurrentAudioSPTask L47-47
	sCurrentAudioSPTask = nil :: GroupsTypesHPlus3.SPTask?,
	-- from src/game/main.c:sCurrentDisplaySPTask L48-48
	sCurrentDisplaySPTask = nil :: GroupsTypesHPlus3.SPTask?,
	-- from src/game/main.c:sNextAudioSPTask L49-49
	sNextAudioSPTask = nil :: GroupsTypesHPlus3.SPTask?,
	-- from src/game/main.c:sNextDisplaySPTask L50-50
	sNextDisplaySPTask = nil :: GroupsTypesHPlus3.SPTask?,
	-- from src/game/main.c:sAudioEnabled L51-51
	sAudioEnabled = 1,
	-- from src/game/main.c:gNumVblanks L52-52
	gNumVblanks = 0,
	-- from src/game/main.c:gResetTimer L53-53
	gResetTimer = 0,
	-- from src/game/main.c:gNmiResetBarsTimer L54-54
	gNmiResetBarsTimer = 0,
	-- from src/game/main.c:gDebugLevelSelect L55-55
	gDebugLevelSelect = 0,
	-- from src/game/main.c:D_8032C650 L56-56
	D_8032C650 = 0,
	-- from src/game/main.c:gShowProfiler L58-58
	gShowProfiler = 0,
	-- from src/game/main.c:gShowDebugText L59-59
	gShowDebugText = 0,
	-- from src/game/main.c:sProfilerKeySequence L63-65
	sProfilerKeySequence = {
		IncludePROsH.U_JPAD,
		IncludePROsH.U_JPAD,
		IncludePROsH.D_JPAD,
		IncludePROsH.D_JPAD,
		IncludePROsH.L_JPAD,
		IncludePROsH.R_JPAD,
		IncludePROsH.L_JPAD,
		IncludePROsH.R_JPAD,
	},
	-- from src/game/main.c:sDebugTextKeySequence L66-67
	sDebugTextKeySequence = {
		IncludePROsH.D_JPAD,
		IncludePROsH.D_JPAD,
		IncludePROsH.U_JPAD,
		IncludePROsH.U_JPAD,
		IncludePROsH.L_JPAD,
		IncludePROsH.R_JPAD,
		IncludePROsH.L_JPAD,
		IncludePROsH.R_JPAD,
	},
	-- from src/game/main.c:sProfilerKey L68-68
	sProfilerKey = 0,
	-- from src/game/main.c:sDebugTextKey L69-69
	sDebugTextKey = 0,
}

Registry.Register("src__game__main", main)

-- from src/game/main.c:handle_debug_key_sequences L62-87
function main.handle_debug_key_sequences()
	error("stale")
	return
end

-- from src/game/main.c:unknown_main_func L89-106
function main.unknown_main_func()
	error("stale")
	return
end

-- from src/game/main.c:stub_main_1 L108-109
function main.stub_main_1()
	error("stale")
	return
end

-- from src/game/main.c:stub_main_2 L111-112
function main.stub_main_2()
	error("stale")
	return
end

-- from src/game/main.c:stub_main_3 L114-115
function main.stub_main_3()
	error("stale")
	return
end

-- from src/game/main.c:setup_mesg_queues L117-129
function main.setup_mesg_queues()
	error("stale")
	return
end

-- from src/game/main.c:alloc_pool L131-137
function main.alloc_pool()
	error("stale")
	return
end

-- from src/game/main.c:create_thread L139-143
function main.create_thread(thread: IncludePROsThreadH.OSThread_s, id: number, entry: () -> (), arg: unknown, sp: unknown, pri: number)
	error("stale")
	return
end

-- from src/game/main.c:handle_nmi_request L149-158
function main.handle_nmi_request()
	error("stale")
	return
end

-- from src/game/main.c:receive_new_tasks L160-184
function main.receive_new_tasks()
	error("stale")
	return
end

-- from src/game/main.c:start_sptask L186-198
function main.start_sptask(taskType: number)
	error("stale")
	return
end

-- from src/game/main.c:interrupt_gfx_sptask L200-205
function main.interrupt_gfx_sptask()
	error("stale")
	return
end

-- from src/game/main.c:start_gfx_sptask L207-213
function main.start_gfx_sptask()
	error("stale")
	return
end

-- from src/game/main.c:pretend_audio_sptask_done L215-219
function main.pretend_audio_sptask_done()
	error("stale")
	return
end

-- from src/game/main.c:handle_vblank L221-272
function main.handle_vblank()
	error("stale")
	return
end

-- from src/game/main.c:handle_sp_complete L274-320
function main.handle_sp_complete()
	error("stale")
	return
end

-- from src/game/main.c:handle_dp_complete L322-330
function main.handle_dp_complete()
	error("stale")
	return
end

-- from src/game/main.c:thread3_main L332-366
function main.thread3_main(arg: unknown)
	error("stale")
	return
end

-- from src/game/main.c:set_vblank_handler L368-380
function main.set_vblank_handler(index: number, handler: GroupsTypesHPlus3.VblankHandler, queue: IncludePROsMessageH.OSMesgQueue_s, msg: unknown)
	error("stale")
	return
end

-- from src/game/main.c:send_sp_task_message L382-385
function main.send_sp_task_message(msg: unknown)
	error("stale")
	return
end

-- from src/game/main.c:dispatch_audio_sptask L387-392
function main.dispatch_audio_sptask(spTask: GroupsTypesHPlus3.SPTask?)
	error("stale")
	return
end

-- from src/game/main.c:exec_display_list L394-406
function main.exec_display_list(spTask: GroupsTypesHPlus3.SPTask?)
	error("stale")
	return
end

-- from src/game/main.c:turn_on_audio L408-410
function main.turn_on_audio()
	error("stale")
	return
end

-- from src/game/main.c:turn_off_audio L412-417
function main.turn_off_audio()
	error("stale")
	return
end

-- from src/game/main.c:thread1_idle L422-453
function main.thread1_idle(arg: unknown)
	error("stale")
	return
end

-- from src/game/main.c:main_func L455-462
function main.main_func()
	error("stale")
	return
end

return main
