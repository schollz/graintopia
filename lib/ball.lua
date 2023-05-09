local Ball={}

function Ball:new(args)
  local m=setmetatable({},{__index=Ball})
  local args=args==nil and {} or args
  for k,v in pairs(args) do
    m[k]=v
  end
  m:init()
  return m
end

function Ball:init()
  self.mass_scale=10
  self.position=math.random(8,120)
  self.velocity=self.v or math.random(-100,100)/200
  self.r=self.r or math.random(3,12)
  self.m=self.r*self.r*self.mass_scale
end

function Ball:update()
  self.position=self.position+self.velocity
end

function Ball:set_r(r)
  self.r=r
  self.m=r*r*self.mass_scale
end

function Ball:check_boundary_collision(min_lim,max_lim)
  if self.position<min_lim then
    self.position=min_lim
    self.velocity=-self.velocity
  elseif self.position>max_lim then
    self.position=max_lim
    self.velocity=-self.velocity
  end
end

-- https://rhettallain.com/2019/03/09/elastic-collisions-in-1d/
function Ball:elastic(mA,mB,vA1,vB1)
  local vC1=vA1-vB1
  local vD2=(2*vC1)/(mB/mA+1)
  local vB2=vD2+vB1
  local vC2=vC1-(mB*vD2)/mA
  local vA2=vC2+vB1
  return {vA2,vB2}
end

function Ball:temperature_adjust(total_energy,total_energy_set)
  local thermoV=math.random(0,100)/100*0.2
  if total_energy<total_energy_set then
    thermoV=thermoV+1
  else
    thermoV=1-thermoV
  end
  self.velocity=self.velocity*thermoV
end

function Ball:check_collision(other,total_energy,total_energy_set)
  -- if math.abs(other.position-self.position)>=math.min(self.r,other.r) then
  if math.abs(other.position-self.position)>=2 then
    do return end
  end
  local a=self:elastic(self.m,other.m,self.velocity,other.velocity)
  self.velocity=a[1]
  other.velocity=a[2]
  if self.position<other.position then
    self.position=self.position-1
    other.position=other.position+1
  else
    self.position=self.position+1
    other.position=other.position-1
  end
  self:temperature_adjust(total_energy,total_energy_set)
  other:temperature_adjust(total_energy,total_energy_set)
  -- print(total_energy,total_energy_set)
end

function Ball:redraw(y)
  screen.circle(util.round(self.position),y,self.r/2)
  screen.level(4)
  screen.fill()
end

return Ball
