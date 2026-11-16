local NUM_MACRO_ICONS_SHOWN = 20;
local NUM_ICONS_PER_ROW = 5;
local NUM_ICON_ROWS = 4;
local MACRO_ICON_ROW_HEIGHT = 36;

local i, j;

UIPanelWindows["BindPadFrame"] = { area = "left", pushable = 8, whileDead = 1 };
UIPanelWindows["BindPadMacroTextFrame"] = { area = "left", pushable = 9, whileDead = 1 };

tinsert(UISpecialFrames,"BindPadBindFrame");

local BINDPAD_MAXSLOTS = 42;
local BINDPAD_TOTALSLOTS = BINDPAD_MAXSLOTS * 4;
local BINDPAD_MAXPROFILETAB = 5;
local BINDPAD_GENERAL_TAB = 1;
local BINDPAD_SAVEFILE_VERSION = 1.3;

BindPadVars = {
  tab = BINDPAD_GENERAL_TAB,
  version = BINDPAD_SAVEFILE_VERSION,
};

BindPadCore = {
  actionButtonNames = {};
  actionButtonIds = {};
  IsHighestCash = {};
  hotkeyShownBefore = {};
  hotkeyTextBefore = {};
  hotkeyShownAfter = {};
  hotkeyTextAfter = {};
  drag = {};
  dragswap = {};
  specInfoCache = {};
};
local BindPadCore = BindPadCore;

StaticPopupDialogs["BINDPAD_CONFIRM_DELETING_CHARACTER_SPECIFIC_BINDINGS"] = {
  text = CONFIRM_DELETING_CHARACTER_SPECIFIC_BINDINGS,
  button1 = OKAY,
  button2 = CANCEL,
  OnAccept = function()
    StaticPopup_Show("BINDPAD_CONFIRM_DELETING_CHARACTER_SPECIFIC_BINDINGS2");
  end,
  OnCancel = function()
    BindPadFrameCharacterButton:SetChecked(GetCurrentBindingSet() == 2);
  end,
  timeout = 0,
  whileDead = 1,
  showAlert = 1,
  hideOnEscape = 1
};

StaticPopupDialogs["BINDPAD_CONFIRM_DELETING_CHARACTER_SPECIFIC_BINDINGS2"] = {
  text = BINDPAD_TEXT_ARE_YOU_SURE,
  button1 = OKAY,
  button2 = CANCEL,
  OnAccept = function()
    LoadBindings(1);
    SaveBindings(1);
    BindPadVars.tab = 1;
    BindPadFrame_OnShow();
  end,
  OnCancel = function()
    BindPadFrameCharacterButton:SetChecked(GetCurrentBindingSet() == 2);
  end,
  timeout = 0,
  whileDead = 1,
  showAlert = 1,
  hideOnEscape = 1
};

StaticPopupDialogs["BINDPAD_CONFIRM_CHANGE_BINDING_PROFILE"] = {
  text = BINDPAD_TEXT_CONFIRM_CHANGE_BINDING_PROFILE,
  button1 = OKAY,
  button2 = CANCEL,
  OnAccept = function()
    LoadBindings(2);
    SaveBindings(2);
    BindPadVars.tab = 2;
    BindPadFrame_OnShow();
  end,
  OnCancel = function()
    BindPadVars.tab = 1;
  end,
  timeout = 0,
  whileDead = 1,
  showAlert = 1,
  hideOnEscape = 1
};

StaticPopupDialogs["BINDPAD_CONFIRM_CONVERT"] = {
  text = BINDPAD_TEXT_CONFIRM_CONVERT,
  button1 = OKAY,
  button2 = CANCEL,
  OnAccept = function(id)
    BindPadCore.ConvertToBindPadMacro(id);
  end,
  OnCancel = function()
  end,
  timeout = 0,
  whileDead = 1,
  showAlert = 1,
  hideOnEscape = 1
};

function BindPadFrame_OnLoad(self)
  PanelTemplates_SetNumTabs(BindPadFrame, 4);

  SlashCmdList["BINDPAD"] = BindPadFrame_SlashCmd;
  SLASH_BINDPAD1 = "/bindpad";
  SLASH_BINDPAD2 = "/bp";

  self:RegisterEvent("PLAYER_LOGIN");
  self:RegisterEvent("SPELLS_CHANGED");
  self:RegisterEvent("ACTIONBAR_SLOT_CHANGED");
  self:RegisterEvent("UPDATE_BINDINGS");
  self:RegisterEvent("PLAYER_TALENT_UPDATE");

  self:RegisterEvent("PLAYER_LOGOUT");
end

function BindPadFrame_OnMouseDown(self)
  if arg1 == "RightButton" then
    BindPadCore.ClearCursor();
  end
end

function BindPadFrame_OnEnter(self)
  BindPadCore.UpdateCursor();
end

function BindPadFrame_OnEvent(self)
  if event == "ACTIONBAR_SLOT_CHANGED" then
    BindPadCore.UpdateHotkey(arg1, BindPadCore.GetActionButton(arg1));
  elseif event == "UPDATE_BINDINGS" then

    BindPadUpdateFrame:Show();
  elseif event == "SPELLS_CHANGED" then
    BindPadCore.InitCash();
    BindPadCore.RefreshMacroIcons();
  elseif BindPadCore.macroIconEvents[event] then
    BindPadCore.RefreshMacroIcons();
  elseif event == "PLAYER_LOGIN" then
    BindPadCore.InitBindPad();
  elseif event == "PLAYER_TALENT_UPDATE" then
    BindPadCore.PlayerTalentUpdate();
  elseif event == "PLAYER_LOGOUT" then
    BindPadCore.PruneEmptySlots(nil);
  end
end

function BindPadFrame_OutputText(text)
  ChatFrame1:AddMessage("[BindPad] "..text, 1.0, 1.0, 0.0);
end

function BindPadFrame_Toggle()
  if BindPadFrame:IsVisible() then
    HideUIPanel(BindPadFrame);
  else
    ShowUIPanel(BindPadFrame);
  end
end

function BindPadFrame_OnShow(id)

  BindPadCore.CreateShareButtons();

  BindPadCore.SetMacroIconEvents(true);
  if id then
    BindPadVars.tab = id;
  elseif nil == BindPadVars.tab then
    BindPadVars.tab = 1;
  end
  if GetCurrentBindingSet() == 1 then

    BindPadVars.tab = 1;
    if id then
      StaticPopup_Show("BINDPAD_CONFIRM_CHANGE_BINDING_PROFILE");
    end
  end
  PanelTemplates_SetTab(BindPadFrame, BindPadVars.tab);

  BindPadFrameCharacterButton:SetChecked(GetCurrentBindingSet() == 2);

  BindPadFrameShowHotkeysButton:SetChecked(BindPadVars.showHotkey);

  BindPadFrameTriggerOnKeydownButton:SetChecked(BindPadVars.triggerOnKeydown);

  for i = 1, BINDPAD_MAXPROFILETAB, 1 do
    local tab = getglobal("BindPadProfileTab"..i);
    tab:SetChecked((BindPadCore.GetCurrentProfileNum() == i));
    BindPadProfileTab_OnShow(tab);
  end

  for i = 1, BINDPAD_MAXSLOTS, 1 do
    local button = getglobal("BindPadSlot"..i);
    BindPadSlot_UpdateState(button);
  end
end

function BindPadFrame_OnHide(self)
  BindPadCore.SetMacroIconEvents(false);
  BindPadBindFrame:Hide();
  BindPadMacroPopupFrame:Hide();
  HideUIPanel(BindPadMacroTextFrame);
end

function BindPadUpdateFrame_OnUpdate(self)
  if BindPadVars.showHotkey == nil then
    BindPadVars.showHotkey = true;
  end

  self:Hide();
  BindPadCore.UpdateAllHotKeys();
end

function BindPadBindFrame_Update()
  StaticPopup_Hide("BINDPAD_CONFIRM_BINDING")
  BindPadBindFrameAction:SetText(BindPadCore.selectedSlot.action);

  local key = GetBindingKey(BindPadCore.selectedSlot.action);
  if key then
    BindPadBindFrameKey:SetText(BINDPAD_TEXT_KEY..BindPadCore.GetBindingText(key, "KEY_"));
  else
    BindPadBindFrameKey:SetText(BINDPAD_TEXT_KEY..BINDPAD_TEXT_NOTBOUND);
  end

  BindPadBindFrameFastTriggerButton:SetChecked(BindPadCore.selectedSlot.fastTrigger);
end

function BindPadBindFrame_OnKeyDown(self, keyOrButton)
  if keyOrButton=="ESCAPE" then
    BindPadBindFrame:Hide()
    return
  end

  if ( GetBindingFromClick(keyOrButton) == "SCREENSHOT" ) then
    RunBinding("SCREENSHOT");
    return;
  end

  local keyPressed = keyOrButton;

  if ( keyPressed == "UNKNOWN" ) then
    return;
  end

  if ( keyPressed == "LeftButton" ) then
    keyPressed = "BUTTON1";
  elseif ( keyPressed == "RightButton" ) then
    keyPressed = "BUTTON2";
  elseif ( keyPressed == "MiddleButton" ) then
    keyPressed = "BUTTON3";
  else
    local num = strmatch(keyPressed, "^Button(%d+)$");
    if num then
      keyPressed = "BUTTON"..num;
    end
  end

  if ( keyPressed == "LSHIFT" or
       keyPressed == "RSHIFT" or
       keyPressed == "LCTRL" or
       keyPressed == "RCTRL" or
       keyPressed == "LALT" or
       keyPressed == "RALT" ) then
    return;
  end
  if ( IsShiftKeyDown() ) then
    keyPressed = "SHIFT-"..keyPressed
  end
  if ( IsControlKeyDown() ) then
    keyPressed = "CTRL-"..keyPressed
  end
  if ( IsAltKeyDown() ) then
    keyPressed = "ALT-"..keyPressed
  end
  if ( keyPressed == "BUTTON1" or keyPressed == "BUTTON2" ) then
    return;
  end
  if keyPressed then
    BindPadCore.keyPressed = keyPressed
    local oldAction = GetBindingAction(keyPressed)

    local keyText = BindPadCore.GetBindingText(keyPressed, "KEY_");
    if oldAction~="" and oldAction ~= BindPadCore.selectedSlot.action then
      if StaticPopupDialogs["BINDPAD_CONFIRM_BINDING"] == nil then
        StaticPopupDialogs["BINDPAD_CONFIRM_BINDING"] = {
          button1 = YES,
          button2 = NO,
          timeout = 0,
          hideOnEscape = 1,
          OnAccept = BindPadBindFrame_SetBindKey,
          OnCancel = BindPadBindFrame_Update,
          whileDead = 1
        }
      end
      StaticPopupDialogs["BINDPAD_CONFIRM_BINDING"].text = format(BINDPAD_TEXT_CONFIRM_BINDING, keyText, oldAction, keyText, BindPadCore.selectedSlot.action);
      StaticPopup_Show("BINDPAD_CONFIRM_BINDING")
    else
      BindPadBindFrame_SetBindKey();
    end
  end
end

function BindPadBindFrame_SetBindKey()
  BindPadCore.BindKey();
  BindPadBindFrame_Update();
end

function BindPadBindFrame_Unbind()
  BindPadCore.UnbindSlot(BindPadCore.selectedSlot);
  BindPadBindFrame_Update();
end

function BindPadBindFrame_OnHide(self)

  StaticPopup_Hide("BINDPAD_CONFIRM_BINDING")
end

function BindPadBindFrame_FastTriggerToggle(self)
  BindPadCore.selectedSlot.fastTrigger = (self:GetChecked() == 1);
  BindPadCore.UpdateMacroText(BindPadCore.selectedSlot);
  BindPadSlot_UpdateState(BindPadCore.selectedSlotButton);
  BindPadBindFrame_Update();
end

