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
  self.show_help_text_i=0
  self.show_help_text_x=0
  self.show_help_text={0,0}
  self.moving={false,false}
  self.waveform=waveform_:new{id=self.id}
  self.endpoints={}
  self.favorites={}

  local update_boundary=function()
    self:update_boundary()
  end
  local params_menu={
    {id="db",name="db",engine=true,min=-96,max=16,exp=false,div=0.25,default=-6,unit="dB"},
    {id="bars",name="grains",min=0,max=6,exp=false,div=1,default=6,unit="",action=function(x) engine.land_set_num(self.id,x) end},
    {id="wet",name="reverb",engine=true,min=0,max=1,exp=false,div=0.05,default=0.2,unit=""},
    {id="rateSlew",name="slew rate",engine=true,min=0,max=10,exp=false,div=0.05,default=math.random(100,200)/100,unit="s"},
    {id="boundary_start",name="boundary start",min=0,max=127,exp=false,div=0.2,default=0,unit="%",action=update_boundary},
    {id="boundary_width",name="boundary width",min=0,max=127,exp=false,div=0.2,default=127,unit="%",action=update_boundary},
    {id="move_duration",name="move duration",engine=true,min=0,max=10,exp=false,div=0.1,default=2,unit="s"},
    {id="timescalein",name="timescale",engine=true,min=0,max=10,exp=false,div=0.1,default=1,unit="x"},
    {id="total_energy",name="temperature",min=1,max=10000,exp=true,div=10,default=100,unit="K"},

  }
  -- params:add_group("LAND "..self.id,#params_menu+1)
  params:add_text(self.id.."favorites","favorites","")
  params:set_action(self.id.."favorites",function(x)
    if self.noupdate then
      do return end
    end
    if x=="" then
      self.favorites={}
      do return end
    end
    local data=json.decode(x)
    if data~=nil then
      self.favorites=data
    end
  end)
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
    -- print(string.format("[sample_file%d] loading '%s'",self.id,x))
    -- print("file exists?",file_exists(x))
    -- print("is_dir?",is_dir(x))
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


function Land:do_move(k,v,x)
  self:pdelta(k,v)
  if (v>0 and self:pget(k)>x) or (v<0 and self:pget(k)<x) then
    self:pset(k,x)
    -- done moving
    do return false end
  end
  -- keep moving
  do return true end
end

function Land:update()
  -- update favorite moving
  if self.moving[1] or self.moving[2] then
    for i,k in ipairs({"boundary_start","boundary_width"}) do
      if self.moving[i] then
        self.moving[i]=self:do_move(k,self.move_velocity[i]*5,self.move_to[i])
      end
    end
  end

  -- update endpoint
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
      engine.record_start(self.id,"/home/we/dust/audio/graintopia/recordings/"..os.date('%Y-%m-%d-%H%M%S')..".wav")
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

function Land:update_favorites()
  -- sort favorites
  table.sort(self.favorites,function(a,b)
    return a[1]<b[1]
  end)
  self.noupdate=true
  params:set(self.id.."favorites",json.encode(self.favorites))
  self.noupdate=nil
end

function Land:add_favorite()
  -- do favorite position
  table.insert(self.favorites,{self:pget("boundary_start"),self:pget("boundary_width")})
  self:update_favorites()
end

function Land:remove_favorite(j)
  local list={}
  for i,v in ipairs(self.favorites) do
    if i==j then
    else
      table.insert(list,v)
    end
  end
  self.favorites=list
  self:update_favorites()
end

function Land:is_favorite()
  local x=self:pget("boundary_start")
  for i,v in ipairs(self.favorites) do
    if v[1]==x then
      do return i end
    end
  end
  return nil
end

function Land:get_closest_favorite()
  local x=self:pget("boundary_start")
  if #self.favorites==0 then
    do return end
  end
  if #self.favorites==1 then
    do return 1 end
  end
  local closest={1,1000}
  for i,v in ipairs(self.favorites) do
    local u=math.abs(v[1]-x)
    if u<closest[2] then
      closest={i,u}
    end
  end
  return closest[1]
end

function Land:move_to_closest_favorite(d)
  local current=self:get_closest_favorite()
  if current==nil then
    do return end
  end
  local next=util.clamp(current+(d>0 and 1 or-1),1,#self.favorites)
  if self:pget("move_duration")==0 then
    self:pset("boundary_start",self.favorites[next][1])
    self:pset("boundary_width",self.favorites[next][2])
  else
    self.move_to={self.favorites[next][1],self.favorites[next][2]}
    self.move_velocity={(self.favorites[next][1]-self:pget("boundary_start"))/(self:pget("move_duration")*CLOCK_RATE),(self.favorites[next][2]-self:pget("boundary_width"))/(self:pget("move_duration")*CLOCK_RATE)}
    self.moving={true,true}
  end
end

function Land:enc(k,d)
  if shift_toggle then
    if k==1 then
      self:pdelta("bars",d)
    elseif k==2 and d~=0 then
      self:move_to_closest_favorite(d)
    elseif k==3 then
      local is_favorite=self:is_favorite()
      if d>0 then
        if not is_favorite then
          -- add favorite
          self:add_favorite()
        end
      elseif d<0 then
        if is_favorite then
          -- remove favorite
          print("removing favorite")
          self:remove_favorite(is_favorite)
        end
      end
    end
  else
    if k==1 then
      self:pdelta("timescalein",d)
      self:pdelta("total_energy",d)
    elseif k==2 then
      self:pdelta("boundary_start",d)
    elseif k==3 then
      self:pdelta("boundary_width",d)
    end
  end
end

function Land:key(k,z)

end

function Land:show_help()
  if (self.show_help_text_x>200) then
    do return end
  end
  self.show_help_text_i=self.show_help_text_i+1
  if self.show_help_text_i>1 then
    self.show_help_text_i=0
  end
  for i,v in ipairs(self.show_help_text) do
    if (self.show_help_text_i==0) then
      if not shift_toggle then
        if v>0 then
          self.show_help_text[i]=v-1
        end
      else
        self.show_help_text_x=self.show_help_text_x+1
        if (self:pget("boundary_start")+self:pget("boundary_width")>64) then
          self.show_help_text[i]=self.show_help_text[i]+(i==1 and-1 or 1)
        else
          self.show_help_text[i]=self.show_help_text[i]+(i==1 and 1 or-1)
        end
      end
    end
    self.show_help_text[i]=util.clamp(self.show_help_text[i],0,5)
    if self.show_help_text[i]>0 then
      screen.level(self.show_help_text[i])
      local fn=screen.text
      local xpos=2
      if i==1 then
        fn=screen.text_right
        xpos=126
      end
      screen.move(xpos,22)
      fn("k1+e2")
      screen.move(xpos,30)
      fn("jumps fav")
      screen.move(xpos,42)
      fn("k1+e3")
      screen.move(xpos,50)
      fn("creates fav")
    end
  end
end

function Land:show_help2()
  screen.level(5)
  screen.move(64,22)
  screen.text_center("k1+k2 loads")
  screen.move(64,42)
  screen.text_center("k1+k3 records")
end

function Land:redraw()
  if not self.loaded then
    self:show_help2()
    do return end
  end
  screen.blend_mode(0)
  self.waveform:redraw(32,32)
  if next(self.endpoints)~=nil then
    screen.blend_mode(5)
    local y=9
    local l=1
    for i=1,#self.endpoints,2 do
      if i==#self.endpoints then
        y=y-1
      end
      screen.level(self.players[l].volume)
      screen.rect(self.endpoints[i],y,self.endpoints[i+1]-self.endpoints[i],5)
      screen.fill()
      if self.players[l].position>0 then
        -- plot position
        screen.level(6)
        screen.rect(self.players[l].position,y,1,5)
        screen.fill()
        -- -- plot pan
        -- screen.level(2)
        -- screen.rect(self.players[l].pan,y,3,6)
        -- screen.fill()
      end
      y=y+9
      l=l+1
    end
  end
  screen.update()
  screen.level(shift_toggle and 15 or 4)
  screen.rect(self:pget("boundary_start"),9,1,50)
  screen.fill()
  screen.rect(self:pget("boundary_start")+self:pget("boundary_width"),9,1,50)
  screen.fill()
  if shift_toggle then
    -- screen.move(self:pget("boundary_start"),7+4)
    -- screen.text_center("*")
    -- screen.move(self:pget("boundary_start")+self:pget("boundary_width"),7)
    -- screen.text_center("*")
  end

  for i,v in ipairs(self.favorites) do
    screen.rect(v[1],60,1,2)
    screen.fill()
    screen.rect(v[1],6,1,2)
    screen.fill()
  end
  self:show_help()
end

return Land










