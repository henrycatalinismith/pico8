pico-8 cartridge // http://www.pico-8.com
version 16
__lua__
n = 0
function _update()
 	n = n + 1
end

function _draw()
		cls(2)
		
  matryoshka(
  { -- matryoshka
  	x=64,
  	y=64,
  	t=1,
  }, { -- ring
  }, { -- circle
  	r1=0.6,
  	a=0.02,
  	t=4,
  }, { -- dot
  	r1=8,
  	r2=2,
  	a=-0.015,
  	l=32,
  	t=11,
  })
end

function tan(a) return sin(a)/cos(a) end

function asin(y)
 return atan2(sqrt(1-y*y),-y)
end

function matryoshka(m, r, c, d)
  for i = 0,m.t do
    r2 = r
    r.x = m.x
    r.y = m.y
    r.r1 = (d.r1 + d.r2 * 2) * i * 2
    r.t = 3
 
    ta = (d.r1 + d.r2) * i
    tb = ta
    tc = d.r2

    cosa = (
      tb^2 + tc^2 - ta^2
    ) / (
      2 * tb * tc
    )
    a = asin(cosa)
    print(d.r2)
    --print(a)
    r.a = a
    --b2 + c2 �☉★ a22bc
    o = tan(2 * d.r1 * i, d.r1)
    print(0)
    ring(r, c, d)
  end
end

function ring(r, c, d)
  for i = 1,r.t do
  		c2 = c
  		c2.x = r.x
  		  + r.r1
  		  * cos(r.a * i)
    c2.y = r.y
      + r.r1
      * sin(r.a * i)
    circle(c2, d)
  end
end

function circle(c, d)
  for i = 1,c.t do
   d2 = d
   d2.x = c.x
   	 + d.r1
     * (c.r1 * cos(c.a * i))
   d2.y = c.y
   	 + d.r1
     * (c.r1 * sin(c.a * i))
   d2.c = ({0, 7, 6, 8, 9, 0})[i]
   dot(d2)
 end
end 


function dot(d)
  dx = d.r1 * cos(d.a * n)
  dy = d.r1 * sin(d.a * n)
  for i = 0,d.l do
    ta = atan2(dx, dy)
      + d.a
      * i
    circfill(
      d.x + d.r1 * cos(ta),
      d.y + d.r1 * sin(ta),
      d.r2,
      d.c
    )
  end
end


