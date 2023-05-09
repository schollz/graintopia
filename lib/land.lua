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

  local update_boundary=function()
    self:update_boundary()
  end
  local params_menu={
    {id="db",name="db",engine=true,min=-96,max=16,exp=false,div=0.25,default=-6,unit="dB"},
    {id="boundary_start",name="boundary start",min=0,max=100,exp=false,div=0.01,default=0,unit="%",action=update_boundary},
    {id="boundary_width",name="boundary width",min=0,max=100,exp=false,div=0.01,default=100,unit="%",action=update_boundary},
    {id="total_energy",name="energy",min=1,max=10000,exp=true,div=10,default=100,unit="K",action=function() self:update_energy() end},
  }
  params:add_group("LAND "..self.id,#params_menu)

  for _,pram in ipairs(params_menu) do
    local formatter=pram.formatter
    if formatter==nil and pram.values~=nil then
      formatter=function(param)
        return pram.values[param:get()]..(pram.unit and (" "..pram.unit) or "")
      end
    end
    local pid=self.id..pram.id
    params:add{
      type="control",
      id=pid,
      name=pram.name,
      controlspec=controlspec.new(pram.min,pram.max,pram.exp and "exp" or "lin",pram.div,pram.default,pram.unit or "",pram.div/(pram.max-pram.min)),
      formatter=formatter,
    }
    params:set_action(pid,function(x)
      if pram.engine then
        engine.set_val(self.id,pram.id,x)
      elseif pram.action then
        pram.action(x)
      end
    end)
  end

  self.bars=self.bars or {2,2,2}
  self.ballpits={}
  for i,v in ipairs(self.bars) do
    table.insert(self.ballpits,ballpit_:new{num=v*2})
  end
  self:update_energy()
  self:update_boundary()
end

function Land:pget(pname)
  return params:get(self.id..pname)
end

function Land:pset(k,v)
  return params:set(self.id..k,v)
end

function Land:pdelta(k,v)
  return params:delta(self.id..k,v)
end

function Land:update_boundary()
  for _,bp in ipairs(self.ballpits) do
    bp.boundary={self:pget("boundary_start"),self:pget("boundary_start")+self:pget("boundary_width")}
  end
end

function Land:update_energy()
  for _,bp in ipairs(self.ballpits) do
    bp.total_energy_set=self:pget("total_energy")
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
  screen.rect(self:pget("boundary_start"),0,1,64)
  screen.fill()
  screen.rect(self:pget("boundary_start")+self:pget("boundary_width"),0,1,64)
  screen.fill()
end

return Land






