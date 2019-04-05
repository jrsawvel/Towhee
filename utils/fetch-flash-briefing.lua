#!/usr/local/bin/lua

local https = require "ssl.https"
local http  = require "socket.http"
local cjson = require "cjson"
local redis = require 'redis'



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



function fetch_url(url)
    local body,code,headers,status

    body,code,headers,status = http.request(url)

    if code < 200 or code >= 300 then
        body,code,headers,status = https.request(url)
    end

    if type(code) ~= "number" then
        code = 500
        status = "url fetch failed"
    end

    return body,code,headers,status
end



----------------------

-- my Toledo WX Lua-based app creates numerous static files, including a JSON file that is used
-- for the Amazon Echo smart home speaker flash briefing.

local json_briefing_url = "http://toledoweather.info/briefing.json"

local json_text, return_code, return_headers, return_status = fetch_url(json_briefing_url)


if return_code >= 300 then
    os.exit("Error: Could not fetch JSON briefing. Status: " .. return_status)
end

local json_table = cjson.decode(json_text)

--[[
json is an array of info.
key "titleText" contains the following values:
  Important Statement
  Current Conditions
  Synopsis
  Forecast
]]


local redis_client = redis.connect('127.0.0.1', 6379)

local redis_response = redis_client:ping()

if redis_response == true then
    redis_client:hset("toledowx", "pubdate", json_table[1].updateDate)
    for i=1, #json_table do
        local title_text = json_table[i].titleText
        local main_text  = trim_spaces(json_table[i].mainText)
        if title_text == "Important Statement" then
            redis_client:hset("toledowx", "statements", main_text)
        elseif title_text == "Current Conditions" then
            redis_client:hset("toledowx", "conditions", main_text)
        elseif title_text == "Synopsis" then
            redis_client:hset("toledowx", "summary", main_text)
        elseif title_text == "Forecast" then
            redis_client:hset("toledowx", "forecast", main_text)
        end
    end
end


-- local value = redis_client:hget('toledowx', 'summary')
-- print(value)


