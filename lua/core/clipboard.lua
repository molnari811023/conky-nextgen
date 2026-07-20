--[[
  Conky NextGen Framework
  core/clipboard.lua — Clipboard handling
]]

local clipboard_cmd = nil

local function detect_clipboard()
  local handle = io.popen("which xclip 2>/dev/null")
  if handle then
    local r = handle:read("*a")
    handle:close()
    if r and r ~= "" then return "xclip" end
  end
  handle = io.popen("which wl-copy 2>/dev/null")
  if handle then
    local r = handle:read("*a")
    handle:close()
    if r and r ~= "" then return "wl-copy" end
  end
  handle = io.popen("which xsel 2>/dev/null")
  if handle then
    local r = handle:read("*a")
    handle:close()
    if r and r ~= "" then return "xsel" end
  end
  return nil
end

function copy_to_clipboard(text)
  if not text or text == "" then return false end

  if not clipboard_cmd then
    local provider = detect_clipboard()
    if provider == "xclip" then
      clipboard_cmd = "xclip -selection clipboard"
    elseif provider == "wl-copy" then
      clipboard_cmd = "wl-copy"
    elseif provider == "xsel" then
      clipboard_cmd = "xsel --clipboard --input"
    else
      return false
    end
  end

  local handle = io.popen(clipboard_cmd, "w")
  if handle then
    handle:write(text)
    handle:close()
    return true
  end
  return false
end
