local GSE = GSE
local L = GSE.L

local Statics = GSE.Static
local GetSpecialization=GetSpecialization or GSE.GetCurrentSpecID
if not GetSpecialization then
	GetSpecialization=GSE.GetCurrentSpecID
end
--- Return the characters current spec id
function GSE.GetSpecialization()
return GSE.GetCurrentSpecID()
end
function GSE.GetCurrentSpecID()
--local  name, iconTexture, pointsSpent, background, previewPointsSpent = GetTalentTabInfo(tabIndex[, inspect[, isPet]][, talentGroup])
-- if event == "INSPECT_READY" then
  -- local spec = ""
  -- _, name = GetTalentTabInfo(GetPrimaryTalentTree(GetActiveTalentGroup()))
  -- spec = name
  -- return spec
-- else
  -- NotifyInspect(unit)
-- end
 -- local currentSpec = GetSpecialization() --local index = GetActiveTalentGroup(isInspect, isPet);
  --return currentSpec and select(1, GetSpecializationInfo(currentSpec)) or 0 ---specid Statics.wotlkSpecIDList 

--local name, icon, pointsSpent, background, previewPointsSpent = GetTalentTabInfo(tab,isInspect,isPet,activeSpec);


  local activeSpec = GetActiveTalentGroup()
local maxpointspents=0
local  primarytree=0
----print(GetTalentTabInfo(activeTalentGroup))
-- Guard every talent API: on classless / custom-talent servers (eg Conquest of
-- Azeroth) GetNumTalentTabs() and GetTalentTabInfo() can return nil.  An
-- unguarded nil as the numeric 'for' limit would raise a hard error here.
local numTalentTabs = tonumber(GetNumTalentTabs()) or 0
for tab = 1, numTalentTabs do
   local tabname, tabicon, nopointsSpent, tabbackground, tabpreviewPointsSpent = GetTalentTabInfo(tab,false,false,activeSpec)
   nopointsSpent = tonumber(nopointsSpent) or 0
   if (nopointsSpent>maxpointspents) then
      maxpointspents=nopointsSpent
      primarytree=tab
   end
   if (primarytree==0) then
      primarytree=1
   end
end

	local name1,icon
	if primarytree > 0 then
		name1,icon=GetTalentTabInfo(primarytree,false,false,activeSpec)
	end
	if name1 then
		name1=string.upper(name1)
	else
		name1 = ""
	end
  local specid;

	  for k,v in pairs(Statics.wotlkSpecIDList) do

		local searchStr = v and string.upper(v) or ""
		-- plain=true (4th arg) so custom talent/class names containing Lua magic
		-- pattern characters (eg -, (, ), +) are matched literally, not as patterns.
		local st,ed=string.find(searchStr,name1,1,true)
		local isClass,isClass1=UnitClass("player")
		isClass = isClass and string.upper(isClass) or ""
		isClass1 = isClass1 and string.upper(isClass1) or ""
		local st1,ed1 = isClass ~= "" and string.find(searchStr,isClass,1,true) or nil
		local st2,ed2 = isClass1 ~= "" and string.find(searchStr,isClass1,1,true) or nil
			if(st~=nil) then 
				if(st1~=nil or st2~=nil) then 
					specid=k 
				end	
			end
	  end
  return specid,name1,icon;
end

-- Standard WoW class tokens -> their classic class file ids.  Used so that when
-- we merge the client's reported class roster we keep the original 10-12 classes
-- at their well-known ids (cross-realm / standard-realm compatibility).
local STANDARD_CLASS_TOKENS = {
  WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5, DEATHKNIGHT = 6,
  SHAMAN = 7, MAGE = 8, WARLOCK = 9, MONK = 10, DRUID = 11, DEMONHUNTER = 12,
}

-- token -> class id for whatever classes THIS client reports (populated below).
GSE.ClassTokenToID = GSE.ClassTokenToID or {}

