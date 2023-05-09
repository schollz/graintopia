-- grainchain
--
-- llllllll.co/t/grainchain
--
-- layer recordings
-- @infinitedigits
--
--    ▼ instructions below ▼
--

engine.name="Grainchain"

ball=include("lib/ball")
ballpit_=include("lib/ballpit")
waveform_=include("lib/waveform")
land_=include("lib/land")
fileselect=require 'fileselect'
selecting=false
function load_file(file)
  selecting=false
  if file~="cancel" then
    waveform:load(file)
  end
end

function init()
  os.execute("mkdir -p ".._path.audio.."grainchain/recordings")
  os.execute(_path.code.."grainchain/lib/oscnotify/run.sh &")

  -- setup waveformer
  waveform=waveform_:new()

  -- setup osc
  osc_fun={
    oscnotify=function(args)
      print("file edited ok!")
      rerun()
    end,
    recorded=function(args)
      local id=tonumber(args[1])
      local fname=args[2]
      print(string.format("[osc-recorded] %s (id %d)",fname,id))
      -- TODO: load into the current land
    end,
    loop_db=function(args)
      -- local side=tonumber(args[1])
      -- loop_db[params:get("loop")]=util.clamp(util.round(util.linlin(-48,12,0,10,tonumber(args[2]))),0,15)
    end,
  }
  osc.event=function(path,args,from)
    if string.sub(path,1,1)=="/" then
      path=string.sub(path,2)
    end
    if path~=nil and osc_fun[path]~=nil then
      osc_fun[path](args)
    else
      -- print("osc.event: '"..path.."' ?")
    end
  end

  params:default()
  params:bang()

  -- redraw
  clock.run(function()
    while true do
      clock.sleep(1/15)
      redraw()
    end
  end)

  -- testing
  waveform:load("/home/we/dust/audio/boombap1.aif")

  land=land_:new{id=1}

  clock.run(function()
    engine.record_start(1,"/home/we/dust/audio/grainchain/recordings/"..os.date('%Y-%m-%d-%H%M%S')..".wav")
    clock.sleep(1)
    engine.record_stop()
  end)
end

function key(k,z)
  if k==1 and z==1 then
    selecting=true
    fileselect.enter(_path.dust,load_file)
  end
end

function enc(k,d)
  if k==2 then
    land:delta_left(d)
  elseif k==3 then
    land:delta_right(d)
  elseif k==1 then
    land:delta_energy(d)
  end
end

function rerun()
  norns.script.load(norns.state.script)
end

function cleanup()
  os.execute("pkill -f oscnotify")
end

function redraw()
  if selecting==true then
    do return end
  end
  screen.clear()
  screen.blend_mode(0)
  waveform:redraw(32,32)
  screen.blend_mode(5)

  land:update()
  land:redraw()

  screen.update()
end

