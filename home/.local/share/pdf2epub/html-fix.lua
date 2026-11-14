-- Normaliza HTML bruto vindo do Marker para XHTML válido (EPUB3).
-- O Marker escreve <br> e eventualmente <img ...> dentro de tabelas HTML;
-- o Pandoc repassa esse HTML bruto sem fechar as tags, o que gera EPUB inválido.
--
-- O OCR também transforma texto literal em "tags": exemplos de NETCONF virão
-- como <get-config>, <rpc-reply>, e e-mails como <hg@cs.umass.edu>. Esses nomes
-- não são elementos HTML, e o epubcheck reprova o EPUB inteiro por causa deles.
-- Tudo que não está na lista de elementos conhecidos é escapado e passa a
-- aparecer como texto.

local ALLOWED = {}
local ELEMENTS = [[
a abbr area article aside audio b bdi bdo big blockquote br button canvas
caption cite code col colgroup data datalist dd del details dfn div dl dt em
embed fieldset figcaption figure footer form h1 h2 h3 h4 h5 h6 header hr i
img ins kbd label legend li main map mark menu meter nav noscript object ol
optgroup option output p picture pre progress q rp rt ruby s samp section
select small source span strong sub summary sup svg table tbody td template
textarea tfoot th thead time tr track u ul var video wbr
math mrow mi mn mo mtext mspace msup msub msubsup mfrac msqrt mroot mtable
mtr mtd mover munder munderover mfenced menclose mmultiscripts semantics
annotation annotation-xml g path circle rect line ellipse polygon polyline
text tspan defs use symbol clippath lineargradient radialgradient stop mask
pattern image foreignobject marker filter fegaussianblur
]]
for name in ELEMENTS:gmatch("%S+") do
  ALLOWED[name] = true
end

local function fix_image(tag)
  local attrs = tag:match("^<img(.*)>$") or ""
  attrs = attrs:gsub("%s*/%s*$", "")
  if not attrs:find("src%s*=") then
    return "" -- ícone decorativo sem imagem real: descarta
  end
  return "<img" .. attrs .. " />"
end

-- Escapa tags cujo nome não é um elemento conhecido, preservando o texto.
local function escape_unknown_tags(s)
  return (s:gsub("<%s*(/?)%s*([%a][%w:%.%-_]*)([^<>]*)>", function(slash, name, rest)
    if ALLOWED[name:lower()] then
      return "<" .. slash .. name .. rest .. ">"
    end
    return "&lt;" .. slash .. name .. rest .. "&gt;"
  end))
end

local function normalize(s)
  s = s:gsub("<br%s*/?>", "<br />")
  s = s:gsub("<hr%s*/?>", "<hr />")
  s = s:gsub("<img[^>]*>", fix_image)
  -- Instruções de processamento e declarações viram texto literal:
  -- exemplos de XML/NETCONF no livro produzem <?xml ...?> e <!DOCTYPE ...>.
  s = s:gsub("<%?([^<>]*)%?>", "&lt;?%1?&gt;")
  s = s:gsub("<!%s*([%a][^<>]*)>", "&lt;!%1&gt;")
  s = s:gsub("<!%[CDATA%[([^<>]*)%]%]>", "&lt;![CDATA[%1]]&gt;")
  s = escape_unknown_tags(s)
  s = s:gsub("<([^%a/!])", "&lt;%1")
  return s
end

function RawInline(el)
  if el.format:match("html") then
    local fixed = normalize(el.text)
    if fixed == "" then
      return {} -- remove o elemento
    end
    el.text = fixed
    return el
  end
end

function RawBlock(el)
  if el.format:match("html") then
    el.text = normalize(el.text)
    return el
  end
end
