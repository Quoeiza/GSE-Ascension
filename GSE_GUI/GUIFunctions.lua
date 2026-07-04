local GSE = GSE
local L = GSE.L
-- Namespaced onto GSE (was a bare global 'myUpdateFix' - global pollution/taint).
function GSE.myUpdateFix()
  GSE:ProcessOOCQueue()
  GSE.ReloadSequences()

end
--- This function pops up a confirmation dialog.
function GSE.GUIDeleteSequence(currentSeq, iconWidget)
  StaticPopupDialogs["GSE-DeleteMacroDialog"].text = string.format(L["Are you sure you want to delete %s?  This will delete the macro and all versions.  This action cannot be undone."], GSE.GUIEditFrame.SequenceName)
  StaticPopupDialogs["GSE-DeleteMacroDialog"].OnAccept = function(self, data)
      GSE.GUIConfirmDeleteSequence(GSE.GUIEditFrame.ClassID, GSE.GUIEditFrame.SequenceName)
  end
  StaticPopup_Show ("GSE-DeleteMacroDialog")
  
end

--- This function then deletes the macro
function GSE.GUIConfirmDeleteSequence(classid, sequenceName)
  GSE.GUIViewFrame:Hide()
  GSE.GUIEditFrame:Hide()
  GSE.DeleteSequence(classid, sequenceName)
  GSE.GUIShowViewer()
end


--- Format the text against the GSE Sequence Spec.
function GSE.GUIParseText(editbox)
  if GSEOptions.RealtimeParse then
    -- text/returntext were global - localise to avoid global pollution/taint.
    local text = GSE.UnEscapeString(editbox:GetText())
    local returntext = GSE.TranslateString(text , GetLocale(), GetLocale(), true)
    editbox:SetText(returntext)
    editbox:SetCursorPosition(string.len(returntext)+2)
  end
end

function GSE.GUILoadEditor(key, incomingframe, recordedstring)
  local classid
  local sequenceName
  local sequence
  
  if GSE.isEmpty(key) then
    classid = GSE.GetCurrentClassID()
    sequenceName = GSE.getSequenceName()
	-- Was a bare global; Editor.lua reads GSE.isNewFirstTimeCreated, so the bare
	-- global assignment had no effect (and polluted _G).  Use the namespaced field.
	GSE.isNewFirstTimeCreated=true
    sequence = {
      ["Author"] = GSE.GetCharacterName(),
      ["Talents"] = GSE.GetCurrentTalents(),
      ["Default"] = 1,
      ["SpecID"] = GSE.GetCurrentSpecID();
      ["MacroVersions"] = {
        [1] = {
          ["PreMacro"] = {},
          ["PostMacro"] = {},
          ["KeyPress"] = {},
          ["KeyRelease"] = {},
          ["StepFunction"] = "Sequential",
          [1] = "/say Hello",
        }
      },
    }
    -- Default new sequences to Global (0) when the client doesn't report a spec
    -- we recognise (classless / Conquest of Azeroth characters).  This makes the
    -- editor's Specialisation/Class dropdown show "Global" instead of a blank
    -- entry, and the macro works for every character.  A standard realm keeps its
    -- detected spec.
    if GSE.isEmpty(sequence.SpecID) or GSE.isEmpty(GSE.Static.wotlkSpecIDList[sequence.SpecID]) then
      sequence.SpecID = 0
    end
    if GSE.isEmpty(classid) or GSE.isEmpty(GSE.Static.wotlkClassIDList[classid]) then
      classid = 0
    end
    if not GSE.isEmpty(recordedstring) then
      sequence.MacroVersions[1][1] = nil
      sequence.MacroVersions[1] = GSE.SplitMeIntolines(recordedstring)
    end
  else
    local elements = GSE.split(key, ",")
    classid = tonumber(elements[1])
    sequenceName = elements[2]
	
    -- Check if the library and sequence exist before cloning
    if GSELibrary[classid] and GSELibrary[classid][sequenceName] then
      sequence = GSE.CloneSequence(GSELibrary[classid][sequenceName], true)
    end
    
    -- If sequence is still nil, don't create a fallback - this prevents corruption
    if not sequence then
      GSE.Print("Error: Could not load sequence '" .. (sequenceName or "unknown") .. "' for class " .. (classid or "unknown") .. ". Please recreate this sequence.")
      -- Close the editor and return to viewer
      if GSE.GUIEditFrame then
        GSE.GUIEditFrame:Hide()
      end
      if GSE.GUIViewFrame then
        GSE.GUIViewFrame:Show()
      end
      return
    end
	GSE.isNewFirstTimeCreated=false
  end
  GSE.GUIEditFrame.SequenceName = sequenceName
  GSE.GUIEditFrame.Sequence = sequence
  GSE.GUIEditFrame.ClassID = classid
  GSE.GUIEditFrame.Default = sequence.Default or 1
  GSE.GUIEditFrame.PVP = sequence.PVP or sequence.Default or 1
  GSE.GUIEditFrame.Mythic = sequence.Mythic or sequence.Default or 1
  GSE.GUIEditFrame.Raid = sequence.Raid or sequence.Default or 1
  GSE.GUIEditFrame.Dungeon = sequence.Dungeon or sequence.Default or 1
  GSE.GUIEditFrame.Heroic = sequence.Heroic or sequence.Default or 1
  GSE.GUIEditFrame.Party = sequence.Party or sequence.Default or 1
  GSE.GUIEditorPerformLayout(GSE.GUIEditFrame)
  GSE.GUIEditFrame.ContentContainer:SelectTab("config")
  incomingframe:Hide()
  if not InCombatLockdown() then
	GSE.myUpdateFix()
	GSE.GUIEditFrame:Show()
  end

