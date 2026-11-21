--!strict
--!optimize 2

--[[
	Draws circular, square and rectangular shadows below recorded objects using the segment 2 shadow display lists.

	Design Notes
		The floor, its normal and the water level come from the port's surface collision at the end of the frame. The vertices
		and a small display list that calls dl_shadow_circle, the vertex load, dl_shadow_9_verts or dl_shadow_4_verts and
		dl_shadow_end are written to the C stack of Memory for the duration of the draw (the lists reference them by address).
		Lava height corrections and flying carpet decals need their own surface handling.
]]

const Animation = require("../port/include/mario_animation_ids_h")
const DisplayList = require("./display_list")
const Recorder = require("../port/src/rom/render_recorder")
const Rom = require("../port/src/rom/rom")
const SurfaceCollision = require("../port/src/engine/surface_collision")
const SurfaceCollisionH = require("../port/src/engine/surface_collision_h")
const Segment2 = require("../port/src/rom/segment2_symbols")

const ShadowCircle9Verts = 0
const ShadowCircle4Verts = 1
const ShadowCirclePlayer = 99
const ShadowSquarePermanent = 10
const ShadowSquareScalable = 11
const ShadowSquareTogglable = 12
const ShadowSpindel = 50
const ShadowWhomp = 51
-- The first command of dl_shadow_9_verts (a triangle of vertices 0, 3, 4), to check the addresses
const NineVertsFirstWord = 0x00001E28
const WaterShadowSolidity = 200
const FarthestShadow = 600
const VertexBytes = 16
const ListBytes = 5 * 8
const TransparentDecalLayer = 6

const Floor: { SurfaceCollisionH.FloorGeometry? } = {}

const function LedgeOpacity(Shadow: Recorder.Shadow): number?
	if Shadow.Type ~= ShadowCirclePlayer then
		return nil
	end

	const Frame = Shadow.AnimationFrame

	if Shadow.Animation == Animation.MARIO_ANIM_IDLE_ON_LEDGE then
		return 0
	elseif Shadow.Animation == Animation.MARIO_ANIM_FAST_LEDGE_GRAB then
		return math.clamp((Frame - 5) / 9, 0, 1)
	elseif Shadow.Animation == Animation.MARIO_ANIM_SLOW_LEDGE_GRAB then
		return math.clamp((Frame - 21) / 12, 0, 1)
	elseif Shadow.Animation == Animation.MARIO_ANIM_CLIMB_DOWN_LEDGE then
		return 1 - math.clamp(Frame / 5, 0, 1)
	end

	return nil
end

const function Dim(Solidity: number, Distance: number): number
	if Solidity < 121 or Distance <= 0 then
		return Solidity
	elseif Distance >= FarthestShadow then
		return 120
	end

	return ((120 - Solidity) * Distance / FarthestShadow + Solidity) // 1
end

const function ScaleWithDistance(Scale: number, Distance: number): number
	if Distance <= 0 then
		return Scale
	elseif Distance >= FarthestShadow then
		return Scale * 0.5
	end

	return Scale * (1 - 0.5 * Distance / FarthestShadow)
end

const function WriteVertex(Address: number, X: number, Y: number, Z: number, S: number, T: number, Alpha: number)
	Rom.WriteS16(Address, X)
	Rom.WriteS16(Address + 2, Y)
	Rom.WriteS16(Address + 4, Z)
	Rom.WriteS16(Address + 6, 0)
	Rom.WriteS16(Address + 8, S * 32)
	Rom.WriteS16(Address + 10, T * 32)
	Rom.WriteU8(Address + 12, 255)
	Rom.WriteU8(Address + 13, 255)
	Rom.WriteU8(Address + 14, 255)
	Rom.WriteU8(Address + 15, Alpha)
end

