
local lpeg = require 'lpeg'
local R, P, S, C, Cs, Cg, Ct, Cc, V = lpeg.R, lpeg.P, lpeg.S, lpeg.C, lpeg.Cs, lpeg.Cg, lpeg.Ct, lpeg.Cc, lpeg.V

local digit = R('09')
local alpha = R('AZ', 'az') + S('áéíóúàèìòùâêÂÊÁÉÍÓÚÀÈÌÒÙüãẽõçÇÃẼÕ')
local symb = S('():/+-!?.,;\\{}$&#^*|_~%=<>"\' \n\t')
local known = digit + alpha + symb

local finalsymb = (P('#') / [[\#]]) + (P('$') / [[\$]]) + (P([[%]]) / [[\%%]]) + (P('&') / [[\&]]) + (P([[\]]) / [[\textbackslash{}]]) + (P('^') / [[\textasciicircum{}]]) + (P('_') / [[\_]]) + (P('{') / [[\{]]) + (P('}') / [[\}]]) + (P('~') / [[\textasciitilde{}]])

local escaper = (Cs(finalsymb) + C(known))^1

print(escaper:match([[ab_c098$%a~sd]]))