end

function GSE.getSequenceName()
  
  local names1 = GSE.GetSequenceNames()
  local numberOfSeqs = 0
  local currentSpecID, specname, specicon = GSE.GetCurrentSpecID()
  local newSeqNameTemp = GSE.TrimWhiteSpace(GSE.LowerAndReplaceSpecialCharacters("New"..specname))
  local newSeqName = GSE.TrimWhiteSpace(GSE.LowerAndReplaceSpecialCharacters("New"..specname))
  local newSeqNumber=numberOfSeqs+1
  if not GSE.isEmpty(GSELibrary[0]) then
    numberOfSeqs = 0
    for k,v in pairs(GSELibrary[0]) do
      numberOfSeqs = numberOfSeqs + 1
      if v.MacroVersions and type(v.MacroVersions) == "table" then
        for i,j in ipairs(v.MacroVersions) do
          GSELibrary[0][k].MacroVersions[tonumber(i)] = GSE.UnEscapeSequence(j)
        end
      end
    end
  end
  if numberOfSeqs <= 0 then
    if not GSE.isEmpty(GSELibrary[GSE.GetCurrentClassID()]) then
      for k,v in GSE.pairsByKeys(names1) do
        numberOfSeqs = numberOfSeqs + 1 
      end
    end
  end
  newSeqNumber=numberOfSeqs+1
  newSeqNameTemp = GSE.TrimWhiteSpace(GSE.LowerAndReplaceSpecialCharacters("New"..specname..newSeqNumber..GetTime()))
  newSeqNameTemp = GSE.TrimWhiteSpace(GSE.LowerAndReplaceSpecialCharacters(newSeqNameTemp))
  for k,v in GSE.pairsByKeys(names1) do
    local elements = GSE.split(k, ",")
    local classid = tonumber(elements[1])
    local sequencename = elements[2]
	if newSeqNameTemp == sequencename then
	  newSeqNumber=numberOfSeqs+1
	  newSeqNameTemp = GSE.TrimWhiteSpace(GSE.LowerAndReplaceSpecialCharacters("New"..specname..newSeqNumber..GetTime()))
	  newSeqNameTemp = GSE.TrimWhiteSpace(GSE.LowerAndReplaceSpecialCharacters(newSeqNameTemp))
	end
  end
  for name, sequence in pairs(GSELibrary[GSE.GetCurrentClassID()]) do
    if newSeqNameTemp == name then
	  newSeqNumber = numberOfSeqs+1
	  newSeqNameTemp = GSE.TrimWhiteSpace(GSE.LowerAndReplaceSpecialCharacters("New"..specname..newSeqNumber..GetTime()))
	  newSeqNameTemp = GSE.TrimWhiteSpace(GSE.LowerAndReplaceSpecialCharacters(newSeqNameTemp))
	end
  end
  newSeqNameTemp = GSE.TrimWhiteSpace(GSE.LowerAndReplaceSpecialCharacters(newSeqNameTemp))
  newSeqName =  GSE.TrimWhiteSpace(GSE.LowerAndReplaceSpecialCharacters(newSeqNameTemp))
  return newSeqName