function BindPadSlot_OnUpdateBindings(self)

  if BindPadCore.character and BindPadFrame:IsVisible() then
    BindPadSlot_UpdateState(self);
  end
end

function BindPadSlot_OnClick(self, button)
  if button == "RightButton" then
    if BindPadCore.CursorHasIcon() then
      BindPadCore.ClearCursor();
    else
      BindPadMacroTextFrame_Open(self);
    end
    return;
  end

  if BindPadCore.CursorHasIcon() then

    BindPadSlot_OnReceiveDrag(self);
  elseif IsShiftKeyDown() then

    BindPadSlot_OnDragStart(self);
  else

    if nil ~= BindPadCore.GetSlotInfo(self:GetID()).type then
      BindPadMacroPopupFrame:Hide();
      HideUIPanel(BindPadMacroTextFrame);
      BindPadCore.selectedSlot = BindPadCore.GetSlotInfo(self:GetID());
      BindPadCore.selectedSlotButton = self;
      BindPadBindFrame_Update();
      BindPadBindFrame:Show();
    end
  end
end

function BindPadSlot_OnDragStart(self)
  if not BindPadCore.CanPickupSlot(self) then
    return;
  end
  BindPadCore.PickupSlot(self, self:GetID());
  BindPadSlot_UpdateState(self);
end

function BindPadSlot_OnReceiveDrag(self)
  if self == BindPadCore.selectedSlotButton then
    BindPadMacroPopupFrame:Hide();
    HideUIPanel(BindPadMacroTextFrame);
    BindPadBindFrame:Hide();
  end
  if not BindPadCore.CanPickupSlot(self) then
    return;
  end

  local type, detail, subdetail = GetCursorInfo();
  if type then
    ClearCursor();
    ResetCursor();
    BindPadCore.PickupSlot(self, self:GetID());
    BindPadCore.PlaceIntoSlot(self:GetID(), type, detail, subdetail);

    BindPadSlot_UpdateState(self);
    BindPadSlot_OnEnter(self);
  elseif "CLICK" == BindPadCore.drag.type then
    local drag = BindPadCore.drag;
    ClearCursor();
    ResetCursor();
    BindPadCore.PickupSlot(self, self:GetID());
    BindPadCore.PlaceVirtualIconIntoSlot(self:GetID(), drag);

    BindPadSlot_UpdateState(self);
    BindPadSlot_OnEnter(self);
  end
end

function BindPadSlot_OnEnter(self)
  BindPadCore.UpdateCursor();

  local padSlot = BindPadCore.GetSlotInfo(self:GetID());

  if padSlot == nil or padSlot.type == nil then
    return;
  end
  GameTooltip:SetOwner(self, "ANCHOR_LEFT");

  if "ITEM" == padSlot.type then
    GameTooltip:SetHyperlink(padSlot.linktext);
  elseif "SPELL" == padSlot.type then
    local spellID = BindPadCore.FindSpellIdByName(padSlot.name, padSlot.rank, padSlot.bookType);
    if spellID then
      GameTooltip:SetSpell(spellID, padSlot.bookType)
    else
      GameTooltip:SetText(BINDPAD_TOOLTIP_UNKNOWN_SPELL..padSlot.name, 1.0, 1.0, 1.0);
    end
    if padSlot.rank then
      GameTooltip:AddLine(BINDPAD_TOOLTIP_DOWNRANK..padSlot.rank, 1.0, 0.7, 0.7);
    end
  elseif "MACRO" == padSlot.type then
    GameTooltip:SetText(BINDPAD_TOOLTIP_MACRO..padSlot.name, 1.0, 1.0, 1.0);
  elseif "CLICK" == padSlot.type then

    if BindPadCore.SetMacroTooltip(padSlot) then
      GameTooltip:AddLine(format(BINDPAD_TOOLTIP_BINDPADMACRO, padSlot.name), 0.6, 0.8, 1.0);
    else
      GameTooltip:SetText(format(BINDPAD_TOOLTIP_BINDPADMACRO, padSlot.name), 1.0, 1.0, 1.0);
    end
  end

  local key = GetBindingKey(padSlot.action);
  if key then
    GameTooltip:AddLine(BINDPAD_TOOLTIP_KEYBINDING..BindPadCore.GetBindingText(key, "KEY_"), 0.8, 0.8, 1.0);
  end

  if not BindPadCore.CursorHasIcon() then
    if "CLICK" == padSlot.type then
      GameTooltip:AddLine(BINDPAD_TOOLTIP_CLICK_USAGE1, 0.8, 1.0, 0.8);
    else
      GameTooltip:AddLine(BINDPAD_TOOLTIP_CLICK_USAGE2, 0.8, 1.0, 0.8);
    end
  end

  GameTooltip:Show();
end

function BindPadSlot_UpdateState(self)
  local padSlot = BindPadCore.GetSlotInfo(self:GetID());

  local icon = getglobal(self:GetName().."Icon");
  local name = getglobal(self:GetName().."Name");
  local hotkey = getglobal(self:GetName().."HotKey");
  local addbutton = getglobal(self:GetName().."AddButton");
  local border = getglobal(self:GetName().."Border");

  if padSlot and padSlot.type then
    icon:SetTexture(BindPadCore.GetSlotTexture(padSlot));
    icon:Show();
    addbutton:Hide();

    if name then
      name:SetText(padSlot.name);
    else
      name:SetText("");
    end

    local key = GetBindingKey(padSlot.action);
    if key then
      hotkey:SetText(BindPadCore.GetBindingText(key, "KEY_", 1));
    else
      hotkey:SetText("");
    end
    if "CLICK" == padSlot.type then
      border:SetVertexColor(0, 1.0, 0, 0.35);
      border:Show();
    else
      border:Hide();
    end

  else
    icon:Hide();
    addbutton:Show();
    name:SetText("");
    hotkey:SetText("");
    border:Hide();
  end
end

local BindPadMacroPopup_oldPadSlot = {};
function BindPadMacroPopupFrame_Open(self)
  if InCombatLockdown() then
    BindPadFrame_OutputText(BINDPAD_TEXT_ERR_BINDPADMACRO_INCOMBAT);
    return;
  end
  local padSlot = BindPadCore.GetSlotInfo(self:GetID());
  local newFlag = false;

  BindPadMacroPopup_oldPadSlot.action = padSlot.action;
  BindPadMacroPopup_oldPadSlot.id = padSlot.id;
  BindPadMacroPopup_oldPadSlot.macrotext = padSlot.macrotext;
  BindPadMacroPopup_oldPadSlot.name = padSlot.name;
  BindPadMacroPopup_oldPadSlot.texture = padSlot.texture;
  BindPadMacroPopup_oldPadSlot.type = padSlot.type;
  BindPadMacroPopup_oldPadSlot.fastTrigger = padSlot.fastTrigger;

  if nil == padSlot.type then
    newFlag = true;
    GetNumMacroIcons();

    padSlot.type = "CLICK";
    padSlot.name = BindPadCore.NewBindPadMacroName(padSlot, "1");
    padSlot.texture = GetMacroIconInfo(1);
    padSlot.macrotext = "";
    padSlot.action = BindPadCore.CreateBindPadMacroAction(padSlot);
    BindPadSlot_UpdateState(self)
  end

  if "CLICK" == padSlot.type then
    BindPadCore.selectedSlot = padSlot;
    BindPadCore.selectedSlotButton = self;

    BindPadMacroPopupEditBox:SetText(padSlot.name);
    BindPadMacroPopupFrame.selectedIconTexture = padSlot.texture;
    BindPadMacroPopupFrame.selectedIcon = nil;
    BindPadBindFrame:Hide();
    HideUIPanel(BindPadMacroTextFrame);
    BindPadMacroPopupFrame:Show();
    if newFlag then
      BindPadMacroPopupEditBox:HighlightText();
    end
  end
end

function BindPadMacroAddButton_OnClick(self)
  if BindPadCore.CursorHasIcon() then
    BindPadSlot_OnReceiveDrag(self);

  else
    HideUIPanel(BindPadMacroTextFrame);

    PlaySound("gsTitleOptionOK");
    BindPadMacroPopupFrame_Open(self);
  end
end

function BindPadMacroPopupFrame_OnShow(self)
  BindPadMacroPopupEditBox:SetFocus();
  BindPadMacroPopupFrame_Update(self);
  BindPadMacroPopupOkayButton_Update(self);
end

function BindPadMacroPopupFrame_OnHide(self)
  if not BindPadFrame:IsVisible() then
    ShowUIPanel(BindPadFrame);
  end
end

function BindPadMacroPopupFrame_Update(self)
  local numMacroIcons = GetNumMacroIcons();
  local macroPopupIcon, macroPopupButton;
  local macroPopupOffset = FauxScrollFrame_GetOffset(BindPadMacroPopupScrollFrame);
  local index;

  local texture;
  for i=1, NUM_MACRO_ICONS_SHOWN do
    macroPopupIcon = getglobal("BindPadMacroPopupButton"..i.."Icon");
    macroPopupButton = getglobal("BindPadMacroPopupButton"..i);
    index = (macroPopupOffset * NUM_ICONS_PER_ROW) + i;
    texture = GetMacroIconInfo(index);
    if ( index <= numMacroIcons ) then
      macroPopupIcon:SetTexture(texture);
      macroPopupButton:Show();
    else
      macroPopupIcon:SetTexture("");
      macroPopupButton:Hide();
    end
    if ( BindPadMacroPopupFrame.selectedIcon and (index == BindPadMacroPopupFrame.selectedIcon) ) then
      macroPopupButton:SetChecked(1);
    elseif ( BindPadMacroPopupFrame.selectedIconTexture ==  texture ) then
      macroPopupButton:SetChecked(1);
    else
      macroPopupButton:SetChecked(nil);
    end
  end

  FauxScrollFrame_Update(BindPadMacroPopupScrollFrame, ceil(numMacroIcons / NUM_ICONS_PER_ROW) , NUM_ICON_ROWS, MACRO_ICON_ROW_HEIGHT );
end

function BindPadMacroPopupFrame_OnScroll(self, offset)
  FauxScrollFrame_OnVerticalScroll(self, offset, MACRO_ICON_ROW_HEIGHT, BindPadMacroPopupFrame_Update);
end

function BindPadMacroPopupEditBox_OnTextChanged(self)
  if InCombatLockdown() then
    BindPadFrame_OutputText(BINDPAD_TEXT_ERR_BINDPADMACRO_INCOMBAT);
    BindPadMacroPopupFrame:Hide();
    return;
  end

  local padSlot = BindPadCore.selectedSlot;
  BindPadCore.DeleteBindPadMacroID(padSlot);
  padSlot.name = BindPadCore.NewBindPadMacroName(padSlot, self:GetText());
  if self:GetText() ~= padSlot.name then
    BindPadFrame_OutputText(BINDPAD_TEXT_ERR_UNIQUENAME);
    self:SetText(padSlot.name);
  end
  BindPadCore.UpdateMacroText(padSlot);
  BindPadSlot_UpdateState(BindPadCore.selectedSlotButton)
end

function BindPadMacroPopupFrame_CancelEdit()
  local padSlot = BindPadCore.GetSlotInfo(BindPadCore.selectedSlotButton:GetID());
  BindPadMacroPopupFrame:Hide();

  if InCombatLockdown() then
    BindPadFrame_OutputText(BINDPAD_TEXT_ERR_BINDPADMACRO_INCOMBAT);
    return;
  end

  padSlot.action = BindPadMacroPopup_oldPadSlot.action;
  padSlot.id = BindPadMacroPopup_oldPadSlot.id;
  padSlot.macrotext = BindPadMacroPopup_oldPadSlot.macrotext;

  BindPadCore.DeleteBindPadMacroID(padSlot);
  padSlot.name = BindPadMacroPopup_oldPadSlot.name;
  BindPadCore.UpdateMacroText(padSlot);

  padSlot.texture = BindPadMacroPopup_oldPadSlot.texture;
  padSlot.type = BindPadMacroPopup_oldPadSlot.type;
  padSlot.fastTrigger = BindPadMacroPopup_oldPadSlot.fastTrigger;

  BindPadMacroPopupFrame.selectedIcon = nil;
  BindPadSlot_UpdateState(BindPadCore.selectedSlotButton)
