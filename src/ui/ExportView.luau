--!strict

local Button = require(script.Parent.components.Button)
local AssetList = require(script.Parent.components.AssetList)
local AssetDefinition = require(script.Parent.Parent.core.AssetDefinition)

local ExportView = {}

export type Handle = {
	root: Frame,
	refresh: () -> (),
}

function ExportView.create(exportService: any, setStatus: (string, boolean?) -> ()): Handle
	local assets: {AssetDefinition.AssetDefinition} = {}

	local root = Instance.new("Frame")
	root.Name = "ExportView"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1

	local list = AssetList.create()
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

	local refreshButton = Button.create({ text = "Refresh", height = 32 })
	refreshButton.Size = UDim2.new(0.34, -6, 0, 32)
	refreshButton.Parent = row

	local selectAllButton = Button.create({ text = "Select All", height = 32 })
	selectAllButton.Size = UDim2.new(0.33, -6, 0, 32)
	selectAllButton.Parent = row

	local deselectAllButton = Button.create({ text = "Deselect All", height = 32 })
	deselectAllButton.Size = UDim2.new(0.33, -6, 0, 32)
	deselectAllButton.Parent = row

	local exportButton = Button.create({ text = "EXPORT SELECTED", height = 42, accent = true })
	exportButton.Position = UDim2.new(0, 0, 0, 44)
	exportButton.Parent = controls

	local function render()
		list.render(assets)
	end

	local function refresh()
		assets = exportService:getSelectionAssets()
		if #assets == 0 then
			setStatus("No supported assets selected.", true)
		else
			setStatus("Loaded " .. tostring(#assets) .. " selected item(s).")
		end
		render()
	end

	refreshButton.MouseButton1Click:Connect(refresh)

	selectAllButton.MouseButton1Click:Connect(function()
		for _, asset in assets do
			if asset.status ~= "Error" then
				asset.selected = true
			end
		end
		render()
	end)

	deselectAllButton.MouseButton1Click:Connect(function()
		for _, asset in assets do
			asset.selected = false
		end
		render()
	end)

	exportButton.MouseButton1Click:Connect(function()
		local result = exportService:exportSelected(assets)
		setStatus(result.message, not result.ok)
	end)

	refresh()

	return {
		root = root,
		refresh = refresh,
	}
end

return ExportView
