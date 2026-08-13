--!strict

local Settings = require(script.Parent.Parent.config.Settings)

export type ProjectConfig = {
	projectRoot: string,
	assetsFolder: string,
}

local ProjectSettings = {}
ProjectSettings.__index = ProjectSettings

local function trim(value: string): string
	return value:gsub("^%s+", ""):gsub("%s+$", "")
end

local function normalizeSlashes(value: string): string
	return value:gsub("\\", "/")
end

local function settingKey(): string
	local gameId = tostring(game.GameId)
	local placeId = tostring(game.PlaceId)
	if gameId == "0" and placeId == "0" then
		return "RefabProjectConfig:local:" .. game.Name
	end
	return "RefabProjectConfig:" .. gameId .. ":" .. placeId
end

function ProjectSettings.new(plugin: Plugin)
	return setmetatable({
		_plugin = plugin,
		_config = {
			projectRoot = "",
			assetsFolder = Settings.AssetsRootFolder,
		} :: ProjectConfig,
	}, ProjectSettings)
end

function ProjectSettings:load(): ProjectConfig
	local saved = self._plugin:GetSetting(settingKey())
	if typeof(saved) == "table" then
		local root = saved.projectRoot
		local assetsFolder = saved.assetsFolder
		if typeof(root) == "string" then
			self._config.projectRoot = normalizeSlashes(trim(root))
		end
		if typeof(assetsFolder) == "string" and trim(assetsFolder) ~= "" then
			self._config.assetsFolder = normalizeSlashes(trim(assetsFolder))
		end
	end

	return self:get()
end

function ProjectSettings:save(projectRoot: string, assetsFolder: string?): ProjectConfig
	local root = normalizeSlashes(trim(projectRoot))
	local folder = Settings.AssetsRootFolder
	if assetsFolder and trim(assetsFolder) ~= "" then
		folder = normalizeSlashes(trim(assetsFolder))
	end
	folder = folder:gsub("^/+", ""):gsub("/+$", "")

	self._config = {
		projectRoot = root,
		assetsFolder = folder,
	}

	self._plugin:SetSetting(settingKey(), self._config)
	return self:get()
end

function ProjectSettings:get(): ProjectConfig
	return {
		projectRoot = self._config.projectRoot,
		assetsFolder = self._config.assetsFolder,
	}
end

function ProjectSettings:resolveAssetPath(assetPath: string): string
	local config = self:get()
	local normalizedAssetPath = normalizeSlashes(assetPath):gsub("^/+", "")
	local projectAssetPath = config.assetsFolder .. "/" .. normalizedAssetPath
	if config.projectRoot == "" then
		return projectAssetPath
	end

	return config.projectRoot:gsub("/+$", "") .. "/" .. projectAssetPath
end

function ProjectSettings:hasProjectRoot(): boolean
	return self._config.projectRoot ~= ""
end

return ProjectSettings
