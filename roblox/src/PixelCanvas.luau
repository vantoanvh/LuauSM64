--!strict
--!optimize 2

--[[
	A small square picture painted pixel by pixel, for the pixel art of the interface (roblox/src/TouchSprites, roblox/src/LoadingScreen):
	New gives a clear canvas, Put sets a pixel, Finish makes the picture an EditableImage, to show with ResampleMode Pixelated so each
	pixel stays a square at any size. The picture's owner keeps it alive for as long as it is shown.
]]

const AssetService = game:GetService("AssetService")

export type Canvas = { Size: number, Pixels: buffer }

-- A finished picture: its Content, to show on an image, and the EditableImage behind it
export type Picture = { Content: Content, Image: EditableImage }

-- A clear canvas of Size x Size pixels
const function New(Size: number): Canvas
	return { Size = Size, Pixels = buffer.create(Size * Size * 4) }
end

-- Sets the pixel (X, Y) (zero based) to a color and an alpha from 0 to 255
const function Put(Self: Canvas, X: number, Y: number, Color: Color3, Alpha: number)
	const Offset = (Y * Self.Size + X) * 4

	buffer.writeu8(Self.Pixels, Offset, math.round(Color.R * 255))
	buffer.writeu8(Self.Pixels, Offset + 1, math.round(Color.G * 255))
	buffer.writeu8(Self.Pixels, Offset + 2, math.round(Color.B * 255))
	buffer.writeu8(Self.Pixels, Offset + 3, Alpha)
end

-- The picture of the canvas
const function Finish(Self: Canvas): Picture
	const Image = AssetService:CreateEditableImage({ Size = Vector2.new(Self.Size, Self.Size) })

	Image:WritePixelsBuffer(Vector2.zero, Vector2.new(Self.Size, Self.Size), Self.Pixels)

	return { Content = Content.fromObject(Image), Image = Image }
end

return { New = New, Put = Put, Finish = Finish }
