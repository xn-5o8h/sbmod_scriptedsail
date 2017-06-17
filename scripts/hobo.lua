hobo = {}

hobo.charWidths = {
  --      
    10,10,10,10,10,10,10,10,0,0,
  --            
    10,10,0,10,10,10,10,10,10,10,
  --         
     10,10,10,10,10,10,10,10,10,10,
  --  [ ]  !   "   #   $   %   &   '   (     [ ] = space
     10,5,4,8,12,10,12,12,4,6,
  -- )   *   +   , -   .   /   0   1   2
     6,8,8,6,8,4,12,10,6,10,
  -- 3   4   5   6   7   8   9   :   ;   <
    10,10,10,10,10,10,10,4,4,8,
  -- =   >   ?   @   A   B   C   D   E   F
     8,8,10,12,10,10,8,10,8,8,
  -- G   H   I   J   K   L   M   N   O   P
    10,10,8,10,10,8,12,10,10,10,
  -- Q   R   S   T   U   V   W   X   Y   Z
    10,10,10,8,10,10,12,10,10,8,
  -- [   \   ]   ^   _   `   a   b   c   d
     6,12,6,8,10,6,10,10,9,10,
  -- e   f   g   h   i   j   k   l   m   n
    10,8,10,10,4,6,9,4,12,10,
  -- o   p   q   r   s   t   u   v   w   x
    10,10,10,8,10,8,10,10,12,8,
  -- y   z   {   |   }   ~       €       ‚
    10,10,8,4,8,10,10,10,10,10,
  -- ƒ   „   …   †   ‡   ˆ   ‰   Š   ‹   Œ
    10,10,10,10,10,10,10,10,10,16,
  --     Ž           ‘   ’   “   ”   •   –
    10,10,10,10,10,10,10,10,10,10,
  -- —   ˜    ™   š   ›   œ       ž   Ÿ
    10,10,10,10,10,10,10,10,10,10,
  -- ¡   ¢   £   ¤   ¥   ¦   §   ¨   ©   ª     ¤ = Starbound Sun,§ = Penguin,ª = Skull
     6,10,10,15,10,5,13,7,14,15,
  -- «   ¬   ­   ®   ¯   °   ±   ²   ³   ´     « = Heart,° = Chucklefish,± = Bird
    15,10,10,14,12,16,14,7,7,6,
  -- µ   ¶   ·   ¸   ¹   º   »   ¼   ½   ¾     º = Monkey,» = Smiley Sun
    11,12,8,7,6,16,16,15,15,15,
  -- ¿   À   Á   Â   Ã   Ä   Å   Æ   Ç   È
    10,10,10,10,10,10,10,14,10,8,
  -- É   Ê   Ë   Ì   Í   Î   Ï   Ð   Ñ   Ò
     8,8,8,8,8,8,8,13,10,10,
  -- Ó   Ô   Õ   Ö   ×   Ø   Ù   Ú   Û   Ü
    10,10,10,10,10,13,10,10,10,10,
  -- Ý   Þ   ß   à   á   â   ã   ä   å   æ     Þ = Floran Mask
    10,14,11,10,10,10,10,10,10,15,
  -- ç   è   é   ê   ë   ì   í   î   ï   ð     ð = Flower
     9,10,10,10,10,8,8,8,8,12,
  -- ñ   ò   ó   ô   õ   ö   ÷   ø   ù   ú
    10,10,10,10,10,10,10,10,10,10,
  -- û   ü   ý   þ   ÿ                         þ = Cat Face
    10,10,10,15,10 }

function hobo.getLengthUtf8(text,fontSize)
  local fontSize = fontSize or 16
  local width = 0
  for i=1, utf8.len(text),1 do
    local offset = utf8.offset(text, i)
    local character = utf8.codepoint(text, offset, offset)
    if character <= 256 then
      width = width + hobo.charWidths[character]
    else
      width = width + 11  --made it slightly larger because it was fitting better with my tests in japanese, 
    end      --I believe if different languages need different default then should check for codepoint range
  end
  return width * fontSize / 16
end

function hobo.getLength(text,fontSize)
  local fontSize = fontSize or 16
  local width = 0
  for i=1,#text,1 do
    local character = string.byte(text,i)
    if character <= 256 then
      width = width + hobo.charWidths[character]
    else
      width = width + 10
    end
  end
  return width * fontSize / 16
end

function hobo.drawText(text,x,y,hAnchor,vAnchor,size,color,args)
  -- args = {shadow = color,shadowOffset = {x,y},outline = color,glow = flash speed}
  -- example call to this function:
  --   hobo.drawText("Hello World!",100,100,"left","top",10,"white",{shadow = "black"})
  -- note that if both shadow and outline are used shadowOffset should also be used to account for the 1 pixel outline!
  local args = args or {}

  if args.shadow then
    if args.shadowOffset then sx,sy = args.shadowOffset[1],args.shadowOffset[2] else sx,sy = 0,-1 end
    local shadow = string.gsub(text,"%^.-%;","")
    self.canvas:drawText(shadow,{position = {x+sx,y+sy},horizontalAnchor = hAnchor,verticalAnchor = vAnchor},size,args.shadow)
  end

  if args.outline then
    local outline = string.gsub(text,"%^.-%;","") -- to strip any ^color; or similar codes from string
    for ox = x-1,x+1 do
      for oy = y-1,y+1 do
        if (ox ~= 0 and oy ~= 0) then self.canvas:drawText(outline,{position = {ox,oy},horizontalAnchor = hAnchor,verticalAnchor = vAnchor},size,args.outline) end
      end
    end
  end

  if args.glow then
    local glow = math.abs(math.sin(os.clock()*args.glow))
    if type(color) == "string" then
      local colors = {
        -- based on Starbounds text colors:
        ["red"]={255,0,0},["orange"]={255,165,0},["yellow"]={255,255,0},["green"]={0,255,0},["blue"]={0,0,255},
        ["indigo"]={75,0,130},["violet"]={238,130,238},["black"]={0,0,0},["white"]={255,255,255},["magenta"]={255,0,255},
        ["darkmagenta"]={128,0,128},["cyan"]={0,255,255},["darkcyan"]={0,128,128},["cornflowerblue"]={100,149,237},["gray"]={160,160,160},
        ["lightgray"]={192,192,192},["darkgray"]={128,128,128},["darkgreen"]={0,128,0},["pink"]={255,192,203},["clear"]={0,0,0,0}
      }
      if colors[color] then
        red,green,blue,alpha = colors[color][1]/2,colors[color][2]/2,colors[color][3]/2,colors[color][4] or 255
      end
    else
      red,green,blue,alpha = color[1]/2,color[2]/2,color[3]/2,color[4] or 255
    end
    red,green,blue = red+(red*glow),green+(green*glow),blue+(blue*glow)
    color = {red,green,blue,alpha}
  end

  self.canvas:drawText(text,{position = {x,y},horizontalAnchor = hAnchor,verticalAnchor = vAnchor},size,color)
end