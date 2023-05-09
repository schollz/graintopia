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

NUM_LANDS=3
rendering_land=0

function init()
  os.execute("mkdir -p ".._path.audio.."grainchain/recordings")
  os.execute(_path.code.."grainchain/lib/oscnotify/run.sh &")

  -- setup softcut renderer

  softcut.buffer_clear()
  softcut.event_render(function(ch,start,i,s)
    if rendering_land>0 then
      print(string.format("[waveform] rendered %d",rendering_land))
      local max_val=0
      for i,v in ipairs(s) do
        if v>max_val then
          max_val=math.abs(v)
        end
      end
      for i,v in ipairs(s) do
        s[i]=math.abs(v)/max_val
      end
      lands[rendering_land]:upload_waveform(s)
    end
  end)

  -- setup osc
  osc_fun={
    oscnotify=function(args)
      print("file edited ok!")
      rerun()
    end,
    recorded=function(args)
      local id=tonumber(args[1])
      local fname=args[2]
      -- print(string.format("[osc-recorded] %s (id %d)",fname,id))
      lands[id]:load(fname)
    end,
    position=function(args)
      local id=tonumber(args[1])
      local l=tonumber(args[2])
      -- print(string.format("[osc-position] %2.0f-%2.0f: %2.0f",id,l,x))
      lands[id]:player_set(l,"position",tonumber(args[3]))
    end,
    pan=function(args)
      local id=tonumber(args[1])
      local l=tonumber(args[2])
      local x=util.linlin(-1,1,1,127,tonumber(args[3]))
      -- print(string.format("[osc-pan] %2.0f-%2.0f: %2.0f",id,l,x))
      lands[id]:player_set(l,"pan",util.round(x))
    end,
    volume=function(args)
      local id=tonumber(args[1])
      local l=tonumber(args[2])
      local x=math.floor(tonumber(args[3]))
      -- print(string.format("[osc-volume] %2.0f-%2.0f: %2.0f",id,l,x))
      if (x>0 and x<16) then
        lands[id]:player_set(l,"volume",x)
      end
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


  params:add_number("land","land",1,NUM_LANDS,1)
  params:set_action("land",function(x)
    local prams={"db","boundary_start","boundary_width","total_energy","sample_file"}
    for i=1,NUM_LANDS do
      for _,p in ipairs(prams) do
        if i==x then
          params:show(i..p)
        else
          params:hide(i..p)
        end
      end
    end
    _menu.rebuild_params()
  end)
  lands={}
  for i=1,NUM_LANDS do
    table.insert(lands,land_:new{id=i})
  end
  -- params:default()
  params:bang()

  -- redraw
  clock.run(function()
    while true do
      clock.sleep(1/15)
      lands[params:get("land")]:update()
      redraw()
    end
  end)

  params:set("1sample_file","/home/we/dust/audio/amenbreak/bamboo2_beats16_bpm145.flac")
end


function key(k,z)
  if k>1 then
    if z==1 then
      params:delta("land",k==2 and-1 or 1)
    end
  end
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

  lands[params:get("land")]:redraw()

  screen.update()
end







