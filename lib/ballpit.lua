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
  self.total_energy=0
  self.total_energy_set=1000
  self.balls={}
  for i=1,6 do
    table.insert(self.balls,ball:new{})
  end
end

function Ballpit:update()
  for i,b in ipairs(self.balls) do
    b:update()
    b:check_boundary_collision(0,128)
    for j,b2 in ipairs(self.balls) do
      if j>i then
        b:check_collision(b2,self.total_energy,self.total_energy_set)
      end
    end
  end
  self.total_energy=0
  for _,b in ipairs(self.balls) do
    self.total_energy=self.total_energy+0.5*b.velocity*b.velocity*b.m
  end
end

function Ballpit:redraw()
  for _,b in ipairs(self.balls) do
    b:redraw()
  end
end

return Ballpit
