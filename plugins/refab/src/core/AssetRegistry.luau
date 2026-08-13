--!strict

local HttpService = game:GetService("HttpService")

local Settings = require(script.Parent.Parent.config.Settings)

local AssetRegistry = {}

local function slugify(value: string): string
	local slug = value:lower()
	slug = slug:gsub("[^%w]+", "_")
	slug = slug:gsub("^_+", ""):gsub("_+$", "")
	if slug == "" then
		return "asset"
	end
	return slug
end

function AssetRegistry.getAssetId(instance: Instance): string?
	local value = instance:GetAttribute(Settings.Attributes.AssetId)
	if typeof(value) == "string" and value ~= "" then
		return value
	end
	return nil
end

function AssetRegistry.isManaged(instance: Instance): boolean
	return AssetRegistry.getAssetId(instance) ~= nil
end

function AssetRegistry.ensureAssetId(instance: Instance): string
	local existing = AssetRegistry.getAssetId(instance)
	if existing then
		return existing
	end

	local id = slugify(instance.Name) .. "_" .. HttpService:GenerateGUID(false):sub(1, 8)
	instance:SetAttribute(Settings.Attributes.AssetId, id)
	return id
end

function AssetRegistry.register(instance: Instance, sourcePath: string, targetPath: string): string
	local id = AssetRegistry.ensureAssetId(instance)
	instance:SetAttribute(Settings.Attributes.SourcePath, sourcePath)
	instance:SetAttribute(Settings.Attributes.TargetPath, targetPath)
	local version = instance:GetAttribute(Settings.Attributes.Version)
	if typeof(version) ~= "number" then
		instance:SetAttribute(Settings.Attributes.Version, 1)
	else
		instance:SetAttribute(Settings.Attributes.Version, version + 1)
	end
	return id
end

function AssetRegistry.getSourcePath(instance: Instance): string?
	local value = instance:GetAttribute(Settings.Attributes.SourcePath)
	if typeof(value) == "string" and value ~= "" then
		return value
	end
	return nil
end

return AssetRegistry
