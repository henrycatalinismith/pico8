pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
--pakpok
--by st33d

--Utils

--globals

--flags
f_player = shl(1, 0)--us
f_wall = shl(1, 1)--hard surface
f_trap = shl(1, 2)--area we scan for ids
f_ledge = shl(1, 3)--hard surface only when going down
f_crate = shl(1, 4)--pushable box, causes bugs
f_puck = shl(1, 5)--kickable box
f_stop = shl(1, 6)--stops crates
--pico 8 doesn't use flags this high, so it works for out-of-bounds
f_outside = shl(1, 8)
--everything except crates ignores these
f_trapstop = bor(f_trap,f_stop)

--physical objects
blokmap = {x=0,y=0,w=16,h=16}--defines room boundaries
dropdamp = 0.98--default falling friction
grav = 0.37--set g on a blok to simulate gravity
minmove = 0.1--avoid micro-sliding, floating point error can lead to phasing
poppwr = 5.6--power of pop-jump

us = nil--the player

levels={
  {x=0,y=32,w=16,h=32},--intro - 1
  {x=0,y=16,w=16,h=16},--spikes - 2
  {x=16,y=0,w=16,h=32},--crumble,slabs - 3
  {x=32,y=16,w=16,h=48},--gliding - 4
  {x=16,y=32,w=16,h=32},--poppa - 5
  {x=32,y=0,w=16,h=16},--crate - 6
  {x=64,y=48,w=16,h=16},--spittas - 7
  {x=64,y=16,w=16,h=32},--poppa tight - 8
  {x=48,y=32,w=16,h=32},--spitta skills - 9
  {x=64,y=0,w=16,h=16},--crate skills - 10
  {x=48,y=0,w=16,h=32},--fast slabs - 11
  {x=128-16,y=48,w=16,h=16}--end - 10
  ,{x=0,y=0,w=16,h=16}--test
}


--add to print out debug
debug = {}
-- the coordinates of the upper left corner of the camera
cam_x,cam_y = 0,0
backcol=12
frames=0
fadep=1
transition=nil--screen fade transition
level=1
--level=#levels

-- screen shake offset
shkx,shky = 0,0
-- screen shake speed
shkdelay,shkxt,shkyt=2,2,2

-- based on https://github.com/jonstoler/class.lua
-- i removed the getter setters, no idea if that
-- broke it but it seems to still work
classdef = {}

-- default (empty) constructor
function classdef:init(...) end

-- create a subclass
function classdef:extend(obj)
  local obj = obj or {}
  local function copytable(table, destination)
    local table = table or {}
    local result = destination or {}
    for k, v in pairs(table) do
      if not result[k] then
        if type(v) == "table" and k ~= "__index" and k ~= "__newindex" then
          result[k] = copytable(v)
        else
          result[k] = v
        end
      end
    end
    return result
  end
  copytable(self, obj)
  obj._ = obj._ or {}
  local mt = {}
  -- create new objects directly, like o = object()
  mt.__call = function(self, ...)
    return self:new(...)
  end
  setmetatable(obj, mt)
  return obj
end

-- create an instance of an object with constructor parameters
function classdef:new(...)
  local obj = self:extend({})
  if obj.init then obj:init(...) end
  return obj
end

function class(attr)
  attr = attr or {}
  return classdef:extend(attr)
end



-- for when you need to send a list of stuff to print
function joinstr(...)
  local args = {...}
  local s = ""
  for i in all(args) do
    if type(i)=="boolean" then
      i = i and "true" or "false"
    end
    if s == "" then
      s = i
    else
      s = s..","..i
    end
  end
  return s
end

function pick1(a,b)
  if rnd(2)>1 then
    return a
  end
  return b
end

--print to debug
function debugp(...)
  add(debug,joinstr(...))
end

function add2(obj, ...)
  local args = {...}
  for table in all(args) do
    add(table, obj)
  end
end

-- method is a function(c,r)
function forinrect(x,y,w,h,method)
  for c=x,(x+w)-1 do
    for r=y,(y+h)-1 do
      method(c,r)
    end
  end
end

function fadepal(_perc)
  local p=flr(mid(0,_perc,1)*100)
  local kmax,col,dpal,j,k
  dpal={0,1,1, 2,1,13,6,
           4,4,9,3, 13,1,13,14}
  for j=1,15 do
   col = j
   kmax=(p+(j*1.46))/22
   for k=1,kmax do
    col=dpal[col]
   end
   if j==12 then backcol=col end--set background col
   pal(j,col)
  end
 end


--transitions
transit=class()

function transit:init(swap,delay)
  self.active,self.dir,self.swap,self.delay,self.t=true,1,swap,delay,0
end

function transit:upd()
  self.t+=self.dir
  if self.t==self.delay then
    self.swap()
    self.dir=-1
  elseif self.t==0 then
    self.active=false
  end
  fadepal(1/self.delay*self.t)
end

--Game
--init----------------------
function _init()
  createlevel(level)
  transition=transit(nil,30)
  transition.dir,transition.t=-1,30--fade in
end

function createlevel(n)
  --setting lists in here for efficient reset
  blox = {}--physics list
  chkpnts = {}--checkpoints
  spikes={}--spike shine
  airspikes={}--air spike shine
  --gfx
  effects={}
  mideffects={}
  backeffects={}
  levelnum=nil
  
  blokmap=levels[n]
  --look for map sprites we can convert to a blok
  local function create(c,r,sp)
    sp = sp or mget(c,r)
    local b = nil
    if sp == 1 then
      mset(c,r,0)
      us = player(c,r)
      b=us
    elseif sp >= 4 and sp <= 7 then
      mset(c,r,0)
      b=slab(c,r,sp)
    elseif sp == 38 or sp==39 then
      mset(c,r,0)
      b=slab(c,r,sp)
    elseif sp == 12 or sp==44 then
      if sp==44 then
        sp=12
        mset(c,r,24)--spikes behind crate
        add(spikes,{x=c*8,y=r*8})
      else mset(c,r,0) end
      --crate
      b=blok(c*8,r*8,8,8,f_crate,bor(f_trap,f_ledge),sp)
      b.pushmask,b.g,b.dy = bor(f_crate,f_player),grav,dropdamp
      b.momignore=f_trap
    elseif sp == 16 then
      b=puck(c,r,sp)
    elseif sp == 56 then
      b=poppa(c,r,sp)
    elseif sp == 19 or sp==20 then
      mset(c,r,0)
      b=spitta(c,r,sp)
    elseif sp == 26 then
      mset(c,r,0)
      add(chkpnts,chkpnt(c,r))
    elseif sp==24 then
      add(spikes,{x=c*8,y=r*8})
    elseif sp==28 then
      add(airspikes,{x=c*8,y=r*8})
    elseif not levelnum and sp==63 then
      levelnum={x=c*8,y=r*8}
    end
    if b then
      add(blox,b)
    end
  end
  forinrect(blokmap.x,blokmap.y,blokmap.w,blokmap.h,create)
  cam_x,cam_y=us:cam()
  
  flrsharps=sharps(spikes,{99,99,100,100,100,101,101,101,101,102,102,103,103})
  airsharps=sharps(airspikes,{88,88,88,104,104,104,104,105,105,106,106,107,107})
  
end

--update----------------------
function _update()
  
  if transition then return end
  
  -- clear colision data
  for a in all(blox) do
    a.touchx,a.touchy = nil,nil
  end
  
  -- simulate
  if(us.active)us:upd()--player 1st for feels
  
  --update checkpoints
  for c in all(chkpnts) do
    c:upd()
  end
  
  for a in all(blox) do
    if(a ~= us and a.active) a:upd()
  end
  
  -- garbage collect
  local good,i = {},1
  for a in all(blox) do
    if a.active then
      good[i] = a
      i += 1
    end
  end
  blox=good
  
  frames+=1
  
end

--draw----------------------
function _draw()
  
  if transition then
    transition:upd()
    if not transition.active then
      transition=nil
      showlevelnum=128
    end
  end
  
  cls(backcol)
  
  -- update camera position
  local x,y = us:cam()
  local f = 0.25
  local scroll_x,scroll_y = (x-cam_x)*f,(y-cam_y)*f
  cam_x += scroll_x
  cam_y += scroll_y
  
  local cx,cy=cam_x+shkx, cam_y+shky
  camera(cx,cy)
  -- cloud lines
  rectfill(cx,cy,cx+127,cy+4,7)
  rectfill(cx,cy+6,cx+127,cy+9,7)
  rectfill(cx,cy+12,cx+127,cy+13,7)
  rectfill(cx,cy+17,cx+127,cy+17,7)
  
  -- draw map
  backeffects=draw_active(backeffects)
  x,y = blokmap.x*8,blokmap.y*8
  
  for c in all(chkpnts) do
    c:draw()
  end
  
  map(blokmap.x,blokmap.y,x,y,blokmap.w,blokmap.h)
  --draw the level number if present
  if levelnum then
    local lvls=#levels-2
    local s = (level<10 and "0"..level or ""..level).."/"..(lvls<10 and "0"..lvls or ""..lvls)
    print(s,levelnum.x+2,levelnum.y+2,1)
    print(s,levelnum.x+1,levelnum.y+1,4)
  end
  flrsharps:draw()
  airsharps:draw()
  --draw a rect of ground under map for screenshake to see
  y += blokmap.h*8
  rectfill(x,y,x+blokmap.w*8,y+8,5)
  mideffects=draw_active(mideffects)
  -- draw blox
  for a in all(blox) do
    if a.active then
      if(a~=us)a:draw()
      --a:drawdbg()
    end
  end
  if(us.active)us:draw()
  
  effects=draw_active(effects)
  
  --update screen shake
  if shkxt > 0 then
    shkxt-=1
    if shkxt == 0 then
      local sn = sgn(shkx)
      if sn > 0 then
        shkx = -shkx
      else
        shkx= -(shkx+1)
      end
      shkxt=shkdelay
    end
  end
  if shkyt > 0 then
    shkyt-=1
    if shkyt == 0 then
      local sn = sgn(shky)
      if sn > 0 then
        shky = -shky
      else
        shky= -(shky+1)
      end
      shkyt=shkdelay
    end
  end
  
  -- print out values added to debug
  pal()
  local total,ty,good=#debug,0,{}
  for i=1,total do
    local s = debug[i]
    print(s,1+cam_x,1+cam_y+ty,0)
    ty += 8
    if(i > total-15) add(good, s)
  end
  debug = good
  
