--!strict

local Button = require(script.Parent.components.Button)
local AssetList = require(script.Parent.components.AssetList)
local AssetDefinition = require(script.Parent.Parent.core.AssetDefinition)

local ImportView = {}

export type Handle = {
	root: Frame,
}

function ImportView.create(importService: any, setStatus: (string, boolean?) -> ()): Handle
	local assets: {AssetDefinition.AssetDefinition} = {}

	local root = Instance.new("Frame")
	root.Name = "ImportView"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1

	local list = AssetList.create("Plugin-only Refab cannot scan local assets folders. Click Choose .rbxm Files to load files with Roblox Studio's file picker.")
	list.root.Position = UDim2.new(0, 0, 0, 0)
	list.root.Parent = root

	local controls = Instance.new("Frame")
	controls.Name = "Controls"
	controls.AnchorPoint = Vector2.new(0, 1)
	controls.Position = UDim2.new(0, 0, 1, 0)
	controls.Size = UDim2.new(1, 0, 0, 88)
	controls.BackgroundTransparency = 1
	controls.Parent = root

	local row = Instance.new("Frame")
	row.Name = "BulkActions"
	row.Size = UDim2.new(1, 0, 0, 34)
	row.BackgroundTransparency = 1
	row.Parent = controls

	local rowLayout = Instance.new("UIListLayout")
	rowLayout.FillDirection = Enum.FillDirection.Horizontal
	rowLayout.Padding = UDim.new(0, 8)
	rowLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rowLayout.Parent = row

	local chooseFilesButton = Button.create({ text = "Choose .rbxm Files", height = 32 })
	chooseFilesButton.Size = UDim2.new(0.34, -6, 0, 32)
	chooseFilesButton.Parent = row

	local selectAllButton = Button.create({ text = "Select All", height = 32 })
	selectAllButton.Size = UDim2.new(0.33, -6, 0, 32)
	selectAllButton.Parent = row

	local deselectAllButton = Button.create({ text = "Deselect All", height = 32 })
	deselectAllButton.Size = UDim2.new(0.33, -6, 0, 32)
	deselectAllButton.Parent = row

	local importButton = Button.create({ text = "IMPORT SELECTED", height = 42, accent = true })
	importButton.Position = UDim2.new(0, 0, 0, 44)
	importButton.Parent = controls

	local function render()
		list.render(assets)
	end

	chooseFilesButton.MouseButton1Click:Connect(function()
		assets = importService:promptForFiles()
		if #assets == 0 then
			setStatus("No .rbxm files selected.", true)
		else
			setStatus("Loaded " .. tostring(#assets) .. " file(s).")
		end
		render()
	end)

	selectAllButton.MouseButton1Click:Connect(function()
		for _, asset in assets do
			asset.selected = true
		end
		render()
	end)

	deselectAllButton.MouseButton1Click:Connect(function()
		for _, asset in assets do
			asset.selected = false
		end
		render()
	end)

	importButton.MouseButton1Click:Connect(function()
		local result = importService:importSelected(assets)
		setStatus(result.message, not result.ok)
	end)

	render()

	return {
		root = root,
	}
end

return ImportView
