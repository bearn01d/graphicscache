
& latex graphicscache.ins
if (-not $?)
{
    throw 'graphicscache compilation failed'
}

$env:TEXINPUTS="$pwd;"

cd example

& pdflatex -shell-escape paper
if (-not $?)
{
    throw 'pdflatex failed'
}
