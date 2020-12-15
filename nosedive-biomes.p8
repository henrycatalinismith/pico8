pico-8 cartridge // http://www.pico-8.com
version 29
__lua__

function biome(l, c)
 local b = {}
 local cf = c[flr(rnd(#c))+1]
 local ci = 1
 local cc = 0
 local cp = 0
 local cy = 0
 local ly = 0
 setmetatable(b, {
  __call = function(b)
   cc += 1
   if cc < 128 then
    cp = cc/128
   elseif ci < l then
    cf = c[flr(rnd(#c))+1]
    ci += 1
    cc = 1
    cp = 0
    cy = ly
   else
    return nil
   end
   local v = cf(cp)
   for i,p in pairs(v) do
    v[i] += cy
   end
   ly = v[1]
   return v
  end,
  __len = function(b)
   return l*128
  end,
 })
 return b
end

function chunk(y1, y2)
 local c = {y1,y2}
 setmetatable(c, {
  __add = chunk_add,
  __and = chunk_and,
  __call = chunk_call,
 })
 return c
end

function chunk_add(c1, c2)
 return chunk(
  c1[1] + c2[1],
  c1[2] + c2[2]
 )
end

function chunk_and(c1, c2)
 for y in all(c2) do
  add(c1, y)
 end
 return c1
end

function chunk_call(c, p)
 local v = {}
 for t in all(c) do
  local y = t(p)
  if y ~= nil then
   add(v, y)
  end
 end
 sort(v)
 return v
end

function sort(a)
 for i=1,#a do
  local j = i
  while j > 1 and a[j-1] > a[j] do
   a[j],a[j-1] = a[j-1],a[j]
   j = j - 1
  end
 end
end

function tunnel(d, h)
 return chunk(
  static(d),
  static(d + h)
 )
end

function room(d)
 return chunk(
  static(d),
  static(d + 120)
 )
end

function resize1(y)
 return chunk(
  linear(y),
  linear(y)
 )
end

function resize(y1, y2)
 return chunk(
  linear(y1),
  linear(y2)
 )
end

function rock(x, y, r)
 return chunk(
  fragment(x, y, r, -1),
  fragment(x, y, r, 1)
 )
end

function nbend(r1, r2)
 return chunk(
  nshape(r2, r1),
  nshape(r1, r2)
 )
end

function sbend(r1, r2)
 return chunk(
  sshape(r1, r2),
  sshape(r2, r1)
 )
end

function ubend(r1, r2)
 return chunk(
  ushape(r2, r1),
  ushape(r1, r2)
 )
end

function zbend(r1, r2)
 return chunk(
  zshape(r2, r1),
  zshape(r1, r2)
 )
end

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

function fragment(x, y, r, d)
 return (
  static(y)
  + (linear(r*d) + sinewave(2, 1) + noise(1)) % range(0, 0.5)
  + (linear(r*-d) + sinewave(2, 1) + noise(1)) % range(0.5, 1)
 ) % trim() % range(x-(r*0.01), x+(r*0.01))
end

function nshape(r1, r2)
 return (
  sshape(r2, r1) % range(0, 0.5)
  + zshape(r1, r2) % range(0.5, 1)
 )
end

function sshape(r1, r2)
 return zshape(r1, r2) * static(-1)
end

function ushape(r1, r2)
 return (
  zshape(r1, r2) % range(0, 0.5)
  + sshape(r2, r1) % range(0.5, 1)
 )
end

function zshape(r1, r2)
 local p1 = r1 / (r1 + r2)
 return (
  static(r2) + pythagoras(r1) % range(0, p1)
  + pythagoras(r2) * invert() % reverse() % range(p1, 1)
 )
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
 cave = {}
end

function rng(n)
 local r = {n}
 local v = flr(rnd(n))
 setmetatable(r, {
  __add = function(v1, v2) return v * v1 end,
  __pow = function(v1, v2) return v ^ v1 end,
  __div = function(v1, v2) return v / v1 end,
  __mul = function(v1, v2) return v * v1 end,
  __sub = function(v1, v2) return v - v1 end,
 })
 return r
end

function _update()
 b = biome(4, {
   tunnel(0, 32) + nbend(16, 32) + resize1(32-rng(64)),
   tunnel(0, 32) + sbend(16, 32) + resize1(32-rng(64)),
   tunnel(0, 32) + zbend(16, 32) + resize1(32-rng(64)),
 })

 xs = 127/#b
 ys = 1

 miny = 999
 maxy = -999

 cave = {}

 for x=1,#b do
  cave[x] = b()
  for y in all(cave[x]) do
   if y > maxy then
    maxy = y
   end
   if y < miny then
    miny = y
   end
  end
 end

 ys = 128 / abs(maxy-miny)

end

function _draw()
 cls()

 fillp(9)
 for c = 0,#b+1 do
  line(c*128*xs, 0, c*128*xs, 127, 1)
  line(0, c*128*xs, 127, c*128*xs, 1)
 end
 fillp()

 for x,slice in pairs(cave) do
  for y in all(slice) do
   pset(x*xs, (y-miny)*xs, 9)
  end
 end

 --local xs = (graph_x2-graph_x1-2)/#cave
 --local ys = (graph_y2-graph_y1-2)/(maxp-minp)

 --rectfill(graph_x1, graph_y1, graph_x2, graph_y2, 1)

 --line(graph_x1, graph_y1, graph_x1, graph_y2, 12)
 --line(graph_x1,
  --graph_y1+(abs(minp)+1)*ys,
  --graph_x2,
  --graph_y1+(abs(minp)+1)*ys,
  --12
 --)

 --local px1,px2
 --for x = 1,128 do
  --local px = graph_x1 + 1 + (x*xs)
  --for y in all(cave[x]) do
   --local py = graph_y1 + (abs(minp)+y)*ys
   --pset(px, py, 8)
  --end
 --end

 --print(minp, graph_x1 - #(tostr(minp))*4, graph_y1 + 1, 5)
 --print(maxp, graph_x1 - #(tostr(maxp))*4, graph_y2 - 4, 6)

end


__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
