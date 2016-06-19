file = io.open (arg[1], "r")
doc = file:read("*a")
io.close(file)

if arg[3] == "aluno" then
  livrodoaluno = 1
end

inspect = require"inspect"

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
local alpha = R('AZ', 'az') + S('áéíóúàèìòôùâêÂÊÁÉÍÓÚÀÈÌÒÙüãẽõçÇÃẼÕ')
local symb = S('():/+-!?.,;\\{}$&#^*|_~%=<>"\' \n\t')
local known = digit + alpha + symb

-- replacing unknown symbols by a string
-- decode a two-byte UTF-8 sequence
local function f2 (s)
  local c1, c2 = string.byte(s, 1, 2)
  return c1 * 64 + c2 - 12416
end

-- decode a three-byte UTF-8 sequence
local function f3 (s)
  local c1, c2, c3 = string.byte(s, 1, 3)
  return (c1 * 64 + c2) * 64 + c3 - 925824
end

-- decode a four-byte UTF-8 sequence
local function f4 (s)
  local c1, c2, c3, c4 = string.byte(s, 1, 4)
  return ((c1 * 64 + c2) * 64 + c3) * 64 + c4 - 63447168
end

local cont = lpeg.R("\128\191")   -- continuation byte

local utf8 = lpeg.R("\0\127") / string.byte
           + lpeg.R("\194\223") * cont / f2
           + lpeg.R("\224\239") * cont * cont / f3
           + lpeg.R("\240\244") * cont * cont * cont / f4

local killunknown = Cs( ( C(known) / '%1' + C(utf8) / '( SÍMBOLO DESCONHECIDO )' )^0 )
doc = killunknown:match(doc)