end

function BindPadMacroPopupOkayButton_Update(self)
  if ( (strlen(BindPadMacroPopupEditBox:GetText()) > 0) and BindPadMacroPopupFrame.selectedIcon ) then
    BindPadMacroPopupOkayButton:Enable();
  else
    BindPadMacroPopupOkayButton:Disable();
  end
  if (strlen(BindPadMacroPopupEditBox:GetText()) > 0) then
    BindPadMacroPopupOkayButton:Enable();
  end
end

function BindPadMacroPopupButton_OnClick(self)
  BindPadMacroPopupFrame.selectedIcon = self:GetID() + (FauxScrollFrame_GetOffset(BindPadMacroPopupScrollFrame) * NUM_ICONS_PER_ROW);

  BindPadMacroPopupFrame.selectedIconTexture = nil;

  BindPadCore.selectedSlot.texture = GetMacroIconInfo(BindPadMacroPopupFrame.selectedIcon);
  BindPadSlot_UpdateState(BindPadCore.selectedSlotButton);

  BindPadMacroPopupOkayButton_Update(self);
  BindPadMacroPopupFrame_Update(self);
end

function BindPadMacroPopupOkayButton_OnClick()
  BindPadMacroPopupFrame:Hide();
  BindPadSlot_UpdateState(BindPadCore.selectedSlotButton);
  BindPadMacroTextFrame_Open(BindPadCore.selectedSlotButton);
end

function BindPadMacroTextFrame_Open(self)
  HideUIPanel(BindPadMacroTextFrame);

  local id = self:GetID();
  local padSlot = BindPadCore.GetSlotInfo(id);

  if nil == padSlot.type then
    return;
  end
  BindPadCore.selectedSlot = padSlot;
  BindPadCore.selectedSlotButton = self;

  if "CLICK" ~= padSlot.type then
    StaticPopup_Show("BINDPAD_CONFIRM_CONVERT", padSlot.type, padSlot.name);
    return;
  end

  BindPadMacroTextFrameSelectedMacroName:SetText(padSlot.name);
  BindPadMacroTextFrameSelectedMacroButtonIcon:SetTexture(BindPadCore.GetSlotTexture(padSlot));
  BindPadMacroTextFrameText:SetText(padSlot.macrotext);
  if not InCombatLockdown() then
    BindPadMacroTextFrameTestButton:SetAttribute("macrotext", padSlot.macrotext);
  end

  BindPadBindFrame:Hide()
  BindPadMacroPopupFrame:Hide();
  ShowUIPanel(BindPadMacroTextFrame);
end

function BindPadMacroTextFrameEditButton_OnClick(self)
  BindPadMacroPopupFrame_Open(BindPadCore.selectedSlotButton);
end

function BindPadMacroDeleteButton_OnClick(self)
  HideUIPanel(self:GetParent());

  local padSlot = BindPadCore.GetSlotInfo(BindPadCore.selectedSlotButton:GetID());

  BindPadCore.DeleteBindPadMacroID(padSlot);

  padSlot.action = nil;
  padSlot.bookType = nil;
  padSlot.id = nil;
  padSlot.linktext = nil;
  padSlot.macrotext = nil;
  padSlot.name = nil;
  padSlot.rank = nil;
  padSlot.texture = nil;
  padSlot.type = nil;
  padSlot.fastTrigger = nil;

  BindPadSlot_UpdateState(BindPadCore.selectedSlotButton);
end

function BindPadMacroTextFrame_OnShow(self)
  BindPadMacroTextFrameText:SetFocus();
end

function BindPadMacroTextFrame_OnHide(self)
  if BindPadCore.selectedSlot.macrotext ~= BindPadMacroTextFrameText:GetText() then
    if InCombatLockdown() then
      BindPadFrame_OutputText(BINDPAD_TEXT_ERR_BINDPADMACRO_INCOMBAT);
      BindPadMacroTextFrameText:SetText(BindPadCore.selectedSlot.macrotext);
    else
      BindPadCore.selectedSlot.macrotext = BindPadMacroTextFrameText:GetText();
      BindPadCore.UpdateMacroText(BindPadCore.selectedSlot);

      if BindPadCore.selectedSlotButton then
        BindPadSlot_UpdateState(BindPadCore.selectedSlotButton);
      end
    end
  end

  if not BindPadFrame:IsVisible() then
    ShowUIPanel(BindPadFrame);
  end
end

function BindPadProfileTab_OnShow(self)
  local normalTexture = self:GetNormalTexture();
  local talentGroup1, talentGroup2 = BindPadCore.GetTalentGroupForProfile(self:GetID());
  local texture = BindPadCore.GetSpecTexture(talentGroup1);
  normalTexture:SetTexture(texture);

  local subIcon = getglobal(self:GetName().."SubIcon");
  if talentGroup2 then
    texture = BindPadCore.GetSpecTexture(talentGroup2);
    subIcon:SetTexture(texture);
    subIcon:Show();
  else
    subIcon:Hide();
  end

  if BindPadCore.GetCurrentProfileNum() == self:GetID() then
    self:SetChecked(1);
  end
end

function BindPadProfileTab_OnClick(self, button, down)
  BindPadCore.SwitchProfile(self:GetID());
  BindPadFrame_OnShow();
  BindPadProfileTab_OnEnter(self);
end

function BindPadProfileTab_OnEnter(self, motion)
  local profileNum = self:GetID();
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
  GameTooltip:SetText(BINDPAD_TOOLTIP_EXTRA_PROFILE..profileNum);

  if profileNum == BindPadCore.GetProfileForTalentGroup(1) then
    GameTooltip:AddLine(TALENT_SPEC_PRIMARY);
  end
  if profileNum == BindPadCore.GetProfileForTalentGroup(2) then
    GameTooltip:AddLine(TALENT_SPEC_SECONDARY);
  end
  GameTooltip:Show();
end

function BindPadCore.GetEquipmentSetTexture(setName)

  local name, textureName;
  for idx = 1, GetNumEquipmentSets() do
    name, textureName = GetEquipmentSetInfo(idx);
    if name == setName then
      return textureName;
    end
  end
  return nil;
end

function BindPadCore.PlaceIntoSlot(id, type, detail, subdetail)

  local padSlot = BindPadCore.GetSlotInfo(id);

  if type == "item" then
    padSlot.linktext = subdetail;
    local name,_,_,_,_,_,_,_,_,texture = GetItemInfo(padSlot.linktext);
    padSlot.name = name;
    padSlot.texture = texture;
    padSlot.type = "ITEM";

  elseif type == "macro" then
    local name, texture = GetMacroInfo(detail);
    padSlot.name = name;
    padSlot.texture = texture;
    padSlot.type = "MACRO";

  elseif type == "spell" then
    local spellName, spellRank = GetSpellName(detail, subdetail);
    local texture = GetSpellTexture(detail, subdetail);
    padSlot.bookType = subdetail;
    padSlot.name = spellName;
    if BindPadCore.IsHighestRank(detail, subdetail) then
      padSlot.rank = nil;
    else
      padSlot.rank = spellRank;
    end
    padSlot.texture = texture;
    padSlot.type = "SPELL";

  elseif type == "merchant" then
    padSlot.linktext = GetMerchantItemLink(detail);
    local name,_,_,_,_,_,_,_,_,texture = GetItemInfo(padSlot.linktext);
    padSlot.name = name;
    padSlot.texture = texture;
    padSlot.type = "ITEM";

  elseif type == "companion" then
    local creatureID, creatureName, creatureSpellID, texture = GetCompanionInfo(subdetail, detail);
    local spellName = GetSpellInfo(creatureSpellID);
    padSlot.name = BindPadCore.NewBindPadMacroName(padSlot, spellName);
    padSlot.texture = texture;
    padSlot.type = "CLICK";
    padSlot.macrotext = "/cast "..spellName;

  elseif type == "equipmentset" then
    local textureName = BindPadCore.GetEquipmentSetTexture(detail);
    padSlot.name = BindPadCore.NewBindPadMacroName(padSlot, detail);
    padSlot.texture = textureName;
    padSlot.type = "CLICK";
    padSlot.macrotext = "/equipset "..detail;

  else
    BindPadFrame_OutputText(format(BINDPAD_TEXT_CANNOT_PLACE, type));
    return;
  end

  padSlot.action = BindPadCore.CreateBindPadMacroAction(padSlot);
  BindPadCore.UpdateMacroText(padSlot);
end

function BindPadCore.PlaceVirtualIconIntoSlot(id, drag)
  if "CLICK" ~= drag.type then
    return;
  end

  local padSlot = BindPadCore.GetSlotInfo(id);

  padSlot.id = drag.id;
  padSlot.macrotext = drag.macrotext;
  padSlot.name = BindPadCore.NewBindPadMacroName(padSlot, drag.name);
  padSlot.texture = drag.texture;
  padSlot.type = drag.type;
  padSlot.fastTrigger = drag.fastTrigger;
  padSlot.action = BindPadCore.CreateBindPadMacroAction(padSlot);

  drag.type = nil;
  PlaySound("igAbilityIconDrop");
end

function BindPadCore.GetCurrentProfileNum()
  if nil == BindPadCore.profileNum then
    BindPadCore.profileNum = 1;
  end
  return BindPadCore.profileNum;
end

function BindPadCore.GetProfileForTalentGroup(talentGroup)
  local character = BindPadCore.character;
  if nil == character then
    return nil;
  end
  if nil == BindPadVars[character].profileForTalentGroup[talentGroup] then
    BindPadVars[character].profileForTalentGroup[talentGroup] = talentGroup;
  end
  return BindPadVars[character].profileForTalentGroup[talentGroup];
end

function BindPadCore.GetTalentGroupForProfile(profileNum)
  local talentGroup1, talentGroup2;
  local character = BindPadCore.character;
  if nil == character then
    return nil;
  end
  for k,v in pairs(BindPadVars[character].profileForTalentGroup) do
    if v == profileNum then
      if talentGroup1 then
        talentGroup2 = k;
      else
        talentGroup1 = k;
      end
    end
  end
  return talentGroup1, talentGroup2;
end

function BindPadCore.GetProfileData()
  local character = BindPadCore.character;
  if nil == character then
    return nil;
  end
  local profileNum = BindPadCore.GetCurrentProfileNum();
  local profile = BindPadVars[character][profileNum];
  if nil == profile.keys then
    profile.keys = {};
  end
  return profile;
end

function BindPadCore.GetSlotInfo(id)
  if id == nil then
    return nil;
  end
  local gid = id + ((BindPadVars.tab or 1) - 1) * BINDPAD_MAXSLOTS;
  return BindPadCore.GetAllSlotInfo(gid);
end

function BindPadCore.GetAllSlotInfo(gid)
  local padSlot;
  if nil == BindPadCore.character then
    BindPadFrame_OutputText("DEBUG: Something wrong.  Please report this message to the author of BindPad.");
    return nil;
  end
  if gid > BINDPAD_MAXSLOTS then
    local character = BindPadCore.character;
    local profileNum = BindPadCore.GetCurrentProfileNum();
    if nil == BindPadVars[character][profileNum] then
      BindPadVars[character][profileNum] = {};
    end
    local sid = gid - BINDPAD_MAXSLOTS;
    if nil == BindPadVars[character][profileNum][sid] then
      BindPadVars[character][profileNum][sid] = {};
    end
    padSlot = BindPadVars[character][profileNum][sid];
  else
    if nil == BindPadVars[gid] then
      BindPadVars[gid] = {};
    end
    padSlot = BindPadVars[gid];
  end
  return padSlot;
end

