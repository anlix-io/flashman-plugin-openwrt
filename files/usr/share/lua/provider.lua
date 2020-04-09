
function handle_provider(command, data)

	local app_protocol_ver = data.version
	local provider_json = data.provider
	local provider_sign = data.sign

	if provider_json == nil or provider_sign == nil then
		web.error_handle(web.ERROR_DATA, nil)
		return
	end

	-- check the provider information
	touch_file("/tmp/provider.data")
	append_to_file("/tmp/provider.data", provider_json)
	touch_file("/tmp/provider.data.sig")
	append_to_file("/tmp/provider.data.sig", provider_sign)

	local result = run_process("pk_verify /etc/provider.pubkey /tmp/provider.data")

	web.send_plain(result)
end
