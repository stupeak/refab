--!strict

local root = script.Parent.Parent

local ExportService = require(root:WaitForChild("export"):WaitForChild("ExportService"))
local HelperClient = require(root:WaitForChild("core"):WaitForChild("HelperClient"))
local ImportService = require(root:WaitForChild("import"):WaitForChild("ImportService"))
local MainWindow = require(root:WaitForChild("ui"):WaitForChild("MainWindow"))
local ProjectSettings = require(root:WaitForChild("core"):WaitForChild("ProjectSettings"))
local Settings = require(root:WaitForChild("config"):WaitForChild("Settings"))

local PluginController = {}
PluginController.__index = PluginController

export type PluginController = typeof(setmetatable({} :: {
	_plugin: Plugin,
	_button: PluginToolbarButton?,
	_window: MainWindow.MainWindow?,
}, PluginController))

function PluginController.new(plugin: Plugin): PluginController
	return setmetatable({
		_plugin = plugin,
		_button = nil,
		_window = nil,
	}, PluginController)
end

function PluginController:start()
	local toolbar = self._plugin:CreateToolbar(Settings.ToolbarName)
	local button = toolbar:CreateButton("RefabButton", Settings.ButtonTooltip, "", Settings.ButtonText)
	button.ClickableWhenViewportHidden = true
	self._button = button

	local projectSettings = ProjectSettings.new(self._plugin)
	projectSettings:load()
	local helperClient = HelperClient.new()

	local exportService = ExportService.new(self._plugin, projectSettings, helperClient)
	local importService = ImportService.new(helperClient)
	self._window = MainWindow.new(self._plugin, exportService, importService, projectSettings, helperClient)
	self._window:setEnabled(false)

	button.Click:Connect(function()
		if self._window then
			self._window:setEnabled(not self._window:isEnabled())
		end
	end)
end

return PluginController