--- Merge the classes the running client actually exposes (via the standard
--  FrameXML globals CLASS_SORT_ORDER / LOCALIZED_CLASS_NAMES_MALE) into the
--  class/spec tables.  Custom Ascension realms (eg Conquest of Azeroth) list
--  their full roster there.  Standard classes keep their original ids; custom
--  classes get a collision-free synthesised id (>1000, well clear of the
--  hardcoded class ids 0-12 and spec ids 62-267).  The original hardcoded
--  entries are never removed, so standard/other realms are unaffected.
function GSE.BuildDynamicClassList()
  if type(CLASS_SORT_ORDER) ~= "table" then
    return
  end
  local names = (type(LOCALIZED_CLASS_NAMES_MALE) == "table") and LOCALIZED_CLASS_NAMES_MALE or {}
  for index, token in ipairs(CLASS_SORT_ORDER) do
    if type(token) == "string" then
      local standardID = STANDARD_CLASS_TOKENS[token]
      if standardID then
        -- Keep the hardcoded entry; just record the token -> id mapping so class
        -- detection works from the token directly.
        GSE.ClassTokenToID[token] = standardID
      else
        local id = 1000 + index
        local name = names[token] or token
        GSE.ClassTokenToID[token] = id
        if GSE.isEmpty(Statics.wotlkClassIDList[id]) then
          Statics.wotlkClassIDList[id] = name
        end
        if GSE.isEmpty(Statics.wotlkSpecIDList[id]) then
          Statics.wotlkSpecIDList[id] = name
        end
        if GSE.isEmpty(Statics.SpecIDHashList[name]) then
          Statics.SpecIDHashList[name] = id
        end
      end
    end
  end
end

--- Return the characters class id
function GSE.GetCurrentClassID()
  --local _, _, currentclassId = UnitClass("player")--classDisplayName, class, classID = UnitClass("unit");
  local class1, class = UnitClass("player")
  -- Prefer the dynamic token map (covers this client's custom classes as well as
  -- the standard ones).  This is how a Conquest of Azeroth character resolves to
  -- its own class bucket instead of collapsing to Global.
  if class and GSE.ClassTokenToID[class] then
    return GSE.ClassTokenToID[class]
  end
  -- Default to 0 (Global) rather than "".  On custom realms UnitClass can return
  -- a token that is not in the hardcoded WotLK list, or even nil.  Returning ""
  -- here previously poisoned GSELibrary[""] and broke every downstream lookup;
  -- 0/Global is the safe fallback the rest of the addon already understands.
  local currentclassId1 = 0
  local uclass = class and string.upper(class) or ""
  local uclass1 = class1 and string.upper(class1) or ""
  if uclass ~= "" or uclass1 ~= "" then
    for k,v in pairs(Statics.wotlkClassIDList) do
      local uv = string.upper(v)
      if (uv == uclass or uv == uclass1) then
        currentclassId1 = k
      end
    end
  end
 -- DEFAULT_CHAT_FRAME:AddMessage("currentclassId1 "..currentclassId1)
  return currentclassId1
end

--- Return the characters class id
function GSE.GetCurrentClassNormalisedName()
  --local _, classnormalisedname, _ = UnitClass("player")--classDisplayName, class, classID = UnitClass("unit");
  local _, classnormalisedname = UnitClass("player")--classDisplayName, class, classID = UnitClass("unit");
  -- UnitClass can return nil for a custom class token; never string.upper(nil).
  return classnormalisedname and string.upper(classnormalisedname) or ""
end

function GSE.GetClassIDforSpec(specid)
  --local id, name, description, icon, role, class = GetSpecializationInfoByID(specid)
