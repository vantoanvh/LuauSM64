--!strict
--!optimize 2

--[[
	The product of the decoder, which every presenter consumes: the triangles of one frame as batches of vertices with the state
	they were drawn with.

	Paradigm
		A Batch is one mesh drawn with one state: vertex arrays (flat, 3 / 4 / 2 numbers per vertex), triangle indices into them
		(3 per triangle, 1-based) and the texture, combiner, blending, depth and culling the RDP had. Positions are view space
		(after the modelview matrix, before the projection, the camera at the origin looking down -Z); colors are the lit vertex
		colors 0..255 and alpha; UVs are texels of the tile (the texture sampler wraps and clamps them). Batches come in draw order.
]]

const Matrix = require("./matrix")
const Texture = require("./texture")

-- A light of the RSP: color, and the direction (signed bytes) in view space
export type Light = { R: number, G: number, B: number, X: number, Y: number, Z: number }

-- The lights a lit vertex was lit with: the ambient light and the directional ones
export type LightSet = { Ambient: Light?, Directional: { Light } }

-- The perspective or orthographic projection of a master list (Scale of an orthographic one is the node's scale); one with a Matrix is the
-- 2D picture of the game on the whole 320x240 screen, whose Matrix is the projection matrix the game loaded
export type Projection = { Perspective: boolean, Fov: number, Near: number, Far: number, Scale: number, Matrix: Matrix.Matrix? }

export type Batch = {
	Layer: number,
	Projection: Projection?,
	Texture: Texture.Texture?,
	-- Texture addressing per axis: Mask is log2 of the wrap size (0: the texture size); the texture mirrors or clamps instead of repeating
	MaskS: number,
	MaskT: number,
	MirrorS: boolean,
	MirrorT: boolean,
	ClampS: boolean,
	ClampT: boolean,
	-- The three point filter (G_TF_BILERP/AVERAGE) or the nearest texel
	Filtered: boolean,
	-- G_SETCOMBINE words a0 b0 c0 d0 (color) Aa0 Ab0 Ac0 Ad0 (alpha), then the same for the second cycle
	Combine: { number },
	TwoCycle: boolean,
	EnvColor: { number },
	PrimColor: { number },
	FogColor: { number },
	FogMultiplier: number,
	FogOffset: number,
	Fog: boolean,
	-- Blend: the color blends with the framebuffer by its alpha; Cutout: alpha below one half drops the pixel
	Translucent: boolean,
	Cutout: boolean,
	DepthCompare: boolean,
	DepthUpdate: boolean,
	Decal: boolean,
	CullBack: boolean,
	CullFront: boolean,
	Positions: { number },
	Colors: { number },
	-- Normals (3 per vertex, the signed bytes over 127) and the lights of the lit vertices of a relight decode (display_list State.Relight);
	-- the others have none
	Normals: { number },
	Lights: { [number]: LightSet },
	UVs: { number },
	Indices: { number },
	VertexCount: number,
}

export type Background = { Fill: number, Skybox: number?, Position: { number }, Focus: { number }, Fov: number }

-- The center and half size in pixels of the area on the screen
export type Viewport = { X: number, Y: number, HalfWidth: number, HalfHeight: number }

export type Scene = {
	Viewport: Viewport,
	-- The framebuffer color before the batches (a plain color background), 0..255
	ClearColor: { number },
	Backgrounds: { Background },
	Batches: { Batch },
	-- Counters of the decode: commands run, triangles, display lists of runtime generated nodes skipped, shadows not drawn, opcodes not handled
	Stats: { Commands: number, Triangles: number, Generated: number, Skipped: number, Unhandled: { [number]: number } },
}

const function New(Viewport: Viewport): Scene
	return {
		Viewport = Viewport,
		ClearColor = { 0, 0, 0 },
		Backgrounds = {},
		Batches = {},
		Stats = { Commands = 0, Triangles = 0, Generated = 0, Skipped = 0, Unhandled = {} },
	}
end

-- The matrix of a master list's projection for an aspect ratio
const function ProjectionMatrix(Projection: Projection, Aspect: number): Matrix.Matrix
	if Projection.Matrix ~= nil then
		return Projection.Matrix
	end

	if Projection.Perspective then
		return Matrix.Perspective(Projection.Fov, Aspect, Projection.Near, Projection.Far)
	end

	const HalfWidth = 160 * Projection.Scale
	const HalfHeight = 120 * Projection.Scale

	return Matrix.Ortho(-HalfWidth, HalfWidth, -HalfHeight, HalfHeight, Projection.Near, Projection.Far)
end

return { New = New, ProjectionMatrix = ProjectionMatrix }
