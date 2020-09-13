pico-8 cartridge // http://www.pico-8.com
version 29
__lua__

function _init()
 c = circle(32, 32, 64)
end

function _draw()
 cls(0)
 circ(c.x, c.y, c.r, 5)

 path = {}
 for x = c.x, c.x + c.r do
  add(path, xy(x, c.y + c:yoffset(x - c.x)))
 end
 for p in all(path) do
  pset(p.x, p.y, 7)
 end
end

function circle(x, y, r)
 local circle = {
  p = xy(x, y),
  r = r,
 }

 setmetatable(circle, {
  __index = function(c, i)
   if i == "x" then return c.p.x end
   if i == "y" then return c.p.y end
  end
 })

 function circle:yoffset(x)
  local d = circle.p + xy(x, circle.r)
  local a = circle.p:angle(d)
  local a = circle.p:angle(d)
  local y = abs(
  	circle.r * sin(a)
  )
  line(circle.p.x, circle.p.y, d.x, d.y, 8)
  return y
 end

 return circle
end

function xy(x, y)
 local p = { x = x or 0, y = y or 0 }
  
 setmetatable(p, {
  __add = function(p1, p2)
   return xy(p1.x + p2.x, p1.y + p2.y)
  end,

  __sub = function(p1, p2)
   return xy(p1.x - p2.x, p1.y - p2.y)
  end,

  __lt = function(p1, p2)
   return p1.x < p2.x and p1.y < p2.y
  end,

  __gt = function(p1, p2)
   return p1.x > p2.x and p1.y > p2.y
  end,
 })

 function p:angle(p2)
  return atan2(p2.x - self.x, -(p2.y - self.y))
 end

 function p:above(p2)
  return self.y < p2.y
 end

 function p:below(p2)
  return self.y > p2.y
 end

 return p
end
__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
