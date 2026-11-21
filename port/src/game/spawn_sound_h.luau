--!strict
--!optimize 2

--[[
	Port of src/game/spawn_sound.h.
]]

-- from src/game/spawn_sound.h:SoundState
export type SoundState = {
	playSound: number,
	animFrame1: number,
	animFrame2: number,
	soundMagic: number,
}

const spawn_sound_h = {}

-- from src/game/spawn_sound.h:SoundState (zero-filled constructor)
function spawn_sound_h.new_SoundState(): SoundState
	return { playSound = 0, animFrame1 = 0, animFrame2 = 0, soundMagic = 0 } :: SoundState
end

return spawn_sound_h
