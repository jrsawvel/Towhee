#!/usr/local/bin/lua

local redis = require 'redis'


local site_name = "sora"

local redis_client = redis.connect('127.0.0.1', 6379)

local redis_response = redis_client:ping()

if redis_response == true then
    local keys = redis_client:hkeys(site_name)

    for k,v in pairs(keys) do
        print("  " .. k .. " - " .. v)
    end

    print("\n\n")

    print(type(keys))

    print(keys[2])

    local title = keys[2]

    local markup = redis_client:hget(site_name, title)

    print(markup)
end

redis_client:quit()

 

