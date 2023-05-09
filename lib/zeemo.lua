local Zeemo={}

function Zeemo:new(args)
  local m=setmetatable({},{__index=Zeemo})
  local args=args==nil and {} or args
  m:init()
  return m
end

function Zeemo:unpack(num)
  local highBits = num >> 7 -- shift right by 7 bits to get the high bits
  local lowBits = num & 0x7F -- bitwise AND with 0x7F (01111111 in binary) to get the low bits
  return lowBits, highBits
end

function Zeemo:init()
  -- connect to the Zeemo midi device
  local found_midi = false
  for i = 1,#midi.vports do -- query all ports
    local m = midi.connect(i) -- connect each device
    if m.name=="Zeemo" then 
      self.midi = m
      found_midi = true 
      break
    end
  end
  if not found_midi then 
    print("[zeemo] could not find midi")
  end

  -- setup the parameters
  local params_menu={
    -- div of 0.00122 is 14-bit resolution over -10 to 10 v
    {id="cv",name="cv",min=-10,max=10,exp=false,div=0.00122,default=0,unit="volts"},
    {id="cvunity",name="uni set",min=0,max=1,exp=false,div=0.001,default=0.5},
    {id="cvmin",name="uni min",min=-10,max=10,exp=false,div=0.00122,default=-10,unit="volts"},
    {id="cvmax",name="uni max",min=-10,max=10,exp=false,div=0.00122,default=10,unit="volts"},
  }
  params:add_group("ZEEMO",#params_menu*8)
  for cv=1,8 do
    for _,pram in ipairs(params_menu) do
      local id="zeemo_"..pram.id..cv
      params:add{
        type="control",
        id=id,
        name=pram.name,
        controlspec=controlspec.new(pram.min,pram.max,pram.exp and "exp" or "lin",pram.div,pram.default,pram.unit or "",pram.div/(pram.max-pram.min)),
        formatter=formatter,
      }
      params:set_action(id,function(x)
        if pram.id=="cv" then 
          -- convert 14-bit number to 70-bit
          local l,h = self:unpack(x)
          if found_midi then 
            self.midi:cc(cv,l,h)
          end
        elseif pram.id=="cvunity" then 
          x = util.clamp(x,0,1)
          params:set("zeemo_cv"..cv,
            util.linlin(0,1,params:get("zeemo_cvmin"..cv),params:get("zeemo_cvmax"..cv),x))
        elseif pram.id=="cvmax" or pram.id=="cvmin" then 
          params:set("zeemo_cv"..cv,
            util.linlin(0,1,params:get("zeemo_cvmin"..cv),params:get("zeemo_cvmax"..cv),params:get("zeemo_cvunity"..cv)))
        end
      end)
    end
  end
end

function Zeemo:set(i,x)
  params:set("zeemo_cvunity"..i,x)
end

function Zeemo:get(i)
  return params:get("zeemo_cvunity"..i)
end

return Zeemo
