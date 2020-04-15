local auth={};

function auth.validate(auth_data)

	local provider_json = auth_data.provider
	local provider_sign = auth_data.sign

	if provider_json == nil or provider_sign == nil then
		return false
	end

	-- check the provider information
	touch_file("/tmp/provider.data")
	append_to_file("/tmp/provider.data", provider_json)
	touch_file("/tmp/provider.data.sig")
	append_to_file("/tmp/provider.data.sig", provider_sign)

	local result = run_process("pk_verify /etc/provider.pubkey /tmp/provider.data")

	if result == "OK" then
		return true
	else
		return false
	end
end

return auth