--classid
	local value,classid,class;
	for k,v in pairs(Statics.wotlkClassIDList) do
		if (k==specid) then 
			classid=k  
		end
	end
  
  for k,v in pairs(Statics.wotlkSpecIDList) do
	if (k==specid) then
		--value=Statics.wotlkSpecIDList[specID]
		-- plain=true: " - " must be matched literally.  As a Lua pattern the
		-- "-" is a lazy quantifier, so the old string.find(v," - ") never
		-- matched "Arcane - Mage" and this function silently failed to derive
		-- the class from a spec name.
		local idx=string.find(v," - ",1,true)
		if(idx~=nil) then
			class=string.sub(v,idx+3)
		end
		--print(v,last,last[#last])
	    --local class=string.upper(last[#last])
		for k1,v1 in pairs(Statics.wotlkClassIDList) do
			if (string.upper(v1)==string.upper(class)) then 
			classid=k1  
			end
		end
	end
  end
	--local last = string.split( value, "% " )
	--local class=string.upper(last[#last])

  
  -- local classid = 0
  -- if specid <= 12 then
    -- classid = specid
  -- else
    -- for i=1, 12, 1 do
    -- local cdn, st, cid = GetClassInfo(i)--classDisplayName, classTag, classID = GetClassInfo(index)

	 -- st=string.upper(st)
      -- if class == st then
        -- classid = i
      -- end
    -- end
  -- end
   return classid
end

function GSE.GetClassIcon(classid)
  local classicon = {}
  -- classicon[1] = "Interface\\Icons\\inv_sword_27" -- Warrior
  -- classicon[2] = "Interface\\Icons\\ability_thunderbolt" -- Paladin
  -- classicon[3] = "Interface\\Icons\\inv_weapon_bow_07" -- Hunter
  -- classicon[4] = "Interface\\Icons\\inv_throwingknife_04" -- Rogue
  -- classicon[5] = "Interface\\Icons\\inv_staff_30" -- Priest
  -- classicon[6] = "Interface\\Icons\\inv_sword_27" -- Death Knight
  -- classicon[7] = "Interface\\Icons\\inv_jewelry_talisman_04" -- SWhaman
  -- classicon[8] = "Interface\\Icons\\inv_staff_13" -- Mage
  -- classicon[9] = "Interface\\Icons\\spell_nature_drowsy" -- Warlock
 -- classicon[10] = "Interface\\Icons\\Spell_Holy_FistOfJustice" -- Monk
  -- classicon[11] = "Interface\\Icons\\inv_misc_monsterclaw_04" -- Druid
 --classicon[12] = "Interface\\Icons\\INV_Weapon_Glave_01" -- DEMONHUNTER

	
	
   classicon[1] = "Interface\\Icons\\inv_sword_27" -- Warrior
  classicon[2] = "Interface\\Icons\\ability_thunderbolt" -- Paladin
  classicon[3] = "Interface\\Icons\\inv_weapon_bow_07" -- Hunter
  classicon[4] = "Interface\\Icons\\inv_throwingknife_04" -- Rogue
  classicon[5] = "Interface\\Icons\\INV_Staff_30" -- Priest
  classicon[6] = "Interface\\Icons\\Spell_Deathknight_ClassIcon" -- Death Knight
  classicon[7] = "Interface\\Icons\\Spell_Nature_BloodLust" -- SWhaman
  classicon[8] = "Interface\\Icons\\INV_Staff_13" -- Mage
  classicon[9] = "Interface\\Icons\\Spell_Nature_FaerieFire" -- Warlock
	classicon[10] = "Interface\\Icons\\INV_Misc_MonsterClaw_04" -- Monk
  classicon[11] = "Interface\\Icons\\INV_Misc_MonsterClaw_04" -- Druid
	classicon[12] = "Interface\\Icons\\inv_weapon_bow_07" -- DEMONHUNTER
  return classicon[classid]

end

--- Check if the specID provided matches the plauers current class.
function GSE.isSpecIDForCurrentClass(specID)
for k,v in pairs(Statics.wotlkSpecIDList) do
	if (k==specID) then 
		local value=Statics.wotlkSpecIDList[specID]
		if value then
			local last = string.split( value, "% " )
	    local class=string.upper(last[#last])
		local currentenglishclass, currentclassDisplayName = UnitClass("player")
		
		currentenglishclass=string.upper(currentenglishclass)
		local currentclassId=string.upper(currentclassDisplayName)
		
		for k1,v1 in pairs(Statics.wotlkClassIDList) do
			if (string.upper(v1)==string.upper(class)) then currentclassId=k1 end
		end
		
		return (class==currentenglishclass or specID==currentclassId)
		end
	end
 end
  return false
end


function GSE.GetSpecNames()
  local keyset={}
  for k,v in pairs(Statics.wotlkSpecIDList) do
    keyset[v] = v
  end
  return keyset
end

--- Returns the Character Name in the form Player@server
function GSE.GetCharacterName()
  return  GetUnitName("player", true) .. '@' .. GetRealmName()
end

--- Returns the current Talent Selections as a string
function GSE.GetCurrentTalents()
  local talents = ""
    for talentTier = 1, 7 do
  --for talentTier = 1, MAX_TALENT_TIERS do
    --local available, selected = GetTalentTierInfo(talentTier, 1)
   -- talents = talents .. (available and selected or "?" .. ",")
   talents = talents .. ("?" .. ",")
  end
  return talents
end


--- Experimental attempt to load a WeakAuras string.
function GSE.LoadWeakauras(str)
  local WeakAuras = WeakAuras

  if WeakAuras then
    WeakAuras.ImportString(str)
  end
end

-- Merge the client's class roster once at load.  pcall-guarded so an unexpected
-- CLASS_SORT_ORDER shape on some client can never abort loading this file.
pcall(GSE.BuildDynamicClassList)
