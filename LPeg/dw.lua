file = io.open (arg[1], "r")
doc = file:read("*a")
io.close(file)

re = require"re"
inspect = require"inspect"

element_breaker = [=[
document     <- {| ( {wrapblock} / {eqblock} / {indentblock} / {line} )* |} !.
line         <- [^%nl]* newline
eqblock      <- "\begin{equation}" newline (%s* !"\end{equation}" [^%nl]+ newline)+ "\end{equation}" newline
indentblock  <- ( "  " [^%nl]* newline )+
wrapblock    <- "<WRAP " %s* wrapkey %s* ">" (wrapblock / eqblock / indentblock / figure / (superchar / " " / newline) )+ "</WRAP>" " "* newline
text         <- (superchar / " ")+
figure       <- "{{" (superchar / " " / [=+-/*|])+ "}}"
superchar    <- [A-Za-z0-9-,.?!áéíóúàèìòùâêÂÊÁÉÍÓÚÀÈÌÒÙüãẽõçÃẼÕ"()*_/\$+-:]
whitespace   <- %s+
wrapkey      <- [a-z]+
newline      <- %nl
]=]

parsed_elements = re.match(doc, element_breaker)

element_parser = [=[
line         <- {~ ( wrapblock / eqblock / codeblock / itemize / enumerate
                  / horline / chapter / section / subsection / normaltext / newline ) ~} / ({.*} ->
"
???
") !.
chapter      <- ("======" {text} "======" ) -> "\chapter{%1}" " "* newline
section      <- ("=====" {text} "=====" ) -> "\section{%1}" " "* newline
subsection   <- ("====" {text} "====" ) -> "\subsection{%1}" " "* newline
wrapblock    <- {~ ( "<WRAP " %s* {wrapkey} %s* ">"
                   {~ ( wrapblock / eqblock / codeblock / itemize / enumerate / bold / italic / under / mono / simplemath / figure / (wordchar / " " / newline) )+ ~}
                    "</WRAP>" " "* newline ) ->
"\begin{mdframed}[style=%1]
%2\end{mdframed}
" ~}

wrapkey      <- [a-z]+
eqblock      <- "\begin{equation}" newline (%s* !"\end{equation}" [^%nl]+ newline)+ "\end{equation}" newline
codeblock    <- ( "  " " "* { [^*-] [^%nl]* newline } -> "  %1")+ ->
"\begin{lstlisting}
%1\end{lstlisting}
"

itemize      <- {~ itemitem+ ~} ->
"\begin{itemize}
%1\end{itemize}
"

itemitem     <- ( "  " " "* "*" {[^%nl]* newline} ) ->  "  \item %1"
enumerate    <- {~ enumitem+ ~} ->
"\begin{enumerate}
%1\end{enumerate}
"

enumitem     <- ( "  " " "* "-" {[^%nl]* newline} ) ->  "  \item %1"
horline      <- ("----" "-"*) ->
"\begin{center}
  \line(1,0){450}
\end{center}
"

normaltext   <- {~ ( bold / italic / under / figure / mono / simplemath / {(wordchar / " " / [<>])} )+ ~} newline
figure       <- ("{{" {(wordchar / " " / [=+-/*|])+} "}}") -> "\includegraphics{%1}"
simplemath   <- "$" { (wordchar / " " / [\=+-/*])+ } "$"
bold         <- {~ ( "**" { (wordchar / " ")+ } "**" ) -> "{\bf %1}" ~}
italic       <- {~ ( "//" { (wordchar / " ")+ } "//" ) -> "{\it %1}" ~}
under        <- {~ ( "__" { (wordchar / " ")+ } "__" ) -> "{\bf %1}" ~}
mono         <- {~ ( "''" { (wordchar / " ")+ } "''" ) -> "{\bf %1}" ~}
text         <- (wordchar / " ")+
wordchar     <- [A-Za-z0-9-,.?!áéíóúàèìòùâêÂÊÁÉÍÓÚÀÈÌÒÙüãẽõçÃẼÕ"():/+-]
whitespace   <- %s+
newline      <- %nl
]=]

outstring = ""

for k, v in pairs(parsed_elements) do
   print(k, inspect(v))
   outstring = outstring .. re.match(v, element_parser)
end

file = io.open (arg[2], "w")
file:write(outstring)
io.close(file)

