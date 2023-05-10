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
end

function Waveform:load(fname)
  self.queue=fname
end

function Waveform:load_()
  if self.queue==nil or rendering_land>0 then
    do return end
  end
  rendering_land=self.id
  local fname=self.queue
  self.queue=nil
  self.rendering_name=fname
  self.current=fname
  _,self.basename,_=string.match(fname,"(.-)([^\\/]-%.?([^%.\\/]*))$")
  print("[waveform] doing render",fname)
  local ch,samples=audio.file_info(fname)
  local length=samples/48000
  clock.run(function()
    print(string.format("[waveform] loading %s",fname))
    softcut.buffer_read_mono(fname,0,1,-1,1,1)
    print(string.format("[waveform] rendering %2.1f sec of %s",length,fname))
    softcut.render_buffer(1,1,length,128)
  end)
end

function Waveform:upload_waveform(s)
  self.renders[self.rendering_name]=s
  rendering_land=0
end

function Waveform:redraw(y,h)
  if self.queue~=nil then
    self:load_()
  end
  if self.current==nil or self.renders[self.current]==nil then
    do return end
  end
  screen.level(1)
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

  screen.blend_mode(0)
  screen.move(2,5)
  screen.level(15)
  screen.text(self.basename)

end

return Waveform