function BindPadCore.CreateKeysArray()

  for gid = BINDPAD_MAXSLOTS + 1, BINDPAD_TOTALSLOTS, 1 do
    local padSlot = BindPadCore.GetAllSlotInfo(gid);
    if padSlot.action then
      if nil == BindPadCore.GetProfileData().keys[padSlot.action] then
        BindPadCore.GetProfileData().keys[padSlot.action] = GetBindingKey(padSlot.action);
      end
    end
  end
end

function BindPadCore.ConvertOldSlotInfo()
  local oldCharacter = GetRealmName().."_"..UnitName("player");
  local character = BindPadCore.character;

  local profileNum = BindPadCore.GetCurrentProfileNum();

  BindPadVars[character] = {};
  BindPadVars[character][profileNum] = {};
  BindPadVars[character][profileNum].keys = {};

  if nil ~= BindPadVars[oldCharacter] then
    for i = 1, BINDPAD_MAXSLOTS do
      BindPadVars[character][profileNum][i] = BindPadVars[oldCharacter][i];
    end
    BindPadVars[oldCharacter] = nil;
  end
  if nil ~= BindPadVars[oldCharacter.."_3"] then
    for i = 1, BINDPAD_MAXSLOTS do
      BindPadVars[character][profileNum][i+BINDPAD_MAXSLOTS] = BindPadVars[oldCharacter.."_3"][i];
    end
    BindPadVars[oldCharacter.."_3"] = nil;
  end
  if nil ~= BindPadVars[oldCharacter.."_4"] then
    for i = 1, BINDPAD_MAXSLOTS do
      BindPadVars[character][profileNum][i+2*BINDPAD_MAXSLOTS] = BindPadVars[oldCharacter.."_4"][i];
    end
    BindPadVars[oldCharacter.."_4"] = nil;
  end

  BindPadCore.CreateKeysArray();
end

function BindPadCore.SwitchProfile(newProfileNum, force)
  local oldProfileNum = BindPadCore.GetCurrentProfileNum();
  if not force and newProfileNum == oldProfileNum then
    return;
  end

  if InCombatLockdown() then
    return;
  end

  BindPadMacroPopupFrame:Hide();
  HideUIPanel(BindPadMacroTextFrame);
  BindPadBindFrame:Hide();

  local character = BindPadCore.character;
  if nil == character then
    return;
  end

  local oldProfile = BindPadCore.GetProfileData();
  BindPadCore.profileNum = newProfileNum;

  local talentGroup = GetActiveTalentGroup();
  BindPadVars[character].profileForTalentGroup[talentGroup] = newProfileNum;

  if nil == BindPadVars[character][newProfileNum] then
    BindPadVars[character][newProfileNum] = {};
    BindPadVars[character][newProfileNum].keys = {};
    local newProfile = BindPadCore.GetProfileData();
    for sid = 1, BINDPAD_TOTALSLOTS - BINDPAD_MAXSLOTS, 1 do

      local src = oldProfile[sid];
      if src and next(src) then
        newProfile[sid] = {};
        for k,v in pairs(src) do
          newProfile[sid][k] = v;
        end
      end
    end
    for k,v in pairs(oldProfile.keys) do
      newProfile.keys[k] = v;
    end
    BindPadFrame_OutputText(BINDPAD_TEXT_CREATE_PROFILETAB);
  end

  for k,v in pairs(BindPadCore.GetProfileData().keys) do
    if strfind(k, "^SPELL ") or strfind(k, "^ITEM ") or strfind(k, "^MACRO ") then

      BindPadCore.GetProfileData().keys["CLICK BindPadKey:"..k] = v;
    end
  end

  for gid = BINDPAD_MAXSLOTS + 1, BINDPAD_TOTALSLOTS, 1 do
    local padSlot = BindPadCore.GetAllSlotInfo(gid);
    if padSlot.action then
      local newKey = BindPadCore.GetProfileData().keys[padSlot.action];
      BindPadCore.UpdateMacroText(padSlot);

      local guard = 0;
      repeat
        local changed = false;
        local oldKey1, oldKey2 = GetBindingKey(padSlot.action);
        if oldKey1 and oldKey1 ~= newKey then
          SetBinding(oldKey1);
          changed = true;
        elseif oldKey2 and oldKey2 ~= newKey then
          SetBinding(oldKey2);
          changed = true;
        end
        guard = guard + 1;
      until not changed or guard > 10
      local alreadyBound = (newKey ~= nil and GetBindingKey(padSlot.action) == newKey);

      if newKey and not alreadyBound then
        SetBinding(newKey, padSlot.action);
        BindPadCore.GetProfileData().keys[padSlot.action] = newKey;
      end
    end
  end
  local bindingset = GetCurrentBindingSet();
  if bindingset == 1 or bindingset == 2 then
    SaveBindings(bindingset);
  else
    BindPadFrame_OutputText("GetCurrentBindingSet() returned:"..(bindingset or "nil"));
  end

  for k,v in pairs(BindPadCore.GetProfileData().keys) do
    if strfind(k, "^SPELL ") or strfind(k, "^ITEM ") or strfind(k, "^MACRO ") then

      BindPadCore.GetProfileData().keys[k] = nil;
    end
  end

  BindPadFrameTitleText:SetText(getglobal("BINDPAD_TITLE_"..newProfileNum));
end

function BindPadCore.CanPickupSlot(self)
  if not InCombatLockdown() then
    return true;
  end
  local padSlot = BindPadCore.GetSlotInfo(self:GetID());
  if "SPELL" == padSlot.type then
    BindPadFrame_OutputText(BINDPAD_TEXT_ERR_SPELL_INCOMBAT);
    return false;
  end
  if "MACRO" == padSlot.type then
    BindPadFrame_OutputText(BINDPAD_TEXT_ERR_MACRO_INCOMBAT);
    return false;
  end
  return true;
end

function BindPadCore.PickupSlot(self, id)
  local padSlot = BindPadCore.GetSlotInfo(id);
  if "ITEM" == padSlot.type then
    PickupItem(padSlot.linktext);
  elseif "SPELL" == padSlot.type then
    local spellID = BindPadCore.FindSpellIdByName(padSlot.name, padSlot.rank, padSlot.bookType);
    if spellID then
      PickupSpell(spellID, padSlot.bookType);
    end
  elseif "MACRO" == padSlot.type then
    PickupMacro(padSlot.name);
  elseif "CLICK" == padSlot.type then
    if self == BindPadCore.selectedSlotButton then
      BindPadMacroPopupFrame:Hide();
      HideUIPanel(BindPadMacroTextFrame);
      BindPadBindFrame:Hide();
    end

    local drag = BindPadCore.dragswap;
    BindPadCore.dragswap = BindPadCore.drag;
    BindPadCore.drag = drag;

    drag.action = padSlot.action;
    drag.id = padSlot.id;
    drag.macrotext = padSlot.macrotext;
    drag.name = padSlot.name;
    drag.texture = padSlot.texture;
    drag.type = padSlot.type;
    drag.fastTrigger = padSlot.fastTrigger;

    BindPadCore.UpdateCursor();
    PlaySound("igAbilityIconPickup");
  end

  if (not IsModifierKeyDown()) then
    padSlot.action = nil;
    padSlot.bookType = nil;
    padSlot.id = nil;
    padSlot.linktext = nil;
    padSlot.macrotext = nil;
    padSlot.name = nil;
    padSlot.rank = nil;
    padSlot.texture = nil;
    padSlot.type = nil;
    padSlot.fastTrigger = nil;
  end
end

function BindPadCore.BindKey()
  if not InCombatLockdown() then
    local padSlot = BindPadCore.selectedSlot;
    BindPadCore.UnbindSlot(padSlot);

    SetBinding(BindPadCore.keyPressed, padSlot.action);
    SaveBindings(GetCurrentBindingSet());
    for k,v in pairs(BindPadCore.GetProfileData().keys) do
      if v == BindPadCore.keyPressed then
        BindPadCore.GetProfileData().keys[k] = nil;
      end
    end
    BindPadCore.GetProfileData().keys[padSlot.action] = BindPadCore.keyPressed;
  else
    BindPadFrame_OutputText(BINDPAD_TEXT_CANNOT_BIND);
  end
end

function BindPadCore.UnbindSlot(padSlot)
  if not InCombatLockdown() then
    repeat
      local key = GetBindingKey(padSlot.action);
      if key then
        SetBinding(key);
        for k,v in pairs(BindPadCore.GetProfileData().keys) do
          if v == key then
            BindPadCore.GetProfileData().keys[k] = nil;
          end
        end
      end
    until key == nil
    SaveBindings(GetCurrentBindingSet());
    BindPadCore.GetProfileData().keys[padSlot.action] = nil;
  end
end

function BindPadCore.GetSpellNum(bookType)
  local spellNum;
  if bookType == BOOKTYPE_PET then
    spellNum = HasPetSpells() or 0;
  else
    local _,_,offset,num = GetSpellTabInfo(GetNumSpellTabs());
    spellNum = offset+num;
  end
  return spellNum;
end

function BindPadCore.InitCash()

  for k,v in pairs(BindPadCore.IsHighestCash) do
    wipe(v);
  end
end

function BindPadCore.IsHighestRank(spellID, bookType)

  local book = bookType or "";
  local cache = BindPadCore.IsHighestCash[book];
  if not cache then
    cache = {};
    BindPadCore.IsHighestCash[book] = cache;
  end
  local cash = cache[spellID];
  if cash ~= nil then
    return cash;
  end

  local srchSpellName, srchSpellRank = GetSpellName(spellID, bookType);
  for i = BindPadCore.GetSpellNum(bookType), 1, -1 do

    local spellName, spellRank = GetSpellName(i, bookType);
    if spellName == srchSpellName then
      local result = (srchSpellRank == spellRank);
      cache[spellID] = result;
      return result;
    end
  end
end

function BindPadCore.FindSpellIdByName(srchName, srchRank, bookType)
  for i = BindPadCore.GetSpellNum(bookType), 1, -1 do
    local spellName, spellRank = GetSpellName(i, bookType);
    if spellName == srchName and (nil == srchRank or spellRank == srchRank) then
      return i;
    end
  end
end

function BindPadCore.FindCompanionIdByName(srchName, TypeID)
  for i = GetNumCompanions(TypeID), 1, -1 do
    local creatureID, creatureName, creatureSpellID, texture = GetCompanionInfo(TypeID, i);
    if creatureName == srchName then
      return i;
    end
  end
end

function BindPadCore.GetBindingText(name, prefix, returnAbbr)
  local modKeys = GetBindingText(name, prefix, nil);

  if ( returnAbbr ) then
    modKeys = gsub(modKeys, "CTRL", "c");
    modKeys = gsub(modKeys, "SHIFT", "s");
    modKeys = gsub(modKeys, "ALT", "a");
    modKeys = gsub(modKeys, "STRG", "st");
    modKeys = gsub(modKeys, "(%l)-(%l)-", "%1%2-");
    modKeys = gsub(modKeys, "Num Pad ", "#");
  end

  return modKeys;
end

function BindPadFrame_ChangeBindingProfile()
  if ( GetCurrentBindingSet() == 1 ) then
    LoadBindings(2);
    SaveBindings(2);
    BindPadFrameCharacterButton:SetChecked(true);
  else
    StaticPopup_Show("BINDPAD_CONFIRM_DELETING_CHARACTER_SPECIFIC_BINDINGS");
  end
end

