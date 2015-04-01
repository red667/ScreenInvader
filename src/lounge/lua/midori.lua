#!/lounge/bin/janosh -f

local util = require("util")

local MidoriClass = {} -- the table representing the class, which will double as the metatable for the instances
MidoriClass.__index = MidoriClass -- failed table lookups on the instances should fallback to the class table, to get methods

function MidoriClass.new()
  return setmetatable({}, MidoriClass)
end

function MidoriClass.cmd(self, cmdstring) 
  print("cmd:", cmdstring)
  Janosh:system("killall -0 midori && midori -e " .. cmdstring)
end

function MidoriClass.minimize(self)
print("mini")
  xid = util:getWindowID("midori.Midori")
  if xid ~= -1 then
  print("minimize:", xid)
  print("xdotool windowminimize " .. xid) 
   Janosh:system("xdotool windowminimize " .. xid)
  end
end

function MidoriClass.raise(self)
print("raise")
  xid = util:getWindowID("midori.Midori")
  if xid ~= -1 then
    print("raise:", xid)
    Janosh:system("xdotool windowraise " .. xid) 
  end
end

function MidoriClass.openUrl(self, url)
  util:notify("Open Browser: " .. url)

  print("openUrl:", url)
  Janosh:system("midori " .. url .. "&")
  self:raise()
end

function MidoriClass.close(self)
  util:notify("Close Browser")
  print("close")
  self:cmd("Homepage")
  self:cmd("TabCloseOther")
  self:minimize()
end

function MidoriClass.pageDown(self) 
  Janosh:sytem("xdotool key Page_Down")
end

function MidoriClass.pageUp(self)
  Janosh:sytem("xdotool key Page_Up")
end

function MidoriClass.scrollDown(self)
  self:cmd("ScrollDown")
end

function MidoriClass.scollUp(self)
  self:cmd("ScrollUp")
end

function MidoriClass.scollLeft(self)
  self:cmd("ScrollLeft")
end

function MidoriClass.scollRight(self)
  self:cmd("ScrollRight")
end

function MidoriClass.zoomIn(self)
  self:cmd("ZoomIn")
end

function MidoriClass.zoomOut(self)
  self:cmd("ZoomOut")
end

function MidoriClass.run(self) 
  while true do
    Janosh:sleep(10000)
  end
end

return MidoriClass:new()
