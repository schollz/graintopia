local Ballpit={}

function Ballpit:new(args)
  local m=setmetatable({},{__index=Ballpit})
  local args=args==nil and {} or args
  for k,v in pairs(args) do
    m[k]=v
  end
  m:init()
  return m
end

function Ballpit:init()
  self.num=self.num or 6
  self.total_energy=0
  self.total_energy_set=self.total_energy_set or 100
  self.balls={}
  for i=1,self.num do
    table.insert(self.balls,ball:new{})
  end
end

function Ballpit:update()
  for i,b in ipairs(self.balls) do
    b:update()
    b:check_boundary_collision(params:get(self.id.."boundary_start"),params:get(self.id.."boundary_start")+params:get(self.id.."boundary_width"))
    for j,b2 in ipairs(self.balls) do
      if j>i then
        b:check_collision(b2,self.total_energy,params:get(self.id.."total_energy"))
      end
    end
  end
  self.total_energy=0
  for _,b in ipairs(self.balls) do
    self.total_energy=self.total_energy+0.5*b.velocity*b.velocity*b.m
  end
end

function Ballpit:positions()
  local p={}
  for _,b in ipairs(self.balls) do
    table.insert(p,b.position)
  end
  return p
end

function Ballpit:redraw()
  for _,b in ipairs(self.balls) do
    b:redraw()
  end
end

return Ballpit
