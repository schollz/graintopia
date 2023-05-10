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
  self.waveform=waveform_:new{id=self.id}
  self.endpoints={}

  local update_boundary=function()
    self:update_boundary()
  end
  local params_menu={
    {id="bars",name="__",min=0,max=6,exp=false,div=1,default=6,unit="",action=function(x) engine.land_set_num(self.id,x) end},
    {id="db",name="db",engine=true,min=-96,max=16,exp=false,div=0.25,default=-6,unit="dB"},
    {id="wet",name="reverb",engine=true,min=0,max=1,exp=false,div=0.05,default=0.2,unit=""},
    {id="timescalein",name="timescale",engine=true,min=0,max=10,exp=false,div=0.1,default=1,unit="x"},
    {id="boundary_start",name="boundary start",min=0,max=127,exp=false,div=0.2,default=0,unit="%",action=update_boundary},
    {id="boundary_width",name="boundary width",min=0,max=127,exp=false,div=0.2,default=127,unit="%",action=update_boundary},
    {id="total_energy",name="energy",min=1,max=10000,exp=true,div=10,default=100,unit="K"},
  }
  -- params:add_group("LAND "..self.id,#params_menu+1)
  params:add_file(self.id.."sample_file","file",_path.audio)
  params:set_action(self.id.."sample_file",function(x)
    local is_dir=function(path)
      local f=io.open(path,"r")
      if f==nil then
        do return false end
      end
      local ok,err,code=f:read(1)
      f:close()
      return code==21
    end
    local file_exists=function(name)
      local f=io.open(name,"r")
      if f~=nil then io.close(f) return true else return false end
    end
    print(string.format("[sample_file%d] loading '%s'",self.id,x))
    print("file exists?",file_exists(x))
    print("is_dir?",is_dir(x))
    if x~="cancel" and file_exists(x) and (not is_dir(x)) then
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
        engine.land_set(self.id,pram.id,x)
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
  self:update_boundary()
end

function Land:upload_waveform(s)
  self.waveform:upload_waveform(s)
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

  if self.loaded then
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

  self.endpoints={}
  for i,v in ipairs(endpoints) do
    table.insert(self.endpoints,util.round(v*128))
  end
end

function Land:record(on)
  if not on then
    self.recording=nil
    engine.record_stop()
  else
    if not self.recording then
      engine.record_start(self.id,"/home/we/dust/audio/sonicules/recordings/"..os.date('%Y-%m-%d-%H%M%S')..".wav")
      self.recording=true
    end
  end
end

function Land:load(fname)
  print("[land:load]",fname)
  self.waveform:load(fname)
  engine.land_load(self.id,fname)
  self.loaded=true
end

function Land:enc(k,d)
  if k==1 then
    self:pdelta("bars",d)
  elseif k==2 then
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
  if next(self.endpoints)~=nil then
    screen.blend_mode(5)
    local y=10
    local l=1
    for i=1,#self.endpoints,2 do
      screen.level(self.players[l].volume)
      screen.rect(self.endpoints[i],y,self.endpoints[i+1]-self.endpoints[i],6)
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
      y=y+9
      l=l+1
    end
  end

  screen.level(10)
  screen.rect(self:pget("boundary_start"),6,1,56)
  screen.fill()
  screen.rect(self:pget("boundary_start")+self:pget("boundary_width"),6,1,56)
  screen.fill()
end

return Land










