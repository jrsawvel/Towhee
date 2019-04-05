#!/usr/local/bin/lua

local signal = require("posix.signal")
local socket = require("socket")
local string = require("string")

local redis = require 'redis'




function split(str, pat)
   local t = {}  -- NOTE: use {n = 0} in Lua-5.0
   local fpat = "(.-)" .. pat
   local last_end = 1
   local s, e, cap = str:find(fpat, 1)
   while s do
      if s ~= 1 or cap ~= "" then
         table.insert(t,cap)
      end
      last_end = e+1
      s, e, cap = str:find(fpat, last_end)
   end
   if last_end <= #str then
      cap = str:sub(last_end)
      table.insert(t, cap)
   end
   return t
end




function wrap(str, limit, indent, indent1)
   indent = indent or ""
   indent1 = indent1 or indent
   limit = limit or 72
   local here = 1-#indent1
   local function check(sp, st, word, fi)
      if fi - here > limit then
         here = st - #indent
         return "\n"..indent..word
      end
   end
   return indent1..str:gsub("(%s+)()(%S+)()", check)
end



function _display_article(c, r)

    local max_lines = 25

    local arr = split(r, "\n")

    local final_output = ""
    local line_counter = 0

    c:send(final_output .. "\n========== BEGIN ARTICLE ==========\n> ")

    for i=1, #arr do
        local new_str = wrap(arr[i], 70, "", "")

        local tmp_arr = split(new_str, "\n")

        if #tmp_arr == 0 then
            final_output = final_output .. "\n"
            line_counter = line_counter + 1
        end

        for x=1, #tmp_arr do
            final_output = final_output .. tmp_arr[x] .. "\n"

            line_counter = line_counter + 1
            if line_counter >= max_lines then
                c:send(final_output .. "\n========== HIT RETURN KEY TO CONTINUE ... ==========\n")
                final_output = ""
                line_counter = 0
                local msg, err = c:receive()
            end
        end
    end

    c:send(final_output .. "\n========== END OF ARTICLE ==========\n> ")
end





function trim_spaces (str)
    if (str == nil) then
        return nil
    end
   
    -- remove leading spaces 
    str = string.gsub(str, "^%s+", "")

    -- remove trailing spaces.
    str = string.gsub(str, "%s+$", "")

    return str
end




function _get_article(rc, num)

    local articles_hash = rc:hkeys('sora')

    local title = articles_hash[tonumber(num)]

    return rc:hget('sora', title)

end




function is_numeric(str)
    if ( str == nil ) then
        return false
    end

    local s = string.match(str, '^[0-9]+$')

    if ( s == nil ) then
        return false
    end

    return true
end



function _get_article_list(rc)

    local str = ""

    local articles_hash = rc:hkeys('sora')

    for k,v in pairs(articles_hash) do
        str = str .. "  " .. k .. " - " .. v .. "\n"
    end

    return str

end




function _process_message(line, rc)

    local redis_response = rc:ping()

    local value = nil

    local is_article = false

    if redis_response == true then
        if line == "statements" then
            value = wrap(rc:hget('toledowx', 'statements'))
        elseif line == "conditions" then
            value = wrap(rc:hget('toledowx', 'conditions'))
        elseif line == "summary" then
            value = wrap(rc:hget('toledowx', 'summary'))
        elseif line == "forecast" then
            value = wrap(rc:hget('toledowx', 'forecast'))
        elseif line == "pubdate" then
            value = rc:hget('toledowx', 'pubdate')
        elseif line == "articles" then
            value = _get_article_list(rc)
        elseif line == "help" or line == "?" then
            value = "Valid commands:\n  statements\n  conditions\n  summary\n  forecast\n  pubdate\n  articles\n  quit\n  help"
        elseif is_numeric(line) == true then
            value = _get_article(rc, line)
            is_article = true
        elseif string.len(trim_spaces(line)) < 1 then
            value = ""
        else
            value = "Invalid command given. Type help for commands."
        end
    end

    return value, is_article

end



-- ========================================================



-- create a TCP socket and bind it to the local host, at any port
-- local server = assert(socket.bind("127.0.0.1", 0))
-- another option:
-- create a TCP socket and bind it to the local host, at any port but make it available over the internet
-- local server = assert(socket.bind("*", 0))
-- i'm choosing to bind at a specific port and make it available over the internet
local server = assert(socket.bind("*", 51515))


-- for testing, use these two commands:
local ip, port = server:getsockname()
print(string.format("telnet %s %s", ip, port))


local running = 1

local function stop(sig)
    running = 0
    return 0
end

-- Interrupt
signal.signal(signal.SIGINT, stop)


-- i don't know about constantly staying connected to redis.
-- i would prefer to connect to redis when a telnet connection is received with this code.
-- i need to find or create a disconnect from redis command.


while 1 == running do


    -- wait for a connection from any client
    local client = server:accept()
    client:send("hello, client.\n\n> ")
--    client:send("Menu\n")
--    client:send("  1. weather\n")
--    client:send("  2. articles\n")
--    client:send("Choose a number or enter the keyword: ")


    -- make sure we don't block waiting for this client's line.
    -- timeout and close connection after 90 seconds of inactivity.
    client:settimeout(90)

    -- receive the line
    local msg, err = client:receive()

    while not err and "quit" ~= msg  and "stop" ~= msg do

        -- print(string.format("received: %s", msg))
        -- client:send(msg)

        local redis_client = redis.connect('127.0.0.1', 6379)

        local response, is_article = _process_message(msg, redis_client)

        if response ~= nil then
            if is_article then
                _display_article(client, response)
            else            
                client:send(response .. "\n\n> ")
            end
        else
            client:send("Unknown error occurred.\n> ")
        end

        redis_client:quit()

        msg, err = client:receive()
    end

    client:send("goodbye client\n")
    client:close()

    if msg == "stop" then
        stop()
    end

end
print("ending ...")
server:close()

