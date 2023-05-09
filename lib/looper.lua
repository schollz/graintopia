local Looper={}

function Looper:new(args)
  local m=setmetatable({},{__index=Looper})
  local args=args==nil and {} or args
  for k,v in pairs(args) do
    m[k]=v
  end
  m:init()

  return m
end

function Looper:init()
  if self.id==nil then
    print("[looper] error: ID not defined")
    do return end
  end
  self.rec_queue={}
  self.rec_current=0
  self.rec_loops=0
  self.loops_recorded={}
  self.notes_on={}
  self.note_location_playing=nil
  self.arp_options={4,8,12,16,24,32}
  self.buttons={}
  for i=1,6 do
    table.insert(self.buttons,{})
    for j=1,6 do
      table.insert(self.buttons[i],false)
    end
  end

  local params_menu={
    {id="db",name="volume",min=1,max=8,exp=false,div=1,default=6,unit="level",values={-96,-12,-9,-6,-3,0,3,6}},
  }
  params:add_group("LOOPER "..self.id,1+#params_menu*8)
  params:add_number(self.id.."loop","loop",1,8,1)
  params:set_action(self.id.."loop",function(x)
    for loop=1,8 do
      for _,pram in ipairs(params_menu) do
        if loop==x then
          params:show(self.id..pram.id..loop)
        else
          params:hide(self.id..pram.id..loop)
        end
      end
    end
    _menu.rebuild_params()
  end)
  params:add_option(self.id.."hold_change","static holds",{"no","yes"},1)
  params:add_option(self.id.."note_pressing","note pressing",{"press","toggle"},2)
  params:set_action(self.id.."note_pressing",function(x)
    if x==1 then
      for r=1,6 do
        for c=1,6 do
          if not self.buttons[r][c] then
            self:note_grid_off(r,c)
          end
        end
      end
    end
  end)
  params:add_option(self.id.."arp_option","arp speeds",{"1/4","1/8","1/12","1/16","1/24","1/36"})

  for loop=1,8 do
    for _,pram in ipairs(params_menu) do
      local formatter=pram.formatter
      if formatter==nil and pram.values~=nil then
        formatter=function(param)
          return pram.values[param:get()]..(pram.unit and (" "..pram.unit) or "")
        end
      end
      local pid=self.id..pram.id..loop
      params:add{
        type="control",
        id=pid,
        name=pram.name,
        controlspec=controlspec.new(pram.min,pram.max,pram.exp and "exp" or "lin",pram.div,pram.default,pram.unit or "",pram.div/(pram.max-pram.min)),
        formatter=formatter,
      }
      params:set_action(pid,function(x)
        if pram.values~=nil then
          x=pram.values[x]
        end
        engine.set_loop(loop+(self.id==1 and 0 or 8),pram.id,x)
      end)
    end
  end

end

function Looper:pget(k)
  return params:get(self.id..k..params:get(self.id.."loop"))
end

function Looper:pset(k,v)
  return params:set(self.id..k..params:get(self.id.."loop"),v)
end


function Looper:clock_loops()
  if self.rec_loops>0 then
    self.rec_loops=self.rec_loops-1
  end
  if self.rec_loops==0 then
    self:rec_queue_down()
  end
end

function Looper:clock_arps(arp_beat,denominator)
  local num_notes_on=#self.notes_on
  if num_notes_on==0 then
    self.note_location_playing=nil
    do return end
  end
  local do_play_note=false
  do_play_note=denominator==self.arp_options[params:get(self.id.."arp_option")]
  if do_play_note and num_notes_on>0 then
    local x=self.notes_on[arp_beat%num_notes_on+1]
    local note=params:get(self.id.."hold_change")==1 and chords[clock_chord].m[x[1]][x[2]] or x[3]
    self.note_location_playing={x[1],x[2]}
    self:note_on(note)
  end
end

function Looper:is_note_playing(i,j)
  if self.note_location_playing==nil then
    do return end
  end
  return self.note_location_playing[1]==i and self.note_location_playing[2]==j
end

function Looper:is_note_on(i,j)
  for _,v in ipairs(self.notes_on) do
    if v[1]==i and v[2]==j then
      do return true end
    end
  end
  return false
end

function Looper:note_on(note)
  print(string.format("[looper %d] note_on %d",self.id,note))
  crow.output[self.id==1 and 1 or 3].volts=(note-24)/12
end

function Looper:note_off()
  print(string.format("[looper %d] note_off",self.id))
  self.note_location_playing=nil
  -- crow.output[2](false)
end

function Looper:button_down(r,c)
  self.buttons[r][c]=true
end

function Looper:button_up(r,c)
  self.buttons[r][c]=false
end

function Looper:note_grid_on(r,c)
  local note=chords[clock_chord].m[r][c]
  print(r,c,note)
  print(string.format("[looper %d] note_grid_on %d,%d on: %d",self.id,r,c,note))
  if #self.notes_on==0 then
    self:note_on(note)
  end
  table.insert(self.notes_on,{r,c,note})
  -- crow.output[2].action=string.format("adsr(%2.3f,0.25,5,0.25)",util.linlin(1,127,0.05,0.5,note))
  -- crow.output[2](true)
end

function Looper:note_grid_off(r,c)
  print(string.format("[looper %d] note_grid_off %d,%d on",self.id,r,c))
  local j=0
  for i,v in ipairs(self.notes_on) do
    if v[1]==r and v[2]==c then
      j=i
    end
  end
  if j>0 then
    table.remove(self.notes_on,j)
  end
  if next(self.notes_on)==nil then
    self:note_off()
  end
end

function Looper:rec_queue_up(x)
  print(string.format("[looper %d] rec_queue_up %d",self.id,x))
  -- don't queue up twice
  for _,v in ipairs(self.rec_queue) do
    if v==x then
      do return end
    end
  end
  table.insert(self.rec_queue,x)
  print(string.format("[looper %d] queued %d",self.id,x))
end

function Looper:is_in_rec_queue(i)
  for _,v in ipairs(self.rec_queue) do
    if v==i then
      do return true end
    end
  end
  do return false end
end

function Looper:is_recorded(i)
  return self.loops_recorded[i]
end

function Looper:rec_queue_down()
  print(string.format("[looper %d] rec_queue_down",self.id))
  if self.rec_current>0 then
    print(string.format("[looper %d] finished %d",self.id,self.rec_current))
    self.loops_recorded[self.rec_current]=true
  end
  if next(self.rec_queue)==nil then
    self.rec_current=0
    do return end
  end
  local x=table.remove(self.rec_queue,1)
  engine.record((self.id==1 and 0 or 8)+x,beats_total*clock.get_beat_sec(),self.id==1 and 0 or 1)
  params:set(self.id.."loop",x)
  print(string.format("[looper %d] recording %d",self.id,x))
  self.rec_current=x
end

function Looper:redraw()
  screen.font_size(8)
  screen.level(15)
  screen.move(1,6)

  if self.rec_current>0 then
    if next(self.rec_queue)~=nil then
      screen.text(string.format("recording %d, then %d",self.rec_current,self.rec_queue[1]))
    else
      screen.text(string.format("recording %d",self.rec_current))
    end
  elseif next(self.rec_queue)~=nil then
    screen.text(string.format("queued %d",self.rec_queue[1]))
  end
end


return Looper


