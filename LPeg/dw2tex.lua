file = io.open (arg[1], "r")
doc = file:read("*a")
io.close(file)

--inspect = require"inspect"

function tprint (tbl, indent)
  if not indent then indent = 0 end
  for k, v in pairs(tbl) do
    formatting = string.rep("  ", indent) .. k .. ": "
    if type(v) == "table" then
      print(formatting)
      tprint(v, indent + 1)
    elseif type(v) == 'boolean' then
      print(formatting .. tostring(v))
    else
      print(formatting .. v)
    end
  end
end

local lpeg = require 'lpeg'
local R, P, S, C, Cs, Cg, Ct, Cc, V = lpeg.R, lpeg.P, lpeg.S, lpeg.C, lpeg.Cs, lpeg.Cg, lpeg.Ct, lpeg.Cc, lpeg.V

local function token(id, patt) return Ct( Cg(P('') / id, 'tag') * Cg( patt, 'value' ) ) end

function surround(id, openp, midp, endp)
    openp = P(openp)
    endp = endp and P(endp) or openp
    return openp * token(id, midp) * endp
end

local digit = R('09')
local alpha = R('AZ', 'az') + S('áéíóúàèìòùâêÂÊÁÉÍÓÚÀÈÌÒÙüãẽõçÇÃẼÕ')
local symb = S('():/+-!?.,;\\{}$&#^*|_~%=<>"\' \n\t')
local known = digit + alpha + symb

-- replacing unknown symbols by a string
local killunknown = Cs( ( C(known) / '%1' + C(P(1)) / '(símbolo desconhecido)' )^0 )
doc = killunknown:match(doc)

local special = P('**') + P('__') + P([[//]]) + P("''") + P('====') + P('$') + P('<WRAP') + P('</WRAP')
local harmless = known - special

local simpletext = harmless^1
local bold = surround('bold', '**', simpletext)
local under = surround('under', '__', simpletext)
local italic = surround('italic', [[//]], (harmless - P([[//]]))^1 )
local mono = surround('mono', "''", simpletext)
local simplemath = surround('simplemath', '$', simpletext)
local title = P('=====') * token('title', simpletext) * P('=====')
local decotext = bold + under + italic + mono + simplemath + title + token('simple', simpletext)

local W = V'W'
local envname = P('professor') + P('exercicio') + P('resposta') + P('abstrato') + P('conexoes') + P('explorando') + P('imagem') + P('introdutorio') + P('massa') + P('refletindo') + P('figura')
local wrap = P{
   W,
   W = Ct( P('<WRAP ') * Cg( C( envname ), 'type') * P('>') * Cg(P('') / 'wrap', 'tag') * Cg( Ct( ( decotext + (V'W') )^1 ), 'value' ) ) * P('</WRAP>')
}

local document = Ct( ( title + bold + under + italic + mono + simplemath + wrap + token('simple', simpletext) + token('error', known) )^1 )

--tprint(document:match(doc))

function texprint (tbl, indent)
  if not indent then indent = 0 end
  for k, v in pairs(tbl) do
    local formatting = string.rep("  ", indent)
    if (v.tag) == "title" then
       print(formatting .. '\\section{' .. v.value .. '}')
       --tprint(v, indent + 1)
    elseif (v.tag) == 'bold' then
       print(formatting .. '{\\bf ' .. v.value .. '}')
    elseif (v.tag) == 'italic' then
       print(formatting .. '{\\it ' .. v.value .. '}')
    elseif (v.tag) == 'under' then
       print(formatting .. '{' .. v.value .. '}')
    elseif (v.tag) == 'simple' then
       print(formatting .. v.value)
    elseif (v.tag) == 'error' then
       print(formatting .. 'ERRO:\\{' .. v.value .. '\\}')
    elseif (v.tag) == 'wrap' then
       print(formatting .. '\\begin{' .. v.type .. '}')
       texprint(v.value, indent + 1)
       print(formatting .. '\\end{' .. v.type .. '}')
    end
  end
end

file = io.open ('header.tex', "r")
print(file:read("*a"))
io.close(file)

texprint(document:match(doc))

print('\\end{document}')

--for k, v in pairs(parsed_elements) do
--   print(k, inspect(v))
--   outstring = outstring .. re.match(v, element_parser)
--end

--file = io.open (arg[2], "w")
--file:write(outstring)
--io.close(file)


