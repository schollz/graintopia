local Waveform={}

function Waveform:new(args)
  local m=setmetatable({},{__index=Waveform})
  local args=args==nil and {} or args
  for k,v in pairs(args) do
    m[k]=v
  end
  m:init()
  return m
end

function Waveform:init()
  self.is_rendering=false
  self.rendering_name=nil
  self.renders={}

  softcut.buffer_clear()
  softcut.event_render(function(ch,start,i,s)
    if self.rendering_name~=nil then
      print(string.format("[waveform] rendered %s",self.rendering_name))
      local max_val=0
      for i,v in ipairs(s) do
        if v>max_val then
          max_val=math.abs(v)
        end
      end
      for i,v in ipairs(s) do
        s[i]=math.abs(v)/max_val
      end
      self.renders[self.rendering_name]=s
      self.rendering_name=nil
      self.is_rendering=false
    end
  end)
end

function Waveform:load(fname)
  self.current=fname
  _,self.basename,_=string.match(fname,"(.-)([^\\/]-%.?([^%.\\/]*))$")
  if self.renders[fname]~=nil then
    do return end
  end
  if self.is_rendering then
    do return end
  end
  self.is_rendering=true
  self.rendering_name=fname
  local ch,samples=audio.file_info(fname)
  local length=samples/48000
  clock.run(function()
    print(string.format("[waveform] loading %s",fname))
    softcut.buffer_read_mono(fname,0,1,-1,1,1)
    print(string.format("[waveform] rendering %2.1f sec of %s",length,fname))
    softcut.render_buffer(1,1,length,128)
  end)
end

function Waveform:redraw(y,h)
  if self.current==nil or self.renders[self.current]==nil then
    do return end
  end
  screen.level(4)
  screen.move(0,y)
  screen.line(129,y)
  screen.stroke()
  for i,v in ipairs(self.renders[self.current]) do
    screen.move(i,y)
    screen.line(i,y+v*h)
    screen.stroke()
    screen.move(i,y)
    screen.line(i,y-v*h)
    screen.stroke()
  end

  screen.blend_mode(1)
  screen.move(1,7)
  screen.text(self.basename)

end

return Waveform
