require("uci")
json = require("json")

local function read_file(path)
  local file = io.open(path, "rb")
  if not file then return nil end
  local content = file:read "*all"
  file:close()
  return content
end

function handle_request(env)
    local command = string.sub(env.PATH_INFO, 2)
    
    if env.REQUEST_METHOD == "POST" then
        local rlen, post_data = uhttpd.recv(8192) -- Max 8K in the post data!
        local data = json.decode(post_data)
        local app_protocol_ver = data.version
        local app_id = data.app_id
        local app_secret = data.app_secret
        local router_passwd = data.router_passwd
        local resp = {}   

        -- authenticate (TODO)
        -- TODO: Verify existence of app key
        -- TODO: if app key and match passwd return app secret else ask passwd (new passwd if no passwd stored)
        -- TODO: Integrate with controle server

        auth = {}
        auth["version"] = "1.0"
        auth["id_router"] = "012345"
        auth["app_secret"] = "12345"
        resp["auth"] = auth      

        -- exec command        
        if command == "info" then
            uhttpd.send("Status: 200 OK\r\n")
            uhttpd.send("Content-Type: text/json\r\n\r\n")

            system_model = read_file("/tmp/sysinfo/model")
            if(system_model == nil) then system_model = "INVALID MODEL" end
            info = {}
            info["anlix_model"] = system_model
            resp["info"] = info
            uhttpd.send(json.encode(resp))
        elseif command == "wifi" then
            u = uci.cursor()
            wifi = u.get_all("wireless")
        
            uhttpd.send("Status: 200 OK\r\n")       
            uhttpd.send("Content-Type: text/json\r\n\r\n")
            resp["wireless"] = wifi      
            uhttpd.send(json.encode(resp))
        else
            uhttpd.send("Status: 404 Not Found\r\n")
        end
    end
end

