---@class DBMCoreNamespace
local private = select(2, ...)

---@class TrashCombatScanningModule: DBMModule
local module = private:NewModule("TrashCombatScanningModule")

---@class DBM
local DBM = private:GetPrototype("DBM")
---@class DBMMod
local bossModPrototype = private:GetPrototype("DBMMod")

local registeredZones = {}--Global table for tracking registered zones
local registeredCombat = {}--Tracks when modules should use return callback for just detecting combat
local registeredCIDs = {}
local ActiveGUIDs = {}--GUIDS we're flagged in combat with
local inCombat = false

--This will not be used in raids, so no raid targets checked
local scannedUids = {
	"mouseover", "target", "focus", "focustarget", "targettarget", "mouseovertarget",
	"party1target", "party2target", "party3target", "party4target",
	"nameplate1", "nameplate2", "nameplate3", "nameplate4", "nameplate5", "nameplate6", "nameplate7", "nameplate8", "nameplate9", "nameplate10",
	"nameplate11", "nameplate12", "nameplate13", "nameplate14", "nameplate15", "nameplate16", "nameplate17", "nameplate18", "nameplate19", "nameplate20",
	"nameplate21", "nameplate22", "nameplate23", "nameplate24", "nameplate25", "nameplate26", "nameplate27", "nameplate28", "nameplate29", "nameplate30",
	"nameplate31", "nameplate32", "nameplate33", "nameplate34", "nameplate35", "nameplate36", "nameplate37", "nameplate38", "nameplate39", "nameplate40"
}

---Scan for new Unit Engages
---<br>This will break if more than one mod is scanning nameplates at once, which shouldn't happen since you can't be in more than one dungeon at same time
---@param self DBMMod
local function ScanEngagedUnits(self)
	--Scan for new Unit Engages
	for _, unitId in ipairs(scannedUids) do
		if UnitAffectingCombat(unitId) then
			local guid = UnitGUID(unitId)
			if guid and DBM:IsCreatureGUID(guid) then
				if not ActiveGUIDs[guid] then
					ActiveGUIDs[guid] = true
					local cid = DBM:GetCIDFromGUID(guid)
					if self.StartNameplateTimers and registeredCIDs[cid] then
						self:StartNameplateTimers(guid, cid)
						DBM:Debug("Firing Engaged Unit for "..cid, 3, nil, true)
					end
				end
			end
		end
	end
	--Only run once per second, and then just subtract 1 from all initial timers
	--Don't want to waste too much cpu and a timer being up to 1 second off isn't a big deal
	DBM:Schedule(1, ScanEngagedUnits)
end

--Still a stupid waste of CPU because blizzard can't bother to give us an event for the GROUP entering combat
--PLAYER_REGEN is useless for tracking group combat, as it's only player combat
local function checkForCombat()
	local combatFound = DBM:GroupInCombat()
	if combatFound and not inCombat then
		inCombat = true
		DBM:Debug("Zone Combat Detected", 2)
		for modId, _ in pairs(registeredCombat) do
			local mod = DBM:GetModByName(modId)
			if mod then
				if mod.EnteringZoneCombat then
					mod:EnteringZoneCombat()
				end
				if mod.StartNameplateTimers then
					ScanEngagedUnits(mod)
					DBM:Debug("Starting Engaged Unit Scans", 2)
				end
			end
		end
	elseif not combatFound and inCombat then
		inCombat = false
		table.wipe(ActiveGUIDs)--if no one is in combat, save to assume all engaged units gone
		DBM:Debug("Zone Combat Ended", 2)
		for modId, _ in pairs(registeredCombat) do
			local mod = DBM:GetModByName(modId)
			if mod and mod.LeavingZoneCombat then
				mod:LeavingZoneCombat()
			end
		end
		DBM:Unschedule(ScanEngagedUnits)
	end
	--This is a more frequent scanner since it's already been thoroughly tested in M+ affix mods for a year and a half now without any performance detrimate since it's only checking 5 units for combat
	DBM:Schedule(0.25, checkForCombat)
end

do
	local eventsRegistered = false
	local function DelayedZoneCheck(force)
		local currentZone = DBM:GetCurrentArea() or 0
		if not force and registeredZones[currentZone] and not eventsRegistered then
			eventsRegistered = true
			checkForCombat()
			DBM:Debug("Registering Dungeon Trash Tracking Events")
		elseif force or (not registeredZones[currentZone] and eventsRegistered) then
			eventsRegistered = false
			table.wipe(ActiveGUIDs)
			DBM:Unschedule(checkForCombat)
			DBM:Unschedule(ScanEngagedUnits)
			DBM:Debug("Unregistering Dungeon Trash Tracking Events")
		end
	end
	function module:LOADING_SCREEN_DISABLED()
		DBM:Unschedule(DelayedZoneCheck)
		--Checks Delayed 1 second after core checks to prevent race condition of checking before core did and updated cached ID
		DBM:Schedule(2, DelayedZoneCheck)
		DBM:Schedule(6, DelayedZoneCheck)
	end
	module.OnModuleLoad = module.LOADING_SCREEN_DISABLED
	module.ZONE_CHANGED_NEW_AREA	= module.LOADING_SCREEN_DISABLED

	function module:CHALLENGE_MODE_COMPLETED()
		--This basically force unloads things even when in a dungeon, so it's not scanning trash that doesn't fight back
		DelayedZoneCheck(true)
	end
end

---Used for registering combat with trash in general for use of notifying affixes mod that party is in combat
---@param zone number Instance ID of the zone
---@param CIDTable table? A table of CIDs to register for engaged unit scanning
function bossModPrototype:RegisterTrashCombat(zone, CIDTable)
	if DBM.Options.NoCombatScanningFeatures then return end
	if not registeredZones[zone] then
		registeredZones[zone] = true
	end
	if not registeredCombat[self.modId] then
		registeredCombat[self.modId] = true
		DBM:Debug("Registered Trash Combat for modID: "..self.modId, 2)
	end
	if CIDTable then
		for i = 1, #CIDTable do
			registeredCIDs[CIDTable[i]] = true
		end
	end
end
