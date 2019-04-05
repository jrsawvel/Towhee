#!/usr/local/bin/lua

local signal = require("posix.signal")
local socket = require("socket")
local string = require("string")

local redis = require 'redis'




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

    if redis_response == true then
        if line == "statements" then
            value = rc:hget('toledowx', 'statements')
        elseif line == "conditions" then
            value = rc:hget('toledowx', 'conditions')
        elseif line == "summary" then
            value = rc:hget('toledowx', 'summary')
        elseif line == "forecast" then
            value = rc:hget('toledowx', 'forecast')
        elseif line == "pubdate" then
            value = rc:hget('toledowx', 'pubdate')
        elseif line == "articles" then
            value = _get_article_list(rc)
        elseif line == "help" then
            value = "Valid commands:\n  statements\n  conditions\n  summary\n  forecast\n  pubdate\n  articles\n  quit\n  help"
        elseif is_numeric(line) == true then
            value = _get_article(rc, line)
        else
            value = "Invalid command given. Type help for commands."
        end
    end

    return value

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
    client:send("hello, client.\n\n")
--    client:send("Menu\n")
--    client:send("  1. weather\n")
--    client:send("  2. articles\n")
--    client:send("Choose a number or enter the keyword: ")


    -- make sure we don't block waiting for this client's line.
    -- timeout and close connection after 90 seconds of inactivity.
    client:settimeout(90)

    -- receive the line
    local msg, err = client:receive()

    while not err and "quit" ~= msg do

        -- print(string.format("received: %s", msg))
        -- client:send(msg)

        local redis_client = redis.connect('127.0.0.1', 6379)

        local response = _process_message(msg, redis_client)

        if response ~= nil then
            client:send(response .. "\n")
        else
            client:send("Unknown error occurred.\n")
        end

        redis_client:quit()

        msg, err = client:receive()
    end

    client:send("goodbye client\n")
    client:close()


end
server:close()

