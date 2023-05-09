b11111110000000=0x3F80
b00000001111111=0x7F

function convert_14bit_to_7bits(number)
  if (number>16383) then
    print("exceeding limit of converter")
  end
  a=(number & b11111110000000)>>7
  b=(number & b00000001111111)
  return a,b
end

function convert_7bits_to_14bit(a,b)
  return (a<<7)+b
end

-- a,b=convert_14bit_to_7bits(5783)
-- print(a,b)
-- print(convert_7bits_to_14bit(a,b))
