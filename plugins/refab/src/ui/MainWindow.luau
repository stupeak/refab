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
	_helperState: TextLabel,
	_helperProject: TextLabel,
	_helperAssets: TextLabel,
	_connectButton: TextButton,
	_connected: boolean,
	_refreshHelper: (() -> ())?,
}, MainWindow))

local function createTab(text: string): TextButton
	local tab = Button.create({ text = text, height = 28 })
	tab.Size = UDim2.new(0.5, -3, 0, 28)
	tab.BackgroundColor3 = Color3.fromRGB(232, 232, 232)
	tab.BorderColor3 = Color3.fromRGB(170, 170, 170)
	return tab
end

local function createLabel(text: string, size: number?, bold: boolean?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.TextColor3 = Color3.fromRGB(65, 65, 65)
	label.TextSize = size or 13
	label.Font = if bold then Enum.Font.SourceSansSemibold else Enum.Font.SourceSans
	label.TextTruncate = Enum.TextTruncate.AtEnd
	return label
end

function MainWindow.new(plugin: Plugin, exportService: any, importService: any, _projectSettings: any, helperClient: any): MainWindow
	local widgetInfo = DockWidgetPluginGuiInfo.new(
		Enum.InitialDockState.Right,
		false,
		false,
		420,
		640,
		340,
		500
	)

	local widget = plugin:CreateDockWidgetPluginGuiAsync(Settings.WidgetId, widgetInfo)
	local titleText = Settings.PluginName .. " v" .. Settings.PluginVersion
	widget.Title = titleText
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

	local helperFrame = Instance.new("Frame")
	helperFrame.Name = "HelperPanel"
	helperFrame.Position = UDim2.new(0, 0, 0, 0)
	helperFrame.Size = UDim2.new(1, 0, 0, 58)
	helperFrame.BackgroundColor3 = Color3.fromRGB(238, 238, 238)
	helperFrame.BorderColor3 = Color3.fromRGB(205, 205, 205)
	helperFrame.BorderSizePixel = 1
	helperFrame.Parent = root

	local helperPadding = Instance.new("UIPadding")
	helperPadding.PaddingTop = UDim.new(0, 6)
	helperPadding.PaddingBottom = UDim.new(0, 6)
	helperPadding.PaddingLeft = UDim.new(0, 8)
	helperPadding.PaddingRight = UDim.new(0, 8)
	helperPadding.Parent = helperFrame

	local helperState = createLabel("", 13, true)
	helperState.Position = UDim2.new(0, 0, 0, 0)
	helperState.Size = UDim2.new(1, -112, 0, 20)
	helperState.TextColor3 = Color3.fromRGB(90, 90, 90)
	helperState.Parent = helperFrame

	local connectButton = Button.create({ text = "Connect", height = 28, accent = true })
	connectButton.Position = UDim2.new(1, -104, 0, 0)
	connectButton.Size = UDim2.new(0, 104, 0, 28)
	connectButton.Parent = helperFrame

	local helperProject = createLabel("Project: -", 13, false)
	helperProject.Position = UDim2.new(0, 0, 0, 20)
	helperProject.Size = UDim2.new(1, -112, 0, 18)
	helperProject.Parent = helperFrame

	local helperAssets = createLabel("Assets: -", 13, false)
	helperAssets.Position = UDim2.new(1, -104, 0, 34)
	helperAssets.Size = UDim2.new(1, 0, 0, 18)
	helperAssets.TextXAlignment = Enum.TextXAlignment.Right
	helperAssets.Parent = helperFrame

	local tabs = Instance.new("Frame")
	tabs.Name = "Tabs"
	tabs.Position = UDim2.new(0, 0, 0, 66)
	tabs.Size = UDim2.new(1, 0, 0, 28)
	tabs.BackgroundTransparency = 1
	tabs.Parent = root

	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.Padding = UDim.new(0, 6)
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Parent = tabs

	local importTab = createTab("To Roblox")
	importTab.Parent = tabs

	local exportTab = createTab("To Local")
	exportTab.Parent = tabs

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Position = UDim2.new(0, 0, 0, 104)
	content.Size = UDim2.new(1, 0, 1, -144)
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
		_helperState = helperState,
		_helperProject = helperProject,
		_helperAssets = helperAssets,
		_connectButton = connectButton,
		_connected = false,
		_refreshHelper = nil,
	}, MainWindow)

	local function setStatus(message: string, isError: boolean?)
		status.Text = message
		status.TextColor3 = if isError then Color3.fromRGB(196, 43, 28) else Color3.fromRGB(85, 85, 85)
	end

	local function refreshHelper()
		local helperStatus = helperClient:getStatus()
		if helperStatus.ok then
			self._connected = true
			helperState.Text = titleText
			helperState.TextColor3 = Color3.fromRGB(20, 130, 70)
			helperProject.Text = "Project: " .. tostring(helperStatus.projectRoot or "-")
			helperAssets.Text = "Assets: " .. tostring(helperStatus.assetCount or 0)
			connectButton.Text = "Disconnect"
			connectButton.BackgroundColor3 = Color3.fromRGB(225, 225, 225)
			connectButton.BorderColor3 = Color3.fromRGB(150, 150, 150)
			connectButton.TextColor3 = Color3.fromRGB(35, 35, 35)
			setStatus("Connected to Refab helper.")
		else
			self._connected = false
			helperState.Text = titleText
			helperState.TextColor3 = Color3.fromRGB(196, 43, 28)
			helperProject.Text = "Project: -"
			helperAssets.Text = "Offline"
			connectButton.Text = "Connect"
			connectButton.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
			connectButton.BorderColor3 = Color3.fromRGB(0, 100, 185)
			connectButton.TextColor3 = Color3.fromRGB(255, 255, 255)
			setStatus("Run: cargo run --manifest-path cli/Cargo.toml -- serve", true)
		end
	end

	self._refreshHelper = refreshHelper
	connectButton.MouseButton1Click:Connect(function()
		if self._connected then
			self._connected = false
			helperState.Text = titleText
			helperState.TextColor3 = Color3.fromRGB(90, 90, 90)
			helperProject.Text = "Project: -"
			helperAssets.Text = "Disconnected"
			connectButton.Text = "Connect"
			connectButton.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
			connectButton.BorderColor3 = Color3.fromRGB(0, 100, 185)
			connectButton.TextColor3 = Color3.fromRGB(255, 255, 255)
			setStatus("Disconnected from helper.")
			return
		end

		refreshHelper()
	end)

	self._exportView = ExportView.create(exportService, setStatus)
	self._exportView.root.Parent = content

	self._importView = ImportView.create(importService, setStatus)
	self._importView.root.Parent = content

	exportTab.MouseButton1Click:Connect(function()
		self:setMode("Export")
	end)

	importTab.MouseButton1Click:Connect(function()
		self:setMode("Import")
	end)

	refreshHelper()
	self:setMode("Import")
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

	self._exportTab.BackgroundColor3 = if showingExport then Color3.fromRGB(0, 120, 215) else Color3.fromRGB(232, 232, 232)
	self._exportTab.BorderColor3 = if showingExport then Color3.fromRGB(0, 100, 185) else Color3.fromRGB(170, 170, 170)
	self._exportTab.TextColor3 = if showingExport then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(35, 35, 35)
	self._importTab.BackgroundColor3 = if showingExport then Color3.fromRGB(232, 232, 232) else Color3.fromRGB(0, 120, 215)
	self._importTab.BorderColor3 = if showingExport then Color3.fromRGB(170, 170, 170) else Color3.fromRGB(0, 100, 185)
	self._importTab.TextColor3 = if showingExport then Color3.fromRGB(35, 35, 35) else Color3.fromRGB(255, 255, 255)
end

function MainWindow:setEnabled(enabled: boolean)
	self._widget.Enabled = enabled
	if enabled and self._refreshHelper then
		self._refreshHelper()
	end
end

function MainWindow:isEnabled(): boolean
	return self._widget.Enabled
end

return MainWindow