local special = P('**') + P('__') + P([[//]]) + P("''") + P('====') + P('$') + P('<WRAP')
   + P('</WRAP') + P('"') + P([[\\]]) + P('{{') + P('}}') + P('/*') + P('*/') + P('<hidden ') + P('</hidden>')
   + P('\n  *') + P('\n  -') + P('\n    *') + P('\n    -') + P('\n') + P(';;#') + P('|')
local harmless = known - special

local whitespace = P(' ')^0
local simpletext = harmless^1
local bold = surround('bold', '**', simpletext)
local under = surround('under', '__', simpletext)
local italic = surround('italic', [[//]], (harmless - P([[//]]))^1 )
local mono = surround('mono', "''", simpletext)
local newline = token('newline', [[\\]])
local linefeed = token('linefeed', '\n')
local simplemath = surround('simplemath', '$', simpletext)
local atividade = token('atividade', '===== - Atividade =====')
local title = P('=====') * token('title', simpletext) * P('=====')
local titlechapter = P('======') * token('title', simpletext) * P('======')
local titleless = P('====') * token('title', simpletext) * P('====')
local include = P('{{page>') * token('include', simpletext) * P('}}')
local image = P('{{') * token('image', simpletext) * P('}}')
local comment = P('/*') * token('comment', 1 - P('*/'))^0 * P('*/') + P(';;#') * token('comment', 1 - P(';;#'))^0 * P(';;#')
local quote = surround('quote', '"', Ct( (bold + under + italic + mono + simplemath + token('simple', simpletext))^0 ))
local decoline = bold + under + italic + mono + quote + simplemath + token('simple', simpletext)
local item = P('\n  *') * token('item', Ct( decoline^0 ))
local itemize = token('itemize', Ct( item^1 ))
local doubleitem = P('\n    *') * token('doubleitem', Ct( decoline^0 ))
local doubleitemize = token('doubleitemize', Ct( doubleitem^1 ))
local enumitem = P('\n  -') * token('enumitem', Ct( decoline^0 ))
local enumerate = token('enumerate', Ct( enumitem^1 ))
local doubleenumitem = P('\n    -') * token('doubleenumitem', Ct( decoline^0 ))
local doubleenumerate = token('doubleenumerate', Ct( doubleenumitem^1 ))
--local hidden = P('<hidden ') * token('comment', simpletext + bold + under + italic + mono + quote + enumerate + itemize + doubleenumerate + doubleitemize + simplemath
--                                        + newline + linefeed + atividade + titlechapter + title + titleless + comment)^0 * P('</hidden>')
local hidden = ( P('<hidden ') * (known - P('>'))^0 * P('>') ) + P('</hidden>')
local cellcontent = token('cellcontent', Ct( (bold + under + italic + mono + quote
                                                 + simplemath + image + token('simple', simpletext))^1 ) )
local tabularline = token('tabularline', Ct( ( ( whitespace * P('|') ) * cellcontent )^1
                                * ( P('|') * whitespace )) * linefeed)
local tabular = token('tabular', Ct(tabularline^1))
local decotext = bold + under + italic + mono + quote + enumerate + itemize + doubleenumerate
   + doubleitemize + simplemath + atividade + titlechapter + tabular
   + title + titleless + include + image + newline + linefeed + comment + hidden + token('simple', simpletext)

local W = V'W'
local envname = P('professor') + P('exercicio') + P('resposta') + P('abstrato') + P('conexoes') + P('explorando') + P('imagem') + P('introdutorio') + P('massa') + P('refletindo') + P('figura') + P('nota')
local wrap = P{
   W,
   W = Ct( P('<WRAP ') * Cg( C( envname ), 'type') * P('>') * Cg(P('') / 'wrap', 'tag') * Cg( Ct( ( decotext + (V'W') )^1 ), 'value' ) ) * P('</WRAP>')
}

--local bighidden = P('<hidden ') * token('comment', decotext + wrap)^1 * P('</hidden>')
local bighidden = P('<hidden ') * (decotext + wrap)^1 * P('</hidden>')

local document = Ct( ( decotext + wrap + bighidden + token('error', special) + token('error', known) )^1 )

--tprint(document:match(doc))

local finalsymb = (P('#') / [[\#]]) + (P('$') / [[\$]]) + (P([[%]]) / [[\%%]]) + (P('&') / [[\&]]) + (P([[\]]) / [[\textbackslash{}]]) + (P('^') / [[\textasciicircum{}]]) + (P('_') / [[\_]]) + (P('{') / [[\{]]) + (P('}') / [[\}]]) + (P('~') / [[\textasciitilde{}]]) + (P('"') / 'QUOTES')

function twothirds(x) return tostring(math.min(6*tonumber(x)/10,600)) end

local formatimagesize = Cs( ( (1 - P('?')) / '' )^1 * ( P('?') / '' )
      * ( P('direct&') / '' )^-1
      * ( ( P('0x') / 'height=' ) * (digit^1 / twothirds) * ( P('') / 'pt' ) )^-1
      * ( ( P('') / 'width=' ) * (digit^1 / twothirds) * ( P('') / 'pt' ) )^-1
      * ( ( P('x') / ',height=' ) * (digit^1 / twothirds) * ( P('') / 'pt' ) )^-1
      * ( simpletext / '' )^0 )
local formatimage = Cs( ( P('') / '/var/www/livro/data/gitrepo/media' ) * ( C(alpha + digit + S('-_.'))
                    + ( P(' ') / '' ) + ( P(':') / '/' ) )^1 * ( simpletext / '' )^0 )
local formatinclude = Cs( ( P('') / '/var/www/livro/data/gitrepo/pages/' )
      * ( C(alpha + digit + S('-_.')) + ( P(' ') / '' ) + ( P(':') / '/' ) )^1
      * ( P('') / '.txt' ) * ( simpletext / '' )^0 )
local formatsimple = Cs( ((finalsymb) + C(known))^1 )

function texprint (tbl, indent)
  local outstr = ""
  if not indent then indent = 0 end
  for k, v in pairs(tbl) do
     local formatting = string.rep("  ", indent)
     if (v.tag) == "atividade" then
        outstr = outstr .. formatting .. '\\section{Atividade}\n'
     elseif (v.tag) == "title" then
        outstr = outstr .. formatting .. '\\section*{' .. formatsimple:match(v.value) .. '}\n'
     elseif (v.tag) == "titleless" then
        outstr = outstr .. formatting .. '\\subsection*{' .. formatsimple:match(v.value) .. '}\n'
     elseif (v.tag) == "titlechapter" then
        outstr = outstr .. formatting .. '\\chapter{' .. formatsimple:match(v.value) .. '}\n'
     elseif (v.tag) == "simplemath" then
        outstr = outstr .. formatting .. '$' .. v.value .. '$'
     elseif (v.tag) == 'bold' then
        outstr = outstr .. formatting .. '{\\bf ' .. formatsimple:match(v.value) .. '}'
     elseif (v.tag) == 'italic' then
        outstr = outstr .. formatting .. '{\\it ' .. formatsimple:match(v.value) .. '}'
     elseif (v.tag) == 'under' then
        outstr = outstr .. formatting .. '{' .. formatsimple:match(v.value) .. '}'
     elseif (v.tag) == 'quote' then
        outstr = outstr .. formatting .. [[``]] .. texprint(v.value, 0) .. [['']]
     elseif (v.tag) == 'newline' then
        outstr = outstr .. formatting .. '\\mbox{} \\newline '
     elseif (v.tag) == 'linefeed' then
        outstr = outstr .. formatting .. '\n'
     elseif (v.tag) == 'simple' then
        outstr = outstr .. formatting .. formatsimple:match(v.value)
        --print(formatting .. v.value)
     elseif (v.tag) == 'include' then
        local includefilename = formatinclude:match(v.value)
        includefile = io.open(includefilename, 'r')
        if (includefile) then
           local includestring = includefile:read("*all")
           includefile:close()
           outstr = outstr .. formatting .. texprint(document:match(includestring))
        end
     elseif (v.tag) == 'image' then
        if (formatimage:match(v.value)) then
           local tempsize = 'width=\textwidth,height=4cm'
           if (formatimagesize:match(v.value)) then
              tempsize = formatimagesize:match(v.value)
           end
           outstr = outstr .. formatting .. ''
             .. formatting .. '\\includegraphics['
             .. tempsize .. ', keepaspectratio]{'
             .. formatimage:match(v.value) .. '}'
             --.. 'value =<' .. v.value .. '>\n'
             --.. 'formatsize =<' .. tempsize .. '>\n'
             --.. 'format =<' .. formatimage:match(v.value) .. '>\n'
        else
           outstr = outstr .. formatting .. 'only value =<' .. v.value .. '>\n'
        end
     elseif (v.tag) == 'cellcontent' then
        outstr = outstr .. texprint(v.value, 0)
     elseif (v.tag) == 'tabularline' then
        outstr = outstr .. formatting
        for k, cell in pairs(v.value) do
           -- print "vvvvvvvvvvvvvvvv"
           -- print(inspect(cell))
           -- print "________________"
           if (k > 1) then outstr = outstr .. '& ' end
           outstr = outstr .. texprint(cell.value, 0)
        end
        outstr = outstr .. '\n'
     elseif (v.tag) == 'tabular' then
        outstr = outstr .. formatting .. '\n\\begin{center}\n'.. formatting .. '  \\begin{tabular}{l*{50}{c}}\n'
           .. texprint(v.value, indent + 2)
           .. formatting .. '  \\end{tabular}\n'.. formatting .. '\\end{center}\n'
     elseif (v.tag) == 'enumitem' then
        outstr = outstr .. formatting .. '\\item' .. texprint(v.value, indent + 1) .. '\n'
     elseif (v.tag) == 'doubleenumitem' then
        outstr = outstr .. formatting .. '\\item' .. texprint(v.value, indent + 1) .. '\n'
     elseif (v.tag) == 'enumerate' then
        outstr = outstr .. formatting .. '\n\\begin{enumerate} [\\quad a)] %s\n' .. texprint(v.value, indent + 1) .. '\\end{enumerate} %s\n'
     elseif (v.tag) == 'doubleenumerate' then
        outstr = outstr .. formatting .. '\n\\begin{enumerate} [\\quad a)] %d\n' .. texprint(v.value, indent + 1) .. '\\end{enumerate} %d\n'
     elseif (v.tag) == 'item' then
        outstr = outstr .. formatting .. '\\item' .. texprint(v.value, indent + 1) .. '\n'
     elseif (v.tag) == 'doubleitem' then
        outstr = outstr .. formatting .. '\\item' .. texprint(v.value, indent + 1) .. '\n'
     elseif (v.tag) == 'itemize' then
        outstr = outstr .. formatting .. '\n\\begin{itemize} %s\n' .. texprint(v.value, indent + 1) .. '\\end{itemize} %s\n'
     elseif (v.tag) == 'doubleitemize' then
        outstr = outstr .. formatting .. '\n\\begin{itemize} %d\n' .. texprint(v.value, indent + 1) .. '\\end{itemize} %d\n'
     elseif (v.tag) == 'error' then
        outstr = outstr .. formatting .. '( ERRO:\\{' .. formatsimple:match(v.value) .. '\\} )'
     elseif (v.tag) == 'wrap' then
        if ((v.type ~= "professor" and v.type ~= "resposta") or not livrodoaluno) then
            outstr = outstr .. formatting .. '\\begin{' .. v.type .. '*}[breakable]{}{}'
            outstr = outstr .. texprint(v.value, indent + 1)
            outstr = outstr .. formatting .. '\\end{' .. v.type .. '*}'
        end
     end
   end
   return outstr
end

file = io.open ('/var/www/livro/data/gitrepo/bin/header.tex', "r")
outstring = file:read("*a")
io.close(file)

outstring = outstring .. texprint(document:match(doc)) .. '\\end{document}'

--tprint(document:match(doc))

--for k, v in pairs(parsed_elements) do
--   print(k, inspect(v))
--   outstring = outstring .. re.match(v, element_parser)
--end

file = io.open (arg[2], "w")
file:write(outstring)
io.close(file)



