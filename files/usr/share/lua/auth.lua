local auth={};

auth.user = ""
auth.is_auth = false

function auth.get_ntp_status()
	local result = run_process("sh -c \". /usr/share/functions/system_functions.sh; ntp_anlix\"")
	-- remove \n
	ntp_st = result:sub(1,-2)

	if ntp_st == "unsync" then
		return false
	end

	return true
end

function auth.get_user()
	return auth.user
end

function auth.is_authorized()
	return auth.is_auth
end

function auth.decode_provider()
	local result = run_process("pk b64dec /tmp/provider.data")
	local status, data = pcall(function() return json.decode(result) end)
	if not status then
		return false
	end

	auth.user = data.user
	return true
end

function auth.authenticate(auth_data)

	local provider_json = auth_data.provider
	local provider_sign = auth_data.sign

	if provider_json == nil or provider_sign == nil then
		return false
	end

	if not (type(provider_json) == "string" and type(provider_sign) == "string") then
		return false
	end

	-- check the provider information
	touch_file("/tmp/provider.data")
	append_to_file("/tmp/provider.data", provider_json .. "\n")
	touch_file("/tmp/provider.data.sig")
	append_to_file("/tmp/provider.data.sig", provider_sign)

	local result = run_process("pk verify /etc/provider.pubkey /tmp/provider.data")

	if string.sub(result, 1, 2) == "OK" then
		if auth.decode_provider() then
			if auth.get_ntp_status() then
				local cur_time = os.time(os.date("!*t"))
				if data.expire <= cur_time then
					auth.is_auth = true
				end
			else
				-- we cant validate expire time (not in sync)
				auth.is_auth = true
			end
		end
	end

	os.remove("/tmp/provider.data")
	os.remove("/tmp/provider.data.sig")	
	return auth.is_auth
end

return auth
