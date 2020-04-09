local web={};

web.ERROR_PROT_VER = 1
web.ERROR_GEN_SECRET = 2
web.ERROR_PARAMETERS = 3
web.ERROR_PASSWD_SAVE = 4
web.ERROR_ROUTER_PASSWD = 5
web.ERROR_CMD_UNKNOWN = 6
web.ERROR_FLASHMAN_UPDATE = 7
web.ERROR_SECRET_MATCH = 8
web.ERROR_AUTH_FAIL = 10
web.ERROR_READ_MAC = 11
web.ERROR_URL = 20
web.ERROR_DATA = 21

function web.error_string(errid)
	if errid == web.ERROR_PROT_VER then return "Invalid Protocol Version"
	elseif errid == web.ERROR_GEN_SECRET then return "Error generating secret for app"
	elseif errid == web.ERROR_PARAMETERS then return "Invalid Parameters"
	elseif errid == web.ERROR_PASSWD_SAVE then return "Error saving password"
	elseif errid == web.ERROR_ROUTER_PASSWD then return "Password not match"
	elseif errid == web.ERROR_CMD_UNKNOWN then return "Command not implemented"
	elseif errid == web.ERROR_FLASHMAN_UPDATE then return "Error updating flashman"
	elseif errid == web.ERROR_SECRET_MATCH then return "Secret not match"
	elseif errid == web.ERROR_AUTH_FAIL then return "Authorization Fail"
	elseif errid == web.ERROR_READ_MAC then return "Error reading mac address"
	elseif errid == web.ERROR_URL then return "Invalid URL"
	elseif errid == web.ERROR_DATA then return "Invalid DATA"
	else return "Unknown Error"
	end
end

function web.error_handle(errid, auth)
	resp = {}
	err = {}
	err["errno"] = errid
	err["errstr"] = web.error_string(errid)
	if auth ~= nil then resp["auth"] = auth end
	resp["Error"] = err

	uhttpd.send("Status: 500 Internal Server Error\r\n")
	uhttpd.send("Content-Type: text/json\r\n\r\n")
	uhttpd.send(json.encode(resp))
end

function web.send_json(data)
	uhttpd.send("Status: 200 OK\r\n")
	uhttpd.send("Content-Type: text/json\r\n\r\n")
	uhttpd.send(json.encode(resp))
end

function web.send_plain(data)
	uhttpd.send("Status: 200 OK\r\n")
	uhttpd.send("Content-Type: text/plain\r\n\r\n")
	uhttpd.send(data)
end

return web
