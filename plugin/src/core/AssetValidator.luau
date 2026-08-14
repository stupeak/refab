--!strict

local AssetPathResolver = require(script.Parent.AssetPathResolver)

local AssetValidator = {}

function AssetValidator.validateExportInstance(instance: Instance): (boolean, string?)
	local root = AssetPathResolver.getSupportedRoot(instance)
	if not root then
		return false, "This asset is outside a supported root."
	end

	if instance == root then
		return false, "Root services are not assets."
	end

	if not instance.Archivable then
		return false, instance.Name .. " is not archivable."
	end

	return true, nil
end

return AssetValidator