function BindPadCore.GetActionCommand(actionSlot, fastTrigger)
  local type, id, subType, subSubType = GetActionInfo(actionSlot);
  local commandType, name;

  if type == "spell" then
    if id == 0 then

      return nil;
    end
    if fastTrigger then
      commandType = "CLICK BindPadFastKey:SPELL ";
    else
      commandType = "CLICK BindPadKey:SPELL ";
    end
    local spellName, spellRank = GetSpellName(id, subType);
    if BindPadCore.IsHighestRank(id, subType) then
      spellRank = nil;
    end
    name = BindPadCore.GetSpellName(spellName, spellRank);
  elseif type == "item" then
    if fastTrigger then
      commandType = "CLICK BindPadFastKey:ITEM ";
    else
      commandType = "CLICK BindPadKey:ITEM ";
    end
    name,_ = GetItemInfo(id);
  elseif type == "macro" then
    if fastTrigger then
      commandType = "CLICK BindPadFastKey:MACRO ";
    else
      commandType = "CLICK BindPadKey:MACRO ";
    end
    name,_ = GetMacroInfo(id);
  else
    return nil;
  end

  if name then
    return commandType..name;
  end
end

function BindPadCore.UpdateHotkey(actionSlot, ...)
  local thisName = select(1, ...);
  if thisName == nil then
    return;
  end
  local thisButton = getglobal(thisName);
  local hotkey = getglobal(thisName.."HotKey") or thisButton.hotkey;
  local text = hotkey:GetText();
  local shown = not (not hotkey:IsShown());
  local textBefore, shownBefore;
  local textNew, shownNew;

  if (BindPadCore.hotkeyShownAfter[thisName] ~= nil) and
     (BindPadCore.hotkeyTextAfter[thisName] == text) then

    textBefore = BindPadCore.hotkeyTextBefore[thisName];
    if BindPadCore.hotkeyShownAfter[thisName] == shown then
      shownBefore = BindPadCore.hotkeyShownBefore[thisName];
    end
  else

    BindPadCore.hotkeyTextBefore[thisName] = text;
    BindPadCore.hotkeyShownBefore[thisName] = shown;
    textBefore = text;
    shownBefore = shown;
  end

  if (BindPadVars.showHotkey and
     (not shownBefore or textBefore == nil or textBefore == "" or textBefore == RANGE_INDICATOR)) then
    local command = BindPadCore.GetActionCommand(actionSlot);
    if command then
      local key = GetBindingKey(command);
      if not key then

        command = BindPadCore.GetActionCommand(actionSlot, true);
        if command then
          key = GetBindingKey(command);
        end
      end
      if key then

        local _, _, keyFrame, virtualButton = string.find(command, "^CLICK (BindPad%a*Key):(.+)");
        local owner = keyFrame and _G[keyFrame];
        if virtualButton and owner and not owner:GetAttribute("*type-"..virtualButton) then

          key = nil;
        end
      end
      textNew = BindPadCore.GetBindingText(key, "KEY_", 1);
    end
  end

  if textNew == nil or textNew == "" then
    textNew = textBefore;
    shownNew = shownBefore;
    BindPadCore.hotkeyShownAfter[thisName] = nil;
  else
    shownNew = true;
    BindPadCore.hotkeyShownAfter[thisName] = true;
    BindPadCore.hotkeyTextAfter[thisName] = textNew;
  end

  if text ~= textNew then
    hotkey:SetText(textNew);
  end
  if textNew == RANGE_INDICATOR and text ~= RANGE_INDICATOR then
    hotkey:SetPoint("TOPLEFT", thisButton, "TOPLEFT", 1, -2);
  elseif textNew ~= RANGE_INDICATOR and text == RANGE_INDICATOR then
    hotkey:SetPoint("TOPLEFT", thisButton, "TOPLEFT", -2, -2);
  end
  if shown and not shownNew then
    hotkey:Hide();
  elseif not shown and shownNew then
    hotkey:Show();
  end

  if select("#", ...) >= 2 then
    BindPadCore.UpdateHotkey(actionSlot, select(2, ...));
  end
end

function BindPadCore.AddActionButton(actionSlot, buttonName)
  local oldSlot = BindPadCore.actionButtonIds[buttonName];
  if oldSlot == actionSlot then
    return false;
  elseif oldSlot ~= nil then
    local oldElement = BindPadCore.actionButtonNames[oldSlot];
    if type(oldElement) == "table" then
      for k,v in pairs(oldElement) do
        if v == buttonName then
          tremove(oldElement, k);
        end
      end
    elseif oldElement == buttonName then
      BindPadCore.actionButtonNames[oldSlot] = nil;
    end
  end
  local element = BindPadCore.actionButtonNames[actionSlot];
  if type(element) == "table" then
    tinsert(element, buttonName);
  elseif type(element) == "string" then
    BindPadCore.actionButtonNames[actionSlot] = {element, buttonName};
  else
    BindPadCore.actionButtonNames[actionSlot] = buttonName;
  end
  BindPadCore.actionButtonIds[buttonName] = actionSlot;
  return true;
end

function BindPadCore.GetActionButton(actionSlot)
  local element = BindPadCore.actionButtonNames[actionSlot];
  if type(element) == "table" then
    return unpack(element);
  else
    return element;
  end
end

function BindPadCore.UpdateAllHotKeys()
  for k,v in pairs(BindPadCore.actionButtonNames) do
    BindPadCore.UpdateHotkey(k, BindPadCore.GetActionButton(k));
  end
end

function BindPadFrame_ShowHotkeysToggle(self)
  BindPadVars.showHotkey = (self:GetChecked() == 1);

  BindPadCore.UpdateAllHotKeys();
end

function BindPadFrame_TriggerOnKeydownToggle(self)
  BindPadVars.triggerOnKeydown = (self:GetChecked() == 1);

  BindPadCore.SetTriggerOnKeydown();
end

function BindPadCore.GetActionTextureHook(actionSlot)
  local self = this;
  if not self then return; end

  local thisName = self:GetName();
  if not thisName then return; end

  local hotkey = getglobal(thisName.."HotKey") or self.hotkey;
  if not hotkey then return; end

  if BindPadCore.AddActionButton(actionSlot, thisName) then
    BindPadUpdateFrame:Show();
  end
end

hooksecurefunc("GetActionTexture", BindPadCore.GetActionTextureHook);

function BindPadCore.ChatEdit_InsertLinkHook(text)
  if ( BindPadMacroTextFrameText and BindPadMacroTextFrameText:IsVisible() ) then
    local item, spell;
    if ( strfind(text, "item:", 1, true) ) then
      item = GetItemInfo(text);
    else
      local _, _, kind, spellid = string.find(text, "^|c%x+|H(%a+):(%d+)[|:]");
    if spellid then
        local name, rank = GetSpellInfo(spellid);
        text = BindPadCore.GetSpellName(name, rank);
      end
    end
    if ( BindPadMacroTextFrameText:GetText() == "" ) then
      if ( item ) then
        if ( GetItemSpell(text) ) then
          BindPadMacroTextFrameText:Insert(SLASH_USE1.." "..item);
        else
          BindPadMacroTextFrameText:Insert(SLASH_EQUIP1.." "..item);
        end
      else
        BindPadMacroTextFrameText:Insert(SLASH_CAST1.." "..text);
      end
    else
      BindPadMacroTextFrameText:Insert(item or text);
    end
  end
end

hooksecurefunc("ChatEdit_InsertLink", BindPadCore.ChatEdit_InsertLinkHook);

function BindPadCore.InitBindPad()
  BindPadCore.character = "PROFILE_"..GetRealmName().."_"..UnitName("player");
  local character = BindPadCore.character;

  if BindPadVars.version == nil or
     BindPadVars.version < 1.2 then
    BindPadVars = {
      tab = BINDPAD_GENERAL_TAB,
      version = BINDPAD_SAVEFILE_VERSION,
    };
    BindPadFrame_OutputText(BINDPAD_TEXT_OBSOLATED);
  end

  if nil == BindPadVars[character] then
    BindPadCore.ConvertOldSlotInfo();
  end
  if nil == BindPadVars[character].profileForTalentGroup then
    BindPadVars[character].profileForTalentGroup = {};
  end

  local newActiveTalentGroup = GetActiveTalentGroup();
  local profileNum = BindPadCore.GetProfileForTalentGroup(newActiveTalentGroup)

  BindPadCore.SwitchProfile(profileNum, true);

  BindPadCore.activeTalentGroup = newActiveTalentGroup;

  for gid = 1, BINDPAD_TOTALSLOTS, 1 do
    local padSlot = BindPadCore.GetAllSlotInfo(gid);
    if "ITEM" ~= padSlot.type then
      padSlot.linktext = nil;
    end
    if padSlot.macrotext ~= nil and padSlot.id then
      if type(padSlot.id) == "number" then
        if strfind(padSlot.action, "^CLICK BindPadMacro%d+:") then

          padSlot.id = padSlot.action;
        end
      else

        padSlot.action = padSlot.id
      end
    end
  end
  for gid = 1, BINDPAD_TOTALSLOTS, 1 do
    BindPadCore.UpdateMacroText(BindPadCore.GetAllSlotInfo(gid));
  end
  BindPadMacro:SetAttribute("*type*", "macro");
  BindPadKey:SetAttribute("*checkselfcast*", true);
  BindPadKey:SetAttribute("*checkfocuscast*", true);

  BindPadFastMacro:SetAttribute("*type*", "macro");
  BindPadFastMacro:RegisterForClicks("AnyDown","AnyUp");

  BindPadFastKey:SetAttribute("*checkselfcast*", true);
  BindPadFastKey:SetAttribute("*checkfocuscast*", true);
  BindPadFastKey:RegisterForClicks("AnyDown","AnyUp");

  BindPadCore.SetTriggerOnKeydown();

  BindPadCore.PruneEmptySlots(character);

  BindPadUpdateFrame:Show();

  GetUIPanelWidth(BindPadMacroTextFrame);

  BindPadVars.version = BINDPAD_SAVEFILE_VERSION;
end

local function PruneProfileSlots(profile)
  if type(profile) ~= "table" then return; end
  for sid = 1, BINDPAD_TOTALSLOTS - BINDPAD_MAXSLOTS, 1 do
    local slot = profile[sid];
    if type(slot) == "table" and next(slot) == nil then
      profile[sid] = nil;
    end
  end
end

function BindPadCore.PruneEmptySlots(skipCharacter)
  for k, v in pairs(BindPadVars) do
    if type(k) == "string" and type(v) == "table" and k ~= skipCharacter
       and strfind(k, "^PROFILE_") then
      for profileNum = 1, BINDPAD_MAXPROFILETAB, 1 do
        PruneProfileSlots(v[profileNum]);
      end
    end
  end
  if skipCharacter == nil then

    for gid = 1, BINDPAD_MAXSLOTS, 1 do
      local slot = BindPadVars[gid];
      if type(slot) == "table" and next(slot) == nil then
        BindPadVars[gid] = nil;
      end
    end
  end
end

function BindPadCore.UpdateMacroText(padSlot)
  if "ITEM" == padSlot.type then
    BindPadKey:SetAttribute("*type-ITEM "..padSlot.name, "item");
    BindPadKey:SetAttribute("*item-ITEM "..padSlot.name, padSlot.name);
    BindPadFastKey:SetAttribute("*type-ITEM "..padSlot.name, "item");
    BindPadFastKey:SetAttribute("*item-ITEM "..padSlot.name, padSlot.name);

  elseif "SPELL" == padSlot.type then
    local spellName = BindPadCore.GetSpellName(padSlot.name, padSlot.rank);
    BindPadKey:SetAttribute("*type-SPELL "..spellName, "spell");
    BindPadKey:SetAttribute("*spell-SPELL "..spellName, spellName);
    BindPadFastKey:SetAttribute("*type-SPELL "..spellName, "spell");
    BindPadFastKey:SetAttribute("*spell-SPELL "..spellName, spellName);

  elseif "MACRO" == padSlot.type then
    BindPadKey:SetAttribute("*type-MACRO "..padSlot.name, "macro");
    BindPadKey:SetAttribute("*macro-MACRO "..padSlot.name, padSlot.name);
    BindPadFastKey:SetAttribute("*type-MACRO "..padSlot.name, "macro");
    BindPadFastKey:SetAttribute("*macro-MACRO "..padSlot.name, padSlot.name);

  elseif padSlot.macrotext ~= nil then
    BindPadMacro:SetAttribute("*macrotext-"..padSlot.name, padSlot.macrotext);
    BindPadFastMacro:SetAttribute("*macrotext-"..padSlot.name, padSlot.macrotext);

  else
    return;
  end

  local newAction = BindPadCore.CreateBindPadMacroAction(padSlot);
  if padSlot.action ~= newAction then
    local key = GetBindingKey(padSlot.action);
    if key then
      SetBinding(key, newAction);
      SaveBindings(GetCurrentBindingSet());
      BindPadCore.GetProfileData().keys[padSlot.action] = nil;
      BindPadCore.GetProfileData().keys[newAction] = key;
    end
    padSlot.action = newAction;
  end
