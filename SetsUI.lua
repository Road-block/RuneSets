local addonName, addon = ...
_G[addonName] = addon
local L = addon.L
local LABEL_FONT_COLOR = CreateColor(0,128/255,128/255)
addon._label = LABEL_FONT_COLOR:WrapTextInColorCode(addonName)
local LDB = LibStub("LibDataBroker-1.1")
local LDBIcon = LibStub("LibDBIcon-1.0")
local LSFDD = LibStub("LibSFDropDown-1.4")
local RUNESET_BUTTON_HEIGHT = 40
local MAX_RUNESETS = 10

local slotid_to_name = {
  [INVSLOT_AMMO] = INVTYPE_AMMO,
  [INVSLOT_HEAD] = INVTYPE_HEAD,
  [INVSLOT_NECK] = INVTYPE_NECK,
  [INVSLOT_SHOULDER] = INVTYPE_SHOULDER,
  [INVSLOT_BODY] = INVTYPE_BODY,
  [INVSLOT_CHEST] = INVTYPE_CHEST,
  [INVSLOT_WAIST] = INVTYPE_WAIST,
  [INVSLOT_LEGS] = INVTYPE_LEGS,
  [INVSLOT_FEET] = INVTYPE_FEET,
  [INVSLOT_WRIST] = INVTYPE_WRIST,
  [INVSLOT_HAND] = INVTYPE_HAND,
  [INVSLOT_FINGER1] = INVTYPE_FINGER,
  [INVSLOT_FINGER2] = INVTYPE_FINGER,
  [INVSLOT_TRINKET1] = INVTYPE_TRINKET,
  [INVSLOT_TRINKET2] = INVTYPE_TRINKET,
  [INVSLOT_BACK] = INVTYPE_CLOAK,
  [INVSLOT_MAINHAND] = INVTYPE_WEAPONMAINHAND,
  [INVSLOT_OFFHAND] = INVTYPE_WEAPONOFFHAND,
  [INVSLOT_RANGED] = INVTYPE_RANGED,
  [INVSLOT_TABARD] = INVTYPE_TABARD,
}
local slotid_to_icon = {
  [INVSLOT_CHEST] = "iconChest",
  [INVSLOT_LEGS] = "iconLegs",
  [INVSLOT_HAND] = "iconHands"
}
local icon_to_tex = {
  iconChest = 136512,
  iconLegs = 136517,
  iconHands = 136515,
}
local ordered_slots = {
  INVSLOT_CHEST,
  INVSLOT_LEGS,
  INVSLOT_HAND,
}
local state_names = {
  ["pvp"] = L["PvP"],
  ["world-solo"] = L["World-Solo"],
  ["world-party"] = L["World-Party"],
  ["world-raid"] = L["World-Raid"],
  ["dungeon"] = L["Dungeon"],
  ["raid"] = L["Raid"],
}
local state_ordered = {
  "pvp", "dungeon", "raid", "world-solo", "world-party", "world-raid"
}
local defaults = {
  sets = {
    {
      name=L["<empty RuneSet>"],
      runes = {},
    }
  }, states =
    {
      ["pvp"] = -1,
      ["world-solo"] = -1,
      ["world-party"] = -1,
      ["world-raid"] = -1,
      ["dungeon"] = -1,
      ["raid"] = -1,
    }
  }
addon.utils = {}
addon.Frame = {}
addon.Minimap = {}
addon.SetButton = {}

RuneSetsDB = RuneSetsDB or {["_edit"]=true,["_auto"]=true}

local f = CreateFrame("Frame", UIParent)
addon._event = f
f.OnEvent = function(_,event,...)
  return addon[event] and addon[event](addon,event,...)
end
f:SetScript("OnEvent", f.OnEvent)
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:RegisterEvent("GROUP_LEFT")
f:RegisterEvent("GROUP_FORMED")
f:RegisterEvent("UNIT_INVENTORY_CHANGED")
f:RegisterEvent("RUNE_UPDATED")

function addon.utils.tCount(tbl)
  local count = 0
  for k,v in pairs(tbl) do
    count = count + 1
  end
  return count
end

function addon.utils.Suppress(enable)
  if enable then
    SetCVar("Sound_EnableSFX", "0")
  else
    SetCVar("Sound_EnableSFX", "1")
  end
end

function addon.utils.Print(msg)
  local chatFrame = (SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME)
  chatFrame:AddMessage(format("%s: %s",addon._label,msg))
