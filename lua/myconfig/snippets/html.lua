local fmt = require("luasnip.extras.fmt").fmt
local insert_node = require("luasnip").insert_node
local snippet = require("luasnip").snippet

return {
  snippet(
    { trig = "html5", name = "HTML5 document" },
    fmt(
      [[
<!DOCTYPE html>
<html lang="{}">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{}</title>
</head>
<body>
  {}
</body>
</html>
]],
      { insert_node(1, "en"), insert_node(2, "Document"), insert_node(0) }
    )
  ),
  snippet(
    { trig = ".name", name = "div with class name", wordTrig = false },
    fmt('<div class="name">{}</div>', { insert_node(0) })
  ),
}
