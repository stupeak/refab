--!strict

local HttpService = game:GetService("HttpService")

local Settings = require(script.Parent.Parent.config.Settings)

export type HelperStatus = {
	ok: boolean,
	projectRoot: string?,
	assetsRoot: string?,
	assetCount: number?,
	message: string?,
}

export type HelperAsset = {
	id: string?,
	name: string,
	source: string,
	target: string?,
	className: string?,
	hash: string?,
	size: number?,
	status: string?,
}

export type HelperResult = {
	ok: boolean,
	message: string?,
}

export type CompareResult = {
	ok: boolean,
	status: string?,
	hash: string?,
	message: string?,
}

local HelperClient = {}
HelperClient.__index = HelperClient

function HelperClient.new(baseUrl: string?)
	return setmetatable({
		_baseUrl = baseUrl or Settings.HelperBaseUrl,
	}, HelperClient)
end

function HelperClient:_request(method: string, path: string, body: any?): (boolean, any)
	local request = {
		Url = self._baseUrl .. path,
		Method = method,
		Headers = {
			["Content-Type"] = "application/json",
		},
	}

	if body ~= nil then
		request.Body = HttpService:JSONEncode(body)
	end

	local ok, response = pcall(function()
		return HttpService:RequestAsync(request)
	end)

	if not ok then
		return false, tostring(response)
	end

	if not response.Success then
		return false, "HTTP " .. tostring(response.StatusCode) .. ": " .. tostring(response.Body)
	end

	if response.Body == "" then
		return true, {}
	end

	local decodeOk, decoded = pcall(function()
		return HttpService:JSONDecode(response.Body)
	end)
	if not decodeOk then
		return false, "Invalid Refab CLI JSON: " .. tostring(decoded)
	end

	return true, decoded
end

function HelperClient:getStatus(): HelperStatus
	local ok, result = self:_request("GET", "/status")
	if not ok then
		return {
			ok = false,
			message = tostring(result),
		}
	end

	result.ok = result.ok == true
	return result
end

function HelperClient:listAssets(): (boolean, {HelperAsset}, string?)
	local ok, result = self:_request("GET", "/assets")
	if not ok then
		return false, {}, tostring(result)
	end

	local assets = result.assets
	if typeof(assets) ~= "table" then
		return false, {}, "Refab CLI response did not include assets."
	end

	return true, assets :: {HelperAsset}, nil
end

function HelperClient:writeAsset(payload: {[string]: any}): HelperResult
	local ok, result = self:_request("POST", "/assets/write", payload)
	if not ok then
		return {
			ok = false,
			message = tostring(result),
		}
	end

	return {
		ok = result.ok == true,
		message = result.message,
	}
end

function HelperClient:compareAsset(payload: {[string]: any}): CompareResult
	local ok, result = self:_request("POST", "/assets/compare", payload)
	if not ok then
		return {
			ok = false,
			message = tostring(result),
		}
	end

	return {
		ok = result.ok == true,
		status = result.status,
		hash = result.hash,
		message = result.message,
	}
end

function HelperClient:readAsset(sourcePath: string): (boolean, string?, HelperAsset?, string?)
	local encodedPath = HttpService:UrlEncode(sourcePath)
	local ok, result = self:_request("GET", "/assets/read?path=" .. encodedPath)
	if not ok then
		return false, nil, nil, tostring(result)
	end

	if result.ok ~= true or typeof(result.dataBase64) ~= "string" then
		return false, nil, nil, result.message or "Refab CLI did not return asset bytes."
	end

	return true, result.dataBase64, result.asset, nil
end

return HelperClient