end

function addon.utils.MakeEscable(frame,enable)
  local frameName
  if type(frame)=="string" then
    frameName = frame
  else
    frameName = frame:GetName()
  end
  if frameName then
    local index = tIndexOf(UISpecialFrames, frameName)
    if enable and not index then
      tinsert(UISpecialFrames, frameName)
    elseif not enable and index then
      tremove(UISpecialFrames, index)
    end
  end
end

function addon.utils.FirstMatchedSet()
  local sets = addon.db[addon._playerKey].sets
  if not sets or #sets==0 then return false end
  local own = {}
  local matched
  for _,slot in ipairs(ordered_slots) do
    local runeInfo = C_Engraving.GetRuneForEquipmentSlot(slot)
    own[slot] = runeInfo and runeInfo.skillLineAbilityID or nil
  end
  if addon.utils.tCount(own) > 0 then
    local matched_id, matched_name
    for set_id, set in pairs(sets) do
      matched_id, matched_name = set_id, set.name
      local runes = set.runes
      for slot, runeid in pairs(own) do
        if not runes[slot] or runes[slot][1] ~= runeid then
          matched_id, matched_name = nil, nil
          break
        end
      end
      if matched_id and matched_name then
        return matched_id, matched_name
      end
    end
    return false
  else
    return false
  end
end

function addon.utils.IsSetEquipped(set_query)
  local sets = addon.db[addon._playerKey].sets
  if not sets or #sets==0 then return false end
  local set_id, set
  if type(set_query)=="number" then
    set_id = set_query
    set = sets[set_id]
  elseif type(set_query)=="string" then
    for id, sset in pairs(sets) do
      if strlower(sset.name) == strlower(set_query) then
        set_id = id
        set = sset
        break
      end
    end
  end
  if set then
    local runes = set.runes
    local equiphash, sethash
    for _,slot in ipairs(ordered_slots) do
      local runeInfo = C_Engraving.GetRuneForEquipmentSlot(slot)
      local runeid = runeInfo and runeInfo.skillLineAbilityID
      local setrune = runes[slot][1]
      equiphash = equiphash and format("%s:%s",equiphash,(runeid or 0)) or tostring(runeid or 0)
      sethash = sethash and format("%s:%s",sethash,(setrune or 0)) or tostring(setrune or 0)
    end
    return (equiphash==sethash and equiphash:gsub("[0:]","")~="")
  end
  return false
end

function addon.utils.StatusChange()
  local inInstance, instanceType = IsInInstance()
  local inBG = InActiveBattlefield()
  local worldPvP = IsInActiveWorldPVP("player")
  local changed, status
  if (instanceType and instanceType == "pvp") or inBG or worldPvP then
    addon._currState = "pvp"
  elseif IsInRaid() and GetNumGroupMembers()>1 then
    status = "raid"
  elseif IsInGroup() and GetNumGroupMembers()>1 then
    status = "party"
  elseif not IsInGroup() or GetNumGroupMembers()<2 then
    status = "solo"
  end
  if status == "solo" and not inInstance then
    addon._currState = "world-solo"
  end
  if (status == "party" or status == "raid") and not inInstance then
    addon._currState = "world-"..status
  end
  if inInstance and instanceType == "party" then
    addon._currState = "dungeon"
  end
  if inInstance and instanceType == "raid" then
    addon._currState = "raid"
  end
  if not addon._currState then addon._currState = "unknown" end
  if not addon._lastState or (addon._lastState ~= addon._currState) then
    changed = true
  else
    changed = false
  end
  addon._lastState = addon._currState
  return changed, addon._currState
end

local function ResizeRuneButtons()
  RUNE_BUTTON_HEIGHT=20
  EngravingFrame.scrollFrame.buttons[1]:SetHeight(20)
  HybridScrollFrame_CreateButtons(EngravingFrame.scrollFrame, "RuneSpellButtonTemplate", 0, -1, "TOPLEFT", "TOPLEFT", 0, -1, "TOP", "BOTTOM")
  for i,button in pairs(EngravingFrame.scrollFrame.buttons) do
    if button.icon then
      button.name:SetJustifyH("CENTER")
      button.icon:SetSize(18,18)
    end
    button:Hide()
  end
end

local function CacheRunes()
  C_Engraving.RefreshRunesList()
  local categories = C_Engraving.GetRuneCategories(true, true)
  for _, category in ipairs(categories) do
    local runes = C_Engraving.GetRunesForCategory(category, true)
  end
