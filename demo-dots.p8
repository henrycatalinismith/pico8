pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
a = 0.01
x = 64
y = 64
n = 0
r = 48

function _update()
  x = r * cos(a * n)
  y = r * sin(a * n)
 	n = n + 1
end

function _draw()
		camera(-64, -64)
		cls(2)
		
  for i = 0,16 do
   ta = atan2(x, y) - i * 0.01
   tx = r * cos(ta)
   ty = r * sin(ta)
   circfill(tx, ty, 3, 14)
  end
  dot(0, 0, 48, 0.03, 16)
  
  print(""..x, 8, 16, 8)
  print(""..y, 8, 24, 8)
end

function dot(x, y, r, a, l)
  dx = x + r * cos(a * n)
  dy = y + r * sin(a * n)
  for i = 0,l do
    ta = atan2(dx, dy) + a * i
    tx = r * cos(ta)
    ty = r * sin(ta)
    circfill(tx, ty, 3, 10)
  end
end


