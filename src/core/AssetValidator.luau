--!strict

local Settings = require(script.Parent.Parent.config.Settings)
local AssetPathResolver = require(script.Parent.AssetPathResolver)

local AssetValidator = {}

function AssetValidator.validateExportInstance(instance: Instance): (boolean, string?)
	if not Settings.SupportedClasses[instance.ClassName] then
		return false, instance.ClassName .. " is not supported."
	end

	local root = AssetPathResolver.getSupportedRoot(instance)
	if not root then
		return false, "This asset is outside a supported root."
	end

	return true, nil
end

function AssetValidator.hasScripts(instance: Instance): boolean
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("LuaSourceContainer") then
			return true
		end
	end
	return false
end

return AssetValidator