end

local function Setup()
  if ( not C_AddOns.IsAddOnLoaded("Blizzard_EngravingUI") ) then
    UIParentLoadAddOn("Blizzard_EngravingUI")
  end
  if not EngravingFrameCloseButton then
    EngravingFrameCloseButton=CreateFrame("Button","EngravingFrameCloseButton",EngravingFrame,"UIPanelCloseButton")
    EngravingFrameCloseButton:SetPoint("TOPRIGHT",EngravingFrame.Border,"TOPRIGHT",0,0)
    EngravingFrameCloseButton:SetFrameStrata("HIGH")
    EngravingFrameCloseButton:Raise()
    EngravingFrame:SetMovable(true)
    EngravingFrame.Border:EnableMouse(true)
    EngravingFrame.Border:RegisterForDrag("LeftButton")
    EngravingFrame.Border:HookScript("OnDragStart", function(self,button)
     EngravingFrame:StartMoving()
    end)
    EngravingFrame.Border:HookScript("OnDragStop",function(self,button)
     EngravingFrame:StopMovingOrSizing()
    end)
    EngravingFrame:HookScript("OnShow",function(self)
      if CharacterFrame:IsShown() then
        EngravingFrame:StopMovingOrSizing()
        EngravingFrame:ClearAllPoints()
        EngravingFrame:SetUserPlaced(false)
        EngravingFrame:SetPoint("TOPLEFT",CharacterFrame,"TOPRIGHT",-24,-70)
      end
    end)
    addon.utils.MakeEscable(EngravingFrame,true)
    ResizeRuneButtons()
  end
  EngravingFrameSpell_OnClick = function(self, button)
    if InCombatLockdown() then return end
    C_Engraving.CastRune(self.skillLineAbilityID)
    if button == "RightButton" then
      local castInfo = C_Engraving.GetCurrentRuneCast()
      if castInfo and castInfo.equipmentSlot then
        addon._isEngraving = true
        addon.utils.Suppress(addon._isEngraving)
        UseInventoryItem(castInfo.equipmentSlot, "player")
        local dialog = StaticPopup_FindVisible("REPLACE_ENCHANT")
        if dialog then
          _G[dialog:GetName().."Button1"]:Click()
          StaticPopup_Hide("REPLACE_ENCHANT")
        end
        addon._isEngraving = false
        addon.utils.Suppress(addon._isEngraving)
      end
    end
  end
  hooksecurefunc("EngravingFrame_UpdateRuneList", function()
    for i,button in pairs(EngravingFrame.scrollFrame.buttons) do
      local runeid = button.skillLineAbilityID
      if runeid and C_Engraving.IsRuneEquipped(runeid) then
        button.selectedTex:Show()
      end
    end
  end)
  hooksecurefunc(GameTooltip,"SetEngravingRune",function(self)
    GameTooltip:AddLine(GREEN_FONT_COLOR:WrapTextInColorCode(L["<Right-Click to Quick Apply>"]))
  end)
end

local function ShowMinimap()
  if RuneSetsDB._minimap.hide then
    LDBIcon:Hide(addonName)
  else
    LDBIcon:Show(addonName)
  end
end

local set_menu_list, set_menu_func = {}, function(btn)
  addon._selectedSet = btn.value
  addon._dataBroker.text = btn.text
end
local function BuildMenu(obj)
  local sets = addon.db[addon._playerKey].sets
  if not sets or #sets==0 then return end
  wipe(set_menu_list)
  for set_id,set in pairs(sets) do
    if set and set.includeInMenus then
      tinsert(set_menu_list,{ notCheckable = true, text=set.name, value=set_id, func = set_menu_func})
    end
  end
  if #set_menu_list > 0 then
    addon.Minimap.dropdown:ddEasyMenu(set_menu_list, "cursor", -50, 0, "menu")
  end
end

local function MinimapOnClick(obj, button)
  if button=="RightButton" then
    ToggleEngravingFrame()
  elseif button=="LeftButton" then
    if addon._selectedSet then
      addon.RunSet(addon._selectedSet)
    else
      BuildMenu(obj)
    end
  elseif button=="MiddleButton" and addon._selectedSet then
    addon._selectedSet = nil
    addon._dataBroker.text = addonName
  end
end

