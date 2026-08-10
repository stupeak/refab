--!strict

local ExportService = require(script.Parent.Parent.export.ExportService)
local ImportService = require(script.Parent.Parent.import.ImportService)
local MainWindow = require(script.Parent.Parent.ui.MainWindow)
local Settings = require(script.Parent.Parent.config.Settings)

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

	local exportService = ExportService.new(self._plugin)
	local importService = ImportService.new()
	self._window = MainWindow.new(self._plugin, exportService, importService)
	self._window:setEnabled(false)

	button.Click:Connect(function()
		if self._window then
			self._window:setEnabled(not self._window:isEnabled())
		end
	end)
end

return PluginController
