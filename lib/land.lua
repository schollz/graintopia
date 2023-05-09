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
  -- setup waveformer
  self.waveform=waveform_:new()

  local update_boundary=function()
    self:update_boundary()
  end
  local params_menu={
    {id="db",name="db",engine=true,min=-96,max=16,exp=false,div=0.25,default=-6,unit="dB"},
    {id="boundary_start",name="boundary start",min=0,max=127,exp=false,div=0.5,default=0,unit="%",action=update_boundary},
    {id="boundary_width",name="boundary width",min=0,max=127,exp=false,div=0.5,default=127,unit="%",action=update_boundary},
    {id="total_energy",name="energy",min=1,max=10000,exp=true,div=10,default=100,unit="K",action=function() self:update_energy() end},
  }
  params:add_group("LAND "..self.id,#params_menu+1)
  params:add_file(self.id.."sample_file","file",_path.audio)
  params:set_action(self.id.."sample_file",function(x)
    local is_dir=function(path)
      local f=io.open(path,"r")
      local ok,err,code=f:read(1)
      f:close()
      return code==21
    end
    if x~="cancel" and util.file_exists(x) and not is_dir(x) then
      self:load(x)
    end
  end)
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
  self.players={}
  for i=1,6 do
    table.insert(self.players,{position=0,pan=0,volume=0})
  end

  for i,v in ipairs(self.bars) do
    table.insert(self.ballpits,ballpit_:new{id=self.id,num=v*2})
  end
  self:update_energy()
  self:update_boundary()
end

function Land:pget(pname)
  return params:get(self.id..pname)
end

function Land:praw(pname)
  return params:raw(self.id..pname)
end

function Land:pset(k,v)
  return params:set(self.id..k,v)
end

function Land:pdelta(k,v)
  return params:delta(self.id..k,v)
end

function Land:player_set(l,k,v)
  self.players[l][k]=v
end

function Land:update_boundary()
  if self:pget("boundary_start")+self:pget("boundary_width")>127 then
    self:pset("boundary_width",127-self:pget("boundary_start"))
  end
end

function Land:update_energy()
  for _,bp in ipairs(self.ballpits) do
    bp.total_energy_set=self:pget("total_energy")
  end
end

function Land:update()
  local endpoints={0,0,0,0,0,0,0,0,0,0}
  local j=1
  for _,bp in ipairs(self.ballpits) do
    bp:update()
    pos=bp:positions()
    for i,_ in ipairs(pos) do
      if i%2==0 then
        local a=pos[i-1]/127
        local b=pos[i]/127
        if a>b then
          endpoints[j]=b
          endpoints[j+1]=a
        else
          endpoints[j]=a
          endpoints[j+1]=b
        end
        j=j+2
      end
    end
  end

  engine.land_set_endpoints(self.id,
    endpoints[1],
    endpoints[2],
    endpoints[3],
    endpoints[4],
    endpoints[5],
    endpoints[6],
    endpoints[7],
    endpoints[8],
    endpoints[9],
    endpoints[10],
    endpoints[11],
  endpoints[12])
end

function Land:record(on)
  if self.recording then
    if not on then
      self.recording=nil
      engine.record_stop()
    end
  else
    if on then
      engine.record_start(self.id,"/home/we/dust/audio/grainchain/recordings/"..os.date('%Y-%m-%d-%H%M%S')..".wav")
    end
  end
end

function Land:load(fname)
  self.waveform:load(fname)
  engine.land_load(self.id,fname)
end

function Land:enc(k,d)
  if k==2 then
    self:pdelta("boundary_start",d)
  elseif k==3 then
    self:pdelta("boundary_width",d)
  end
end

function Land:key(k,z)

end

function Land:redraw()
  screen.blend_mode(0)
  self.waveform:redraw(32,32)
  screen.blend_mode(5)
  local y=10
  local l=1
  for _,bp in ipairs(self.ballpits) do
    pos=bp:positions()
    for i,_ in ipairs(pos) do
      if i%2==0 then
        screen.level(4)
        screen.rect(util.round(pos[i-1]),y,util.round(pos[i]-pos[i-1]),6)
        screen.fill()
        if self.players[l].position>0 then
          -- plot position
          screen.level(5)
          screen.rect(self.players[l].position,y,1,6)
          screen.fill()
          -- plot pan
          screen.level(2)
          screen.rect(self.players[l].pan,y,3,6)
          screen.fill()
        end
        -- bp.balls[i]:redraw(y+3)
        -- bp.balls[i-1]:redraw(y+3)
        y=y+9
        l=l+1
      end
    end
  end
  screen.level(10)
  screen.rect(self:pget("boundary_start"),0,1,64)
  screen.fill()
  screen.rect(self:pget("boundary_start")+self:pget("boundary_width"),0,1,64)
  screen.fill()
end

return Land