local function MinimapOnEnter(tooltip)
  tooltip:SetText(addon._label)
  if addon._selectedSet then
    tooltip:AddDoubleLine(L["Click:"],L["Apply Set"],nil,nil,nil,1,1,1)
    tooltip:AddDoubleLine(L["Middle-Click:"],L["Clear Selected"],nil,nil,nil,1,1,1)
  else
    tooltip:AddDoubleLine(L["Click:"],L["Select Set"],nil,nil,nil,1,1,1)
  end
  tooltip:AddDoubleLine(L["Right-Click:"],L["Toggle Engraving Frame"],nil,nil,nil,1,1,1)
end

local function InitBroker(isLogin, isReload)
  addon._dataBroker = LDB:NewDataObject(addonName, {
    type = "launcher",
    text = addonName,
    label = addon._label,
    icon = [[Interface\Icons\INV_Misc_Rune_06]],
    OnClick = MinimapOnClick,
    OnTooltipShow = MinimapOnEnter,
  })
  RuneSetsDB._minimap = RuneSetsDB._minimap or { hide = false }
  LDBIcon:Register(addonName, addon._dataBroker, RuneSetsDB._minimap)
  addon.Minimap.dropdown = addon.Minimap.dropdown or LSFDD:SetMixin({})
  addon.Minimap.dropdown:ddHideWhenButtonHidden(LDBIcon:GetMinimapButton(addonName))
  addon.Minimap.dropdown:ddSetMaxHeight(180)
  ShowMinimap()
end

local function InitVars(isLogin, isReload)
  addon._playerKey = format("%s-%s",(UnitNameUnmodified("player")),(GetNormalizedRealmName()))
  addon.db = addon.db or RuneSetsDB
  addon.db[addon._playerKey] = addon.db[addon._playerKey] or defaults
  InitBroker(isLogin, isReload)
end

local function HasAutomation(status)
  local states = addon.db[addon._playerKey].states
  if status then
    local set_id = states[status]
    if set_id and set_id > 0 then
      return true, set_id
    end
    return false
  end
  for state, set_id in pairs(states) do
    if set_id and set_id > 0 then
      return true
    end
  end
  return false
end

local function AutomateSet(newStatus)
  local sets = addon.db[addon._playerKey].sets
  if not sets or #sets==0 then return false end
  local hasSet, set_id = HasAutomation(newStatus)
  local status_name = state_names[newStatus]
  local set = sets[set_id]
  if hasSet and set and not addon.utils.IsSetEquipped(set_id) then
    addon._selectedSet = set_id
    addon._dataBroker.text = set.name
    PlaySound(SOUNDKIT.TUTORIAL_POPUP)
    RaidNotice_AddMessage(RaidBossEmoteFrame, format(L["%s: RuneSet %q Ready"],status_name, set.name),ChatTypeInfo["RAID_WARNING"], 10)
    addon.utils.Print(format(L["%s: RuneSet %q Ready"],status_name, set.name))
    return true
  end
end

local function ConfirmDelete(setname,set_id)
  if not StaticPopupDialogs["RUNESETS_CONFIRM_DELETE"] then
    StaticPopupDialogs["RUNESETS_CONFIRM_DELETE"] = {}
  end
  local t = StaticPopupDialogs["RUNESETS_CONFIRM_DELETE"]
  for k in pairs(t) do
    t[k] = nil
  end
  t.text = format(L["You are removing %q Rune Set"],setname)
  t.button1 = ACCEPT
  t.button2 = CANCEL
  t.preferredIndex = STATICPOPUP_NUMDIALOGS
  t.OnAccept = function(self,data)
    local set_id = data
    local states = addon.db[addon._playerKey].states
    local sets = addon.db[addon._playerKey].sets
    sets[set_id] = nil
    for state,id in pairs(states) do
      if id == set_id then
        states[state] = -1
        break
      end
    end
    addon.Frame.UpdateSetList(RuneSetsFrame)
  end
  t.OnCancel = function(self,data)
  end
  t.timeout = 0
  t.whileDead = 1
  t.hideOnEscape = 1
  local dialog = StaticPopup_Show("RUNESETS_CONFIRM_DELETE",setname)
  if dialog then
    dialog.data = set_id
  end
end

function addon:ADDON_LOADED(event,...)
  if ... == addonName then
    if RuneSetsDB._auto then
      addon._event:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    else
      addon._event:UnregisterEvent("PLAYER_EQUIPMENT_CHANGED")
    end
  end
