--!strict
--!optimize 2

--[[
	Port of include/PR/os_thread.h.
]]

-- from include/PR/os_thread.h:__OSfp_f
export type __OSfp_f = {
	f_odd: number,
	f_even: number,
}

-- from include/PR/os_thread.h:__OSfp
-- union: the fields are views of the same storage in C; decide how they alias
export type __OSfp = {
	f: __OSfp_f,
}

-- from include/PR/os_thread.h:__OSThreadContext
export type __OSThreadContext = {
	at: number,
	v0: number,
	v1: number,
	a0: number,
	a1: number,
	a2: number,
	a3: number,
	t0: number,
	t1: number,
	t2: number,
	t3: number,
	t4: number,
	t5: number,
	t6: number,
	t7: number,
	s0: number,
	s1: number,
	s2: number,
	s3: number,
	s4: number,
	s5: number,
	s6: number,
	s7: number,
	t8: number,
	t9: number,
	gp: number,
	sp: number,
	s8: number,
	ra: number,
	lo: number,
	hi: number,
	sr: number,
	pc: number,
	cause: number,
	badvaddr: number,
	rcp: number,
	fpcsr: number,
	fp0: __OSfp,
	fp2: __OSfp,
	fp4: __OSfp,
	fp6: __OSfp,
	fp8: __OSfp,
	fp10: __OSfp,
	fp12: __OSfp,
	fp14: __OSfp,
	fp16: __OSfp,
	fp18: __OSfp,
	fp20: __OSfp,
	fp22: __OSfp,
	fp24: __OSfp,
	fp26: __OSfp,
	fp28: __OSfp,
	fp30: __OSfp,
}

-- from include/PR/os_thread.h:__OSThreadprofile_s
export type __OSThreadprofile_s = {
	flag: number,
	count: number,
	time: number,
}

-- from include/PR/os_thread.h:OSThread_s
export type OSThread_s = {
	next: OSThread_s?,
	priority: number,
	queue: { OSThread_s? }?,
	tlnext: OSThread_s?,
	state: number,
	flags: number,
	id: number,
	fp: number,
	thprof: __OSThreadprofile_s?,
	context: __OSThreadContext,
}

-- from include/PR/os_thread.h:data
const os_thread_h = {
	OS_PRIORITY_MAX = 255,
	OS_PRIORITY_VIMGR = 254,
	OS_PRIORITY_RMON = 250,
	OS_PRIORITY_RMONSPIN = 200,
	OS_PRIORITY_PIMGR = 150,
	OS_PRIORITY_SIMGR = 140,
	OS_PRIORITY_APPMAX = 127,
	OS_PRIORITY_IDLE = 0,
	OS_STATE_STOPPED = 1,
	OS_STATE_RUNNABLE = 2,
	OS_STATE_RUNNING = 4,
	OS_STATE_WAITING = 8,
}

-- from include/PR/os_thread.h:__OSfp_f (zero-filled constructor)
function os_thread_h.new___OSfp_f(): __OSfp_f
	return { f_odd = 0, f_even = 0 } :: __OSfp_f
end

-- from include/PR/os_thread.h:__OSThreadContext (zero-filled constructor)
function os_thread_h.new___OSThreadContext(): __OSThreadContext
	return {
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
	} :: __OSThreadContext
end

-- from include/PR/os_thread.h:__OSThreadprofile_s (zero-filled constructor)
function os_thread_h.new___OSThreadprofile_s(): __OSThreadprofile_s
	return { flag = 0, count = 0, time = 0 } :: __OSThreadprofile_s
end

-- from include/PR/os_thread.h:OSThread_s (zero-filled constructor)
function os_thread_h.new_OSThread_s(): OSThread_s
	return {
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
	} :: OSThread_s
end

return os_thread_h