end

-- set screen shake
function shake(x,y)
  if(abs(x)>abs(shkx)) shkx,shkxt=x,shkdelay+1
  if(abs(y)>abs(shky)) shky,shkyt=y,shkdelay+1
end

-- garbage collect drawings on the fly
function draw_active(table)
  local good,i = {},1
  for a in all(table) do
    if a.active then
      a:draw()
      good[i] = a
      i += 1
    end
  end
  return good
end




--Engine
-- aabb recursive moving entity
blok = class()
blokn = 0--track instances of blok for debugging

-- x,y,w,h: bounds
-- flag: a pico 8 map flag
-- ignore: flags we want this blok to ignore
-- sp: sprite
function blok:init(x,y,w,h,flag,ignore,sp)
  self.active,self.x,self.y,self.w,self.h,self.flag,self.ignore,self.sp=
    true,x or 0,y or 0,w or 8,h or 8,flag or 0,ignore or 0,sp or 1
  self.vx,self.vy,self.dx,self.dy,self.touchx,self.touchy=
    0,0,0,0,nil,nil
  self.flipx,self.flipy=false,false
  self.pushmask,self.crushmask,self.momignore = 0,0,nil
  --parent and child carrying, mom and kids
  self.mom,self.kids,self.g = nil,{},0
  blokn+=1
  self.n=blokn
end

--update
function blok:upd()
  --move x, then y, allowing us to slide off walls
  --avoid micro-sliding, floating point error can cause phasing
  if abs(self.vx) > 0.1 then
    self:movex(self.vx)
  end
  if abs(self.vy) > 0.1 then
    self:movey(self.vy)
  end
  --apply damping
  self.vx*=self.dx
  self.vy*=self.dy
  --fall
  if abs(self.g)~=0 then
    if not self.mom then
      self.vy+=self.g
    else
      local m=self.mom
      --check mom is still there
      if not m.movex then
        if mget(m.x/8,m.y/8)~=m.sp then
          self.mom=nil
        end
      end
    end
  end
end

function blok:movex(v)
  local x,y,w,h = self.x,self.y,self.w,self.h
  local edge,obstacles = v>0 and x+w or x,{}
  if v>0 then
    obstacles=getobstacles(x+w,y,v,h,self.ignore,self)
    sort(obstacles,rightwards)
  elseif v<0 then
    obstacles=getobstacles(x+v,y,abs(v),h,self.ignore,self)
    sort(obstacles,leftwards)
  end
  if #obstacles>0 then
    for ob in all(obstacles) do
      local obedge=v>0 and ob.x or ob.x+ob.w
      --break if v reduced to no overlap
      if (v>0 and obedge > edge+v) or (v<0 and obedge < edge+v) then break end
      local shdmove = (edge+v)-obedge--how far should it move?
      self.touchx=ob
      --push?
      if band(ob.flag, self.pushmask)>0 and ob.movex then
        local moved,crush=ob:movex(shdmove),band(ob.flag,self.crushmask)>0
        if abs(moved) < abs(shdmove) then
          if crush then--won't budge, destroy?
            if ob.death then ob:death(self) end
          else v -= shdmove-moved end
        end
      else
        v -= shdmove
      end
      --quit or shdmove will work in reverse
      if(abs(v)<000.1)break
    end
  end
  
  self.x+=v
  
  --have i lost a parent?
  if self.mom then
    local p=self.mom
    if self.x>=p.x+p.w or self.x+self.w<=p.x then
      if p.delkid then
        p:delkid(self)
      else self.mom = nil end
    end
  end
  
  --move children
  if #self.kids>0 then
    local kids=self.kids
    if v>0 then
      for i=#kids,1,-1 do
        kids[i]:movex(v)
      end
    elseif v<0 then
      for i=1,#kids do
        kids[i]:movex(v)
      end
    end
  end
  
  return v
end

--jumping up thru ledges and moving plaforms
--makes this bit very hacky
function blok:movey(v)
  local x,y,w,h = self.x,self.y,self.w,self.h
  local edge,obstacles = v>0 and y+h or y,{}
  if v>0 then
    --ledge landing hack when moving down
    obstacles=getobstacles(x,y+h,w,v,self.momignore or self.ignore,self)
    sort(obstacles,downwards)
  elseif v<0 then
    obstacles=getobstacles(x,y+v,w,abs(v),self.ignore,self)
    sort(obstacles,upwards)
  end
  if #obstacles>0 then
    for ob in all(obstacles) do
      local obedge=v>0 and ob.y or ob.y+ob.h
      --break if v reduced to no overlap
      if (v>0 and obedge > edge+v) or (v<0 and obedge < edge+v) then break end
      --how far should it move?
      local shdmove,skip = (edge+v)-obedge,false
      --is there a special rule for landing on it?
      if v>0 and self.momignore then
        --skip this block if we were below its top
        if y+h>ob.y then skip=true end
      end
      if not skip then
        self.touchy=ob
        local moved,crush=0,band(ob.flag,self.crushmask)>0
        --push?
        if band(ob.flag, self.pushmask)>0 and ob.movey then
          
          moved=ob:movey(shdmove)
          
          --add to children if slower than us
          if v<0 and v<ob.vy and ob.mom ~= self then
            self:addkid(ob)
          end
          if abs(moved) < abs(shdmove) then
            --crush
            if crush then--won't budge, destroy?
              if ob.death then ob:death(self) end
            else
              v -= shdmove-moved
            end
          end
        else v -= shdmove end
        
        --let's say if i can't crush it, it's floor
        if shdmove > 0 and not crush then
          if self.mom then self:delmom() end
          if ob.addkid then ob:addkid(self)
          else
            self.mom=ob
            self.vy=0--cancel velocity
          end
        end
        
        --quit or shdmove will work in reverse
        if(abs(v)<000.1)break
      end
    end
  end
  
  self.y+=v
  
  --have i lost a parent?
  if self.mom then
    if self.y+self.h<self.mom.y then
      self:delmom()
    end
  end
  --move children down? (up is handled by push)
  if v>0 and #self.kids>0 then
    for b in all(self.kids) do
      if b.active then b:movey(v) end
    end
  end
  
  return v
end

function blok:addkid(b)
  if b.mom then b:delmom() end
  b.mom = self
  b.vy = 0
  add(self.kids, b)
  --need to sort children so they're moved without colliding
  sort(self.kids, rightwards)
end

function blok:delkid(b)
  b.mom = nil
  del(self.kids, b)
end

--check there is a parent before calling this
function blok:delmom()
  if self.mom.delkid then self.mom:delkid(self)
  else self.mom = nil end
end

-- clear parent and children - usually called during death()
function blok:divorce()
  if self.mom then self:delmom() end
  for b in all(self.kids) do
    b.mom,b.vy = nil,0
  end
  self.kids = {}
end

function blok:jmp(p)
  self:divorce()
  local s = -p*0.8--magic jumping ratio that i accidentally got stuck on
  self.vy=s
  self.dy=dropdamp
end

function blok:center()
  return self.x+self.w*0.5,self.y+self.h*0.5
end

function blok:intersectsblok(a)
  return not (a.x>=self.x+self.w or a.y>=self.y+self.h or self.x>=a.x+a.w or self.y>=a.y+a.h)
end

function blok:intersects(x,y,w,h)
  return not (x>=self.x+self.w or y>=self.y+self.h or self.x>=x+w or self.y>=y+h)
end

function blok:contains(x,y)
  return x>=self.x and y>=self.y and x<self.x+self.w and y<self.y+self.h
end

function blok:within(x)
  return x>=self.x and x<self.x+self.w
end


--this fails at long distance
--the overflow causes 0,0,0 to be returned, watch for it
function blok:normalto(bx,by)
  local ax,ay = self:center()
  local vx,vy = (bx-ax),(by-ay)
  local len = sqrt(vx*vx+vy*vy)
  if(len > 0) return vx/len,vy/len,len
  return 0,0,0
end

--x,y:position or x is an blok, v:speed, d:damping
function blok:moveto(x,y,v,d)
  local tx,ty,len = self:normalto(x,y)
  if(v > len) v = len
  self.vx,self.vy,self.dx,self.dy = tx*v,ty*v,d,d
end

--check for traps
function blok:trapchk()
  local traps = mapobjects(self.x,self.y,self.w,self.h,bnot(f_trap))
  local endgame = false
  if #traps > 0 then
    -- found traps
    for t in all(traps) do
      local c,r,s = flr(t.x/8),flr(t.y/8),t.sp
      -- floor spikes?
      if s==24 then
        --hit when going down
        if self.y+self.h > t.y+2 and self.y+self.h<=t.y+t.h and blok.within(t,self.x+self.w/2) and
          (self.vy>grav*2 or (self.y+self.h < t.y+t.h-2 and self.vy>0))
        then
          self:death(t)
        end
      -- air spikes?
      elseif s==28 then
        --be nice
        if blok.contains(t,self:center()) then
          self:death(t)
        end
      end
      if not self.active then break end
    end
  end
end

function blok:death(src)--source of death
  self:divorce()
  self.active=false
end

function blok:drawdbg()
  rect(self.x,self.y,self.x+self.w-1,self.y+self.h-1,3)
 if self.mom then
   local m=self.mom
   line(self.x+self.w/2,self.y+self.h/2,m.x+m.w/2,m.y+m.h/2,3)
 end
 print(self.n,self.x,self.y-8,7)
end