end

function addon:PLAYER_ENTERING_WORLD(event,...)
  local isLogin, isReload = ...
  if isLogin or isReload then
    Setup()
    InitVars(isLogin, isReload)
    CacheRunes()
  end
  if HasAutomation() then
    local statusChanged, newStatus = addon.utils.StatusChange()
    if statusChanged then
      AutomateSet(newStatus)
    end
  end
end

function addon:ZONE_CHANGED_NEW_AREA(event,...)
  if HasAutomation() then
    local statusChanged, newStatus = addon.utils.StatusChange()
    if statusChanged then
      AutomateSet(newStatus)
    end
  end
end
addon.GROUP_LEFT = addon.ZONE_CHANGED_NEW_AREA
addon.GROUP_FORMED = addon.ZONE_CHANGED_NEW_AREA

function addon:UNIT_INVENTORY_CHANGED(event,...)
  if ... == "player" and EngravingFrame:IsVisible() then
    EngravingFrame_UpdateRuneList(EngravingFrame)
  end
end

function addon:RUNE_UPDATED(event,...)
  local rune = ...
  if EngravingFrame:IsVisible() then
    addon.Frame.UpdateSetList(RuneSetsFrame)
  end
end

function addon:PLAYER_EQUIPMENT_CHANGED(event,...)
  local slot, emptied = ...
  if not emptied and slotid_to_icon[slot] then
    local runeInfo = C_Engraving.GetRuneForEquipmentSlot(slot)
    if not (runeInfo and runeInfo.skillLineAbilityID) then
      local ownedSlotRunes = C_Engraving.GetRunesForCategory(slot, true) -- owned only
      -- maybe we do a quickload popout down the road for now just show Engraving
      if #ownedSlotRunes > 0 then
        local prompted
        if HasAutomation() then
          local statusChanged, newStatus = addon.utils.StatusChange()
          prompted = AutomateSet(newStatus)
        end
        if not prompted then
          if not EngravingFrame:IsVisible() then
            ToggleEngravingFrame()
          end
        end
        RaidNotice_AddMessage(RaidBossEmoteFrame,format(L["New %s item equipped without a Rune"],slotid_to_name[slot]),ChatTypeInfo["SYSTEM"], 5)
        addon.utils.Print(format(L["New %s item equipped without a Rune"],slotid_to_name[slot]))
      end
    end
  end
end

function addon:NEW_RECIPE_LEARNED(event,...)
  local recipeID,recipeLevel,baseRecipeID = ...
end

function addon.RunSet(set_id)
  local sets = addon.db[addon._playerKey].sets
  if not sets or #sets==0 then return end
  local set, runes
  if type(set_id)=="number" then
    set = sets[set_id]
    if set then
      runes = set.runes
    end
  elseif type(set_id)=="string" then
    for id, v in pairs(sets) do
      if strlower(v.name)==strlower(set_id) then
        set_id = id
        set = v
        runes = set.runes
        break
      end
    end
  end
  if runes and addon.utils.tCount(runes)>0 then
    for slot, rune in pairs(runes) do
      local skillLineAbilityID = rune[1]
      if not C_Engraving.IsRuneEquipped(skillLineAbilityID) then
        C_Engraving.CastRune(skillLineAbilityID)
        local castInfo = C_Engraving.GetCurrentRuneCast()
        if castInfo and castInfo.equipmentSlot then
          addon._isEngraving = true
          addon.utils.Suppress(addon._isEngraving)
          UseInventoryItem(castInfo.equipmentSlot, "player")
          local dialog = StaticPopup_FindVisible("REPLACE_ENCHANT")
          if dialog then
            _G[dialog:GetName().."Button1"]:Click()
            StaticPopup_Hide("REPLACE_ENCHANT")
          end
          addon._isEngraving = false
          addon.utils.Suppress(addon._isEngraving)
        end
      end
    end
  end
end

