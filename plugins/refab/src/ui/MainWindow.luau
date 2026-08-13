--!strict

local ExportView = require(script.Parent.ExportView)
local ImportView = require(script.Parent.ImportView)
local Button = require(script.Parent.components.Button)
local Settings = require(script.Parent.Parent.config.Settings)

local MainWindow = {}
MainWindow.__index = MainWindow

export type MainWindow = typeof(setmetatable({} :: {
	_widget: DockWidgetPluginGui,
	_exportView: ExportView.Handle?,
	_importView: ImportView.Handle?,
	_content: Frame,
	_status: TextLabel,
	_exportTab: TextButton,
	_importTab: TextButton,
	_projectRootBox: TextBox,
	_assetsFolderBox: TextBox,
}, MainWindow))

local function createTab(text: string): TextButton
	local tab = Button.create({ text = text, height = 34 })
	tab.Size = UDim2.new(0.5, -4, 0, 34)
	return tab
end

local function createLabel(text: string): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(65, 65, 65)
	label.TextSize = 13
	label.Font = Enum.Font.SourceSans
	return label
end

local function createTextBox(placeholder: string): TextBox
	local box = Instance.new("TextBox")
	box.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	box.BorderColor3 = Color3.fromRGB(190, 190, 190)
	box.BorderSizePixel = 1
	box.ClearTextOnFocus = false
	box.Font = Enum.Font.SourceSans
	box.PlaceholderText = placeholder
	box.Text = ""
	box.TextColor3 = Color3.fromRGB(35, 35, 35)
	box.PlaceholderColor3 = Color3.fromRGB(120, 120, 120)
	box.TextSize = 14
	box.TextXAlignment = Enum.TextXAlignment.Left
	return box
end

