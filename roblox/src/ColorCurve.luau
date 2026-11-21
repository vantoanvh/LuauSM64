--!strict
--!optimize 2

--[[
	The level to give Roblox for a color level the N64 would show.

	Paradigm
		With the unlit lighting of the Presenter (no sun, a white ambient light, an exposure of -0.2 and the gain of a color correction, see Presenter.New), the plain material and every part
		white (Color3.new(1, 1, 1): the default gray of a part would take a third of the light), Roblox shows a color about as it is in the middle
		of the range (a little brighter), but takes the vertex color and the texel through its own transfer curve at the ends: dark levels come
		out darker and bright ones are held back (the shown level of a white one is 248, not 255). The levels below were measured in Studio on gray quads (a screenshot of 17 levels, read
		back pixel by pixel); Level inverts them: the level that Roblox shows as the wanted one, the wanted level scaled so that white is the
		brightest Roblox shows. Applied to every vertex color and every texel (each channel on its own), so that the product of the two,
		which Roblox forms, comes out as the product the N64 forms. The picture of the game that is a screen gui (roblox/src/Overlay) is not
		put through the curve: a screen gui shows its colors as they are.

	Design Notes
		The curve is not a power law, so the product is exact only where the two factors are near one or near each other; the error is a few
		levels in the shadows. A change of Lighting (exposure, ambient) or of the color of the parts needs the table measured again (a raised exposure
		bends the middle of the curve, which the product of the vertex color and the texel does not survive).
]]

-- Level given -> level shown, at 17 points
const Measured = {
	{ 0, 0 }, { 16, 4 }, { 32, 13 }, { 48, 28 }, { 64, 48 }, { 80, 70 }, { 96, 93 }, { 112, 116 }, { 128, 138 },
	{ 144, 159 }, { 160, 177 }, { 176, 194 }, { 192, 209 }, { 208, 221 }, { 224, 232 }, { 240, 241 }, { 255, 248 },
}

const Brightest = Measured[#Measured][2]

-- The level to give for each wanted level 0..255 (index + 1)
const Table = table.create(256, 0)

for Wanted = 0, 255 do
	const Target = Wanted * Brightest / 255
	local Given = 0

	for Index = 1, #Measured - 1 do
		const Low = Measured[Index]
		const High = Measured[Index + 1]

		if Target <= High[2] then
			Given = if Target <= Low[2] then Low[1] else Low[1] + (Target - Low[2]) / (High[2] - Low[2]) * (High[1] - Low[1])

			break
		end

		Given = High[1]
	end

	Table[Wanted + 1] = math.round(Given)
end

-- The level to give Roblox for a wanted level (0..255, any real: it is rounded)
const function Level(Wanted: number): number
	return Table[math.clamp(math.round(Wanted), 0, 255) + 1]
end

return Level
