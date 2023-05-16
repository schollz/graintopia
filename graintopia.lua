-- graintopia
--
-- llllllll.co/t/graintopia
--
-- land of grains.
-- v1.2.0
--
--    ▼ instructions below ▼
--
-- k2/k3 navigates
-- e1 changes timescale
-- e2/e3 boundaries
-- k1 shifts / toggles favs
-- k1+k2 loads
-- k1+k3 records
-- k1+e1 changes grains
-- k1+e2 scrubs favs
-- k2+e3 creates favs

-- check for requirements
installer_=include("lib/scinstaller/scinstaller")
installer=installer_:new{requirements={"Fverb"},zip="https://github.com/schollz/portedplugins/releases/download/v0.4.5/PortedPlugins-RaspberryPi.zip"}
engine.name=installer:ready() and 'Graintopia' or nil

CLOCK_RATE=15
if not string.find(package.cpath,"/home/we/dust/code/graintopia/lib/") then
  package.cpath=package.cpath..";/home/we/dust/code/graintopia/lib/?.so"
end
json=require("cjson")
ball=include("lib/ball")
ballpit_=include("lib/ballpit")
waveform_=include("lib/waveform")
land_=include("lib/land")
fileselect=require 'fileselect'
selecting=false
function load_file(file)
  selecting=false
  if file~="cancel" then
    params:set(params:get("land").."sample_file",file)
  end
end

NUM_LANDS=3
rendering_land=0
recording=false
shift=false
shift_toggle=false


levels={}

function init()

  if not installer:ready() then
    clock.run(function()
      while true do
        redraw()
        clock.sleep(1/5)
      end
    end)
    do return end
  end
  norns.enc.sens(1,16)
  os.execute("mkdir -p ".._path.audio.."graintopia/recordings")
  os.execute(_path.code.."graintopia/lib/oscnotify/run.sh &")

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
      local id=math.floor(tonumber(args[1]))
      local fname=args[2]
      print(string.format("[osc-recorded] %s (land %d)",fname,id))
      params:set(id.."sample_file",fname)
      show_message("loaded recording.",1)
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
    local prams={"bars","db","favorites","boundary_start","boundary_width","freeze","record","total_energy","sample_file","timescalein","wet","move_duration","rateSlew"}
    for i=1,NUM_LANDS do
      for _,p in ipairs(prams) do
        if i==x and p~="favorites" then
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
      clock.sleep(1/CLOCK_RATE)
      lands[params:get("land")]:update()
      redraw()
    end
  end)

  --debug
  if not util.file_exists(_path.data.."graintopia/first") then
    params:set("1sample_file","/home/we/dust/code/graintopia/lib/piano_cm.flac")
    params:set("1boundary_start",15)
    params:set("1boundary_width",15)
    show_message("welcome to graintopia",10)
    params:set("2sample_file","/home/we/dust/code/graintopia/lib/choir_cm.flac")
    params:set("2boundary_start",27.6)
    params:set("2boundary_width",13.2)
    params:set("1favorites",json.encode({{12,23},{34,10},{90,7}}))
    os.execute("touch ".._path.data.."graintopia/first")
  end

  -- setup levels
  print("setting monitor level")
  levels["monitor_level"]=params:get("monitor_level")
  params:set("monitor_level",-inf)
  levels["engine_level"]=params:get("engine_level")
  params:set("engine_level",0)

end

function recording_start()
  if recording then
    do return end
  end
  recording=true
  show_message("recording (any key stops)",60)
  lands[params:get("land")]:record(true)
end

function recording_stop()
  if not recording then
    do return end
  end
  recording=false
  show_message("loading recording...",10)
  lands[params:get("land")]:record(false)
end

function key(k,z)
  if not installer:ready() then
    installer:key(k,z)
    do return end
  end
  if recording and z==1 then
    recording_stop()
    do return end
  end

  if k==1 then
    shift=z==1
    if shift then
      shift_toggle=not shift_toggle
    end
  else
    if shift then
      if k==3 and z==1 then
        -- do recording
        recording_start()
      elseif k==2 and z==1 then
        fileselect.enter(_path.dust,load_file)
        selecting=true
        shift=false
      end
    else
      if z==1 then
        params:delta("land",k==2 and-1 or 1)
      end
    end
  end
end

function enc(k,d)
  if not installer:ready() then
    do return end
  end
  lands[params:get("land")]:enc(k,d)
end

function rerun()
  norns.script.load(norns.state.script)
end

function cleanup()
  for k,v in pairs(levels) do
    params:set(k,v)
  end
  os.execute("pkill -f oscnotify")
end



function show_progress(val)
  show_message_progress=util.clamp(val,0,100)
end

function show_message(message,seconds)
  seconds=seconds or 2
  show_message_clock=10*seconds
  show_message_text=message
end

function draw_message()
  if show_message_clock~=nil and show_message_text~=nil and show_message_clock>0 and show_message_text~="" then
    show_message_clock=show_message_clock-1
    screen.blend_mode(0)

    local screen_fade_in=15
    local x=64
    local y=28
    local w=screen.text_extents(show_message_text)+8
    screen.rect(x-w/2,y,w+2,10)
    screen.level(0)
    screen.fill()
    screen.rect(x-w/2,y,w+2,10)
    screen.level(15)
    screen.stroke()
    screen.move(x,y+7)
    screen.level(math.floor(screen_fade_in*2/3))
    screen.text_center(show_message_text)
    if show_message_progress~=nil and show_message_progress>0 then
      -- screen.update()
      screen.blend_mode(13)
      screen.rect(x-w/2,y,w*(show_message_progress/100)+2,9)
      screen.level(math.floor(screen_fade_in*2/3))
      screen.fill()
      screen.blend_mode(0)
    else
      -- screen.update()
      screen.blend_mode(13)
      screen.rect(x-w/2,y,w+2,9)
      screen.level(math.floor(screen_fade_in*2/3))
      screen.fill()
      screen.blend_mode(0)
      screen.level(0)
      screen.rect(x-w/2,y,w+2,10)
      screen.stroke()
    end
    if show_message_clock==0 then
      show_message_text=""
      show_message_progress=0
    end
  end
end


function redraw()
  if not installer:ready() then
    installer:redraw()
    do return end
  end
  if selecting==true then
    do return end
  end
  screen.clear()

  lands[params:get("land")]:redraw()

  draw_message()

  -- draw placement
  for i=1,NUM_LANDS do
    screen.level(i==params:get("land") and 10 or 2)
    screen.rect(2+128/NUM_LANDS*(i-1),63,128/NUM_LANDS-5,1)
    screen.fill()
  end
  screen.update()
end









