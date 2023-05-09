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
      lands[id]:load(fname)
    end,
    position=function(args)
      local id=tonumber(args[1])
      local l=tonumber(args[2])
      local x=tonumber(args[3])
      print(string.format("[osc-position] %2.0f-%2.0f: %2.0f",id,l,x))
      lands[id]:player_set(l,"position",x)
    end,
    pan=function(args)
      local id=tonumber(args[1])
      local l=tonumber(args[2])
      local x=tonumber(args[3])
      print(string.format("[osc-pan] %2.0f-%2.0f: %2.0f",id,l,x))
      lands[id]:player_set(l,"pan",x)
    end,
    volume=function(args)
      local id=tonumber(args[1])
      local l=tonumber(args[2])
      local x=tonumber(args[3])
      print(string.format("[osc-volume] %2.0f-%2.0f: %2.0f",id,l,x))
      lands[id]:player_set(l,"volume",x)
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

  params:add_number("land","land",1,4,1)
  lands={}
  for i=1,1 do
    table.insert(lands,land_:new{id=i})
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

  clock.run(function()
    engine.record_start(1,"/home/we/dust/audio/grainchain/recordings/"..os.date('%Y-%m-%d-%H%M%S')..".wav")
    clock.sleep(1)
    engine.record_stop()
  end)
end


function key(k,z)
  lands[params:get("land")]:key(k,z)
end

function enc(k,d)
  lands[params:get("land")]:enc(k,d)
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


  lands[params:get("land")]:update()
  lands[params:get("land")]:redraw()

  screen.update()
end







