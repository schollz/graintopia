local Land={}

function Land:new(args)
  local m=setmetatable({},{__index=Land})
  local args=args==nil and {} or args
  for k,v in pairs(args) do
    m[k]=v
  end
  m:init()
  return m
end

function Land:init()
  self.boundary={1,30}
  self.bars=self.bars or {2,2,2}
  self.ballpits={}
  for i,v in ipairs(self.bars) do
    table.insert(self.ballpits,ballpit_:new{num=v*2,total_energy_set=50})
  end
  self:update_boundary()
end

function Land:update_boundary()
  for _,bp in ipairs(self.ballpits) do
    bp.boundary={self.boundary[1],self.boundary[1]+self.boundary[2]}
  end

end

function Land:delta_left(b1)
  self.boundary={self.boundary[1]+b1,self.boundary[2]}
  self:update_boundary()
end

function Land:delta_right(b1)
  self.boundary={self.boundary[1],self.boundary[2]+b1}
  self:update_boundary()
end

function Land:delta_energy(x)
  for _,bp in ipairs(self.ballpits) do
    bp.total_energy_set=bp.total_energy_set+x
  end
end

function Land:update()
  for i,bp in ipairs(self.ballpits) do
    bp:update()
  end
end

function Land:redraw()
  local y=10
  for _,bp in ipairs(self.ballpits) do
    pos=bp:positions()
    for i,_ in ipairs(pos) do
      if i%2==0 then
        screen.rect(pos[i-1],y,pos[i]-pos[i-1],6)
        screen.fill()
        -- bp.balls[i]:redraw(y+3)
        -- bp.balls[i-1]:redraw(y+3)
        y=y+9
      end
    end
  end
  screen.rect(self.boundary[1],0,1,64)
  screen.fill()
  screen.rect(self.boundary[1]+self.boundary[2],0,1,64)
  screen.fill()
end

return Land