-- Adds the shadow to the state's batches under the matrix ModelView (the shadow's vertices are relative to its position: a renderer that
-- puts the object in the world itself passes the identity); false when the game would not draw it (or the type is not supported)
const function Add(State: DisplayList.State, Shadow: Recorder.Shadow, ZBuffer: boolean, Projection: Recorder.Projection?, ModelView: { number }): boolean
	const Nine = Shadow.Type == ShadowCircle9Verts or Shadow.Type == ShadowCirclePlayer
	const Square = Shadow.Type == ShadowSquarePermanent or Shadow.Type == ShadowSquareScalable or Shadow.Type == ShadowSquareTogglable
	const Rectangle = Shadow.Type == ShadowSpindel or Shadow.Type == ShadowWhomp

	if not (Nine or Square or Rectangle or Shadow.Type == ShadowCircle4Verts) then
		return false
	end

	const Ledge = LedgeOpacity(Shadow)

	if Ledge == 0 then
		return false
	end

	const ParentX = Shadow.Position[1]
	const ParentY = Shadow.Position[2]
	const ParentZ = Shadow.Position[3]
	local FloorHeight = SurfaceCollision.find_floor_height_and_data(ParentX, ParentY, ParentZ, Floor)
	local NormalX = 0
	local NormalY = 1
	local NormalZ = 0
	local OriginOffset = 0
	const Geometry = Floor[1]
	local AboveWater = false

	const WaterLevel = SurfaceCollision.find_water_level(ParentX, ParentZ)

	if WaterLevel >= SurfaceCollisionH.FLOOR_LOWER_LIMIT_SHADOW and ParentY >= WaterLevel and FloorHeight <= WaterLevel then
		AboveWater = true
		FloorHeight = WaterLevel
		OriginOffset = -WaterLevel
	elseif FloorHeight < SurfaceCollisionH.FLOOR_LOWER_LIMIT_SHADOW or Geometry == nil or Geometry.normalY <= 0 then
		return false
	else
		NormalX = Geometry.normalX
		NormalY = Geometry.normalY
		NormalZ = Geometry.normalZ
		OriginOffset = Geometry.originOffset
	end

	const Distance = ParentY - FloorHeight
	const Flat = Square or Rectangle

	if Shadow.Type == ShadowSquareTogglable and Distance >= FarthestShadow then
		return false
	end

	const Solidity = if AboveWater then WaterShadowSolidity elseif Ledge ~= nil then (Shadow.Solidity * Ledge) // 1 elseif Flat then Shadow.Solidity else Dim(Shadow.Solidity, Distance)
	const Scale = if Shadow.Type == ShadowSquarePermanent or Shadow.Type == ShadowSquareTogglable then Shadow.Scale else ScaleWithDistance(Shadow.Scale, Distance)
	const Width = if Rectangle then ScaleWithDistance(if Shadow.Type == ShadowSpindel then 720 else 400, Distance) else Scale
	const Length = if Rectangle then ScaleWithDistance(if Shadow.Type == ShadowSpindel then 460 else 360, Distance) else Scale
	const Downward = if Flat then Shadow.Yaw * math.pi / 0x8000 else math.atan2(NormalX, NormalZ)
	const Steepness = math.sqrt(NormalX * NormalX + NormalZ * NormalZ)
	const Tilt = if Flat or Steepness == 0 then 0 else math.pi / 2 - math.atan2(NormalY, Steepness)
	const TiltedLength = math.cos(Tilt) * Length
	const Sin, Cos = math.sin(Downward), math.cos(Downward)
	const Count = if Nine then 9 else 4
	const Columns = if Nine then 3 else 2
	const Bytes = ListBytes + Count * VertexBytes
	const List = Rom.PushStack(Bytes)
	const Vertices = List + ListBytes

	for Index = 0, Count - 1 do
		local UnitX = Index % Columns - 1
		local UnitZ = Index // Columns - 1

		if not Nine then
			UnitX = if UnitX == 0 then 1 else UnitX
			UnitZ = if UnitZ == 0 then 1 else UnitZ
		end

		const Half = UnitX * Width / 2
		const HalfTilted = UnitZ * TiltedLength / 2
		const X = HalfTilted * Sin + Half * Cos + ParentX
		const Z = HalfTilted * Cos - Half * Sin + ParentZ
		const Extrapolated = if Flat then FloorHeight else -(NormalX * X + NormalZ * Z + OriginOffset) / NormalY
		local Y = Extrapolated
		local Alpha = Solidity

		if AboveWater then
			Y = FloorHeight
		elseif Nine then
			Y = SurfaceCollision.find_floor_height_and_data(X, ParentY, Z, {})

			-- A vertex over another floor triangle than the center: the game flattens it onto the plane and makes it clear
			const Tilted = (X - ParentX) * NormalX + (Y - FloorHeight) * NormalY + (Z - ParentZ) * NormalZ

			if Tilted >= 1 or Tilted <= -1 then
				Y = Extrapolated
				Alpha = 0
			end
		end

		const TextureX = if Nine then Index % 3 * 15 - 15 else Index % 2 * 30 - 15
		const TextureY = if Nine then Index // 3 * 15 - 15 else Index // 2 * 30 - 15

		WriteVertex(Vertices + Index * VertexBytes, math.round(X - ParentX), math.round(Y - ParentY), math.round(Z - ParentZ), TextureX, TextureY, Alpha)
	end

	Rom.WriteU32(List, 0x06000000)
	Rom.WriteU32(List + 4, if Flat then Segment2.dl_shadow_square else Segment2.dl_shadow_circle)
	Rom.WriteU32(List + 8, 0x04000000 + ((Count - 1) * 16) * 65536 + Count * VertexBytes)
	Rom.WriteU32(List + 12, Vertices)
	Rom.WriteU32(List + 16, 0x06000000)
	Rom.WriteU32(List + 20, if Nine then Segment2.dl_shadow_9_verts else Segment2.dl_shadow_4_verts)
	Rom.WriteU32(List + 24, 0x06000000)
	Rom.WriteU32(List + 28, Segment2.dl_shadow_end)
	Rom.WriteU32(List + 32, 0xB8000000)
	Rom.WriteU32(List + 36, 0)

	if Rom.ReadU32(Rom.SegmentedToVirtual(Segment2.dl_shadow_9_verts) + 4) ~= NineVertsFirstWord then
		error("segment 2 does not hold the shadow display lists at the expected addresses")
	end

	DisplayList.Draw(State, List, ModelView, TransparentDecalLayer, ZBuffer, Projection)
	Rom.PopStack(Bytes)

	return true
end

return Add
