pico-8 cartridge // http://www.pico-8.com
version 16
__lua__

menu = {
  "linear",
  "easein",
  "easeout",
  "easeinout",
}

easing = {
  linear = function(t)
    return t
  end,

  easein = function(t)
    return t * t
  end,

  easeout = function(t)
    return t*(2-t)
  end,

  easeinout = function(t)
    if t < 0.5 then
      return 2*t*t
    else
      return -1+(4-2*t)*t
    end
  end,
}

function _init()
  tick = 1
  updated = 1
  index = 1
  points = {}
  old = {}

  local name = menu[index]
  for x = 0,64 do
    local t = x/64
    local y = easing[menu[index]](t) * 64
    old[x] = 0
    points[x] = y
  end

end

function _update()
  local changed = false
  if btnp(2) then
    index = index - 1
    if index == 0 then
      index = #menu
    end
    changed = true
  elseif btnp(3) then
    index = index + 1
    if index > #menu then
      index = 1
    end
    changed = true
  end

  if changed == true then
    local name = menu[index]
    for x = 0,64 do
      local t = x/64
      local y = easing[name](t) * 64
      old[x] = points[x]
      points[x] = y
    end
    updated = tick
  end

  tick = tick + 1
end

function _draw()
 local graph_size = 65

 local graph_x1 = 10
 local graph_y1 = 32
 local graph_x2 = graph_x1 + graph_size
 local graph_y2 = graph_y1 + graph_size

 local menu_x1 = graph_x2 + 4
 local menu_y1 = graph_y1
 local menu_x2 = menu_x1 + 40
 local menu_y2 = graph_y2

 local since = tick - updated

 cls(7)

 local pts = {}
 if since > 30 then
   pts = points
 else
   pts = old
   for x,p in pairs(pts) do
     local t = since / 30
     local diff = points[x] - old[x]
     --local t = x/64
     pts[x] = old[x] + easing[menu[index]](t) * diff
   end
 end

 for x,p in pairs(pts) do
   circfill(graph_x1 + x, graph_y2 - p, 1, 14)
 end

 for x,p in pairs(pts) do
   pset(graph_x1 + x, graph_y2 - p, 8)
 end

 rectfill(graph_x1 - 1, graph_y1, graph_x1, graph_y2, 13)
 rectfill(graph_x1 - 1, graph_y2, graph_x2, graph_y2 + 1, 13)

 local i = 1
 for name in all(menu) do
   local item_x1 = menu_x1
   local item_y1 = menu_y1 + (i-1) * 8
   local item_x2 = menu_x2
   local item_y2 = item_y1 + 6
   local item_color = 14

   if index == i then
     rectfill(item_x1, item_y1, item_x2, item_y2, 14)
     item_color = 7
   end
   print(name, item_x1 + 1, item_y1 + 1, item_color)

   i = i + 1
 end
end