function blok:dustx()
  dust((self.flipx and self.x+self.w or self.x),
          self.y+self.h/2+rnd(self.h/2),
          2,pick1(6,7))
end
 
function blok:dusty()
  dust(self.x+self.w/2,self.y+self.h,2,pick1(6,7))
end

function blok:updanim()
  self.anim:draw()
  if not self.anim.active then self.anim=nil end
end

function blok:draw(sp,offx,offy)
  sp,offx,offy = sp or self.sp,offx or -4,offy or -4
  local x,y=offx+self.x+self.w*0.5,offy+self.y+self.h*0.5
  spr(sp,x,y,1,1,self.flipx,self.flipy)
end

-- collision utils

function centertile(c,r,w,h)
  w,h = (w or 0),(h or 0)
  return (4+c*8)-w*0.5,(4+r*8)-h*0.5
end

function lookblokx(x,y,w,h,v,source)
  for b in all(blox) do
    if b~=source and ((v>0 and b:intersects(x+w,y,v,h)) or
      (v<0 and b:intersects(x+v,y,abs(v),h))) then
      return b
    end
  end
  return nil
end

function lookbloky(x,y,w,h,v,source)
  for b in all(blox) do
    if b~=source and ((v>0 and b:intersects(x,y+h,w,v)) or
      (v<0 and b:intersects(x,y+v,w,abs(v)))) then
      return b
    end
  end
  return nil
end

--return a table of objects describing tiles on the map
--ignore: do not return anything with this flag
--result: a table of results to add to
function mapobjects(x,y,w,h,ignore,result)
  result,ignore = result or {},ignore or 0
  local xmin, ymin = flr(x/8),flr(y/8)
  -- have to deduct a tiny amount, or we end up looking at a neighbour
  local xmax, ymax = flr((x+w-0.0001)/8),flr((y+h-0.0001)/8)
  local rxmin,rymin,rxmax,rymax = blokmap.x,blokmap.y,blokmap.x+blokmap.w-1,blokmap.y+blokmap.h-1
  for c=xmin,xmax do
    for r=ymin,ymax do
      --bounds check
      if c<rxmin or r<rymin or c>rxmax or r>rymax then
        add(result, {x=c*8,y=r*8,w=8,h=8,flag=f_outside,sp=0})
      else
        local sp=mget(c,r)
        local f = fget(sp)
        if f > 0 and band(f, ignore) == 0 then
          add(result, {x=c*8,y=r*8,w=8,h=8,flag=f,sp=sp})
        end
      end
    end
  end
  return result
end

function getblox(x,y,w,h,ignore,source)
  local result = {}
  ignore = ignore or 0
  for a in all(blox) do
    if a ~= source and a.active then
      if band(ignore, a.flag)==0 and a:intersects(x,y,w,h) then
        add(result, a)
      end
    end
  end
  return result
end

--return all blox or tiles in an area,
--excluding source from the list and anything with a flag it ignores
--tiles returned are basic versions of blox
function getobstacles(x,y,w,h,ignore,source)
  local result = {}
  ignore = ignore or 0
  mapobjects(x,y,w,h,ignore,result)
  for a in all(blox) do
    if a ~= source and a.active then
      if band(ignore, a.flag)==0 and a:intersects(x,y,w,h) then
        add(result, a)
      end
    end
  end
  return result
end



-- sorting comparators
function rightwards(a,b)
  return a.x>b.x
end
function leftwards(a,b)
  return a.x<b.x
end
function downwards(a,b)
  return a.y>b.y
end
function upwards(a,b)
  return a.y<b.y
end

--insertion sort
function sort(a,cmp)
  for i=1,#a do
    local j = i
    while j > 1 and cmp(a[j-1],a[j]) do
        a[j],a[j-1] = a[j-1],a[j]
    j = j - 1
    end
  end
end

--it's you murphy
player = blok:extend()

function player:init(c,r)
  self.sc, self.sr = c,r -- spawn column & row
  add(chkpnts,chkpnt(c,r))--drop a checkpoint
  c,r = c*8+1,r*8+2
  blok.init(self,c,r,6,6,f_player,bor(f_trapstop,f_ledge),1)
  self.dx,self.dy,self.speed,self.g=
    0.4,dropdamp,0.8,grav
  self.pushmask = bor(f_puck,f_crate)
  --same as our normal self.ignore, but without f_ledge
  --this hack allows us to collide with only the top of
  --an f_ledge and ignore the rest
  --(i would implement all directions, but pico8 m8)
  self.momignore = f_trapstop
  self.coyote=0
  self.jmpheld=false
  self.jmphold=0
  self.camy=self.y+self.h/2
  self.launched=false
  self.exit=false
end

function player:upd()
  
  if self.exit then
    if self.x<self.exit.x+10 then
      self.x+=1
    else
      if not transition then
        transition=transit(function()
          if level<=#levels then
            level+=1
            createlevel(level)
          end
        end,30)
      end
    end
    return
  end
  
  --trap check
  self:trapchk()
  if not self.active then return end
  
  -- move
  if btn(0) then
   self.vx -= self.speed
   self.flipx=true
  end
  if btn(1) then
   self.vx += self.speed
   self.flipx=false
  end
  self.dy=dropdamp
  --jump curve
  --if self.vy<0 and self.jumphold<-0.1 then
  --  self.vy+=self.jumphold
  --  self.jumphold*=0.5
  --end
  local btndwn=(btn(4) or btn(5))
  if btndwn then
    if btndwn~=self.btndwn then
      sfx(3,0)--flap wings
    end
    if self.mom==nil and self.vy>=0 then
      self.dy=0.1
    end
    if self.coyote>0 and not self.jmpheld then
      self:jmp(3.1)
      sfx(2)
    end
  else
    self.jmpheld=false
    if btndwn~=self.btndwn then
      sfx(-1,0)--stop flap wings
    end
  end
  self.btndwn=btndwn
  
  --input lag
  if self.mom then self.coyote=3
  else self.coyote-=1 end
  --if we're about to push a crate, make it feel heavy
  if abs(self.vx) > minmove then
    local ob=lookblokx(self.x,self.y,self.w,self.h,self.vx)
    if ob then
      if band(ob.flag,f_crate)>0 then self.vx*=0.67 end
    end
  end
  
  if self.coyote>0 or self.vy>0 then self.camy=self.y+self.h/2 end
  
  --simulate
  blok.upd(self)
  
  if self.touchx then
    local ob=self.touchx
    if self.mom then
      if band(ob.flag,f_puck)>0 then
        if not ob.charge then
          --kick
           ob:bump(self.flipx,self)
        end
      elseif ob.sp==29 then
         self.exit=ob
         self.y=(ob.y+ob.h)-self.h
         sfx(-1,0)--stop flap wings
         sfx(6)--fanfare
      end
    end
    self.vx=0
  end
  if(self.touchy and self.touchy.mom~=self) self.vy=0
  
  
end

function player:jmp(p)
  blok.jmp(self,p)
  self.coyote=0
  self.jmpheld=true
  if p==poppwr then
    splode(self.x+self.w/2,self.y+self.h/2,5,7,effects,7)
    self.launched=true
    sfx(1)
  end
end

--where does the camera go?
function player:cam()
  local x,y = self:center()
  
  if(not self.active) x,y = centertile(self.sc,self.sr)
  --local s=64--scale of camera steps
  --x,y=flr((x+s/2)/s)*s,flr(y/s)*s
  --handle any size room of 8px units
  x = min(max(x-64, blokmap.x*8), -128+(blokmap.x+blokmap.w)*8)
  y = min(max(y-64, blokmap.y*8), -128+(blokmap.y+blokmap.h)*8)
  return x,y
end

function player:death(src)--src: source of death
  blok.death(self)
  
  --crush pop
  --pop out/in the player if the kill is unfair
  if src.crushmask and band(self.flag,src.crushmask)>0 then
    if src.touchy==self then
      local c=self.x+self.w/2
      local sandwich = {src, self.touchy}
      for b in all(sandwich) do
        --pop if center of filling is outside of bread
        if c<=b.x then
          local v = (b.x-self.w)-self.x
          local m = self:movex(v)
          if m == v and (self.x+self.w<=src.x or self.x>=src.x+src.w) then
            self.active=true
          end
        elseif c>=b.x+b.w then
          local v = (b.x+b.w)-self.x
          local m = self:movex(v)
          if m == v and (self.x+self.w<=src.x or self.x>=src.x+src.w) then
            self.active=true
          end
        end
        if self.active then break end
      end
    end
  end
  --create corpse
  if not self.active then
    self.launched=false
    splode(self.x+self.w/2,self.y+self.h/2,6,8,effects,7)
    add(effects,corpse(self,self.x,self.y,79,0,-3))
    sfx(-1,0)--stop flap wings
    sfx(5)
  end
end

function player:respawn()
  self.x,self.y,self.active,self.vy=self.sc*8,self.sr*8,true,0
  add(blox,self)
end

function player:draw()
  if self.exit then
    blok.draw(self,1+((frames/2)%2),-4,-4)
    local x,y=self.exit.x,self.exit.y
    spr(30,x,y)
    spr(mget(x/8+1,y/8),x+8,y)
  elseif (btn(4) or btn(5)) then
    local f=(frames%6)+73
    blok.draw(self,f,-4,-5)
  else
    blok.draw(self,((btn(1)or btn(0)) and 1+((frames/2)%2) or 1),-4,-4)
  end
  if self.launched then
    self:dusty()
    if self.vy>=0 then self.launched=false end
  end
  if self.anim then self:updanim() end
end




--kickable crate
puck = blok:extend()

function puck:init(c,r,sp)
  self.sc, self.sr = c,r -- spawn column & row
  mset(c,r,25)--spawn marker
  c,r = c*8+1,r*8+2
  blok.init(self,c,r,6,6,f_puck,bor(f_trapstop,f_ledge),sp)
  self.dx,self.dy,self.speed,self.g=
    0,dropdamp,2,grav
  self.pushmask = bor(f_player,f_puck)
  self.momignore = f_trapstop
  self.charge=false
  self.anim=nil
