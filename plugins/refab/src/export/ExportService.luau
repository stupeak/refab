--!strict

local Selection = game:GetService("Selection")
local SerializationService = game:GetService("SerializationService")
local Workspace = game:GetService("Workspace")

local AssetDefinition = require(script.Parent.Parent.core.AssetDefinition)
local AssetRegistry = require(script.Parent.Parent.core.AssetRegistry)
local AssetPathResolver = require(script.Parent.Parent.core.AssetPathResolver)
local AssetValidator = require(script.Parent.Parent.core.AssetValidator)

export type ExportResult = {
	ok: boolean,
	message: string,
	count: number,
}

export type SerializeProbeResult = {
	ok: boolean,
	message: string,
	byteCount: number,
	stringByteCount: number,
	canConvertToString: boolean,
	valueType: string,
	previewHex: string,
	previewText: string,
}

export type RoundtripProbeResult = {
	ok: boolean,
	message: string,
	serializedByteCount: number,
	deserializedCount: number,
	names: string,
}

local ExportService = {}
ExportService.__index = ExportService

function ExportService.new(plugin: Plugin, projectSettings: any)
	return setmetatable({
		_plugin = plugin,
		_projectSettings = projectSettings,
	}, ExportService)
end

function ExportService:getSelectionAssets(): {AssetDefinition.AssetDefinition}
	local assets = {}

	for _, instance in Selection:Get() do
		local ok, validationMessage = AssetValidator.validateExportInstance(instance)
		local resolved, assetPath, parentPathOrMessage = AssetPathResolver.instanceToAssetPath(instance)

		if ok and resolved and assetPath and parentPathOrMessage then
			local assetId = AssetRegistry.getAssetId(instance)
			local fullPath = self._projectSettings:resolveAssetPath(assetPath)
			local asset = AssetDefinition.fromInstance(instance, assetPath, parentPathOrMessage, fullPath, assetId)
			table.insert(assets, asset)
		else
			table.insert(assets, {
				id = instance:GetDebugId(0),
				name = instance.Name,
				className = instance.ClassName,
				instance = instance,
				assetPath = "",
				fullAssetPath = "",
				parentPath = "",
				assetId = nil,
				managed = false,
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
			local okTarget, targetPath = AssetPathResolver.instanceToTargetPath(asset.instance)
			if not okTarget or not targetPath then
				return {
					ok = false,
					message = "Failed to resolve target path for " .. asset.name .. ".",
					count = exported,
				}
			end

			local assetId = AssetRegistry.register(asset.instance, asset.assetPath, targetPath)
			asset.assetId = assetId
			asset.managed = true

			local previousSelection = Selection:Get()
			Selection:Set({ asset.instance })

			local suggestedFileName = asset.fullAssetPath
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

local function previewBuffer(serialized: buffer): (string, string)
	local byteCount = buffer.len(serialized)
	local previewCount = math.min(byteCount, 16)
	local hexParts = {}
	local textParts = {}

	for index = 0, previewCount - 1 do
		local byte = buffer.readu8(serialized, index)
		table.insert(hexParts, string.format("%02X", byte))
		if byte >= 32 and byte <= 126 then
			table.insert(textParts, string.char(byte))
		else
			table.insert(textParts, ".")
		end
	end

	return table.concat(hexParts, " "), table.concat(textParts, "")
end

function ExportService:probeSerializeSelected(assets: {AssetDefinition.AssetDefinition}): SerializeProbeResult
	local instances = {}
	for _, asset in assets do
		if asset.selected and asset.instance and asset.status ~= "Error" then
			table.insert(instances, asset.instance)
		end
	end

	if #instances == 0 then
		return {
			ok = false,
			message = "No assets selected for SerializationService test.",
			byteCount = 0,
			stringByteCount = 0,
			canConvertToString = false,
			valueType = "nil",
			previewHex = "",
			previewText = "",
		}
	end

	local ok, serializedOrError = pcall(function()
		return SerializationService:SerializeInstancesAsync(instances)
	end)

	if not ok then
		return {
			ok = false,
			message = "SerializationService failed: " .. tostring(serializedOrError),
			byteCount = 0,
			stringByteCount = 0,
			canConvertToString = false,
			valueType = typeof(serializedOrError),
			previewHex = "",
			previewText = "",
		}
	end

	local valueType = typeof(serializedOrError)
	if valueType ~= "buffer" then
		return {
			ok = false,
			message = "SerializationService returned " .. valueType .. ", expected buffer.",
			byteCount = 0,
			stringByteCount = 0,
			canConvertToString = false,
			valueType = valueType,
			previewHex = "",
			previewText = "",
		}
	end

	local serialized = serializedOrError :: buffer
	local byteCount = buffer.len(serialized)
	local previewHex, previewText = previewBuffer(serialized)
	local canConvertToString = false
	local stringByteCount = 0
	local stringOk, binaryStringOrError = pcall(function()
		return buffer.tostring(serialized)
	end)
	if stringOk and typeof(binaryStringOrError) == "string" then
		canConvertToString = true
		stringByteCount = #binaryStringOrError
	end
	local stringResultMessage = if canConvertToString then tostring(stringByteCount) .. " bytes." else "failed."

	return {
		ok = true,
		message = "SerializationService returned buffer, "
			.. tostring(byteCount)
			.. " bytes. buffer.tostring: "
			.. stringResultMessage,
		byteCount = byteCount,
		stringByteCount = stringByteCount,
		canConvertToString = canConvertToString,
		valueType = valueType,
		previewHex = previewHex,
		previewText = previewText,
	}
end

local function getSelectedInstancesForSerialization(assets: {AssetDefinition.AssetDefinition}): {Instance}
	local instances = {}
	for _, asset in assets do
		if asset.selected and asset.instance and asset.status ~= "Error" then
			table.insert(instances, asset.instance)
		end
	end
	return instances
end

function ExportService:probeRoundtripSelected(assets: {AssetDefinition.AssetDefinition}): RoundtripProbeResult
	local instances = getSelectedInstancesForSerialization(assets)
	if #instances == 0 then
		return {
			ok = false,
			message = "No assets selected for roundtrip test.",
			serializedByteCount = 0,
			deserializedCount = 0,
			names = "",
		}
	end

	local serializeOk, serializedOrError = pcall(function()
		return SerializationService:SerializeInstancesAsync(instances)
	end)
	if not serializeOk or typeof(serializedOrError) ~= "buffer" then
		return {
			ok = false,
			message = "Roundtrip serialize failed: " .. tostring(serializedOrError),
			serializedByteCount = 0,
			deserializedCount = 0,
			names = "",
		}
	end

	local serialized = serializedOrError :: buffer
	local byteCount = buffer.len(serialized)

	local deserializeOk, deserializedOrError = pcall(function()
		return SerializationService:DeserializeInstancesAsync(serialized)
	end)
	if not deserializeOk or typeof(deserializedOrError) ~= "table" then
		return {
			ok = false,
			message = "Roundtrip deserialize failed: " .. tostring(deserializedOrError),
			serializedByteCount = byteCount,
			deserializedCount = 0,
			names = "",
		}
	end

	local folder = Workspace:FindFirstChild("RefabRoundtripTest")
	if folder then
		folder:Destroy()
	end

	folder = Instance.new("Folder")
	folder.Name = "RefabRoundtripTest"
	folder.Parent = Workspace

	local names = {}
	local deserialized = deserializedOrError :: {Instance}
	for _, instance in deserialized do
		table.insert(names, instance.ClassName .. ":" .. instance.Name)
		instance.Parent = folder
	end

	return {
		ok = true,
		message = "Roundtrip OK: "
			.. tostring(#deserialized)
			.. " instance(s), "
			.. tostring(byteCount)
			.. " serialized bytes. Cloned into Workspace.RefabRoundtripTest.",
		serializedByteCount = byteCount,
		deserializedCount = #deserialized,
		names = table.concat(names, ", "),
	}
end

return ExportService
