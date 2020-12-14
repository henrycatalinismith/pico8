pico-8 cartridge // http://www.pico-8.com
version 29
__lua__

function terrain(fn)
 local t = {fn}
 setmetatable(t, {
  __add = terrain_add,
  __call = terrain_call,
  __mod = terrain_mod,
  __mul = terrain_mul,
 })
 return t
end

function terrain_add(t1, t2)
 return terrain(
  function(p)
   local y1 = t1(p)
   local y2 = t2(p)
   if y1 == nil or y2 == nil then
    return nil
   end
   return y1 + y2
  end
 )
end

function terrain_call(t, p)
 if p == nil then
  return nil
 else
  return t[1](p)
 end
end

function terrain_mod(t1, t2)
 return terrain(
  function(p)
   local y1 = t2(p)
   local y2 = t1(y1)
   if y1 == nil or y2 == nil then
    return nil
   end
   return y2
  end
 )
end

function terrain_mul(t1, t2)
 return terrain(
  function(p)
   local y1 = t1(p)
   local y2 = t2(p)
   if y1 == nil or y2 == nil then
    return nil
   end
   return y1 * y2
  end
 )
end

function invert()
 return terrain(
  function(p)
   return -1
  end
 )
end

function linear(y)
 return terrain(
  function(p)
   return p * y
  end
 )
end

function noise(n)
 return terrain(
  function(p)
   if p == 1 then
    return 0
   else
    return flr(rnd(2^n)) - 2^n/2
   end
  end
 )
end

function pythagoras(r)
 return terrain(
  function(p)
   return r - sqrt(r^2 - flr(r*p)^2)
  end
 )
end

function range(from, to)
 return terrain(
  function(p)
   if p <= from then
    return 0
   elseif p >= to then
    return 1
   else
    return (p-from)/(to-from)
   end
  end
 )
end

function reverse()
 return terrain(
  function(p)
   return 1 - p
  end
 )
end

function rock(x, y, r, d)
 --local front = static(r) + pythagoras(r) * invert() % reverse() % range(0, 0.5)
 --local back = pythagoras(r) * invert() % range(0.5, 1)
 --return static(y) + front + back % trim() % range(0.2,0.7)
 return (
  static(y)
  + (linear(r*d) + sinewave(2, 1) + noise(1)) % range(0, 0.5)
  + (linear(r*-d) + sinewave(2, 1) + noise(1)) % range(0.5, 1)
 ) % trim() % range(x-(r*0.01), x+(r*0.01))
end

function sbend(r1, r2, d)
 local p1 = r1 / (r1 + r2)
 return (
  static(r2) + pythagoras(r1) % range(0, p1)
  + pythagoras(r2) * invert() % reverse() % range(p1, 1)
 ) * static(d)
end

function sinewave(magnitude, frequency)
 return terrain(
  function(p)
   return sin(p * frequency) * magnitude
  end
 )
end

function static(y)
 return terrain(
  function(p)
   return y
  end
 )
end

function trim()
 return terrain(
  function(p)
   if p > 0 and p < 1 then
    return p
   end
  end
 )
end

function _init()
 graph_x1 = 32
 graph_y1 = 32
 graph_x2 = 95
 graph_y2 = 95

 terrains = {}
 index = 1

 add(terrains, {
   name = "linear(128)",
   fn = linear(128),
 })

 add(terrains, {
   name = "noise(3)",
   fn = noise(3),
 })

 add(terrains, {
   name = "pythagoras(128)",
   fn = pythagoras(128),
 })

 add(terrains, {
   name = "static(64)",
   fn = static(64),
 })

 add(terrains, {
   name = "pythagoras(128) % reverse()",
   fn = pythagoras(128) % reverse(),
 })

 add(terrains, {
   name = "pythagoras(128) % range(0, 0.5)",
   fn = pythagoras(128) % range(0, 0.5),
 })

 add(terrains, {
   name = "sbend(16, 32, 1)",
   fn = sbend(16, 32, 1),
 })

 add(terrains, {
   name = "sinewave(8, 2)",
   fn = sinewave(8, 2),
 })

 add(terrains, {
   name = "rock(0.5, 64, 8, 1)",
   fn = rock(0.5, 64, 8, 1),
 })

 add(terrains, {
   name = "rock(0.5, 64, 8, -1)",
   fn = rock(0.5, 64, 8, -1),
 })

 points = {}

 index = #terrains
end

function _update()
 points = {}
 maxp = 0
 minp = 0

 for x = 1,128 do
  local p = x/128
  if x == 1 then p = 0 elseif x == 128 then p = 1 end
  local y = terrains[index].fn(p) 
  points[x] = {y}
  if y == nil then
   goto continue
  end
  if y > maxp then
   maxp = ceil(y)
  end
  if y < minp then
   minp = flr(y)
  end
  ::continue::
 end

 if btnp(2) then
  index = index - 1
  if index == 0 then
   index = #terrains
  end
 elseif btnp(3) then
  index = index + 1
  if index > #terrains then
   index = 1
  end
 end
end

function _draw()
 cls()

 local xs = (graph_x2-graph_x1-2)/#points
 local ys = (graph_y2-graph_y1-2)/(maxp-minp)

 rectfill(graph_x1, graph_y1, graph_x2, graph_y2, 1)

 line(graph_x1, graph_y1, graph_x1, graph_y2, 12)
 line(graph_x1, graph_y1+(maxp+1)*ys, graph_x2, graph_y1+(maxp+1)*ys, 12)

 local px1,px2
 for x = 1,128 do
  local y = points[x][1]
  local px = graph_x1 + 1 + (x*xs)
  if y ~= nil then
   local py = graph_y1 + (maxp-y)*ys
   pset(px, py, 8)
  end
 end

 print(maxp, graph_x1 - #(tostr(maxp))*4, graph_y1 + 1, 6)

 print(terrains[index].name, 2, graph_y2 + 8, 7)
end


__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
