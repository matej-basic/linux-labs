-- Pandoc filter for the student docs on GitHub Pages (scripts/update-pages.sh).
-- The guides name each other as plain file names ("see troubleshooting.md.")
-- because they are also read as text files under /usr/share/doc. On the site
-- those names become links to the rendered .html pages, and every table is
-- wrapped in a div that scrolls on narrow screens. The guides also write
-- placeholders like <lab> as plain text; GFM would pass them through as raw
-- HTML tags, so they are turned back into text.

local guides = { ["getting-started"] = true, commands = true, troubleshooting = true }

function Str(el)
  local name, rest = el.text:match("^([%w%-]+)%.md(.*)$")
  if name and guides[name] then
    local link = pandoc.Link(name .. ".md", name .. ".html")
    if rest == "" then
      return link
    end
    return { link, pandoc.Str(rest) }
  end
end

function Link(el)
  if el.target:match("^[%w%-]+%.md$") then
    el.target = el.target:gsub("%.md$", ".html")
  end
  return el
end

function Table(el)
  return pandoc.Div({ el }, pandoc.Attr("", { "table-wrap" }))
end

function RawInline(el)
  if el.format == "html" then
    return pandoc.Str(el.text)
  end
end

function RawBlock(el)
  if el.format == "html" then
    return pandoc.Plain({ pandoc.Str(el.text) })
  end
end
