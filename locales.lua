local addonName, addon = ...

local L = setmetatable({}, { __index = function(t, k)
  local v = tostring(k)
  rawset(t, k, v)
  return v
end })
addon.L = L
local LOCALE = GetLocale()

BINDING_HEADER_RUNESETS = addonName

-- replace the parts after = if you want to help with localization
if LOCALE == "ruRU" then

elseif LOCALE == "frFR" then

elseif LOCALE == "deDE" then

else -- default

end

BINDING_HEADER_RUNESETSBINDS = L["RuneSet Binds"]
BINDING_NAME_RUNESETSTOGGLE = L["Toggle Engraving Frame"]
BINDING_NAME_RUNESET1 = L["Apply RuneSet 1"]
BINDING_NAME_RUNESET2 = L["Apply RuneSet 2"]
BINDING_NAME_RUNESET3 = L["Apply RuneSet 3"]
BINDING_NAME_RUNESET4 = L["Apply RuneSet 4"]
BINDING_NAME_RUNESET5 = L["Apply RuneSet 5"]
BINDING_NAME_RUNESET6 = L["Apply RuneSet 6"]
BINDING_NAME_RUNESET7 = L["Apply RuneSet 7"]
BINDING_NAME_RUNESET8 = L["Apply RuneSet 8"]