require("uci")
json = require("json")

local function run_process(proc)
  local handle = io.popen(proc)
  local result = handle:read("*a")
  handle:close() 
  return result
end

local function get_router_id()
  local result = run_process("sh -c \". /usr/share/functions.sh; get_mac\"")
  -- remove \n
  return result:sub(1,-2)
end

local function read_file(path)
  local file = io.open(path, "rb")
  if not file then return nil end
  local content = file:read "*all"
  file:close()
  return content
end

local function authorized_controle(id)
  -- TODO: communicate with controle to verify app id
  return true
end

local function get_key(id)
  return read_file("/root/" .. id)
end

local function gen_app_key(id)
  local file = io.open("/root/" .. id, "wb")                                           
  if not file then return nil end  
  local secret = run_process("head -c 128 /dev/urandom | tr -dc 'a-zA-Z0-9'")                                         
  file:write(secret)                                           
  file:close()                                                               
  return secret
end

local function get_router_passwd()
  return read_file("/root/router_passwd")
end

local function save_router_passwd(pass)
  local file = io.open("/root/router_passwd", "wb")                                            
  if not file then return false end                                                       
  file:write(pass)                                                                    
  file:close() 
  return true
end    

local function error_handle(errid, errinfo, auth)
  resp = {}
  err = {}                                                                   
  err["errno"] = errid                                         
  err["errstr"] = errinfo
  if auth ~= nil then resp["auth"] = auth end
  resp["Error"] = err

  uhttpd.send("Status: 500 Internal Server Error\r\n")                                
  uhttpd.send("Content-Type: text/json\r\n\r\n")                                
  uhttpd.send(json.encode(resp))
end

function handle_request(env)
    local command = string.sub(env.PATH_INFO, 2)
    
    if env.REQUEST_METHOD == "POST" then
        local rlen, post_data = uhttpd.recv(8192) -- Max 8K in the post data!
        local data = json.decode(post_data)
        local app_protocol_ver = data.version
	local app_id = data.app_id

	if app_protocol_ver == nil then return end
	if app_id == nil then return end

        if tonumber(app_protocol_ver) > 1 then                                          
	  error_handle(1, "Invalid Protocol Version", nil)
          return                                                                        
        end

        if command == "ping" then                                                       
	    -- no need to authenticate ping command
            uhttpd.send("Status: 200 OK\r\n")                                           
            uhttpd.send("Content-Type: text/json\r\n\r\n")                              
                                                                                        
            system_model = read_file("/tmp/sysinfo/model")                              
            if(system_model == nil) then system_model = "INVALID MODEL" end             
            info = {}                                                                   
            info["anlix_model"] = system_model                                          
            uhttpd.send(json.encode(info)) 
	    return
	end

	local secret = get_key(app_id)
	local app_secret = data.app_secret

	if app_secret == nil or secret == nil then
	  -- the app do not provide a secret, verify with controle
	  if not authorized_controle(app_id) then return end
	  -- controle authorized, generate secret and store
	  secret = gen_app_key(app_id)
	  if secret == nil then
	    -- error generating key, report to app
	    error_handle(2, "Error generating secret for app", nil)
            return
	  end
	else
	  -- we have key, compare secrets
	  if app_secret ~= secret then return end
	end

	-- authenticated successfully
        local resp = {}                                                                 
                                                                                        
        auth = {}                                                                       
        auth["version"] = "1.0"                                                         
        auth["id_router"] = get_router_id()                                             
        auth["app_secret"] = secret                                                     
        resp["auth"] = auth 

	-- verify if we need passwd
	local passwd = get_router_passwd()
        local router_passwd = data.router_passwd
	if passwd == nil then
	  if router_passwd == nil then
	    error_handle(3, "Password not defined yet", auth)            
	    return
          else
	    if not save_router_passwd(router_passwd) then
	      error_handle(4, "Error saving password", auth)
	      return
	    end
	  end
	else
	  if router_passwd ~= passwd then
	    error_handle(5, "Password not match", auth)
	    return
	  end
	end
	
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
	    error_handle(6, "Command not implemented", auth)
        end
    end
end