end

function BindPadCore.NewBindPadMacroName(padSlot, name)
  local successFlag;
  repeat
    successFlag = true;
    for gid = 1, BINDPAD_TOTALSLOTS, 1 do
      local curSlot = BindPadCore.GetAllSlotInfo(gid);
      if "CLICK" == curSlot.type and
            name == curSlot.name and
         padSlot ~= curSlot then
        local first, last, num = strfind(name, "(%d+)$");
        if nil == num then
          name = name.."_2";
        else
          name = strsub(name, 0, first - 1)..(num+1);
        end
        successFlag = false;
        break;
      end
    end
  until successFlag;

  return name;
end

function BindPadCore.DeleteBindPadMacroID(padSlot)
  BindPadMacro:SetAttribute("*macrotext-"..padSlot.name, nil);
  BindPadFastMacro:SetAttribute("*macrotext-"..padSlot.name, nil);
end

function BindPadCore.UpdateCursor()
  local drag = BindPadCore.drag;
  if GetCursorInfo() then
    BindPadCore.ClearCursor();
  end
  if "CLICK" == drag.type then
    SetCursor(drag.texture);
  end
end

function BindPadCore.GetSpellName(name, rank)
  if rank == nil then
    if strfind(name, "(", 1, true) then

      return name.."()";
    else
      return name;
    end
  else
    return name.."("..rank..")";
  end
end

function BindPadCore.CreateBindPadMacroAction(padSlot)
  if padSlot.fastTrigger then
    if "ITEM" == padSlot.type then
      return "CLICK BindPadFastKey:ITEM "..padSlot.name;
    elseif "SPELL" == padSlot.type then
      return "CLICK BindPadFastKey:SPELL "..BindPadCore.GetSpellName(padSlot.name, padSlot.rank);
    elseif "MACRO" == padSlot.type then
      return "CLICK BindPadFastKey:MACRO "..padSlot.name;
    elseif "CLICK" == padSlot.type then
      return "CLICK BindPadFastMacro:"..padSlot.name;
    end
  else
    if "ITEM" == padSlot.type then
      return "CLICK BindPadKey:ITEM "..padSlot.name;
    elseif "SPELL" == padSlot.type then
      return "CLICK BindPadKey:SPELL "..BindPadCore.GetSpellName(padSlot.name, padSlot.rank);
    elseif "MACRO" == padSlot.type then
      return "CLICK BindPadKey:MACRO "..padSlot.name;
    elseif "CLICK" == padSlot.type then
      return "CLICK BindPadMacro:"..padSlot.name;
    end
  end
  return nil;
end

function BindPadCore.ConvertToBindPadMacro()
  local padSlot = BindPadCore.selectedSlot;

  if "ITEM" == padSlot.type then
    padSlot.type = "CLICK";
    padSlot.linktext = nil;
    padSlot.macrotext = "/use [mod:SELFCAST,@player][mod:FOCUSCAST,@focus][] "..padSlot.name;

  elseif "SPELL" == padSlot.type then
    padSlot.macrotext = "/cast [mod:SELFCAST,@player][mod:FOCUSCAST,@focus][] "..BindPadCore.GetSpellName(padSlot.name, padSlot.rank);
    padSlot.type = "CLICK";
    padSlot.rank = nil;

  elseif "MACRO" == padSlot.type then
    local name, texture, macrotext = GetMacroInfo(padSlot.name);
    padSlot.type = "CLICK";
    padSlot.macrotext = (macrotext or "");

  else
    return;
  end

  padSlot.name = BindPadCore.NewBindPadMacroName(padSlot, padSlot.name);
  padSlot.action = BindPadCore.CreateBindPadMacroAction(padSlot);
  BindPadCore.UpdateMacroText(padSlot);

  BindPadSlot_UpdateState(BindPadCore.selectedSlotButton);
  BindPadMacroTextFrame_Open(BindPadCore.selectedSlotButton);
end

function BindPadCore.CursorHasIcon()
  return (GetCursorInfo() or BindPadCore.drag.type)
end

function BindPadCore.ClearCursor()
  local drag = BindPadCore.drag;
  if "CLICK" == drag.type then
    BindPadCore.DeleteBindPadMacroID(drag);
    ResetCursor();
    PlaySound("igAbilityIconDrop");
  end
  drag.type = nil;
end

function BindPadCore.PlayerTalentUpdate()
  local newActiveTalentGroup = GetActiveTalentGroup();
  local profileNum = BindPadCore.GetProfileForTalentGroup(newActiveTalentGroup)

  BindPadCore.SwitchProfile(profileNum);
  if BindPadFrame:IsShown() then
    BindPadFrame_OnShow();
  end

  if newActiveTalentGroup == BindPadCore.activeTalentGroup then

    local specInfoCache = BindPadCore.GetSpecInfoCache(newActiveTalentGroup);
    if nil ~= specInfoCache then
      specInfoCache.primaryTabIndex = nil;
    end
  else
    BindPadCore.activeTalentGroup = newActiveTalentGroup;
  end
end

function BindPadCore.GetSpecInfoCache(talentGroup)
  if nil == talentGroup then
    return nil;
  end
  if nil == BindPadCore.specInfoCache[talentGroup] then
    BindPadCore.specInfoCache[talentGroup] = {};
  end
  local specInfoCache = BindPadCore.specInfoCache[talentGroup];
  if nil == specInfoCache.primaryTabIndex then
    TalentFrame_UpdateSpecInfoCache(specInfoCache, false, false, talentGroup);
  end
  return specInfoCache;
end

function BindPadCore.GetSpecTexture(talentGroup)
  local specInfoCache = BindPadCore.GetSpecInfoCache(talentGroup);
  if nil == specInfoCache then
    return nil;
  else
    local primaryTabIndex = specInfoCache.primaryTabIndex;
    if ( primaryTabIndex > 0 ) then

      return specInfoCache[primaryTabIndex].icon;
    else
      return TALENT_HYBRID_ICON;
    end
  end
end

function BindPadCore.SetTriggerOnKeydown()
  if BindPadVars.triggerOnKeydown then

    BindPadMacro:RegisterForClicks("AnyDown");
    BindPadKey:RegisterForClicks("AnyDown");
  else

    BindPadMacro:RegisterForClicks("AnyUp");
    BindPadKey:RegisterForClicks("AnyUp");
  end
end

local strbyte, strchar = string.byte, string.char;

local SHARE_HEADER = "BP1";

local SHARE_FIELDS = { t = "type", n = "name", b = "bookType", r = "rank",
  x = "texture", l = "linktext", m = "macrotext" };
local SHARE_ORDER = { "t", "n", "b", "r", "x", "l", "m" };
local SHARE_TYPES = { ITEM = true, SPELL = true, MACRO = true, CLICK = true };
local SHARE_SCOPES = {
  tab = "current tab",
  profile = "profile (character tabs)",
  all = "all tabs (General + character tabs)",
};

local function ShareEncode(s)
  return (gsub(tostring(s), "[^%w %-_%./%[%]@:,#!%?%(%)%+%*'\"<>{}%$]", function(c)
    return format("%%%02X", strbyte(c));
  end));
end

local function ShareDecode(s)
  return (gsub(s, "%%(%x%x)", function(h)
    return strchar(tonumber(h, 16));
  end));
end

local function ShareChecksum(s)
  local a, b = 1, 0;
  for i = 1, #s do
    a = (a + strbyte(s, i)) % 65521;
    b = (b + a) % 65521;
  end
  return b * 65536 + a;
end

local function ShareScopeRange(scope, tab)
  if scope == "tab" then
    local base = ((tab or 1) - 1) * BINDPAD_MAXSLOTS;
    return base + 1, base + BINDPAD_MAXSLOTS, base;
  elseif scope == "profile" then
    return BINDPAD_MAXSLOTS + 1, BINDPAD_TOTALSLOTS, 0;
  end
  return 1, BINDPAD_TOTALSLOTS, 0;
end

function BindPadCore.ShareSerialize(scope, tab, getSlot, getKey)
  local first, last, offset = ShareScopeRange(scope, tab);
  local entries = {};
  for gid = first, last do
    local s = getSlot(gid);
    if type(s) == "table" and SHARE_TYPES[s.type] and s.name then
      local parts = { tostring(gid - offset) };
      for _, code in ipairs(SHARE_ORDER) do
        local v = s[SHARE_FIELDS[code]];
        if v ~= nil then
          tinsert(parts, code.."="..ShareEncode(v));
        end
      end
      if s.fastTrigger then
        tinsert(parts, "f=1");
      end
      local key = s.action and getKey(s.action);
      if key then
        tinsert(parts, "k="..ShareEncode(key));
      end
      tinsert(entries, table.concat(parts, ";"));
    end
  end
  local body = table.concat(entries, "&");
  return SHARE_HEADER.."~"..scope.."~"..#entries.."~"..tostring(ShareChecksum(body)).."~"..body, #entries;
end

function BindPadCore.ParseShareString(text)
  if type(text) ~= "string" then
    return nil, "Nothing to import: paste a BindPad string first.";
  end

  text = gsub(text, "[\r\n]", "");
  text = gsub(gsub(text, "^%s+", ""), "%s+$", "");
  if text == "" then
    return nil, "Nothing to import: paste a BindPad string first.";
  end
  local header, scope, count, sum, body = strmatch(text, "^(%w+)~(%a+)~(%d+)~(%d+)~(.*)$");
  if header ~= SHARE_HEADER then
    return nil, "This is not a BindPad export string.";
  end
  if not SHARE_SCOPES[scope] then
    return nil, "Unknown export type '"..scope.."'.";
  end
  if tonumber(sum) ~= ShareChecksum(body) then
    return nil, "The string is damaged or incomplete. Copy it again, all of it.";
  end

  local minId, maxId;
  if scope == "tab" then
    minId, maxId = 1, BINDPAD_MAXSLOTS;
  else
    minId, maxId = ShareScopeRange(scope);
  end

  local data = { scope = scope, slots = {}, count = 0 };
  for entry in gmatch(body, "[^&]+") do
    local id;
    local slot = {};
    for token in gmatch(entry, "[^;]+") do
      if not id then
        id = tonumber(token);
        if not id or id ~= floor(id) or id < minId or id > maxId or data.slots[id] then
          return nil, "Invalid slot number in the string.";
        end
      else
        local code, value = strmatch(token, "^(%a)=(.*)$");
        if not code then
          return nil, "Malformed entry in slot "..id..".";
        end
        value = ShareDecode(value);
        if code == "f" then
          slot.fastTrigger = (value == "1") or nil;
        elseif code == "k" then
          if value ~= "" and #value < 64 then
            slot.key = value;
          end
        elseif SHARE_FIELDS[code] then
          slot[SHARE_FIELDS[code]] = value;
        end

      end
    end
    if not SHARE_TYPES[slot.type] or not slot.name or slot.name == "" then
      return nil, "Slot "..tostring(id).." has an invalid type or name.";
    end
    if slot.bookType and slot.bookType ~= "spell" and slot.bookType ~= "pet" then
      return nil, "Slot "..id.." has an invalid spell book type.";
    end
    if slot.type == "CLICK" and slot.macrotext == nil then
      slot.macrotext = "";
    end
    data.slots[id] = slot;
    data.count = data.count + 1;
  end
  if data.count ~= tonumber(count) then
    return nil, "The string is incomplete (slot count does not match).";
  end
  return data;
