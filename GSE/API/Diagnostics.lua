-- Diagnostics.lua
-- Self-contained diagnostic + automatic error-capture facility for GSE on
-- Project Ascension / custom 3.3.5a clients.
--
-- Why this exists: the addon's failures are swallowed at runtime and 3.3.5a
-- clients make copying chat output painful.  This module (a) chains the global
-- Lua error handler so EVERY error (from any addon) is written to
-- SavedVariables, and (b) provides /gse diag which runs a full structured probe
-- - including a live test of whether this client supports the secure
-- Execute/WrapScript machinery every GSE sequence depends on - and writes the
-- whole report to SavedVariables so it can be copied straight out of the file.
--
-- Usage (for the maintainer):
--   1. /gse diag        -> runs the probe, prints a short summary, saves report
--   2. /reload          -> flushes SavedVariables to disk
--   3. open  WTF\Account\<ACCOUNT>\SavedVariables\GSE.lua  and copy the
--      GSEOptions["LastDiagnosticReport"] string (and ErrorLog) out.

local GSE = GSE
local Statics = GSE.Static
local L = GSE.L

local MAX_ERRORS = 150

-- ---------------------------------------------------------------------------
-- Timestamp helper (date() should exist on 3.3.5a; guard just in case).
-- ---------------------------------------------------------------------------
local function timestamp()
  local ok, t = pcall(function() return date("%Y-%m-%d %H:%M:%S") end)
  if ok and t then
    return t
  end
  return "t+" .. tostring(math.floor(GetTime() or 0))
end