function MainWindow.new(plugin: Plugin, exportService: any, importService: any, projectSettings: any): MainWindow
	local widgetInfo = DockWidgetPluginGuiInfo.new(
		Enum.InitialDockState.Right,
		false,
		false,
		380,
		620,
		320,
		460
	)

	local widget = plugin:CreateDockWidgetPluginGuiAsync(Settings.WidgetId, widgetInfo)
	widget.Title = Settings.PluginName
	widget.Name = Settings.WidgetId

	local root = Instance.new("Frame")
	root.Name = "Root"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundColor3 = Color3.fromRGB(245, 245, 245)
	root.BorderSizePixel = 0
	root.Parent = widget

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = root

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 28)
	title.BackgroundTransparency = 1
	title.Text = Settings.PluginName
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextColor3 = Color3.fromRGB(35, 35, 35)
	title.TextSize = 22
	title.Font = Enum.Font.SourceSansBold
	title.Parent = root

	local projectConfig = projectSettings:get()

	local projectFrame = Instance.new("Frame")
	projectFrame.Name = "ProjectSettings"
	projectFrame.Position = UDim2.new(0, 0, 0, 36)
	projectFrame.Size = UDim2.new(1, 0, 0, 104)
	projectFrame.BackgroundColor3 = Color3.fromRGB(238, 238, 238)
	projectFrame.BorderColor3 = Color3.fromRGB(205, 205, 205)
	projectFrame.BorderSizePixel = 1
	projectFrame.Parent = root

	local projectPadding = Instance.new("UIPadding")
	projectPadding.PaddingTop = UDim.new(0, 8)
	projectPadding.PaddingBottom = UDim.new(0, 8)
	projectPadding.PaddingLeft = UDim.new(0, 8)
	projectPadding.PaddingRight = UDim.new(0, 8)
	projectPadding.Parent = projectFrame

	local projectLabel = createLabel("Project Root")
	projectLabel.Position = UDim2.new(0, 0, 0, 0)
	projectLabel.Size = UDim2.new(1, 0, 0, 16)
	projectLabel.Parent = projectFrame

	local projectRootBox = createTextBox("C:/Roblox Projects/my-game")
	projectRootBox.Position = UDim2.new(0, 0, 0, 18)
	projectRootBox.Size = UDim2.new(1, -168, 0, 28)
	projectRootBox.Text = projectConfig.projectRoot
	projectRootBox.Parent = projectFrame

	local saveProjectButton = Button.create({ text = "Save", height = 28, accent = true })
	saveProjectButton.Position = UDim2.new(1, -160, 0, 18)
	saveProjectButton.Size = UDim2.new(0, 76, 0, 28)
	saveProjectButton.Parent = projectFrame

	local clearProjectButton = Button.create({ text = "Clear", height = 28 })
	clearProjectButton.Position = UDim2.new(1, -76, 0, 18)
	clearProjectButton.Size = UDim2.new(0, 76, 0, 28)
	clearProjectButton.Parent = projectFrame

	local assetsLabel = createLabel("Assets Folder")
	assetsLabel.Position = UDim2.new(0, 0, 0, 50)
	assetsLabel.Size = UDim2.new(1, 0, 0, 16)
	assetsLabel.Parent = projectFrame

	local assetsFolderBox = createTextBox("assets")
	assetsFolderBox.Position = UDim2.new(0, 0, 0, 66)
	assetsFolderBox.Size = UDim2.new(1, 0, 0, 28)
	assetsFolderBox.Text = projectConfig.assetsFolder
	assetsFolderBox.Parent = projectFrame

	local tabs = Instance.new("Frame")
	tabs.Name = "Tabs"
	tabs.Position = UDim2.new(0, 0, 0, 152)
	tabs.Size = UDim2.new(1, 0, 0, 34)
	tabs.BackgroundTransparency = 1
	tabs.Parent = root

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 8)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabs

	local exportTab = createTab("EXPORT")
	exportTab.Parent = tabs

	local importTab = createTab("IMPORT")
	importTab.Parent = tabs

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Position = UDim2.new(0, 0, 0, 198)
	content.Size = UDim2.new(1, 0, 1, -238)
	content.BackgroundTransparency = 1
	content.Parent = root

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.AnchorPoint = Vector2.new(0, 1)
	status.Position = UDim2.new(0, 0, 1, 0)
	status.Size = UDim2.new(1, 0, 0, 32)
	status.BackgroundTransparency = 1
	status.Text = "Ready."
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextYAlignment = Enum.TextYAlignment.Center
	status.TextWrapped = true
	status.TextColor3 = Color3.fromRGB(85, 85, 85)
	status.TextSize = 14
	status.Font = Enum.Font.SourceSans
	status.Parent = root

	local self = setmetatable({
		_widget = widget,
		_exportView = nil,
		_importView = nil,
		_content = content,
		_status = status,
		_exportTab = exportTab,
		_importTab = importTab,
		_projectRootBox = projectRootBox,
		_assetsFolderBox = assetsFolderBox,
	}, MainWindow)

	local function setStatus(message: string, isError: boolean?)
		status.Text = message
		status.TextColor3 = if isError then Color3.fromRGB(196, 43, 28) else Color3.fromRGB(85, 85, 85)
	end

	self._exportView = ExportView.create(exportService, setStatus)
	self._exportView.root.Parent = content

	self._importView = ImportView.create(importService, setStatus)
	self._importView.root.Parent = content

	saveProjectButton.MouseButton1Click:Connect(function()
		local saved = projectSettings:save(projectRootBox.Text, assetsFolderBox.Text)
		projectRootBox.Text = saved.projectRoot
		assetsFolderBox.Text = saved.assetsFolder
		setStatus("Saved Refab project root for this place.")
		if self._exportView then
			self._exportView.refresh()
		end
	end)

	clearProjectButton.MouseButton1Click:Connect(function()
		local saved = projectSettings:save("", assetsFolderBox.Text)
		projectRootBox.Text = saved.projectRoot
		assetsFolderBox.Text = saved.assetsFolder
		setStatus("Cleared Refab project root for this place.")
		if self._exportView then
			self._exportView.refresh()
		end
	end)

	exportTab.MouseButton1Click:Connect(function()
		self:setMode("Export")
	end)

	importTab.MouseButton1Click:Connect(function()
		self:setMode("Import")
	end)

	self:setMode("Export")
	return self
end

function MainWindow:setMode(mode: "Export" | "Import")
	local showingExport = mode == "Export"
	if self._exportView then
		self._exportView.root.Visible = showingExport
		if showingExport then
			self._exportView.refresh()
		end
	end
	if self._importView then
		self._importView.root.Visible = not showingExport
	end

	self._exportTab.BackgroundColor3 = if showingExport then Color3.fromRGB(0, 120, 215) else Color3.fromRGB(242, 242, 242)
	self._exportTab.TextColor3 = if showingExport then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(35, 35, 35)
	self._importTab.BackgroundColor3 = if showingExport then Color3.fromRGB(242, 242, 242) else Color3.fromRGB(0, 120, 215)
	self._importTab.TextColor3 = if showingExport then Color3.fromRGB(35, 35, 35) else Color3.fromRGB(255, 255, 255)
end

function MainWindow:setEnabled(enabled: boolean)
	self._widget.Enabled = enabled
end

function MainWindow:isEnabled(): boolean
	return self._widget.Enabled
end

return MainWindow
