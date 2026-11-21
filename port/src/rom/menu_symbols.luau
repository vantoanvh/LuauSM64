--!strict
--!optimize 2

--[[
	Segmented address of the display lists and tables the menu, star select and title screen code names (US ROM layout): segment 7 of
	the menu level (levels/menu/leveldata.c), segment 7 of the intro level (levels/intro/leveldata.c) and segment 0xA of the title
	screen background (bin/title_screen_bg.c), and the textures of segment 2 the screen transitions and the moving textures (water,
	mist, lava) load (bin/segment2.c).
	segmented_to_virtual(MenuSymbols.dl_menu_idle_hand) is the Memory address.

	Design Notes
		Hand written: levels/menu/leveldata.c and levels/intro/leveldata.c have no .inc.c files, which gen_segment_symbols.mjs reads.
		The addresses in the comments above their definitions are those of another version after the idle hand display list, so
		each address was found in the decompressed MIO0 block of its segment by the first words of the list (the comment is 0x14C8
		above the US address from dl_menu_ia8_text_begin on); the intro addresses and the title screen background ones are those of
		the C names (intro_seg7_dl_0700B3A0, title_screen_bg_dl_0A000100) and agree with the block. The transition textures are at
		the US offsets of reference/assets.json (the 0xF458 of their file names is the JP offset).
]]

-- from levels/menu/leveldata.c:addresses
return {
	menu_hud_lut = 0x0700ABD0,
	menu_font_lut = 0x0700B840,
	dl_menu_idle_hand = 0x070073A0,
	dl_menu_grabbing_hand = 0x070073B8,
	dl_menu_ia8_text_begin = 0x0700BC40,
	dl_menu_ia8_text_end = 0x0700BC98,
	dl_menu_rgba16_wood_course = 0x0700DD60,
	-- from levels/intro/leveldata.c:addresses
	intro_seg7_dl_logo = 0x0700B3A0,
	intro_seg7_dl_copyright = 0x0700C6A0,
	intro_seg7_table_0700C790 = 0x0700C790,
	intro_seg7_table_0700C880 = 0x0700C880,
	-- from bin/title_screen_bg.c:addresses
	title_screen_bg_dl_0A000100 = 0x0A000100,
	title_screen_bg_dl_0A000118 = 0x0A000118,
	title_screen_bg_dl_0A000130 = 0x0A000130,
	title_screen_bg_dl_0A000148 = 0x0A000148,
	title_screen_bg_dl_0A000160 = 0x0A000160,
	title_screen_bg_dl_0A000178 = 0x0A000178,
	title_screen_bg_dl_0A000190 = 0x0A000190,
	mario_title_texture_table = 0x0A0065C0,
	game_over_texture_table = 0x0A0065D0,
	-- from bin/segment2.c:addresses
	texture_transition_star_half = 0x020122B8,
	texture_transition_circle_half = 0x02012AB8,
	texture_transition_mario = 0x020132B8,
	texture_transition_bowser_half = 0x020142B8,
	texture_waterbox_water = 0x02014AB8,
	texture_waterbox_jrb_water = 0x020152B8,
	texture_waterbox_unknown_water = 0x02015AB8,
	texture_waterbox_mist = 0x020162B8,
	texture_waterbox_lava = 0x02016AB8,
}
