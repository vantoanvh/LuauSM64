--!strict
--!optimize 2

--[[
	Port of include/PR/os_eeprom.h.
]]

-- from include/PR/os_eeprom.h:data
const os_eeprom_h = {
	EEPROM_TYPE_4K = 0x01,
	EEPROM_TYPE_16K = 0x02,
	EEPROM_MAXBLOCKS = 64,
	EEP16K_MAXBLOCKS = 256,
	EEPROM_BLOCK_SIZE = 8,
}

return os_eeprom_h
