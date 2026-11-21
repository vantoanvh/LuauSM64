--!strict
--!optimize 2

--[[
	Linker symbols of the US build whose address game code takes (`setup_game_memory`), as constants.

	Paradigm
		ROM addresses are byte offsets in the ROM image (`__romPos` of sm64.ld). The N64 RAM addresses are the ones of sm64.ld and
		include/segments.h; only display output reads them, no game state depends on their value.

	Design Notes
		native/verify/verify_rom.luau checks the ROM addresses against the image (the MIO0 header of segment 2, the entry script, the
		count of the Mario animation and demo tables).
]]

return {
	EntrySegmentRomStart = 0x108A10,
	EntrySegmentRomEnd = 0x108A40,
	Segment2Mio0SegmentRomStart = 0x108A40,
	Segment2Mio0SegmentRomEnd = 0x114750,
	-- Segmented address of seg2_dialog_table (170 DialogEntry pointers and a NULL), dialog-entry-rom-offsets
	Seg2DialogTable = 0x02010A68,
	MarioAnims = 0x4EC000,
	DemoInputs = 0x579C20,
	ZBuffer = 0x80000400,
	Framebuffer0 = 0x8038F800,
	Framebuffer1 = 0x803B5000,
	Framebuffer2 = 0x803DA800,
	-- gDecompressionHeap (buffers.c) is a block of Memory below the C stack, outside the pool (decompression-heap-block)
	DecompressionHeap = 0x7E3000,
	DecompressionHeapSize = 0xD000,
	-- The data of Goddard that the linker places in the program (renderer_static.luau: textures, vertices and display lists of the
	-- stars and the sparkles, the hilites and the look at vectors) is a block of Memory below the decompression heap, outside the
	-- main pool (goddard-static-data)
	GoddardData = 0x7D3000,
	GoddardDataSize = 0x10000,
	-- The Gfx pool the game writes its display lists into (GFX_POOL_SIZE commands of 8 bytes) is a block of Memory below the
	-- Goddard data, outside the main pool (gfx-display-list-pool)
	GfxPool = 0x7C6800,
	GfxPoolSize = 0xC800,
	-- gZBuffer and the three gFramebuffer arrays (320 * 240 * 2 bytes each) that level_cmd_load_mario_head hands to Goddard's heap
	-- are blocks of Memory below the Gfx pool, outside the main pool, which the harness boot ends here (goddard-game-integration)
	GoddardZBuffer = 0x730800,
	ZBufferSize = 0x25800,
	GoddardFramebuffers = 0x756000,
	FramebufferSize = 0x25800,
}