end

function GSE.GUIUpdateSequenceList()
  local names = GSE.GetSequenceNames()
  GSE.GUIViewFrame.SequenceListbox:SetList(names)
end

function GSE.GUIToggleClasses(buttonname)
  if buttonname == "class" then
    classradio:SetValue(true)
    specradio:SetValue(false)
  else
    classradio:SetValue(false)
    specradio:SetValue(true)
  end
end


function GSE.GUIUpdateSequenceDefinition(classid, SequenceName, sequence)

  -- Changes have been made so save them
  if sequence.MacroVersions and type(sequence.MacroVersions) == "table" then
    for k,v in ipairs(sequence.MacroVersions) do
      sequence.MacroVersions[k] = GSE.TranslateSequenceFromTo(v, GetLocale(), "enUS", SequenceName)
      sequence.MacroVersions[k] = GSE.UnEscapeSequence(sequence.MacroVersions[k])
    end
  end

  if not GSE.isEmpty(SequenceName) then
    if GSE.isEmpty(classid) then
      classid = GSE.GetCurrentClassID()
    end
    if not GSE.isEmpty(SequenceName) then
      local vals = {}
      vals.action = "Replace"
      vals.sequencename = SequenceName
      vals.sequence = sequence
      vals.classid = classid
      table.insert(GSE.OOCQueue, vals)
      GSE.GUIEditFrame:SetStatusText(string.format(L["Sequence %s saved."], SequenceName))
    end
  end
end


function GSE.GUIGetColour(option)
  -- 'hex' was an unused global (pollution); it is not needed by the return below.
  return tonumber("0x".. string.sub(option,5,6))/255, tonumber("0x"..string.sub(option,7,8))/255, tonumber("0x"..string.sub(option,9,10))/255
end

function  GSE.GUISetColour(option, r, g, b)
  option = string.format("|c%02x%02x%02x%02x", 255 , r*255, g*255, b*255)
end


function GSE:OnInitialize()
    GSE.GUIRecordFrame:Hide()
    GSE.GUIVersionFrame:Hide()
    GSE.GUIEditFrame:Hide()
    GSE.GUIViewFrame:Hide()
end


function GSE.OpenOptionsPanel()
  local config = LibStub:GetLibrary("AceConfigDialog-3.0")
  config:Open("GSE")
  --config:SelectGroup("GSSE", "Debug")

end

--- Adds a "GSE" button to the ESC game menu (like ElvUI), for quicker access
--  than typing /gse.  Inserted below the AddOns button; the Logout group and the
--  frame height are shifted to make room.  Guarded and run once.
function GSE.CreateGameMenuButton()
  if _G["GSEGameMenuButton"] then
    return
  end
  local frame = GameMenuFrame
  if not frame then
    return
  end
  local anchor = _G["GameMenuButtonAddOns"] or _G["GameMenuButtonMacros"]
    or _G["GameMenuButtonKeybindings"] or _G["GameMenuButtonUIOptions"] or _G["GameMenuButtonOptions"]
  if not anchor then
    return
  end

  local btn = CreateFrame("Button", "GSEGameMenuButton", frame, "GameMenuButtonTemplate")
  btn:SetText("|cffff0000G|r|cff00d1ffSE|r")
  btn:SetPoint("TOP", anchor, "BOTTOM", 0, -1)
  btn:SetScript("OnClick", function()
    if HideUIPanel then
      HideUIPanel(frame)
    else
      frame:Hide()
    end
    if not InCombatLockdown() then
      GSE.GUIShowViewer()
    end
  end)

  -- Push the Logout button (and everything anchored to it) down below our button
  -- and grow the frame to fit, preserving Logout's original gap.
  local logout = _G["GameMenuButtonLogout"]
  local grow = (btn:GetHeight() or 16) + 1
  if logout then
    local point, _, relPoint, x, y = logout:GetPoint()
    logout:ClearAllPoints()
    logout:SetPoint(point or "TOP", btn, relPoint or "BOTTOM", x or 0, (y and y < 0) and y or -16)
  end
  frame:SetHeight((frame:GetHeight() or 0) + grow)
end

-- Insert the button the first time the game menu is shown (running after other
-- addons such as ElvUI have laid the menu out).  Guarded so it only happens once.
if GameMenuFrame then
  GameMenuFrame:HookScript("OnShow", function()
    pcall(GSE.CreateGameMenuButton)
  end)
end
