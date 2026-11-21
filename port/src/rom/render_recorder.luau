--!strict
--!optimize 2

--[[
	Render recorder: what the geo traversal hands to the RCP in one frame, kept for the renderer (render/).

	Paradigm
		The traversal ports drop the gSP/gDP calls (gfx-display-lists-noop); the data those calls carry is still built: the master
		list of display lists per layer, the Mtx of each (N64 fixed point, 16 s32 words), the projection parameters, the viewport of
		the root node. Begin turns recording on, End returns the Frame and turns it off; a hook in the traversal costs one boolean
		test while disabled and never changes game state.

	Owned State
		Enabled and the Frame being recorded; the projection the last perspective or ortho node set, which a master list reads.

	Design Notes
		A Draw's DisplayList is the segmented address the geo layout holds (a number), or the table of a runtime generated list
		(a callback node), which the renderer does not decode yet. Matrix is the table the traversal made for the node (not copied).
]]

const GroupsTypesHPlus3 = require("../../groups/types_h_plus3")

export type Draw = { Layer: number, DisplayList: unknown, Matrix: { unknown } }

export type Projection = { Perspective: boolean, Fov: number, Near: number, Far: number, Scale: number, Matrix: { number }? }

-- The shadow of an object, from the position and scale geo_process_shadow settles on; ModelView is the camera matrix moved to the
-- shadow position (16 numbers, row major)
export type Shadow = {
	Position: { number },
	Scale: number,
	Solidity: number,
	Type: number,
	Yaw: number,
	Animation: number,
	AnimationFrame: number,
	ModelView: { number },
}

-- One master list: the draws of its layers in the order the RCP runs them, then the shadows below its objects
-- View is the camera matrix of the pass (16 numbers, row major, row vectors: the world to the view space), nil when no camera node is under it
export type Pass = { ZBuffer: boolean, Projection: Projection?, View: { number }?, Draws: { Draw }, Shadows: { Shadow } }

-- A skybox or fill color node; Camera is the position and focus the skybox follows
export type Background = { Fill: number, Skybox: number?, Position: { number }, Focus: { number }, Fov: number }

-- The root node's screen area: center and half size in pixels
export type Viewport = { X: number, Y: number, HalfWidth: number, HalfHeight: number }

-- The commands the game wrote into the Gfx pool outside the geo traversal (the HUD, text, menus, transitions): Start up to End, Memory addresses
export type Overlay = { Start: number, End: number }

export type Frame = { Viewport: Viewport?, Passes: { Pass }, Backgrounds: { Background }, Overlay: Overlay? }

const Recorder = {
	Enabled = false,
	Frame = { Passes = {}, Backgrounds = {} } :: Frame,
}

local CurrentProjection: Projection? = nil
local CurrentView: { number }? = nil
local PendingShadows: { Shadow } = {}

function Recorder.Begin()
	Recorder.Frame = { Passes = {}, Backgrounds = {} }
	Recorder.Enabled = true
	CurrentProjection = nil
	CurrentView = nil
	PendingShadows = {}
end

function Recorder.End(): Frame
	Recorder.Enabled = false

	return Recorder.Frame
end

function Recorder.Root(Node: GroupsTypesHPlus3.GraphNodeRoot)
	Recorder.Frame.Viewport = { X = Node.x, Y = Node.y, HalfWidth = Node.width, HalfHeight = Node.height }
end

function Recorder.Overlay(Start: number, End: number)
	Recorder.Frame.Overlay = { Start = Start, End = End }
end

-- The camera node's matrix (4 rows): the draws of the master list the node is under are in the view space it makes
function Recorder.Camera(Matrix: { { number } })
	const View = table.create(16, 0)

	for Row = 1, 4 do
		for Column = 1, 4 do
			View[(Row - 1) * 4 + Column] = Matrix[Row][Column]
		end
	end

	CurrentView = View
end

function Recorder.Perspective(Node: GroupsTypesHPlus3.GraphNodePerspective)
	CurrentProjection = { Perspective = true, Fov = Node.fov, Near = Node.near, Far = Node.far, Scale = 1 }
end

function Recorder.Ortho(Node: GroupsTypesHPlus3.GraphNodeOrthoProjection)
	CurrentProjection = { Perspective = false, Fov = 0, Near = 0, Far = 100, Scale = Node.scale }
end

function Recorder.MasterList(Node: GroupsTypesHPlus3.GraphNodeMasterList)
	const Draws: { Draw } = {}

	for Layer = 0, GroupsTypesHPlus3.GFX_NUM_MASTER_LISTS - 1 do
		local Entry = Node.listHeads[Layer + 1]

		while Entry ~= nil do
			table.insert(Draws, { Layer = Layer, DisplayList = Entry.displayList, Matrix = Entry.transform :: { unknown } })
			Entry = Entry.next
		end
	end

	table.insert(Recorder.Frame.Passes, {
		ZBuffer = bit32.btest(Node.node.flags, GroupsTypesHPlus3.GRAPH_RENDER_Z_BUFFER),
		Projection = CurrentProjection,
		View = CurrentView,
		Draws = Draws,
		Shadows = PendingShadows,
	})
	PendingShadows = {}
	CurrentView = nil
end

-- Camera is the camera node's matrix (4 rows); the shadow is drawn under the object at Position with the node's solidity and type
function Recorder.Shadow(Node: GroupsTypesHPlus3.GraphNodeShadow, Object: GroupsTypesHPlus3.GraphNodeObject, Position: { number }, Scale: number, Camera: { { number } })
	const ModelView = table.create(16, 0)

	for Row = 1, 3 do
		for Column = 1, 4 do
			ModelView[(Row - 1) * 4 + Column] = Camera[Row][Column]
		end
	end

	for Column = 1, 4 do
		ModelView[12 + Column] = Camera[4][Column] + Position[1] * Camera[1][Column] + Position[2] * Camera[2][Column] + Position[3] * Camera[3][Column]
	end

	table.insert(PendingShadows, {
		Position = Position,
		Scale = Scale,
		Solidity = Node.shadowSolidity,
		Type = Node.shadowType,
		Yaw = Object.angle[2],
		Animation = Object.animInfo.animID,
		AnimationFrame = Object.animInfo.animFrame,
		ModelView = ModelView,
	})
end

-- Fill is the background color word, Skybox the skybox of a callback node (nil for a plain color); Camera is the area's first view
function Recorder.Background(Node: GroupsTypesHPlus3.GraphNodeBackground, Camera: GroupsTypesHPlus3.GraphNodeCamera?)
	const Perspective = if Camera then Camera.parent :: GroupsTypesHPlus3.GraphNodePerspective? else nil

	table.insert(Recorder.Frame.Backgrounds, {
		Fill = Node.background,
		Skybox = if Node.func ~= nil then Node.background else nil,
		Position = if Camera then { Camera.pos[1], Camera.pos[2], Camera.pos[3] } else { 0, 0, 0 },
		Focus = if Camera then { Camera.focus[1], Camera.focus[2], Camera.focus[3] } else { 0, 0, 1 },
		Fov = if Perspective then Perspective.fov else 45,
	})
end

return Recorder