end

local function ShareTargetText(scope)
  local profileNum = BindPadCore.GetCurrentProfileNum();
  if scope == "tab" then
    if (BindPadVars.tab or 1) == 1 then
      return "the General tab (shared by all your characters)";
    end
    return "the open character tab (profile "..profileNum..")";
  elseif scope == "profile" then
    return "profile "..profileNum.." (character tabs)";
  end
  return "the General tab AND profile "..profileNum;
end

local function ShareCanImport(scope)
  if InCombatLockdown() then
    return "Cannot import while in combat.";
  end
  if nil == BindPadCore.character then
    return "BindPad is not ready yet.";
  end
  local touchesCharacterTabs = (scope ~= "tab") or ((BindPadVars.tab or 1) ~= 1);
  if touchesCharacterTabs and GetCurrentBindingSet() ~= 2 then
    return "Turn on 'Character Specific Key Bindings' in BindPad first.";
  end
end

function BindPadCore.ApplyImport(data)
  local err = ShareCanImport(data.scope);
  if err then
    BindPadFrame_OutputText(err);
    return false;
  end

  BindPadMacroPopupFrame:Hide();
  HideUIPanel(BindPadMacroTextFrame);
  BindPadBindFrame:Hide();
  BindPadCore.ClearCursor();

  local first, last, offset = ShareScopeRange(data.scope, BindPadVars.tab or 1);
  local keys = BindPadCore.GetProfileData().keys;

  for gid = first, last do
    local s = BindPadCore.GetAllSlotInfo(gid);
    if s.action then
      local guard = 0;
      local key = GetBindingKey(s.action);
      while key and guard < 10 do
        SetBinding(key);
        guard = guard + 1;
        key = GetBindingKey(s.action);
      end
      keys[s.action] = nil;
    end
    if "CLICK" == s.type and s.name then
      BindPadCore.DeleteBindPadMacroID(s);
    end
    wipe(s);
  end

  local bound = 0;
  for id, src in pairs(data.slots) do
    local s = BindPadCore.GetAllSlotInfo(id + offset);
    s.type = src.type;
    s.name = src.name;
    s.texture = src.texture;
    s.bookType = src.bookType;
    s.rank = src.rank;
    s.fastTrigger = src.fastTrigger;
    if "ITEM" == src.type then
      s.linktext = src.linktext;
    end
    if "CLICK" == src.type then
      s.macrotext = src.macrotext;

      s.name = BindPadCore.NewBindPadMacroName(s, s.name);
    end
    s.action = BindPadCore.CreateBindPadMacroAction(s);
    BindPadCore.UpdateMacroText(s);
    if src.key and s.action then
      for k, v in pairs(keys) do
        if v == src.key then
          keys[k] = nil;
        end
      end
      if SetBinding(src.key, s.action) then
        keys[s.action] = src.key;
        bound = bound + 1;
      end
    end
  end

  SaveBindings(GetCurrentBindingSet());
  BindPadUpdateFrame:Show();
  if BindPadFrame:IsShown() then
    BindPadFrame_OnShow();
  end
  BindPadFrame_OutputText(format("Imported %d slot(s) and %d key binding(s) into %s.",
    data.count, bound, ShareTargetText(data.scope)));
  return true;
end

StaticPopupDialogs["BINDPAD_CONFIRM_IMPORT"] = {
  text = "%s",
  button1 = OKAY,
  button2 = CANCEL,
  OnAccept = function()
    local data = BindPadCore.pendingImport;
    BindPadCore.pendingImport = nil;
    if data and BindPadCore.ApplyImport(data) and BindPadShareFrame then
      BindPadShareFrame:Hide();
    end
  end,
  OnCancel = function()
    BindPadCore.pendingImport = nil;
  end,
  timeout = 0,
  whileDead = 1,
  showAlert = 1,
  hideOnEscape = 1
};

local function ShareSetHint(f, text, isError)
  if isError then
    f.hint:SetText("|cffff3030"..text.."|r");
  else
    f.hint:SetText(text);
  end
end

local function ShareImportClick()
  local f = BindPadShareFrame;
  local data, err = BindPadCore.ParseShareString(f.editBox:GetText());
  if not data then
    ShareSetHint(f, err, true);
    BindPadFrame_OutputText("Import failed: "..err);
    return;
  end
  err = ShareCanImport(data.scope);
  if err then
    ShareSetHint(f, err, true);
    BindPadFrame_OutputText(err);
    return;
  end
  BindPadCore.pendingImport = data;
  StaticPopup_Show("BINDPAD_CONFIRM_IMPORT", format(
    "Import %d slot(s) into %s?\n\nEverything there now (slots and their key bindings) will be replaced.",
    data.count, ShareTargetText(data.scope)));
end

local function GetShareFrame()
  if BindPadShareFrame then
    return BindPadShareFrame;
  end
  local f = CreateFrame("Frame", "BindPadShareFrame", UIParent);
  f:SetWidth(520);
  f:SetHeight(380);
  f:SetPoint("CENTER");
  f:SetFrameStrata("DIALOG");
  f:SetToplevel(true);
  f:EnableMouse(true);
  f:SetMovable(true);
  f:SetClampedToScreen(true);
  f:RegisterForDrag("LeftButton");
  f:SetScript("OnDragStart", f.StartMoving);
  f:SetScript("OnDragStop", f.StopMovingOrSizing);
  f:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  });
  f:Hide();
  tinsert(UISpecialFrames, "BindPadShareFrame");

  f.title = f:CreateFontString(nil, "ARTWORK", "GameFontNormal");
  f.title:SetPoint("TOP", 0, -18);

  f.hint = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall");
  f.hint:SetPoint("TOPLEFT", 22, -38);
  f.hint:SetPoint("TOPRIGHT", -22, -38);
  f.hint:SetJustifyH("LEFT");

  f.scopeButtons = {};
  local labels = { tab = "Current tab", profile = "Profile (char tabs)", all = "All tabs" };
  local prev;
  for i, scope in ipairs({ "tab", "profile", "all" }) do
    local b = CreateFrame("Button", "BindPadShareScopeButton"..i, f, "UIPanelButtonTemplate");
    b:SetWidth(150);
    b:SetHeight(20);
    b:SetText(labels[scope]);
    if prev then
      b:SetPoint("LEFT", prev, "RIGHT", 6, 0);
    else
      b:SetPoint("TOPLEFT", 22, -60);
    end
    b:SetScript("OnClick", function() BindPadCore.ShowExport(scope); end);
    b.scope = scope;
    f.scopeButtons[i] = b;
    prev = b;
  end

  local bg = CreateFrame("Frame", nil, f);
  bg:SetPoint("TOPLEFT", 18, -86);
  bg:SetPoint("BOTTOMRIGHT", -18, 46);
  bg:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  });
  bg:SetBackdropColor(0, 0, 0, 0.85);
  bg:EnableMouse(true);

  local sf = CreateFrame("ScrollFrame", "BindPadShareScrollFrame", bg, "UIPanelScrollFrameTemplate");
  sf:SetPoint("TOPLEFT", 8, -8);
  sf:SetPoint("BOTTOMRIGHT", -28, 8);

  local eb = CreateFrame("EditBox", "BindPadShareEditBox", sf);
  eb:SetMultiLine(true);
  eb:SetAutoFocus(false);
  eb:SetMaxLetters(0);
  eb:SetFontObject(ChatFontNormal);
  eb:SetWidth(440);
  eb:SetHeight(220);
  eb:SetScript("OnEscapePressed", function() f:Hide(); end);

  eb:SetScript("OnCursorChanged", function(self, x, y, w, h)
    local top = sf:GetVerticalScroll();
    local height = sf:GetHeight();
    y = -y;
    if y < top then
      sf:SetVerticalScroll(y);
    elseif y + h > top + height then
      sf:SetVerticalScroll(y + h - height);
    end
  end);
  sf:SetScrollChild(eb);
  bg:SetScript("OnMouseDown", function() eb:SetFocus(); end);
  f.editBox = eb;

  local close = CreateFrame("Button", "BindPadShareCloseButton", f, "UIPanelButtonTemplate");
  close:SetWidth(100);
  close:SetHeight(22);
  close:SetPoint("BOTTOMRIGHT", -20, 16);
  close:SetText(CLOSE);
  close:SetScript("OnClick", function() f:Hide(); end);

  local import = CreateFrame("Button", "BindPadShareImportButton", f, "UIPanelButtonTemplate");
  import:SetWidth(100);
  import:SetHeight(22);
  import:SetPoint("RIGHT", close, "LEFT", -6, 0);
  import:SetText("Import");
  import:SetScript("OnClick", ShareImportClick);
  f.importButton = import;

  local selectAll = CreateFrame("Button", "BindPadShareSelectButton", f, "UIPanelButtonTemplate");
  selectAll:SetWidth(100);
  selectAll:SetHeight(22);
  selectAll:SetPoint("BOTTOMLEFT", 20, 16);
  selectAll:SetText("Select all");
  selectAll:SetScript("OnClick", function()
    eb:SetFocus();
    eb:HighlightText();
  end);

  f:SetScript("OnHide", function() eb:ClearFocus(); end);
  return f;
end

local function ShareSetMode(f, mode)
  f.mode = mode;
  for _, b in ipairs(f.scopeButtons) do
    if mode == "export" then b:Show(); else b:Hide(); end
  end
  if mode == "import" then
    f.importButton:Show();
  else
    f.importButton:Hide();
  end
end

local function ShareDisplayText(text)
  return (gsub(text, "&", "&\n"));
end

function BindPadCore.ShowExport(scope)
  if nil == BindPadCore.character then
    return;
  end
  if not SHARE_SCOPES[scope] then
    scope = "tab";
  end
  local tab = BindPadVars.tab or 1;
  local keys = BindPadCore.GetProfileData().keys;
  local text, count = BindPadCore.ShareSerialize(scope, tab,
    BindPadCore.GetAllSlotInfo,
    function(action) return GetBindingKey(action) or keys[action]; end);

  local f = GetShareFrame();
  ShareSetMode(f, "export");
  local what = SHARE_SCOPES[scope];
  if scope == "tab" then
    what = (tab == 1) and "General tab" or ("tab "..tab.." of profile "..BindPadCore.GetCurrentProfileNum());
  end
  f.title:SetText(format("BindPad Export: %s, %d slot(s)", what, count));
  for _, b in ipairs(f.scopeButtons) do
    if b.scope == scope then b:LockHighlight(); else b:UnlockHighlight(); end
  end
  ShareSetHint(f, "Press Ctrl+C to copy. Then on any character open BindPad, click Import (or type /bp import) and paste it with Ctrl+V.");
  f:Show();
  f.editBox:SetText(ShareDisplayText(text));
  f.editBox:SetFocus();
  f.editBox:HighlightText();
end

function BindPadCore.ShowImport(prefill, note)
  local f = GetShareFrame();
  ShareSetMode(f, "import");
  f.title:SetText("BindPad Import");
  ShareSetHint(f, note or "Paste a BindPad string with Ctrl+V and click Import. A 'Current tab' string goes into the tab you have open now.");
  f:Show();
  f.editBox:SetText(prefill or "");
  f.editBox:SetFocus();
end

local function ShareCharName(charKey)
  return strmatch(charKey, "^PROFILE_.*_([^_]+)$") or charKey;
end

function BindPadCore.ListCharacters()
  BindPadFrame_OutputText("Characters with saved BindPad data:");
  for k, v in pairs(BindPadVars) do
    if type(k) == "string" and type(v) == "table" and strfind(k, "^PROFILE_") then
      local profiles = {};
      for p = 1, BINDPAD_MAXPROFILETAB do
        if type(v[p]) == "table" then
          tinsert(profiles, p);
        end
      end
      local realm = strmatch(k, "^PROFILE_(.*)_[^_]+$") or "?";
      BindPadFrame_OutputText(format("  %s (%s): profiles %s", ShareCharName(k), realm, table.concat(profiles, ", ")));
    end
  end
