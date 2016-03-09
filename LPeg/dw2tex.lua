file = io.open (arg[1], "r")
doc = file:read("*a")
io.close(file)

--inspect = require"inspect"

local lpeg = require 'lpeg'
local R, P, S, C, Cs, Cg, Ct = lpeg.R, lpeg.P, lpeg.S, lpeg.C, lpeg.Cs, lpeg.Cg, lpeg.Ct

local function token(id, patt) return Ct(Cc(id) * C(patt)) end

local digit = R('09')
local alpha = R('AZ', 'az') + S('áéíóúàèìòùâêÂÊÁÉÍÓÚÀÈÌÒÙüãẽõçÇÃẼÕ')
local harmless = digit + alpha + S('():/+-!?.,;')
local symb = S('\\{}$&#^*|_~%=<>\n\t"\' ')
local known = harmless + symb

-- replacing unknown symbols by a string
local killunknown = Cs( ( C(known) / '%1' + P(1) / '(símbolo desconhecido)' )^0 )
doc = killunknown:match(doc)






print(doc)

outstring = ""

--for k, v in pairs(parsed_elements) do
--   print(k, inspect(v))
--   outstring = outstring .. re.match(v, element_parser)
--end

file = io.open (arg[2], "w")
file:write(outstring)
io.close(file)