end

function puck:upd()
  --trap check
  self:trapchk()
  if not self.active then return end
  
  if self.charge then
    if self.flipx then
      self.vx -= self.speed
    else
      self.vx += self.speed
    end
  end
  --simulate
  blok.upd(self)
  if self.charge then
    if self.touchx then
      local ob=self.touchx
      local c=ob.x+ob.w/2
      if (self.flipx and c<self.x) or (not self.flipx and c>self.x) then 
        if ob==us then--and us.coyote>0 then
          self:launch(ob)
        elseif ob.sp==self.sp then
          --kick
          self.charge=false
          ob:bump(self.flipx,self)
        else
          --is it crumble?
          if ob.sp>=52 and ob.sp<=54 then
            local x,y=ob.x+ob.w/2,ob.y+ob.h/2
            for i=1,4 do
              add(effects,debris(x,y,pick1(93,94),-1+rnd(2),-2-rnd(2)))
            end
            splode(x,y,5,7,effects,7)
            sfx(9)
            mset(ob.x/8,ob.y/8,0)
          end
          --bump
          self.flipx=(not self.flipx)
          sfx(7)
        end
      end
    end
  else
    if self.mom==us then
      if us.mom then
        self:divorce()
        us.y,self.y=self.y,self.y+us.h
        us:jmp(poppwr)
      end
    end
  end
end

function puck:bump(flipx,bumper)
  --anim:init(x,y,sps,table,t)
  sfx(0)
  self.charge,self.flipx=true,flipx
  bumper.anim=anim((flipx and self.x+self.w or self.x-8), self.y+self.h-8,
  {84,84,85,85,86,86,87,87},6,flipx,bumper)
end

function puck:death()
  blok.death(self)
  self.charge,self.vx,self.vy=false,0,0
  splode(self.x+self.w/2,self.y+self.h/2,6,8,effects,7)
  add(effects,corpse(self,self.x,self.y,95,0,-3))
  sfx(5)
end

function puck:respawn()
  self.x,self.y,self.active,self.vy=self.sc*8,self.sr*8,true,0
  add(blox,self)
end

function puck:launch(ob,flipx)
  flipx=flipx or self.flipx
  ob:movey(self.y-(ob.y+ob.h))--move item to top
  self:movex(flipx and -6 or 6)--slide under
  self.vx=0
  self.charge=false
  shake(0,2)
  ---ob.y=(self.y+self.h)-ob.h--consistent  jump
  ob:jmp(poppwr)
  --splode(self.x+self.w/2,self.y+self.h/2,5,6,effects,7)
end

function puck:draw()
  if self.charge then
    blok.draw(self,self.sp+1+((frames)%2))
    self:dustx()
  else
    blok.draw(self)
  end
  if self.anim then self:updanim() end
end

--walking trap
poppa = blok:extend()

function poppa:init(c,r,sp)
  self.sc, self.sr = c,r -- spawn column & row
  mset(c,r,25)--spawn marker
  c,r = c*8,r*8+4
  blok.init(self,c,r,8,4,f_trap,bor(f_trap,f_ledge),sp)
  self.dx,self.dy,self.speed,self.g=
    0,dropdamp,0.5,grav
  self.pushmask = 0
  self.momignore = f_trapstop
  self.charge=false
end

function poppa:upd()
  --trap check
  self:trapchk()
  if not self.active then return end
  
  local tops = getblox(self.x-4,self.y-4,self.w+8,self.h+4,bor(f_trapstop,f_wall),self)
  
  if self.charge then
    if #tops>0 then
      for b in all(tops) do
        if b.y+b.h==self.y+self.h then
          local c = b.x+b.w/2
          if c>self.x and c<self.x+self.w then
            self.charge=false
            if b==us then shake(0,2)
            else
              splode(self.x+self.w/2,self.y+self.h/2,5,7,effects,7)
            end
            sfx(1)
            b:jmp(poppwr)
            b:movey(-4)--out of sensor, reattach child
          end
        end
      end
    end
  else
    if #tops>0 then
      if not self.charge then sfx(10) end
      self.charge=true
    else
      self.vx += (self.flipx and -self.speed or self.speed)
    end
  end
  --simulate
  blok.upd(self)
  
  if self.touchx then
    self.flipx=(not self.flipx)
  end
  
end

function poppa:death()
  blok.death(self)
  self.charge,self.vx,self.vy=false,0,0
  splode(self.x+self.w/2,self.y+self.h/2,6,8,effects,7)
  add(effects,corpse(self,self.x,self.y,127,0,-3))
  sfx(5)
end

function poppa:respawn()
  self.x,self.y,self.active,self.vy=self.sc*8,self.sr*8,true,0
  add(blox,self)
end


function poppa:draw()
  if self.charge then
    blok.draw(self,self.sp+2)
  else
    blok.draw(self,self.sp+((frames/2)%2))
  end
end

function poppa:drawdbg()
  rect(self.x-4,self.y-4,(self.x-4)+self.w+8,(self.y-4)+self.h+4,10)
  blok.drawdbg(self)
end

--shoots projectile
spitta = blok:extend()
spitframes={20,68,69,70,69,70,69,70,69,70,69,70,69,70,71,72}
spitframetotal=#spitframes
function spitta:init(c,r,sp)
  blok.init(self,c*8,r*8+2,8,6,f_wall,0,sp)
  self.pushmask = 0
  self.momignore = f_trapstop
  self.charge=false
end

function spitta:upd()
  local tops = getblox(self.x,self.y-2,self.w,2,bor(f_trapstop,f_wall),self)
  if #tops>0 then
    if not self.charge and tops[1].mom==self then
      self.charge=true
      sfx(11)
      local b=ball(self.x+4,self.y+2,(self.sp==19 and -2 or 2))
      add(blox,b)
    end
  else
    self.charge=false
  end
end

function spitta:draw()
  if self.charge then
    self.flipx=false
    blok.draw(self,self.sp+2)
  else
    local sp = spitframes[1+flr(frames/4)%spitframetotal]
    self.flipx=self.sp==19
    blok.draw(self,sp,-4,-5)
  end
end

ball = blok:extend()
function ball:init(x,y,vx)
  blok.init(self,x+vx*2,y,4,4,f_trap,bor(f_trapstop,f_ledge),23)
  self.dx,self.dy,self.vx,self.speed=
    1,1,vx,vx
  self.pushmask = 0
  self.momignore = f_trapstop
end
function ball:upd()
  blok.upd(self)
  if self.touchx then
    local ob=self.touchx
    for i=1,4 do
      add(effects,debris(self.x-2,self.y-2,pick1(80,81),-1+rnd(2),-2-rnd(2)))
    end
    splode(self.x+self.w/2,self.y+self.h/2,3,11,effects,10)
    if ob.bump then
      ob:bump(self.speed<0,self)
      local a=self.anim
      a.x,a.y,a.track=self.x+a.x,self.y+a.y,nil
      add(effects,self.anim)
    else
      sfx(12)
    end
    self:death()
  end
end




--all purpose crusher and moving platform
slab = blok:extend()
slabignore=bor(f_trapstop,f_ledge)
slabledgeignore=f_outside-1--ignore everything going down
function slab:init(c,r,sp)
  self.sc, self.sr = c,r -- spawn column & row
  mset(c,r,59)--spawn marker
  self.speed,self.fast=0.5,1
  blok.init(self,c*8,r*8,8,sp>=38 and 2 or 8,fget(sp),slabignore,sp)
  local push=bor(f_puck,bor(f_player,f_crate))
  self.pushmask,self.crushmask = push,push
  --stretch
  local n=c+1
  while mget(n,r)==sp do
    mset(n,r,59)
    self.w+=8
    n+=1
  end
  n=r+1
  while mget(c,n)==sp do
    mset(c,n,59)
    self.h+=8
    n+=1
  end
    
end

function slab:upd()
  --direction command check (top left)
  local traps = mapobjects(self.x,self.y,8,8,bnot(f_trap))
  local endgame = false
  if #traps > 0 then
    -- found a trap
    local t = traps[1]
    local c,r,s = flr(t.x/8),flr(t.y/8),t.sp
    -- is it a dir command?
    if (s>=8 and s<=11) or (s>=40 and s<=43) then
      local fast=1
      if s>=40 and s<=43 then
        fast,s=4,s-32
      end
      -- dir commands start at 8
      local cx,cy = self.x+4,self.y+4
      local tx,ty = centertile(c,r)
      local nsp = s-4
      if(self.sp>=38)nsp+=32
      if(abs(tx-cx)==0 and abs(ty-cy)==0) self.sp,self.fast,sp=nsp,fast,nsp
    end
  end
  -- move
  local sp,speed = self.sp,self.speed*self.fast
  if (sp==4) self.vx -= speed
  if (sp==5) self.vx += speed
  if (sp==6) self.vy -= speed
  if (sp==7) self.vy += speed
  if sp==38 then
    self.vy -= speed
    self.ignore=slabignore
  elseif sp==39 then
    self.vy+=speed
    self.ignore=slabledgeignore
  end
  blok.upd(self)
end

function slab:draw(x,y,big)
  x,y,sp=x or self.x,y or self.y,self.sp
  spr(sp,x,y)
  if (frames/4)%2<1 then
    if sp>=38 then spr(sp+28,x,y-1)
    else spr(sp+60,x,y) end
  end
  if not big and self.w>8 then
    for xb=self.w-8,8,-8 do
      self:draw(x+xb,y,true)
    end
  end
  if not big and self.h>8 then
    for yb=self.h-8,8,-8 do
      self:draw(y,y+yb,true)
    end
  end
end




-- just a sprite from the sheet
anim = class()
function anim:init(x,y,sps,t,flipx,track)
  self.active,self.x,self.y,self.sps,self.i,self.t,self.flipx,self.track=
    true,(track and x-track.x or x),(track and y-track.y or y),sps,1,t or 0,flipx,track
