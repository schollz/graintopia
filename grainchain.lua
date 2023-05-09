-- grainchain
--
-- llllllll.co/t/grainchain
--
-- layer recordings
-- @infinitedigits
--
--    ▼ instructions below ▼
--

-- engine.name="grainchain"


ball=include("lib/ball")
ballpit_=include("lib/ballpit")
land_=include("lib/land")
waveform_=include("lib/waveform")

function init()
  os.execute(_path.code.."grainchain/lib/oscnotify/run.sh &")

  -- setup waveformer
  waveform=waveform_:new()

  -- setup osc
  osc_fun={
    oscnotify=function(args)
      print("file edited ok!")
      rerun()
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
  waveform:load("/home/we/dust/audio/tehn/mancini2.wav")

  ballpit=ballpit_:new{}
  land=land_:new{}
  land:set_boundary(30,60)
end

function key(k,z)
end

function enc(k,d)
  if k==2 then
    land:delta_left(d)
  elseif k==3 then
    land:delta_right(d)
  end
end

function rerun()
  norns.script.load(norns.state.script)
end

function cleanup()
  os.execute("pkill -f oscnotify")
end

function redraw()
  screen.clear()
  screen.blend_mode(0)
  waveform:redraw(32,32)
  screen.blend_mode(5)

  -- ballpit:update()
  -- ballpit:redraw()
  land:update()
  land:redraw()

  screen.update()
end