end

function BindPadCore.CopyFrom(arg)
  if nil == BindPadCore.character then
    return;
  end
  local who, num = strmatch(arg or "", "^%s*(.-)%s*(%d*)%s*$");
  if who == "" and num == "" then
    BindPadFrame_OutputText("Usage: /bp copy <character> [profile]  or  /bp copy <profile>");
    return;
  end

  local charKey;
  if who == "" then
    charKey = BindPadCore.character;
  else
    local wanted, realm = strlower(who), GetRealmName();
    local sameRealm, otherRealm;
    for k in pairs(BindPadVars) do
      if type(k) == "string" and strfind(k, "^PROFILE_") and strlower(ShareCharName(k)) == wanted then
        if strmatch(k, "^PROFILE_(.*)_[^_]+$") == realm then
          sameRealm = k;
        else
          otherRealm = otherRealm or k;
        end
      end
    end
    charKey = sameRealm or otherRealm;
    if not charKey then
      BindPadFrame_OutputText("No saved BindPad data for '"..who.."'. Type /bp chars to see the list.");
      return;
    end
  end

  local cdata = BindPadVars[charKey];
  local profileNum = tonumber(num)
    or (cdata.profileForTalentGroup and cdata.profileForTalentGroup[1]) or 1;
  local profile = cdata[profileNum];
  if type(profile) ~= "table" then
    BindPadFrame_OutputText(format("%s has no profile %d.", ShareCharName(charKey), profileNum));
    return;
  end
  if charKey == BindPadCore.character and profileNum == BindPadCore.GetCurrentProfileNum() then
    BindPadFrame_OutputText("That is the profile you are using now.");
    return;
  end

  local pkeys = profile.keys or {};
  local text, count = BindPadCore.ShareSerialize("profile", nil,
    function(gid) return profile[gid - BINDPAD_MAXSLOTS]; end,
    function(action) return pkeys[action]; end);
  BindPadCore.ShowImport(ShareDisplayText(text), format(
    "Copied profile %d of %s (%d slot(s)). Click Import to put it into your current profile %d.",
    profileNum, ShareCharName(charKey), count, BindPadCore.GetCurrentProfileNum()));
end

function BindPadFrame_SlashCmd(msg)
  local cmd, rest = strmatch(msg or "", "^%s*(%S*)%s*(.-)%s*$");
  cmd = strlower(cmd or "");
  if cmd == "" then
    BindPadFrame_Toggle();
  elseif cmd == "export" then
    BindPadCore.ShowExport(strlower(rest or ""));
  elseif cmd == "import" then
    BindPadCore.ShowImport();
  elseif cmd == "copy" then
    BindPadCore.CopyFrom(rest);
  elseif cmd == "chars" then
    BindPadCore.ListCharacters();
  else
    BindPadFrame_OutputText("Commands:");
    BindPadFrame_OutputText("  /bp - open or close BindPad");
    BindPadFrame_OutputText("  /bp export [tab|profile|all] - export as text");
    BindPadFrame_OutputText("  /bp import - paste a string to import");
    BindPadFrame_OutputText("  /bp copy <character> [profile] - copy a profile from another character");
    BindPadFrame_OutputText("  /bp copy <profile> - copy another profile of this character");
    BindPadFrame_OutputText("  /bp chars - list characters with saved data");
  end
end

function BindPadCore.CreateShareButtons()
  if BindPadFrameExportButton then
    return;
  end
  local function addTooltip(button, text)
    button:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
      GameTooltip:SetText(text, 1, 1, 1, 1, 1);
      GameTooltip:Show();
    end);
    button:SetScript("OnLeave", function() GameTooltip:Hide(); end);
  end

  local export = CreateFrame("Button", "BindPadFrameExportButton", BindPadFrame, "UIPanelButtonTemplate");
  export:SetWidth(60);
  export:SetHeight(20);
  export:SetPoint("TOPLEFT", BindPadProfileTab5, "BOTTOMLEFT", -2, -24);
  export:SetText("Export");
  export:SetScript("OnClick", function() BindPadCore.ShowExport("tab"); end);
  addTooltip(export, "Export the current tab, the whole profile or all tabs as text you can copy.");

  local import = CreateFrame("Button", "BindPadFrameImportButton", BindPadFrame, "UIPanelButtonTemplate");
  import:SetWidth(60);
  import:SetHeight(20);
  import:SetPoint("TOPLEFT", export, "BOTTOMLEFT", 0, -4);
  import:SetText("Import");
  import:SetScript("OnClick", function() BindPadCore.ShowImport(); end);
  addTooltip(import, "Paste a BindPad string to import it.\nTo copy a profile from another character: /bp copy <name> [profile]");
end

local MACRO_ICON_CMDS;
local function GetMacroIconCmds()
  if MACRO_ICON_CMDS then
    return MACRO_ICON_CMDS;
  end
  MACRO_ICON_CMDS = {
    ["/cast"] = "cast", ["/spell"] = "cast", ["/use"] = "use",
    ["/castsequence"] = "sequence", ["/castrandom"] = "random", ["/userandom"] = "random",
  };
  local function add(prefix, kind)
    for i = 1, 9 do
      local s = _G[prefix..i];
      if type(s) == "string" then
        MACRO_ICON_CMDS[strlower(s)] = kind;
      end
    end
  end
  add("SLASH_CAST", "cast");
  add("SLASH_USE", "use");
  add("SLASH_CASTSEQUENCE", "sequence");
  add("SLASH_CASTRANDOM", "random");
  add("SLASH_USERANDOM", "random");
  return MACRO_ICON_CMDS;
end

local function MacroOptionParse(args)
  if SecureCmdOptionParse then
    return SecureCmdOptionParse(args);
  end
  return (gsub(args, "%b[]", ""));
end

local function MacroCleanValue(v)
  v = gsub(v, "^%s*!", "");
  return (gsub(gsub(v, "^%s+", ""), "%s+$", ""));
end

local function MacroValueTexture(value, preferItem)
  local num = tonumber(value);
  if num then
    if num >= 1 and num <= 19 then
      local tex = GetInventoryItemTexture("player", num);
      if tex then return tex, "slot", num; end
    end
    return nil;
  end
  local bag, slot = strmatch(value, "^(%d+)%s+(%d+)$");
  if bag then
    bag, slot = tonumber(bag), tonumber(slot);
    local tex = GetContainerItemInfo(bag, slot);
    if tex then return tex, "bag", bag, slot; end
    return nil;
  end

  local function spell()
    local _, _, tex = GetSpellInfo(value);
    local base = value;
    if not tex then

      base = gsub(value, "%s*%([^%)]*%d+%)$", "");
      _, _, tex = GetSpellInfo(base);
    end
    if tex then return tex, "spell", base; end
  end
  local function item()
    local _, link, _, _, _, _, _, _, _, tex = GetItemInfo(value);
    if tex then return tex, "item", link; end
  end

  local tex, kind, a, b;
  if preferItem then
    tex, kind, a, b = item();
    if not tex then tex, kind, a, b = spell(); end
  else
    tex, kind, a, b = spell();
    if not tex then tex, kind, a, b = item(); end
  end
  return tex, kind, a, b;
end

local function MacroCommandValue(kind, args)
  local v = MacroOptionParse(args);
  if not v or v == "" then
    return nil;
  end
  if kind == "sequence" then
    v = gsub(v, "^%s*reset=%S+%s*", "");
    v = strmatch(v, "^([^,]*)") or v;
  elseif kind == "random" then
    v = strmatch(v, "^([^,]*)") or v;
  end
  v = MacroCleanValue(v);
  if v == "" then
    return nil;
  end
  return v;
end

function BindPadCore.ResolveMacroIcon(macrotext)
  if type(macrotext) ~= "string" or macrotext == "" then
    return nil;
  end
  local cmds = GetMacroIconCmds();
  for line in gmatch(macrotext, "[^\r\n]+") do
    local cmd, args = strmatch(line, "^%s*([#/]%S*)%s*(.-)%s*$");
    if cmd then
      cmd = strlower(cmd);
      if cmd == "#showtooltip" or cmd == "#show" then
        if args ~= "" then

          local v = MacroOptionParse(args);
          if not v or v == "" then
            return nil;
          end
          return MacroValueTexture(MacroCleanValue(v), false);
        end
      elseif cmds[cmd] then
        local v = MacroCommandValue(cmds[cmd], args);
        if v then
          local tex, kind, a, b = MacroValueTexture(v, cmds[cmd] == "use");
          if tex then
            return tex, kind, a, b;
          end
        end
      end
    end
  end
  return nil;
end

local function IsQuestionMarkTexture(texture)
  return type(texture) == "string"
    and strfind(strlower(texture), "inv_misc_questionmark", 1, true) ~= nil;
end

function BindPadCore.GetSlotTexture(padSlot)
  if "CLICK" == padSlot.type and padSlot.macrotext and IsQuestionMarkTexture(padSlot.texture) then
    local tex = BindPadCore.ResolveMacroIcon(padSlot.macrotext);
    if tex then
      return tex;
    end
  end
  return padSlot.texture;
end

local function HasShowTooltip(macrotext)
  for line in gmatch(macrotext, "[^\r\n]+") do
    if strfind(strlower(line), "^%s*#showtooltip") then
      return true;
    end
  end
  return false;
end

function BindPadCore.SetMacroTooltip(padSlot)
  if type(padSlot.macrotext) ~= "string" or not HasShowTooltip(padSlot.macrotext) then
    return false;
  end
  local tex, kind, a, b = BindPadCore.ResolveMacroIcon(padSlot.macrotext);
  if not tex then
    return false;
  end
  if kind == "spell" then
    local id = BindPadCore.FindSpellIdByName(a, nil, BOOKTYPE_SPELL);
    if id then
      GameTooltip:SetSpell(id, BOOKTYPE_SPELL);
      return true;
    end
    id = BindPadCore.FindSpellIdByName(a, nil, BOOKTYPE_PET);
    if id then
      GameTooltip:SetSpell(id, BOOKTYPE_PET);
      return true;
    end
  elseif kind == "item" and a then
    GameTooltip:SetHyperlink(a);
    return true;
  elseif kind == "slot" then
    GameTooltip:SetInventoryItem("player", a);
    return GameTooltip:NumLines() > 0;
  elseif kind == "bag" then
    GameTooltip:SetBagItem(a, b);
    return GameTooltip:NumLines() > 0;
  end
  return false;
end

function BindPadCore.RefreshMacroIcons()
  if not BindPadFrame:IsVisible() or nil == BindPadCore.character then
    return;
  end
  for i = 1, BINDPAD_MAXSLOTS, 1 do
    local padSlot = BindPadCore.GetSlotInfo(i);
    if padSlot and "CLICK" == padSlot.type then
      local icon = _G["BindPadSlot"..i.."Icon"];
      if icon then
        icon:SetTexture(BindPadCore.GetSlotTexture(padSlot));
      end
    end
  end
end

local MACRO_ICON_EVENTS = {
  "MODIFIER_STATE_CHANGED", "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED",
  "BAG_UPDATE", "PLAYER_EQUIPMENT_CHANGED", "UPDATE_SHAPESHIFT_FORM", "ACTIONBAR_PAGE_CHANGED",
};
BindPadCore.macroIconEvents = {};
for _, e in ipairs(MACRO_ICON_EVENTS) do
  BindPadCore.macroIconEvents[e] = true;
end

function BindPadCore.SetMacroIconEvents(enable)
  for _, e in ipairs(MACRO_ICON_EVENTS) do
    if enable then
      BindPadFrame:RegisterEvent(e);
    else
      BindPadFrame:UnregisterEvent(e);
    end
  end
end
