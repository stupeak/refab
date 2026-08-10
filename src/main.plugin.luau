--!strict

print("REFAB PLUGIN BOOT")

local function start()
	local core = script:WaitForChild("core")
	local PluginController = require(core:WaitForChild("PluginController"))

	local controller = PluginController.new(plugin)
	controller:start()
end

local ok, message = xpcall(start, debug.traceback)
if not ok then
	warn("REFAB PLUGIN FAILED TO START")
	warn(message)
end
