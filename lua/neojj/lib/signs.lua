local M = {}

local signs = { NeoJJBlank = " " }

function M.get(name)
  local sign = signs[name]
  if sign == "" then
    return " "
  else
    return sign
  end
end

function M.setup(config)
  if not config.disable_signs then
    for key, val in pairs(config.signs) do
      if key == "hunk" or key == "item" or key == "section" then
        signs["NeoJJClosed" .. key] = val[1]
        signs["NeoJJOpen" .. key] = val[2]
      end
    end
  end
end

return M
