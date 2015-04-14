#!/lounge/bin/janosh -f

local util = require("util")

Janosh:set("/player/active", "false")
Janosh:set("/player/paused", "false")

--Janosh:setenv("VDPAU_OSD","1")
Janosh:setenv("DISPLAY",":0")
Janosh:system("killall -9 mpv")
local MPID, MSTDIN, MSTDOUT, MSTDERR = Janosh:popen("mpv", "-idle", "--input-unix-socket", "/tmp/mpv.socket")
Janosh:pclose(MSTDIN)

Janosh:sleep(3000)
local S1PID, S1STDIN, S1STDOUT, S1STDERR = Janosh:popen("/usr/bin/socat", "-", "/tmp/mpv.socket")
Janosh:pclose(S1STDERR)

-- unset causes wierd errors

local MpvClass = {} -- the table representing the class, which will double as the metatable for the instances
MpvClass.__index = MpvClass -- failed table lookups on the instances should fallback to the class table, to get methods

function MpvClass.new()
  return setmetatable({}, MpvClass)
end

function MpvClass.jump(self, idx) 
  print("jump:", idx)
  obj = Janosh:get("/playlist/items/.")
  idx = tonumber(idx) + 1;
  if idx > #obj then
    idx = #obj
  end
  print("### IDX", idx)
  file = obj[idx].url
  title = obj[idx].title
  if string.match(file, "http[s]*://") then
    p, i, o, e = Janosh:popen("curl", "--head", file)
    line=Janosh:preadLine(o)
    if line == nil then
      util:exception("Can't fix item:" .. idx - 1)
      return
    end
    Janosh:pclose(i)
    Janosh:pclose(e)
    Janosh:pclose(o)
    Janosh:pwait(p)

    token=util:split(line," ")[2]
    code=tonumber(token)
    if code ~= 200 and code ~= 302 then
      Janosh:publish("cacheFix", "W", idx - 1)
      return
    end
  end

  Janosh:transaction(function() 
    Janosh:set_t("/player/active", "true")
    util:notifyLong(title)
    self:cmd("loadfile", file)
    Janosh:set_t("/playlist/index", tostring(idx - 1))
  end)
end

function MpvClass.previous(self) 
  util:notify("previous")
  self:jump(tonumber(Janosh:get("/playlist/index").index) - 1)
end

function MpvClass.next(self)
  util:notify("next")
  self:jump(tonumber(Janosh:get("/playlist/index").index) + 1)
end

function MpvClass.seek(self, seconds)
  self:cmd("seek", seconds, "absolute")
end

function MpvClass.enqueue(self, videoUrl, title, srcUrl) 
  util:notify("Queued: " .. title)
  if title == "" then
    title = "(no title)"
  end
  size = Janosh:size("/playlist/items/.")
  Janosh:mkobj_t("/playlist/items/#" .. size .. "/.")
  Janosh:set_t("/playlist/items/#" .. size .. "/url", videoUrl)
  Janosh:set_t("/playlist/items/#" .. size .. "/title", title)
  Janosh:set_t("/playlist/items/#" .. size .. "/source", srcUrl)
  print("enqueuend")
end

function MpvClass.add(self, videoUrl, title, srcUrl)
  self:enqueue(videoUrl, title, srcUrl)

  if Janosh:get("/player/active").active == "false" then
    self:jump(10000000) -- jump to the ned of the playlist
  end
end

function MpvClass.run(self) 
print("run")
  Janosh:thread(function() 
  while true do
    line=""
    pos=""
    len=""
    while true do
      line = Janosh:preadLine(MSTDERR)
--      print("STDERR:", line)
      if line == nil then break end
      tokens = util:split(line, " ")
      if #tokens >= 4 and (tokens[2] ~= pos or tokens[4] ~= len) then
        info = {}
        info[1] = tokens[2]
        pos = tokens[2]
        info[2] = tokens[4]
        len = tokens[4]
        Janosh:publish("playerTimePos","W",JSON:encode(info))
      end
    end
    Janosh:sleep(1000)
  end
  end)()

  Janosh:thread(function()
    while true do
      line=""
      while true do
        line = Janosh:preadLine(S1STDOUT)
        print("RECEIVED:", line)
        if line == nil then break end
        obj = JSON:decode(line)
        if obj.event == "idle" then
          self:onIdle()
        elseif obj.event == "playback-restart" then
--        self:sotrack()
--      elseif string.find(line, CACHEEMPTY) then
--        self:cache_empty()
--      elseif string.find(line, TIMEPOS) then
--        times=util:split(line:gsub(TIMEPOS,""), "/")
--        Janosh:publish("playerTimePos", "W", JSON:encode(times))
        end
          
      end
      Janosh:sleep(1000)
    end
  end)()

  while true do
    line=""
    while true do
      line = Janosh:preadLine(MSTDOUT)
      if line == nil then break end
      print("STDOUT", line)
    end
    Janosh:sleep(1000)
  end
end

function MpvClass.cmd(self, ...) 
  local arg={...}
  print("cmd:", unpack(arg))
  obj = {}
  obj["command"] = {}

  for i, a in ipairs(arg) do
    obj["command"][i]=a
  end
  print(JSON:encode(obj)) 
  Janosh:pwrite(S1STDIN, JSON:encode(obj) .. "\n")
end

function MpvClass.forward(self) 
  util:notify("Forward")
  self:cmd("seek", "10")
end

function MpvClass.forwardMore(self)
  util:notify("Forward more")
  self:cmd("seek", "60")
end

function MpvClass.rewind(self)
  util:notify("Rewind")
  self:cmd("seek", "-10")
end

function MpvClass.rewindMore(self)
  util:notify("Rewind more")
  self:cmd("seek", "-60")
end

function MpvClass.pause(self)
  Janosh:transaction(function()
    util:notify("Pause")
    paused = Janosh:get("/player/paused").paused
 
    if paused == "false" then
      self:cmd("set_property","pause",true)
      Janosh:set_t("/player/paused", "true")
    else
      self:cmd("set_property","pause",false)
      Janosh:set_t("/player/paused", "false")
    end
  end)
end

function MpvClass.stop(self)
  util:notify("Stop")

  Janosh:transaction(function()
    self:cmd("set_property","pause",true)
    Janosh:set("/player/paused", "true")
    if Janosh:get("/player/active").active == "true" then
      Janosh:set_t("/player/active","false")
      Janosh:publish("backgroundRefresh", "W", "")
    end
  end)
end

function MpvClass.cache_empty(self)
  Janosh:publish("notifySend", "Network Problem!")
end

function MpvClass.onIdle(self) 
  print("onIdle")
  obj = Janosh:get("/playlist/.")
  idx = tonumber(obj.index)
  len = #obj.items
  if idx < len then
    Janosh:publish("backgroundRefresh", "W", "")
    self:jump(tostring(idx))
  else
    Janosh:publish("backgroundRefresh", "W", "")
    Janosh:set_t("/player/active","false")
  end
end

function MpvClass.loadFile(self,path)
  Janosh:set_t("/player/active", "true")
  self:cmd("loadfile ", path)
end

return MpvClass:new()