function addon.SetButton.OnEnter(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetText(addon._label)
  local sets = addon.db[addon._playerKey].sets
  if addon.db._edit then
    GameTooltip:AddLine(L["Click runes on the left then click on this button to store them"],nil,nil,nil,true)
    GameTooltip:AddLine(L["Double-click the Set name to edit"],nil,nil,nil,true)
  else
    GameTooltip:AddLine(L["Click to apply Set Runes"])
    local set_id = self:GetID()
    if sets and #sets>0 then
      local runes = sets[set_id] and sets[set_id].runes
      if runes and addon.utils.tCount(runes)>0 then
        for _,slot in ipairs(ordered_slots) do
          if runes[slot] then
            GameTooltip:AddLine(runes[slot][3],1,1,1)
          else
            GameTooltip:AddLine(EMPTY)
          end
        end
      end
      local bindingText = GetBindingText(GetBindingKey("RUNESET"..set_id))
      if bindingText and bindingText~="" then
        GameTooltip:AddDoubleLine("Keybind:",bindingText)
      end
    end
  end
  GameTooltip:Show()
end
function addon.SetButton.ShowIncludeOption(option)
  local set_id = option:GetParent():GetID()
  local sets = addon.db[addon._playerKey].sets
  if not sets or #sets==0 then return end
  local set = set_id and sets[set_id]
  if set then
    option:SetChecked(not not set.includeInMenus)
  end
end
function addon.SetButton.IncludeOptionClicked(option)
  local set_id = option:GetParent():GetID()
  local sets = addon.db[addon._playerKey].sets
  if not sets or #sets==0 then return end
  local set = set_id and sets[set_id]
  if set then
    set.includeInMenus = option:GetChecked()
  end
end
function addon.SetButton.PreClick(self, button)
  if not addon.db._edit then return end
  local castInfo = C_Engraving.GetCurrentRuneCast()
  local sets = addon.db[addon._playerKey].sets
  if castInfo and castInfo.equipmentSlot then
    local setID = self:GetID()
    local slot = castInfo.equipmentSlot
    local skillLineAbilityID = castInfo.skillLineAbilityID
    local name = castInfo.name
    local icon = castInfo.iconTexture
    self[slotid_to_icon[slot]]:SetTexture(icon)
    sets[setID] = sets[setID] or {name = L["<empty RuneSet>"], runes = {}}
    sets[setID].runes[slot] = {skillLineAbilityID,icon,name}
    PlaySound(SOUNDKIT.IG_ABILITY_ICON_DROP)
    if sets[setID].includeInMenus == nil then -- respect false setting
      sets[setID].includeInMenus = true
    end
  end
end
function addon.SetButton.PostClick(self, button)
  if addon.db._edit then return end
  local setID = self:GetID()
  local sets = addon.db[addon._playerKey].sets
  if not sets or #sets==0 then return end
  local runes = sets[setID] and sets[setID].runes
  if runes then
    for slot, rune in pairs(runes) do
      local skillLineAbilityID = rune[1]
      if not C_Engraving.IsRuneEquipped(skillLineAbilityID) then
        C_Engraving.CastRune(skillLineAbilityID)
        local castInfo = C_Engraving.GetCurrentRuneCast()
        if castInfo and castInfo.equipmentSlot then
          addon._isEngraving = true
          addon.utils.Suppress(addon._isEngraving)
          UseInventoryItem(castInfo.equipmentSlot, "player")
          local dialog = StaticPopup_FindVisible("REPLACE_ENCHANT")
          if dialog then
            _G[dialog:GetName().."Button1"]:Click()
            StaticPopup_Hide("REPLACE_ENCHANT")
          end
          addon._isEngraving = false
          addon.utils.Suppress(addon._isEngraving)
        end
      end
    end
  end
end
function addon.SetButton.NameClick(setbutton)
  local now = GetTime()
  if setbutton._lastClick and (now-setbutton._lastClick)<0.6 then
    setbutton.editBox:Show()
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
  end
  setbutton._lastClick = now
end
function addon.SetButton.NameGet(setbutton)
  local set_id = setbutton:GetID()
  local sets = addon.db[addon._playerKey].sets
  if not sets or #sets==0 then return L["<empty RuneSet>"] end
  if sets[set_id] then
    return sets[set_id].name
  end
  return L["<empty RuneSet>"]
end
function addon.SetButton.NameSet(setbutton)
  local set_id = setbutton:GetID()
  local sets = addon.db[addon._playerKey].sets
  if sets and sets[set_id] then
    local currText = strtrim(setbutton.editBox:GetText())
    sets[set_id].name = currText ~= "" and currText or L["<empty RuneSet>"]
  end
  setbutton.editBox:Hide()
  PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
  addon.Frame.UpdateSetList(RuneSetsFrame)
end
function addon.SetButton.DeleteSet(setbutton)
  local sets = addon.db[addon._playerKey].sets
  local set_id = setbutton:GetID()
  local set = sets and sets[set_id]
  if set then
    local setname = set.name
    ConfirmDelete(setname, set_id)
  end
  PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
end
function addon.SetButton.ScriptSet(setbutton)
  local set_id = setbutton:GetID()
  local sets = addon.db[addon._playerKey].sets
  local states = addon.db[addon._playerKey].states
  local set = sets and sets[set_id]
  if set then
    local name = set.name
    local statekey,statename
    for key,id in pairs(states) do
      if id == set_id then
        statekey = key
        statename = state_names[statekey]
        break
      end
    end
    if not RuneSetsSetOptionFrame:IsShown() then
      RuneSetsSetOptionFrame:SetID(set_id)
      RuneSetsSetOptionFrame.setName.Text:SetText(name)
      if statekey and statename then
        UIDropDownMenu_SetSelectedValue(RuneSetsSetOptionFrame.statedd, statekey)
        UIDropDownMenu_SetText(RuneSetsSetOptionFrame.statedd, statename)
      else
        UIDropDownMenu_SetSelectedValue(RuneSetsSetOptionFrame.statedd, -1)
        UIDropDownMenu_SetText(RuneSetsSetOptionFrame.statedd, NONE)
      end
      RuneSetsSetOptionFrame:ClearAllPoints()
      RuneSetsSetOptionFrame:SetPoint("TOPLEFT",setbutton,"TOPRIGHT",40,0)
      RuneSetsSetOptionFrame:Show()
    else
      local option_id = RuneSetsSetOptionFrame:GetID()
      if option_id and option_id == set_id then
        RuneSetsSetOptionFrame:Hide()
      else
        RuneSetsSetOptionFrame:SetID(set_id)
        RuneSetsSetOptionFrame.setName.Text:SetText(name)
        if statekey and statename then
          UIDropDownMenu_SetSelectedValue(RuneSetsSetOptionFrame.statedd, statekey)
          UIDropDownMenu_SetText(RuneSetsSetOptionFrame.statedd, statename)
        else
          UIDropDownMenu_SetSelectedValue(RuneSetsSetOptionFrame.statedd, -1)
          UIDropDownMenu_SetText(RuneSetsSetOptionFrame.statedd, NONE)
        end
        RuneSetsSetOptionFrame:ClearAllPoints()
        RuneSetsSetOptionFrame:SetPoint("TOPLEFT",setbutton,"TOPRIGHT",40,0)
      end
    end
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
  end
end
function addon.Frame.Toggle(self)
  if ( self.collapsed ) then
    RuneSets.Frame.Expand(self)
    PlaySound(SOUNDKIT.IG_QUEST_LIST_OPEN)
  else
    RuneSets.Frame.Collapse(self)
    PlaySound(SOUNDKIT.IG_QUEST_LIST_CLOSE)
  end
end

function addon.Frame.Automate(self, arg1)
  local dropdown = self:GetParent().dropdown
  UIDropDownMenu_SetSelectedValue(dropdown, arg1)
  UIDropDownMenu_SetText(dropdown, self.value)
  local set_id = dropdown:GetParent():GetID()
  local states = addon.db[addon._playerKey].states
  if set_id then
    if arg1 == -1 then
      for state,id in pairs(states) do
        if id == set_id then
          states[state]=arg1
          break
        end
      end
    else
      if states[arg1]~=set_id then
        states[arg1]=set_id
        if HasAutomation() then
          local statusChanged, newStatus = addon.utils.StatusChange()
          AutomateSet(newStatus)
        end
      end
    end
  end
end

function addon.Frame.MiniOptionClicked(self)
  if (self.enabled) then
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
  else
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
  end
  RuneSets.db._minimap.hide = not self:GetChecked()
  ShowMinimap()
end

function addon.Frame.AutoClicked(self)
  if (self.enabled) then
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
  else
    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
  end
  addon.db._auto = self:GetChecked()
  if addon.db._auto then
    addon._event:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
  else
    addon._event:UnregisterEvent("PLAYER_EQUIPMENT_CHANGED")
  end
end
function addon.Frame.Expand(self)
  self.collapsed = false;
  self:SetPoint("TOPLEFT", EngravingFrame, "TOPRIGHT",15,0)
  self.contentFrame:Show()
  self:Raise()
end
function addon.Frame.Collapse(self)
  self.collapsed = true;
  self:SetPoint("TOPLEFT", EngravingFrame, "TOPLEFT",0,0)
  self.contentFrame:Hide()
  RuneSetsSetOptionFrame:Hide()
  self:Lower()
end
function addon.Frame.UpdateSetList(self)
  local editmode = addon.db._edit
  local numSets = 0
  local scrollFrame = RuneSetsFrame.contentFrame.scrollFrame
  local buttons = scrollFrame.buttons
  local offset = HybridScrollFrame_GetOffset(scrollFrame)
  local sets = addon.db[addon._playerKey].sets
  for buttonIndex = 1, #buttons do
    local button = buttons[buttonIndex]
    local set_id = buttonIndex + offset
    button:SetID(set_id)
    local differs
    if set_id <= MAX_RUNESETS then
      local set = sets and sets[set_id]
      if set then
        button.name:SetText(set.name)
        local runes = sets[set_id].runes
        for slot, key in pairs(slotid_to_icon) do
          button[key]:SetTexture(icon_to_tex[key])
        end
        for slot, rune in pairs(runes) do
          button[slotid_to_icon[slot]]:SetTexture(rune[2])
          if not C_Engraving.IsRuneEquipped(rune[1]) then
            differs = true
          end
        end
        if not (differs or editmode) then
          button.disabledBG:Show()
          button:Disable()
        else
          button.disabledBG:Hide()
          button:Enable()
        end
        button.iconPlay:SetDesaturated(false)
      else
        button.name:SetText(L["<empty RuneSet>"])
        for slot, key in pairs(slotid_to_icon) do
          button[key]:SetTexture(icon_to_tex[key])
        end
        button.disabledBG:Hide()
        button.iconPlay:SetDesaturated(true)
        button:Enable()
      end
      if editmode then
        button.iconPlay:Hide()
        button.delete:Show()
        button.options:Show()
      else
        button.delete:Hide()
        button.options:Hide()
        button.iconPlay:Show()
      end
      button:Show()
    else
      button:Hide()
    end
  end

  local totalHeight = MAX_RUNESETS * RUNESET_BUTTON_HEIGHT
  HybridScrollFrame_Update(scrollFrame, totalHeight+10, 348)

  RuneSetsFrame.contentFrame.scrollFrame.emptyText:Hide()
end
function addon.Frame.StatesDDInit()
  local info = UIDropDownMenu_CreateInfo()
  info.func = addon.Frame.Automate

  info.text = NONE
  info.notCheckable = true
  info.arg1 = -1
  UIDropDownMenu_AddButton(info)

  for _,state in ipairs(state_ordered) do
    info.text = state_names[state]
    info.notCheckable = true
    info.arg1 = state
    UIDropDownMenu_AddButton(info)
  end

end
function addon.Frame.OnLoad(self)
  self:RegisterEvent("ADDON_LOADED")
  self.contentFrame.scrollFrame.update = function() addon.Frame.UpdateSetList(self) end
  self.contentFrame.scrollFrame.scrollBar.doNotHide = true;

  HybridScrollFrame_CreateButtons(self.contentFrame.scrollFrame, "RuneSetButtonTemplate", 0, -1, "TOPLEFT", "TOPLEFT", 0, -1, "TOP", "BOTTOM")
end
function addon.Frame.OnEvent(self,event,...)
  if ... == "Blizzard_EngravingUI" then
    self:ClearAllPoints()
    self:SetParent(EngravingFrame)
    RuneSets.Frame.Collapse(RuneSetsFrame)
    EngravingFrame:HookScript("OnHide",function()
      RuneSets.Frame.Collapse(RuneSetsFrame)
      RuneSetsFrame:Hide()
    end)
    EngravingFrame:HookScript("OnShow",function()
      RuneSetsFrame:Show()
      addon.Frame.UpdateSetList(RuneSetsFrame)
      RuneSets.Frame.Collapse(RuneSetsFrame)
    end)
  end
end

SLASH_RUNESETS1 = "/engraveme"
SLASH_RUNESETS2 = "/runeme"
SLASH_RUNESETS3 = "/"..addonName:lower()
SlashCmdList["RUNESETS"] = function(msg)
  local msg = (msg or ""):trim()
  local set_id = tonumber(msg)
  if set_id then
    addon.RunSet(set_id)
  elseif #msg > 0 then
    addon.RunSet(msg)
  else
    ToggleEngravingFrame()
  end
end