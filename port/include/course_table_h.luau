--!strict
--!optimize 2

--[[
	Port of include/course_table.h.
]]

-- from include/course_table.h:data
const course_table_h = {
	COURSE_CAP_COURSES = 20, -- COURSE_COTMC
	COURSE_NONE = 0,
	COURSE_BOB = 1,
	COURSE_WF = 2,
	COURSE_JRB = 3,
	COURSE_CCM = 4,
	COURSE_BBH = 5,
	COURSE_HMC = 6,
	COURSE_LLL = 7,
	COURSE_SSL = 8,
	COURSE_DDD = 9,
	COURSE_SL = 10,
	COURSE_WDW = 11,
	COURSE_TTM = 12,
	COURSE_THI = 13,
	COURSE_TTC = 14,
	COURSE_RR = 15,
	COURSE_BONUS_STAGES = 16,
	COURSE_STAGES_MAX = 15,
	COURSE_STAGES_COUNT = 15,
	COURSE_BITDW = 16,
	COURSE_BITFS = 17,
	COURSE_BITS = 18,
	COURSE_PSS = 19,
	COURSE_COTMC = 20,
	COURSE_TOTWC = 21,
	COURSE_VCUTM = 22,
	COURSE_WMOTR = 23,
	COURSE_SA = 24,
	COURSE_CAKE_END = 25,
	COURSE_END = 26,
	COURSE_MAX = 25,
	COURSE_COUNT = 25,
	COURSE_MIN = 1,
}

-- from include/course_table.h:COURSE_IS_MAIN_COURSE L29-29
function course_table_h.COURSE_IS_MAIN_COURSE(cmd: number): number
	return if cmd >= course_table_h.COURSE_MIN and cmd <= course_table_h.COURSE_STAGES_MAX then 1 else 0
end

-- from include/course_table.h:COURSE_NUM_TO_INDEX L30-30
function course_table_h.COURSE_NUM_TO_INDEX(cmd: number): number
	return cmd - 1
end

return course_table_h