end
function anim:draw()
  local sp = self.sps[self.i]
  if self.track then
    if(sp)spr(sp,self.x+self.track.x,self.y+self.track.y,1,1,self.flipx)
  else
    if(sp)spr(sp,self.x,self.y,1,1,self.flipx)
  end
  self.i+=1
  --if self.i>#self.sps then self.i=1 end
  if self.t > 0 then
    self.t-=1
    if self.t <= 0 then
      self.active=false
    end
  end
end

debris=class()
function debris:init(x,y,sp,vx,vy)
  self.active,self.x,self.y,self.sp,self.vx,self.vy,self.flipx=
    true,x,y,sp,vx,vy,(rnd(2)>1 and true or false)
end
function debris:draw()
  spr(self.sp,self.x,self.y,1,1,self.flipx)
  self.x+=self.vx
  self.y+=self.vy
  --apply damping
  self.vx*=dropdamp
  self.vy*=dropdamp
  self.vy+=grav
  if self.y>cam_y+128 then self.active=false end
end

sharps=anim:extend()
function sharps:init(list,sps)
  anim.init(self,0,0,sps,#sps+30+flr(rnd(60)))
  self.list=list
  self.n=flr(rnd(#list))+1
end
function sharps:next()
  local n,list=self.n,self.list
  if #list>1 then
    repeat
      n+=flr(rnd(#list))+1
      if(n>#list)n=1
    until list[n]~=self.ob
    self.ob,self.x,self.y=list[n],list[n].x,list[n].y
  end
  self.n,self.t,self.active,self.i=n,#self.sps+80+flr(rnd(60)),true,1
end
function sharps:draw()
  if #self.list==0 then return end--safety
  if self.ob then
    anim.draw(self)
    if not self.active then
      self:next()
    end
  else self:next() end
end

corpse=debris:extend()
function corpse:init(body,x,y,sp,vx,vy)
  self.body,self.stg=body,0
  debris.init(self,x,y,sp,vx,vy)
end
function corpse:draw()
  if self.stg==2 then--fly up
    self.y-=4
    self.v*=1.15
    self.x+=self.v
    if self.y<cam_y then
      self.active=false
    end
    spr(108+(frames%4),self.x,self.y,1,1,self.flipx)
  elseif self.stg==1 then--carry body to respawn
    self.y-=2
    local targ=self.body.sr*8
    if self.y>targ+32 then
      self.y-=2
    end
    self.body.y=self.y+6
    if self.y+6<targ then
      self.body:respawn()
      self.stg,self.v=2,rnd(0.6)-0.3
      sfx(8,2)
    end
    self.body:draw()
    spr(108+(frames%4),self.x,self.y,1,1,self.flipx)
  else--fall
    debris.draw(self)
    if not self.active then
      --pull body up screen
      self.stg,self.active=1,true
      self.x,self.y=self.body.sc*8,(cam_y+128<self.body.sr*8 and blokmap.h*8 or cam_y+128)
      self.body.x=self.x
    end
  end
end
    

dust=class()
function dust:init(x,y,r,c)
  self.active,self.x,self.y,self.r,self.c=true,x,y,r,c
  add(mideffects,self)
end
function dust:draw()
  circfill(self.x,self.y,self.r,self.c)
  self.r-=0.2
  self.y+=0.1
  if self.r<=0 then self.active=false end
end

-- bang
splode = class()
function splode:init(x,y,r,col,table,colw)
  self.active,self.x,self.y,self.r,self.t,self.col,self.colw,table=
    true,x or 64,y or 64,r or 8,0,col or 7,colw or 7,table or effects
  -- add to a list for drawing
  add(table, self)
end
function splode:draw()
  local t,x,y,r,col,colw = flr(self.t*0.5),self.x,self.y,self.r,self.col,self.colw
  if t == 0 then
    --black frame to make it pop
    circfill(x,y,r,colw)
    circfill(x,y,r-1,9)
  elseif t < 2 then
    --full
    circfill(x,y,r,col)
    circfill(x,y,r-1,colw)
  else
    --shrink
    if t <= r then
      for rf=t,r do
        if rf==r then
          circ(x,y,rf,col)
        else
          circ(x,y,rf,colw)
        end
      end
    else
      self.active = false
    end
  end
  self.t+=1
end

--checkpoint
chkpnt=class()
function chkpnt:init(c,r)
  self.c,self.r,self.on,self.y=c,r,false,r*8
end

function chkpnt:upd()
  if not self.on then
    if us.active then
      local x,y=us:center()
      if flr(x/8)==self.c and flr(y/8)==self.r then
        self.on=true
        us.sc,us.sr=self.c,self.r
        sfx(4,2)
        for c in all(chkpnts) do
          if c~=self then
            c.on=false
          end
        end
      end
    end
    if self.y<self.r*8 then
      self.y+=1
    end
  else
    if self.y>(self.r-1)*8 then
      self.y-=1
    end
  end
end

function chkpnt:draw()
  local x,y,h=self.c*8,self.y,(self.r+1)*8-self.y
  if h>8 then
    spr(98,x,y+8,1,(h-8)/8)--vine
    h=8
  end
  if self.on then
    spr(27,x,y,1,h/8)
  else
    spr(26,x,y,1,h/8)
  end
end

__gfx__
000000000000000000000000bb33b3b33bb33b333bb33b333bb33b333bb33b33000000000000000000000000000000006b333bb3bb3b3b33bb3b3b33bb3b3b33
00000000088808000888080033344433544554455445544554455445544554450000d000000d0000000000000000000064444443555555500555555005554555
0070070088881880888818805444444554a8854554588a4554a11a4554588545000dd000000dd000000dd0000000000054000045554404000044040000005445
000770008888188088881880544444455518885555888155558888555588885500ddd000000ddd0000dddd000dddddd054000045400000000000000000000005
000770008881118088811180544444455518885555888155558888555588885500ddd000000ddd000dddddd000dddd0054000045000000000000000000000000
00700700811a1a10811a1a105454455554a8854554588a455458854555a11a55000dd000000dd00000000000000dd00054000045000000000000000000000000
00000000101010100101010055544555555554555555545555555455555554550000d000000d0000000000000000000054444445000000000000000000000000
00000000000000000000000055555555055555500555555005555550055555500000000000000000000000000000000055555556000000000000000000000000
0998980000000000000000000088880000888800000000000000000000000000000000000000000000000000000880000000700054b3b44554b3b44500000000
98898980099898000998980008888e8008e888800a8a88800888a8a0000000000000000000077000000830000008800007306070531113550000035500000000
888989809889898098898980a1a8eee88eee8a1a1118eee88eee8111000aa00000070007007aa70000898300088aa88000633630511111350000003500000000
81111110888989808889898011111e8888e1111100188e8888e8810000aab30000060006007a97000038b300088a9880763bb300b11111350000003500000000
111a1a10888989808889898013b3188888813b310018888888888100003b330000730073000770000003300000088000003b3367311111b5000000b500000000
01010100111a1a10111a1a1013331888888133310318888888888130000330000063006300003000000030000008830003633600511111550000005500000000
01010100010101001010101011311880088113111113883003883111000000000333003300003300000033000000300007060370b11111350000003500000000
000000000000000000000000b33388300388333b000000000000000000000000033b033b00003000000030000000300000070000311111b5000000b500000000
bbb3b3b3bb33b3b33b3bb3bbb3bbb3bbb3bbb3bb33bbbbbbbb3b3b33bb3b3b33000000000000000000000000000000006b333bb3544444453b3bb3bb00000000
b3344433333444335333333355334433333b33335333b33304a11a4004588540000d00d00d00d000000dd0000d0000d064444443544444453444444300000000
b3444445544444455444433554444443344344435443344b008888000088880000d00d0000d00d0000d00d0000d00d0054070745555455453444444500000000
34444445544444455554444555444443554444455544444500888800008888000d00d000000d00d00d0000d0000dd00054060645555455455554554500000000
3444444554444445555444455544444555444445554444550008800000a11a000d00d000000d00d0000dd0000d0000d054737345555455555554555500000000
545454555454455555555445554554450555544555445550000000000000000000d00d0000d00d0000d00d0000d00d0054636345555555555555555500000000
5554545555544555555555555555544505555445554455500000000000000000000d00d00d00d0000d0000d0000dd00054444445055555500555555000000000
55555555555555555555555555555555000555555555500000000000000000000000000000000000000000000000000055555556005555500055555000000000
544444455444444554444445544444453b3bb3b3555515551555155154444445000000000000000000000000000dd00000000000000000000000000055555555
54544445544445555444444554554445543313455445154554455445544444450000000000000000000000000000d00000000000000000000000000055555555
54544445544445555554555554554445544555555445555554555445555455458989898989898989000000000000000000000000000000000000000055555555
5555455555555555555455555555455555551511555515115555155155545545088888800888888000000000dd0dd00d00000000000000000000000055555555
05554555555555555554555555554550115155551151555511515555555455550111a1a00111a1a000000000d00dd0dd00000000000000000000000055555555
05555555555555555555555555555550555515455555154555555445555555550010101001010100000000000000000000000000335000000000054555555555
0555555555555555555555555555555054455545544555455445544505555550000000000000000089898989000d000000000000344500000000544355555555
000555555555555555555555555550005555155555551555155515510055555000000000000000001888a8a1000dd00000000000b5b530300030353b55555555
00000000000000000000000000000000008888000088880000888800008888000088880088800088888000888880008888800088888000888880008800000000
0000000000000000000000000008800008e8888008e8888008e8888008e8888008e8888088880888888808888888088888880888888808888888088810101010
00a1880000881a0000a11a00008888008eee8a1a8eee8a1a8eee8a1a8eee8a1a8eee8a1a70880880008808800088088060880880008808800088088081121210
0011888008881100001111000088880088e1111188e1111188e1111188e1111188e1111107081806000818006008180006081807000818007008180088811180
0011888008881100008888000011110088813b318881131188811811888118118881181100111110661111170611111700111110771111160711111688881880
00a1880000881a000088880000a11a00888113118881181188888888888188818881838106111117771111160711111607111116661111170611111788881880
000000000000000000088000000000000888888808888888088888880888181808813b31601a1a10001a1a10701a1a10701a1a10001a1a10601a1a1008880800
000000000000000000000000000000000388333b0388333b0388333b0388333b03811b1101010100010101000101010001010100010101000101010000000000
00000000000000000000000000000000000006770000677000000670000000600000000000000000000000000000000000000000000000000000000001010100
00000000000000000000000000000000000060670000067700000067000000060000000000000000000000000000000000000000000000000000000001010100
00000000000000000000000000000000000007070000006700000007000000070000700050000050000000000000000000000000005551000055500011111110
000ba000000ab00000000000000000000000007700000677000000070000000000777000053b3500003b3000603b3060003b3000054455100554551081121210
000330000003b0000000000000000000000000770000067700000007000000000007770000111000551115500611160066111660054555100544551088898980
00000000000000000000030000000030000007070000006700000007000000070007000006a1a60066a1a66005a1a50055a1a550015551000155111098898980
000000000000000000300300000000b0000060670000067700000067000000060000000060000060000000005000005000000000001110000011100009989800
000000000000000000300b03030b03b3000006770000677000000670000000600000000000000000000000000000000000000000000000000000000000000000
000dd000000000000003000000000000000000000000000000000000000000000000700000007000000070000000700000000000000000000000000000000000
000d00000000000000b0000000000000000000000000000000000000000000000770707007707070077070700770707000090000000900000009000000090000
000dd0000000000000330000000000000000000000070007000700070007000700777770007777700070777000000070600a0060000a0000000a0000000a0000
0000d000ddddd00d000b000000000000000000000007000700070007000700077777770077700700777000007700000006090600000900007009007000090000
0000d000d00ddddd00033000000000000000000000770077007700770070007000777777007007770000077700000077008a8000668a8660078a8700778a8770
000dd0000000000000b3300000000000000700070077007700770077007000700777770007777700077707000700000007888700778887700688860066888660
000d00000000000000b3000000070007000700070777007707700070070000000707077007070770070707700707077070111070001110006011106000111000
000dd000000000000003000000070007007700770777077707700770070007000007000000070000000700000007000000a1a00000a1a00000a1a00000a1a000
000dd000000000000000000055555555555555555555555555555555555555555555555555555555555555555555555555555555555555550000000000000000
0000d00000000000000000005aaaaa8555aaaa855aa85aa855aaaa85511151515551115111511151115115555511151115111511151155550000000000000000
0000d00000000000003bb0005aa88aa85aa88aa85aa8aa855aa88aa8515151515551515151515151515151555515555155155515551515550000000000101010
000dd000ddd00ddd3b33330b5aa85aa85aa85aa85aaaa8555aa85aa8511551115551115111511551515151555511155155115511551515550000000001112120
000dd000d0dddd0d033003305aaaaa885aaaaaa85aaaa8555aa85aa8515155155551515151515151515151555555155155155515551515550000000008888880
000d000000000000000000005aa888855aa88aa85aa8aa855aa85aa8511155155551515151515151115151555511155155111511151155550000000089898989
000d000000000000000000005aa855555aa85aa85aa88aa858aaaa88555555555555555555555555555555555555555555555555555555550000000000000000
000dd000000000000000000058885555588858885888588855888885555555555555555555555555555555555555555555555555555555550000000000000000
1300000000000000000000000000001323137313731373137313731313131313130000000000000000000000000000231313f3f3f32313330000000000001010
133300000000e383002500d300000313000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1300000025350000000000000000002313130013001300130013001300000013138181810000818181818181818181232313233303330000000000003510d113
230000000000f0d0f0d0f0d035000023000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
13000002d0f0320000000000000000d1233300730073007300730013000000d113d0e0e00000f0d0e0e0f0d0e0e0f02313233300000000000000100010f04213
230000000000000000000000e0000023000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1300f033000013000000000000000222130000000000000000000073d0e0f0231300000000000000000000000000002323330000000000000010e00000000013
23000000000000000000000000e0f023000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
13d0e000000013000000000000002313130000000000000000000000000000131381818181818181810000a100000013230000000000000000000000f0d00013
13000000000000000000004300000013000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
13000000010013000000000000000323132500838181812535813525818181231322d0e0f0d0e0e0e00000e20000002313000000000000001000000000000013
1300250100000000000000e200350013000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
13003500e0f01300000000000000001323d0f0d0e0f0d0e0e0e0f0d0e01212232313000000000000008181818181812323d00041000000000000000000010013
23d0e0f0d000000000000000e0e0f023000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
13d0e0f0d0f0d20000000000000000131300e0a10000000000000000000313232323000000000000000212222212121323004222221000c100c1000000e0f013
230000c1e30000830025d30000000013000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
13000000000000000000000000000013230000e2000000000000000000000323232300c1000000c1001333000000001323000000d20000000000000000000023
13000000f0d0e0f0d0f0d0a100000023000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1300010000f03200000000000000002323d0000000000000000000000000001323130000000000000013000035310023233500011000000000000000a1310013
2300000000000000000000e00035c113000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
131222121222130000000000000000131300000000000000c100000000b0b0132313000000000000002300000222122313d0e0f0d00000000000000002221223
230000000000000000000000f0d0f023000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
132313131323330025000001002635131300832500e2000000000000000607232323000000000000002300001313132323001010000000000000000003330013
23000000000000000000000000000023000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
23231323330000f0d0f022222222221313d0e0f0d000000000000000000706131323c10000c10000c12300000323231323101041000000000000000000010013
23350100000000000000e20035000023000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1333000000003500e0000313131323131300000000000000a100000000707023232300000000000000130000000003131310f0d00000000000000000e0e0f013
23d0f0d000000000000000f0d0e0f013000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
230000000000e00000000000000000131300000000000000e000000000a0a0232313000000000000001300000000001313d02500a1258181818181818181c113
13c1250000e383351000d3000000c113000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
13000000e0000000000000000000001313000000000000e00000000000b0b0232313c100c100c100c1230041250000131352d0f0d0e0f042121252e242221213
13123212221222221212122212221213000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2300000000e0000000000000000000232300000000000000e0000000006060232313000000000000002312223200001313000000e03500000000000000000013
137300000000b000000000232500d113000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
13000000f0d00000000000000001002313000000000000000000000000070623232300c100c100c100232323130000132300000000e000000000000000000013
230100000000700000312523d0f04223000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
13350000000000000000000000e0f023230000000000c1e0e0e0c100000607131323000000000000001323231300251323000001000000000000000031000013
23d0e00000000700e0f0d07300000023000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
23d000000012000000350000022222231300000000000000e000000000a0a0232313818100000081811313131312122323d0f0d0e000000000000000f0d00013
230000000000a0003500e00043434323000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
13e035000003221222221212f3f3f323130000a100000000c1000000350232131323123200008102121333007300032313000000000000000000000000e0f013
130000a1422212122222122213f3f3f3000000000000000000000000000000000000000000000000000000000000000000000091000000b10000009100000000
231222d0000000000313131313131323130000023200008300000000022313132323231300810213330000000000002323009040408000009050508000000013
13810002000000000000000000000013000000000000000000000000000000000000000000000000000000000000000000000212320002123200023200000000
13132300e0000000000000000000001323d0f0d0e0e0e0f0d0e0f0d0e00003231313233300421333000000000000002323d00000000000000000000000000013
23d0812300000000000001a100000023000000000000000000000000000000000000000000000000000000000000000000001300000000230000130032000000
1323130000e0000000000000250000131300e0000000000000000000000000231300000000000000000000000000002313000000000000000000000000000013
2300f0730025350000e0f0d00000f013000000000000000000000000000000000000000000000000000000000000000000002332000000130000230013000000
231313d03500000000000000e0000013230000e200000000000000000000002323000000a135000000000100250000131325000000003500000001002535c123
13d0006343f0d000002500c131e0c123000000000000000000000000000000000000000000000000000000000000000000001300000000230000230013000000
23233300e0000000000000e00000002323d0000000000000000000000100001323d00002221222320000021222121213131222524252d0e0b0e0f04252e24213
23d0f0d0e0e0f0d0f0d0e0f0d0e0f01300000000000000000000000000000000000000000000000000000000000000000000d200000002133200030033000000
131300000000000000250000000000131300000000120000000000f0d0e0f0132300f00313231333000003232313132323330000000000007200000000000023
230000000000000000000000e2d0f023000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1333000000000000001200000100351313000000f0330000000000000000002323d0000000000000000000003500d1132300000000000000a000000000000013
2300004100000000000000000001e023000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000f0221212121212221313d0e0f0d000000000000200358300131300e0000000000000000000e0f042132300004100000000e000000000013513
23d0e0f0d00000000000000000e0f023000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0010000000000000133747573767571313000000000000000000131212121223130000e00000000000000000000000132300f0d0000000000000000000e0f013
2300000000e000000000000000000013000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
12123235000100352313231323131313130010002500000083001313f3f3f32323d0e00025000000350035002500c12323d0250000102500000035000000c113
13000035000025e0000010003500c113000000000000000000000000000000000000000000000000000000000000000012320000000010000001000000000222
131313223030122223778797a7b7c7d7132222221212122212221323231313132322122222122212121212221212221313123212221212221212122222221213
13123212222222221212122222221213000000000000000000000000000000000000000000000000000000000000000023232212222212221212222212222323
__label__
5444444577777777777777777777777777777777bb3b3b3377777777777777777777777777777777777777777777777777777777777777777777777754444445
54444445777777777777777777777777777777777555555777777777777777777777777777777777777777777777777777777777777777777777777754444445
55545555777777777777777777777777777777777744747777777777777777777777777777777777777777777777777777777777777777777777777755545555
55545555777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777755545555
55545555777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777755545555
55555555cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc55555555
55555555777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777755555555
55555555777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777755555555
54444445777777777777777777777777bb3b3b33bb3b3b3377777777777777777777777777777777777777777777777777777777777777777777777754444445
54444555777777777777777777777777755545555555555777777777777777777777777777777777777777777777777777777777799898777777777754444445
54444555cccccccccccccccccccccccccccc54455544c4cccccccccccccccccccccccccccccccccccccccccccccccccccccccccc9889898ccccccccc55545555
55555555ccccccccccccccccccccccccccccccc54ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc8889898ccccccccc55545555
55555555777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777811111177777777755545555
55555555777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777111a1a177777777755555555
55555555ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc1c131cccccccccc55555555
55555555ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc1c131cccccccccc55555555
54444445ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccbb3b3b33bb3b3b3354444445
54444555777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777777755555577555455554444445
54444555cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc44c4cccccc544555545555
55555555ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc555545555
55555555cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc55545555
55555555cccccc3ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc55555555
55555555ccccccbccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc55555555
55555555c3cbc3b3cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc55555555
54444445bb3b3b33ccccccccccccccccccccccccbb33b3b3ccccccccccccccccccccccccccccccccccccccccccccccccbbb3b3b33b3bb3bb3b3bb3bb54444445
544444455555555ccccccccccccccccccccccccc33344433ccccccccccccccccccccccccccccccccccccccccccccccccb3344433533333335333333354444445
555455555544c4cccccccccccccccccccccccccc54444445ccccccccccccccccccccccccccccccccccccccccccccccccb3444445544443355444433555545555
555455554ccccccccccccccccccccccccccccccc54444445cccccccccccccccccccccccccccccccccccccccccccccccc34444445555444455554444555545555
55545555cccccccccccccccccccccccccccccccc54444445cccccccccccccccccccccccccccccccccccccccccccccccc34444445555444455554444555545555
55555555cccccccccccccccccccccccccccccccc54544555cccccccccccccccccccccccccccccc3ccccccccccccccccc54545455555554455555544555555555
55555555cccccccccccccccccccccccccccccccc55544555ccccccccccccccccccccccccccccccbccccccccccccccccc55545455555555555555555555555555
55555555cccccccccccccccccccccccccccccccc55555555ccccccccccccccccccccccccc3cbc3b3cccccccccccccccc55555555555555555555555555555555
54444445bb3b3b33cccccccccccccccccccccccc544444453b3bb3bbbb33b3b33b3bb3bb3b3bb3bbbb33b3b3bb33b3b355555555555555555555555554444445
54444555c555555ccccccccccccccccccccccccc5454444553333333333444335333333353333333333444333334443354445445555454455445555554444445
54444555cc44c4cccccccccccccccccccccccccc5454444554444335544444455444433554444335544444455444444554141541554515415541555555545555
55555555cccccccccccccccccccccccccccccccc5555455555544445544444455554444555544445544444455444444554141541554155415541555555545555
55555555ccccccccccccccccccccccccccccccccc555455555544445544444455554444555544445544444455444444554141541554155415541555555545555
55555555cccccccccccccc3cccccccccccccccccc555555555555445545445555555544555555445545445555454455554441444545154445444555555555555
55555555ccccccccccccccbcccccccccccccccccc555555555555555555445555555555555555555555445555554455555111511151555111511155555555555
55555555ccccccccc3cbc3b3ccccccccccccccccccc5555555555555555555555555555555555555555555555555555555555555555555555555555555555555
54444445bb33b3b33b3bb3bbbb3b3b33cccccccccccccccccccccccccccccccc5444444554444445544444455444444554444445544444455444444554444445
5444444533344433533333335555555ccccccccccccccccccccccccccccccccc5454444554444555544445555444455554444555544445555444455554444445
5554555554444445544443355544c4cccccccccccccccccccccccccccccccccc5454444554444555544445555444455554444555544445555444455555545555
5554555554444445555444454ccccccccccccccccccccccccccccccccccccccc5555455555555555555555555555555555555555555555555555555555545555
555455555444444555544445ccccccccccccccccccccccccccccccccccccccccc555455555555555555555555555555555555555555555555555555555545555
555555555454455555555445ccccccccccccccccccccccccccccccccccccccccc555555555555555555555555555555555555555555555555555555555555555
555555555554455555555555ccccccccccccccccccccccccccccccccccccccccc555555555555555555555555555555555555555555555555555555555555555
555555555555555555555555ccccccccccccccccccccccccccccccccccccccccccc5555555555555555555555555555555555555555555555555555555555555
544444455444444554444445ccccccccbb3b3b33cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc54444445
544445555444455554444445ccccccccc555555ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc54444555
544445555444455555545555cccccccccc44c4cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc54444555
555555555555555555545555cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc55555555
555555555555555555545555cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc55555555
555555555555555555555555cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc55555555
555555555555555555555555cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc55555555
555555555555555555555555cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc55555555
544444455444444554444445ccccccccccccccccbb3b3b33cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc54444445
544445555444444554444555ccccccccccccccccc555555ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc54444555
544445555554555554444555cccccccccccccccccc44c4cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc54444555
555555555554555555555555cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc55555555
555555555554555555555555cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc55555555
555555555555555555555555ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc3cccccccccccccccccc55555555
555555555555555555555555cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc3cc3cccccccccccccccccc55555555
555555555555555555555555cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc3ccbc3cccccccccccccccc55555555
544444455444444554444445bb3b3b33ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccbb3b3b33cccccccccccccccc54444445
5444444554444555544445555555555cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc555555ccccccccccccccccc54444555
5554555554444555544445555544c4cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc44c4cccccccccccccccccc54444555
5554555555555555555555554ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc55555555
555455555555555555555555cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc55555555
555555555555555555555555cccccccccccccc3ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc55555555
555555555555555555555555ccccccccccccccbccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc55555555
555555555555555555555555ccccccccc3cbc3b3cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc55555555
544444455444444554444445ccccccccbb3b3b33ccccccccccccccccccccccccccccccccccccccccccccccccbb3b3b33cccccccccccccccccccccccc54444445
544444455444444554554445ccccccccc555555cccccccccccccccccccccccccccccccccccccccccccccccccc555555ccccccccccccccccccccccccc54444445
555455555554555554554445cccccccccc44c4cccccccccccccccccccccccccccccccccccccccccccccccccccc44c4cccccccccccccccccccccccccc55545555
555455555554555555554555cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc55545555
55545555555455555555455ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc55545555
55555555555555555555555ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc55555555
55555555555555555555555ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc55555555
555555555555555555555ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc55555555
5444444554444445cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc54444445
5444455554444555cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc54444555
5444455554444555cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc54444555
5555555555555555cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc55555555
5555555555555555cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc55555555
5555555555555555ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc3cccccccccccccccccccccccccccccccccccccccccc55555555
5555555555555555cccccccccccccccccccccccccccccccccccccccccccccccccccccccccc3cc3cccccccccccccccccccccccccccccccccccccccccc55555555
5555555555555555cccccccccccccccccccccccccccccccccccccccccccccccccccccccccc3ccbc3cccccccccccccccccccccccccccccccccccccccc55555555
5444444554444445ccccccccccccccccccccccccccccccccccccccccccccccccccccccccbb33b3b3cccccccccccccccccccccccccccccccccccccccc54444445
5444455554554445cccccccccccccccccccccccccccccccccccccccccccccccccccccccc33344433ccccccccccccccccc99898cccccccccccccccccc54444555
5444455554554445cccccccccccccccccccccccccccccccccccccccccccccccccccccccc54444445cccccccccccccccc9889898ccccccccccccccccc54444555
5555555555554555cccccccccccccccccccccccccccccccccccccccccccccccccccccccc54444445cccccccccccccccc8889898ccccccccccccccccc55555555
555555555555455ccccccccccccccccccccccccccccccccccccccccccccccccccccccccc54444445cccccccccccccccc8111111ccccccccccccccccc55555555
555555555555555ccccccccccccccccccccccccccccccccccccccccccccccccccccccccc54544555cccccccccccccccc111a1a1ccccccccccccccc3c55555555
555555555555555ccccccccccccccccccccccccccccccccccccccccccccccccccccccccc55544555ccccccccccccccccc1c131ccccccccccccccccbc55555555
5555555555555ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc55555555ccccccccccccccccc1c131ccccccccccc3cbc3b355555555
ccccccccccc88cccccccccccccccccccccccccccccccccccccccccccbb3b3b333b3bb3bbbb33b3b3bb33b3b3bb33b3b3bb33b3b3bb33b3b33b3bb3bb54444445
ccccccccccc88cccccccccccccccccccccccccccccccccccccccccccc55545555333333333344433333444333334443333344433333444335333333354444555
ccccccccc88aa88ccccccccccccccccccccccccccccccccccccccccccccc54455444433554444445544444455444444554444445544444455444433554444555
ccccccccc88a988cccccccccccccccccccccccccccccccccccccccccccccccc55554444554444445544444455444444554444445544444455554444555555555
ccccccccccc88ccccccccccccccccccccccccccccccccccccccccccccccccccc5554444554444445544444455444444554444445544444455554444555555555
ccccccccccc883cccccccccccccccccccccccccccccccccccccccccccccccccc5555544554544555545445555454455554544555545445555555544555555555
cccccccccccc3ccccccccccccccccccccccccccccccccccccccccccccccccccc5555555555544555555445555554455555544555555445555555555555555555
cccccccccccc3ccccccccccccccccccccccccccccccccccccccccccccccccccc5555555555555555555555555555555555555555555555555555555555555555
ccccccccccc3cccccccccccccccccccccccccccccccccccccccccccccccccccc5444444555555555555555555555555555555555555555555555555554444445
ccccccccccbccccccccccccccccccccccccccccccccccccccccccccccccccccc544445555aaaaa8555aaaa855aa85aa85aaaaa8555aaaa855aa85aa854444555
ccccccccc888c8cccccccccccccccccccccccccccccccccccccccccccccccccc544445555aa88aa85aa88aa85aa8aa855aa88aa85aa88aa85aa8aa8554444555
cccccccc8888188ccccccccccccccccccccccccccccccccccccccccccccccccc555555555aa85aa85aa85aa85aaaa8555aa85aa85aa85aa85aaaa85555555555
cccccccc8888188ccccccccccccccccccccccccccccccccccccccccccccccccc555555555aaaaa885aaaaaa85aaaa8555aaaaa885aa85aa85aaaa85555555555
cccccccc8881118ccccccccccccccccccccccccccccccccccccccccccccccccc555555555aa888855aa88aa85aa8aa855aa888855aa85aa85aa8aa8555555555
cccccccc811a1a1ccccccccccccccccccccccccccccccccccccccccccccccccc555555555aa855555aa85aa85aa88aa85aa8555558aaaa885aa88aa855555555
cccccccc1c131c1ccccccccccccccccccccccccccccccccccccccccccccccccc5555555558885555588858885888588858885555558888855888588855555555
bb33b3b3bb33b3b3b3bbb3bbcccccccccccccccccccccccccccccccccccccccc5444444554444445544444455444444554444445544444455444444554444445
333444333334443355334433ccccccccccccccccc99898cccccccccccccccccc5444444554444555544444455444455554444445544445555444455554444555
544444455444444554444443cccccccccccccccc9889898ccccccccccccccccc5554555554444555555455555444455555545555544445555444455554444555
544444455444444555444443cccccccccccccccc8889898ccccccccccccccccc5554555555555555555455555555555555545555555555555555555555555555
544444455444444555444445cccccccccccccccc8111111ccccccccccccccccc5554555555555555555455555555555555545555555555555555555555555555
545445555454455555455445cccccc3ccccccccc111a1a1ccccccccccccccc3c5555555555555555555555555555555555555555555555555555555555555555
555445555554455555555445ccccccbcccccccccc1c131ccccccccccccccccbc5555555555555555555555555555555555555555555555555555555555555555
555555555555555555555555c3cbc3b3ccccccccc1c131ccccccccccc3cbc3b35555555555555555555555555555555555555555555555555555555555555555
5444444554444445544444453b3bb3bbbb33b3b3bb33b3b3bb33b3b33b3bb3bb5444444555555555555555555555555555555555555555555555555555555555
54444555544445555444455553333333333444333334443333344433533333335444444551115151555111511151115111511555551115111511151115115555
54444555544445555444455554444335544444455444444554444445544443355554555551515151555151515151515151515155551555515515551555151555
55555555555555555555555555544445544444455444444554444445555444455554555551155111555111511151155151515155551115515511551155151555
55555555555555555555555555544445544444455444444554444445555444455554555551515515555151515151515151515155555515515515551555151555
55555555555555555555555555555445545445555454455554544555555554455555555551115515555151515151515111515155551115515511151115115555
55555555555555555555555555555555555445555554455555544555555555555555555555555555555555555555555555555555555555555555555555555555
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555

__gff__
0001010202020202040404041008080820202002020202200404040404020200020202020202080804040404100202000202020202020202202020000040400202020202020202020201010101010101000000000000000000000000000202200000000000000000000000000000000000000002020202020202020202020020
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
31010101010101012d0101010101313131010101011d32010101010101010131310101313131010100313231000000313100000000000000313200000000323131000000003700000000000000003131000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
32010101010101010101010101011d32310101010e012d0101010101010101313101013031320101531d32330000003232000000000000003132530000001d3132531400000000000000001000531d32000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3201010101010101010101010e012e323101010101533601010101010b0b0b3231010101303201010f22330000000032320000000000000030330d0e0e0f2432320d0e0e000000000020242121212132000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
320101010e0e0e01010101010101013231010101010101010101012360706032320101010131010e003100000000003232000000000000000000000000000032320d000e000000000032000000000032000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
31010e010101010101010101010101313101010101010101010101316060703231010101013701010f37000000100031315310291a6171617161716105285331313e2c1818183d1a002d000000000031000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3101010e01010e0e01010e0101010131310101010101010101010132607070313201010101010e010d000000000e0f3232250d0e0e0e0f0d0e0f0d0e0f2422323121222221220d0f0d00000000000031000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
323301010101010101010101010101323201011a010e0101010101307070603232010101010101010000000f0d0e0f31320000000e000000000000000000003132313131323100000000000000000032000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
32010101010101010101010101010131310b010101100134343401536070603131013e010c0c181818183d001a000f3131000904716171282961716105080b3132313f3f3f3100000000001a10525331000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
310101010101010e01010101010e013231700132010e01010e0e01016060703232010e0e01010e0e0f0d0e000e001c31310000000000000000000000000027313131313131320000000e0f0d0e0e0f32000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
32010e01010e0101010101010101013132600132010101010101013206060631320101010101010100000000000e0031320000000018181818181818531a0a3132323132323318000000000000000031000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3201011a2401010101010101313f3f323270013201010101010101300a0a0a323101010101010101000000000000003231000000002e0d0f2e0d0f24250d00313200000000002e1818183e3800523d32000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
321801200101010101010101010101323260013101010101010101012401013232013e10010c01011a003d18181818323100530e0e2b00002b00002b2b000031320000000000000f0d0e0f0d0e0e0f32000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
320118320101010101011001013131323260013601010101011053010130313231010e0e012e01010d0f21212221213232000e0000600000700000607000003132530010520000000000000000000032000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
32000f3700525300000e0f0d0e00003131703436090561080f0d0e0e0000003132000000000c00000e00313f3f3f3231310d0e00000600000600000606005231320d0e0f0d0000000000000000000031000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
310d0036340f0d000052001c0e1352313206062100000000000000000e1a0031310001002023005300003131323132313252001a000a52000a52000a0a530f31311c53013e182c18182c18182c183d31000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
31212322222222222121212222222131320a00321818181818181818220d0b3231212221313222212121323232323231310d0b0f22222121212222212221213131212322222222222121212222222131000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
31000000000000002d0000000000313231212231212221220d0e0e0f310b60313100000000000000000000000000003131006000303f3f3f323131313231323131000000000000000000000000003231000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
31000000000000000000000000001d32313f3f3f32323133000000003270703131000100530000000000000000000032320027002b00002b00002b000000003132000000000000000000000053001d32000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3200000000100000000000000e0f2e31310000000000000000000000320660323121222223000000000000000000003132000a000700000700000700000000323200000000000000000000000e0f2432000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
320d1a000e0e0e00000000000000003131000000000000000000000032700732313f3f3f330018180000000000000032320d00000a00000a00000a000000003232000000000000000000000000000032000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
32000e18181818181818000052000032320000000000000000001000326070323100000000180f0d0018181800000031320009040404047161710852000000323100000000003e5200383d5200000031000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
31220d0e0f0d0e0e0f0d0e1c0e1c0f3132097105080904610820212132700a3231000000000e0018180e0f0d0018183231000000000000000000002e001a53313100000000000f0d0f0d0e2e00000031000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3133000000000000000000000000003132000e000000000000353235310a0f31310000000000000f0d000000000e0f313200000000000000000000000e0e0e31320000000000000000000036000e0f32000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
310000000000001a0000000010005232310d0e0000000000003036353300003131000000000000000000001a0053003231002b2b29040404617161710800003132000000000000000000003600000031000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
310000000000000e0000000f0d0e0f313100000e521a53000000353500005231310000000018181818182e0d0e0f2432310070600000000000000000000000323100101a000000000000003500005332000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
320d0e00000e00000000000000000031310d0e0f0d0e0f22222121212121213131181800000f0d0e0f0d0000000000323200607000001c001c001c0000000031320d0e0f0d0000000000002022212131000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3223005200000000000000000000003232000000000e00363133000000303232310d0e0000000000000000000000003132002727000000000000000000000032321c000e3e00380052533d30323f3f3f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
313203032300000000000000000000323200000e0000003033000000000000313100000000000000000000000000003232527060000000000000000000000031320e0f0d0e0f0d0e0e0f0d0000000032000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
31000000302300000000000000100032310d0000000000000000000000000031311818001a5352000000000000000032310d0a0a000000000000000053100031321c0000000000000000000000000032000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3200000000181800000000000f0d0f3132000000000e00340000000000000032310d0e0f0d0f0d0000000000000000323200000000000000000000000e0e0f32321c0100000000000000000000000031000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
31000100202203231818181818202232315300010000343534000010005200323100000000001818181818181800003132000129040404617161280052001c3201013e380053003d1a00100000000031000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
32222203313f3f3f2221222121323232312221212222212122222221212221313100000000000f0d0e0e0f0d0e000032322123212221212221212122222221010121232122250d0e0f0d0f2422222131000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100002e620251301d1100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00010000106301b540205501e54019520000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000161001610026200562009630116000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00040002006100f600026000a60000000186001760025600256002660026600266002660026600276002860000000000000000000000000000000000000000000000000000000000000000000000000000000000
00080000035300152004510085200b510197201d720017000170001500015000150004500065000750007500095000c50022500285002d5000000000000000000000000000000000000000000000000000000000
000200002b210282202421020220216400f2201a61008220116100961006610046200260001610006000060000600006000060000600006000060000600006000060000600006000000000000000000000000000
000c0000035300152004510085200b510197201772015750197400070015750015001c750065000750007500095000c50022500285002d5000000000000000000000000000000000000000000000000000000000
000100000c03009020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000600001c01000700170100000020010000000220000000022000220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100001462023620156300d62000620176101e610216201c620186200e6100461015600106000d6100a61007600036000161000600006100160004610006000362000600036100060001600000000000000000
000300000d11007110030200003006300003000030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0002000016520023000a050000000d7200d70011730107000c0100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000100000061001600066200860011630000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
