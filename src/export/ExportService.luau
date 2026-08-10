--!strict

local Selection = game:GetService("Selection")

local AssetDefinition = require(script.Parent.Parent.core.AssetDefinition)
local AssetPathResolver = require(script.Parent.Parent.core.AssetPathResolver)
local AssetValidator = require(script.Parent.Parent.core.AssetValidator)

export type ExportResult = {
	ok: boolean,
	message: string,
	count: number,
}

local ExportService = {}
ExportService.__index = ExportService

function ExportService.new(plugin: Plugin)
	return setmetatable({
		_plugin = plugin,
	}, ExportService)
end

function ExportService:getSelectionAssets(): {AssetDefinition.AssetDefinition}
	local assets = {}

	for _, instance in Selection:Get() do
		local ok, validationMessage = AssetValidator.validateExportInstance(instance)
		local resolved, assetPath, parentPathOrMessage = AssetPathResolver.instanceToAssetPath(instance)

		if ok and resolved and assetPath and parentPathOrMessage then
			local asset = AssetDefinition.fromInstance(instance, assetPath, parentPathOrMessage)
			if AssetValidator.hasScripts(instance) then
				asset.status = "Warning"
				asset.message = "Contains scripts. Refab is intended for assets managed outside Rojo code."
			end
			table.insert(assets, asset)
		else
			table.insert(assets, {
				id = instance:GetDebugId(0),
				name = instance.Name,
				className = instance.ClassName,
				instance = instance,
				assetPath = "",
				parentPath = "",
				selected = false,
				status = "Error",
				message = validationMessage or parentPathOrMessage or "Unsupported asset.",
				sourceFile = nil,
			})
		end
	end

	return assets
end

function ExportService:exportSelected(assets: {AssetDefinition.AssetDefinition}): ExportResult
	local exported = 0

	for _, asset in assets do
		if asset.selected and asset.instance and asset.status ~= "Error" then
			local previousSelection = Selection:Get()
			Selection:Set({ asset.instance })

			local suggestedFileName = asset.assetPath
			local ok, result = pcall(function()
				return self._plugin:PromptSaveSelectionAsync(suggestedFileName)
			end)

			Selection:Set(previousSelection)

			if not ok then
				return {
					ok = false,
					message = "Failed to export " .. asset.name .. ": " .. tostring(result),
					count = exported,
				}
			end

			if result then
				exported += 1
			end
		end
	end

	if exported == 0 then
		return {
			ok = false,
			message = "No assets were exported.",
			count = 0,
		}
	end

	return {
		ok = true,
		message = "Exported " .. tostring(exported) .. " asset(s).",
		count = exported,
	}
end

return ExportService