-- ---------------------------------------------------------------------------
-- Persistent error capture.
-- ---------------------------------------------------------------------------
local function appendError(msg)
  if type(GSEOptions) ~= "table" then
    return
  end
  GSEOptions.ErrorLog = GSEOptions.ErrorLog or {}
  local log = GSEOptions.ErrorLog
  log[#log + 1] = timestamp() .. " | " .. tostring(msg)
  while #log > MAX_ERRORS do
    table.remove(log, 1)
  end
end
GSE.DiagAppendError = appendError

-- Chain (do not clobber) the current global error handler.  Error handlers run
-- in insecure context AFTER an error has already unwound the stack, so this
-- cannot propagate taint into the secure macro path - it only records.
do
  local origHandler = geterrorhandler and geterrorhandler() or nil
  local function gseErrorHandler(err)
    pcall(appendError, err)
    if origHandler then
      return origHandler(err)
    end
  end
  if seterrorhandler then
    pcall(seterrorhandler, gseErrorHandler)
  end
end

-- ---------------------------------------------------------------------------
-- The report builder.
-- ---------------------------------------------------------------------------
function GSE.RunDiagnostics()
  local out = {}
  -- Key results echoed to chat by ShowDiagnostics for an immediate read.
  local summary = {}
  GSE.DiagSummary = summary
  local function line(s)
    out[#out + 1] = (s == nil) and "" or tostring(s)
  end
  local function kv(k, v)
    out[#out + 1] = tostring(k) .. ": " .. tostring(v)
  end
  -- pcall wrapper that returns a readable value or an ERR() marker.
  local function try(fn)
    local ok, a = pcall(fn)
    if ok then
      if a == nil then return "nil" end
      return a
    end
    return "ERR(" .. tostring(a) .. ")"
  end

  line("================ GSE DIAGNOSTIC REPORT ================")
  kv("Generated", timestamp())
  kv("GSE Version", GSE.VersionString)
  kv("Client version", try(function() return (GetBuildInfo()) end))
  kv("Interface build", try(function() return select(4, GetBuildInfo()) end))
  kv("Locale", GetLocale())
  kv("InCombatLockdown", InCombatLockdown() and true or false)
  line("")

  line("---- Addon / timer state ----")
  kv("OnEnable ran", GSE.DiagOnEnableRan and true or false)
  kv("OOCTimer running", not GSE.isEmpty(GSE.OOCTimer))
  kv("OOCTimer re-armed by PEW", GSE.DiagTimerRearmed and true or false)
  kv("ProcessOOCQueue ticks", tostring(GSE.DiagOOCTicks or 0))
  kv("OOCQueue length", try(function() return #GSE.OOCQueue end))
  kv("PrintAvailable", GSE.PrintAvailable and true or false)
  kv("TranslatorAvailable", GSE.TranslatorAvailable and true or false)
  line("")

  line("---- Class / spec detection ----")
  local uc1, uc2, uc3 = UnitClass("player")
  kv("UnitClass localized", tostring(uc1))
  kv("UnitClass token", tostring(uc2))
  kv("UnitClass 3rd return", tostring(uc3))
  kv("GetCurrentClassID", try(function() return GSE.GetCurrentClassID() end))
  kv("GetCurrentSpecID", try(function() return (GSE.GetCurrentSpecID()) end))
  kv("GetNumTalentTabs", try(function() return GetNumTalentTabs() end))
  kv("GetActiveTalentGroup", try(function() return GetActiveTalentGroup() end))
  line("")

  -- Client class enumeration - so we can wire the editor's class dropdown to the
  -- classes THIS client actually exposes (eg Conquest of Azeroth's custom set)
  -- instead of hardcoding guesses.  These are standard FrameXML globals that a
  -- custom client may have extended.
  line("---- Client class enumeration (for custom classes) ----")
  kv("GetNumClasses", try(function() return GetNumClasses() end))
  kv("MAX_CLASSES", tostring(MAX_CLASSES))
  if type(CLASS_SORT_ORDER) == "table" then
    kv("#CLASS_SORT_ORDER", #CLASS_SORT_ORDER)
    for i, token in ipairs(CLASS_SORT_ORDER) do
      local locname = (type(LOCALIZED_CLASS_NAMES_MALE) == "table" and LOCALIZED_CLASS_NAMES_MALE[token]) or "?"
      line(string.format("  [%d] token=%s name=%s", i, tostring(token), tostring(locname)))
    end
  else
    kv("CLASS_SORT_ORDER", type(CLASS_SORT_ORDER))
  end
  if type(LOCALIZED_CLASS_NAMES_MALE) == "table" then
    local names = {}
    for token, locname in pairs(LOCALIZED_CLASS_NAMES_MALE) do
      names[#names + 1] = tostring(token) .. "=" .. tostring(locname)
    end
    line("  LOCALIZED_CLASS_NAMES_MALE: " .. table.concat(names, ", "))
  end
  line("")

  -- The single most important section: does this client support the secure
  -- snippet machinery at all?  Every GSE sequence relies on Execute+newtable and
  -- WrapScript.  If either FAILs here, that is the root cause of "macros do
  -- nothing" and no amount of macro-content tweaking will help.
  line("---- Secure environment probe ----")
  local probeName = "GSEDiagProbeButton"
  local btn = _G[probeName]
  if not btn then
    local ok, err = pcall(function()
      return CreateFrame("Button", probeName, nil, "SecureActionButtonTemplate,SecureHandlerBaseTemplate")
    end)
    kv("CreateFrame(secure)", ok and "OK" or ("FAIL: " .. tostring(err)))
    btn = _G[probeName]
  else
    kv("CreateFrame(secure)", "OK (already existed)")
  end
  if btn then
    kv("objectType", try(function() return btn:GetObjectType() end))
    kv("has Execute method", type(btn.Execute))
    kv("has WrapScript method", type(btn.WrapScript))
    kv("SetAttribute type=macro", (pcall(function() btn:SetAttribute("type", "macro") end)) and "OK" or "FAIL")
    local okE, errE = pcall(function() btn:Execute("macros = newtable([=[/say probe]=])") end)
    kv("Execute + newtable", okE and "OK" or ("FAIL: " .. tostring(errE)))
    summary.execute = okE and "OK" or ("FAIL: " .. tostring(errE))
    local okW, errW = pcall(function() btn:WrapScript(btn, "OnClick", "self:SetAttribute('step', 1)") end)
    kv("WrapScript OnClick", okW and "OK" or ("FAIL: " .. tostring(errW)))
    summary.wrapscript = okW and "OK" or ("FAIL: " .. tostring(errW))
    kv("SetAttribute macrotext", (pcall(function() btn:SetAttribute("macrotext", "/say probe") end)) and "OK" or "FAIL")
    kv("read back macrotext", try(function() return btn:GetAttribute("macrotext") end))
  else
    line("  (no probe button - secure frame creation failed)")
  end
  line("")

  -- Run the REAL compile pipeline on a known-good trivial macro and report where
  -- it lands.  This bypasses the queue and calls OOCUpdateSequence directly under
  -- pcall so the true error (if any) is captured rather than swallowed.
  line("---- Live compile test (name 'GSEDiagTest') ----")
  local testName = "GSEDiagTest"
  local testMV = {
    [1] = "/say GSE diag test step",
    KeyPress = {},
    KeyRelease = {},
    PreMacro = {},
    PostMacro = {},
    StepFunction = "Sequential",
  }
  local okC, errC = pcall(GSE.OOCUpdateSequence, testName, testMV)
  kv("OOCUpdateSequence pcall", okC and "OK" or ("FAIL: " .. tostring(errC)))
  summary.compile = okC and "OK" or ("FAIL: " .. tostring(errC))
  local tbtn = _G[testName]
  kv("_G['GSEDiagTest'] created", tbtn ~= nil)
  summary.buttonCreated = (tbtn ~= nil)
  if tbtn then
    summary.macrotext = (pcall(function() return tbtn:GetAttribute("macrotext") end))
      and tbtn:GetAttribute("macrotext") or "(unreadable)"
  end
  if tbtn then
    kv("  type", try(function() return tbtn:GetAttribute("type") end))
    kv("  macrotext", try(function() return tbtn:GetAttribute("macrotext") end))
    kv("  step", try(function() return tbtn:GetAttribute("step") end))
    kv("  KeyPress", try(function() return tbtn:GetAttribute("KeyPress") end))
    kv("  KeyRelease", try(function() return tbtn:GetAttribute("KeyRelease") end))
    kv("  loopstart", try(function() return tbtn:GetAttribute("loopstart") end))
    kv("  loopstop", try(function() return tbtn:GetAttribute("loopstop") end))
    kv("  SequencesExec length", try(function() return #(GSE.SequencesExec[testName] or {}) end))
  end
  line("")

  line("---- Stored sequences (button state) ----")
  if type(GSELibrary) == "table" then
    local count = 0
    for classid, lib in pairs(GSELibrary) do
      if type(lib) == "table" then
        for name, seq in pairs(lib) do
          count = count + 1
          local btnExists = _G[name] ~= nil
          local mt = "-"
          if btnExists then
            mt = try(function() return _G[name]:GetAttribute("macrotext") end)
          end
          local mvcount = "?"
          if type(seq) == "table" and type(seq.MacroVersions) == "table" then
            mvcount = tostring(#seq.MacroVersions)
          end
          line(string.format("  [class %s] '%s' | versions=%s | button=%s | macrotext=%s",
            tostring(classid), tostring(name), mvcount, tostring(btnExists), tostring(mt)))
        end
      end
    end
    if count == 0 then
      line("  (no stored sequences)")
    end
  else
    line("  GSELibrary is not a table (type=" .. type(GSELibrary) .. ")")
  end
  line("")

  line("---- Captured Lua errors (most recent, max " .. MAX_ERRORS .. ") ----")
  if type(GSEOptions) == "table" and type(GSEOptions.ErrorLog) == "table" and #GSEOptions.ErrorLog > 0 then
    for _, e in ipairs(GSEOptions.ErrorLog) do
      line("  " .. tostring(e))
    end
  else
    line("  (none captured this session)")
  end
  line("================ END REPORT ================")

  local report = table.concat(out, "\n")
  if type(GSEOptions) == "table" then
    GSEOptions.LastDiagnosticReport = report
  end
  GSE.LastDiagnosticReport = report
  return report
end

-- ---------------------------------------------------------------------------
-- User-facing entry points (wired into /gse diag and /gse diaglog).
-- ---------------------------------------------------------------------------
function GSE.ShowDiagnostics()
  local report
  local ok, err = pcall(function()
    report = GSE.RunDiagnostics()
  end)
  if not ok then
    GSE.Print("GSE diagnostics failed to run: " .. tostring(err))
    return
  end
  GSE.Print("|cff00ff00GSE diagnostic complete.|r  Key results:")
  local s = GSE.DiagSummary or {}
  GSE.Print("  secure Execute+newtable : " .. tostring(s.execute))
  GSE.Print("  secure WrapScript       : " .. tostring(s.wrapscript))
  GSE.Print("  live compile pcall      : " .. tostring(s.compile))
  GSE.Print("  test button created     : " .. tostring(s.buttonCreated))
  GSE.Print("  test button macrotext   : " .. tostring(s.macrotext))
  GSE.Print("  OnEnable ran / OOC ticks: " .. tostring(GSE.DiagOnEnableRan and true or false) .. " / " .. tostring(GSE.DiagOOCTicks or 0))
  GSE.Print("To send the FULL report:")
  GSE.Print("1) Type |cffffff00/reload|r to flush the report to disk.")
  GSE.Print("2) Open |cffffff00WTF\\Account\\<ACCOUNT>\\SavedVariables\\GSE.lua|r and copy the")
  GSE.Print("   |cffffff00LastDiagnosticReport|r and |cffffff00ErrorLog|r values, then send them over.")
  -- Also stream it into the debug buffer so /gse showdebugoutput shows it.
  GSE.DebugOutput = report .. "\n"
  pcall(StaticPopup_Show, "GS-DebugOutput")
  return report
end

function GSE.ShowErrorLog()
  local buf = {}
  buf[#buf + 1] = "==== GSE captured error log ===="
  if type(GSEOptions) == "table" and type(GSEOptions.ErrorLog) == "table" and #GSEOptions.ErrorLog > 0 then
    for _, e in ipairs(GSEOptions.ErrorLog) do
      buf[#buf + 1] = tostring(e)
    end
  else
    buf[#buf + 1] = "(no errors captured this session)"
  end
  local text = table.concat(buf, "\n")
  GSE.DebugOutput = text .. "\n"
  GSE.Print("GSE captured " .. ((type(GSEOptions) == "table" and type(GSEOptions.ErrorLog) == "table") and #GSEOptions.ErrorLog or 0) .. " error(s). Showing them now; also in SavedVariables (GSEOptions.ErrorLog).")
  pcall(StaticPopup_Show, "GS-DebugOutput")
  return text
end

--- Clears the persisted error log.
function GSE.ClearErrorLog()
  if type(GSEOptions) == "table" then
    GSEOptions.ErrorLog = {}
  end
  GSE.Print("GSE error log cleared.")
end

GSE.DiagnosticsAvailable = true
