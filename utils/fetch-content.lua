#!/usr/local/bin/lua

local redis = require 'redis'


local site_name = "sora"


local title = arg[1]
local file  = arg[2]

if ( title == nil  or  file == nil ) then
    error("missing arg(s). usage: fetch-conent title file")
end 


local f = assert(io.open(file, "r"))

local markup = f:read("a")

f:close()


local redis_client = redis.connect('127.0.0.1', 6379)

local redis_response = redis_client:ping()

if redis_response == true then
    
    redis_client:hset(site_name, title, markup)

end

print(redis_client:hget(site_name, title))

