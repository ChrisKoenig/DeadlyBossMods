---@class DBMTest
local test = DBM.Test

local nilValue = newproxy(false)

---@class DBMTestMocks
local mocks = {}
test.Mocks = mocks

local fakeCLEUArgs = {
	-- Number of args to handle nil values gracefully
	n = nil
}
function mocks.CombatLogGetCurrentEventInfo()
	if fakeCLEUArgs.n then
		return unpack(fakeCLEUArgs, 1, fakeCLEUArgs.n)
	else
		return CombatLogGetCurrentEventInfo()
	end
end

function mocks:SetFakeCLEUArgs(mockPlayerName, ...)
	table.wipe(fakeCLEUArgs)
	fakeCLEUArgs.n = 0
	for i = 1, select("#", ...) do
		-- Add missing args, see transcribeCleu() in ParseTranscriptor
		if fakeCLEUArgs.n == 0 then
			fakeCLEUArgs.n = fakeCLEUArgs.n + 1
			fakeCLEUArgs[fakeCLEUArgs.n] = self:GetTime()
		elseif fakeCLEUArgs.n == 2 then
			fakeCLEUArgs.n = fakeCLEUArgs.n + 1
			fakeCLEUArgs[fakeCLEUArgs.n] = false -- hideCaster
		end
		fakeCLEUArgs.n = fakeCLEUArgs.n + 1
		fakeCLEUArgs[fakeCLEUArgs.n] = select(i, ...)
	end
	if fakeCLEUArgs[5] == mockPlayerName then
		fakeCLEUArgs[4] = UnitGUID("player")
		fakeCLEUArgs[5] = UnitName("player")
	end
	if fakeCLEUArgs[9] == mockPlayerName then
		fakeCLEUArgs[8] = UnitGUID("player")
		fakeCLEUArgs[0] = UnitName("player")
	end
end

---@type InstanceInfo
local fakeInstanceInfo
function mocks.GetInstanceInfo()
	if fakeInstanceInfo then
		return fakeInstanceInfo.name, fakeInstanceInfo.instanceType, fakeInstanceInfo.difficultyID,
			fakeInstanceInfo.difficultyName, fakeInstanceInfo.maxPlayers, fakeInstanceInfo.dynamicDifficulty,
			fakeInstanceInfo.isDynamic, fakeInstanceInfo.instanceID, fakeInstanceInfo.instanceGroupSize,
			fakeInstanceInfo.lfgDungeonID
	else
		return GetInstanceInfo()
	end
end

---@param instanceInfo InstanceInfo
function mocks:SetInstanceInfo(instanceInfo)
	fakeInstanceInfo = instanceInfo
	test:HookPrivate("LastInstanceMapID", instanceInfo.instanceID)
end

local fakeIsEncounterInProgress
function mocks.IsEncounterInProgress()
	return fakeIsEncounterInProgress
end

function mocks:SetEncounterInProgress(value)
	fakeIsEncounterInProgress = value
end

function mocks.AntiSpam(mod, time, id)
	-- Mods often define AntiSpam timeouts in whole seconds and some periodic damage effects trigger exactly every second
	-- This can lead to flaky tests as they sometimes trigger and sometimes don't because even with fake time there is unfortunately still some dependency on actual frame timings
	-- Just subtracting 0.1 seconds fixes this problem; an example affected by this is SoD/ST/FesteringRotslime
	if time and time > 0 and math.floor(time) == time then
		time = time - 0.1
	end
	return DBM.AntiSpam(mod, time, id)
end

-- TODO: mocking the whole "raid" local in DBM would increase coverage a bit
function mocks.DBMGetRaidUnitId(_, name)
	return "fakeunitid-name-" .. name
end

local bosses = {}
function mocks.DBMGetUnitIdFromGUID(_, guid, scanOnlyBoss)
	return bosses[guid] and bosses[guid].uId or not scanOnlyBoss and "fakeunitid-guid-" .. guid
end

function mocks:UpdateBoss(uId, name, guid, canAttack, exists, visible)
	local boss = {uId = uId, name = name, guid = guid, canAttack = canAttack, exists = exists, visible = visible}
	bosses[guid] = boss
	bosses[uId] = boss
end

local unitTargets = {}
function mocks:UpdateTarget(uId, name, target)
	unitTargets["fakeunit-name" .. name] = target
	unitTargets[uId] = target
end

function mocks.DBMGetUnitFullName(_, uId)
	if not uId then return end
	local base = uId:match("(.-)target$")
	if base then
		return unitTargets[base]
	end
	local fromFakeId = uId:match("fakeunitid%-name%-(.*)")
	return fromFakeId or bosses[uId] and bosses[uId].name
end

local function parseFakeUnit(id)
	return {
		unitId = not id:match("^fakeunitd") and id,
		name = id:match("^fakeunitid%-name%-(.*)") or UnitName(id),
		guid = id:match("^fakeunitid%-guid%-(.*)") or UnitGUID(id),
	}
end

-- Stores timestamps of when someone had aggro
local threatInfo = {}
function mocks.UnitDetailedThreatSituation(playerUid, enemyUid)
	local player = parseFakeUnit(playerUid)
	local enemy = parseFakeUnit(enemyUid)
	if not enemy.name and not enemy.guid then return end
	if not player.name and not player.guid then return end
	local tanks = threatInfo[enemy.name or enemy.guid]
	-- Enemy unknown or player was never tanking it
	if not tanks or not tanks.names[player.name] and not tanks.guids[player.guid] then
		return false, nil, 0, 0, 0
	end
	local sortedTanks = {}
	for name, time in pairs(tanks.names) do
		sortedTanks[#sortedTanks + 1] = {time = time, name = name}
	end
	for guid, time in pairs(tanks.guids) do
		sortedTanks[#sortedTanks + 1] = {time = time, guid = guid}
	end
	table.sort(sortedTanks, function(e1, e2) return e1.time < e2.time end)
	local lastTank = sortedTanks[#sortedTanks]
	-- Latest target is "securely tanking" (status 3), no matter how stale that information is
	if lastTank.name == player.name or lastTank.guid == player.guid then
		return true, 3, 100, 100, 1000
	end
	-- Was previously tanking, so high threat but not target
	return true, 1, 99, 99, 990
end

function mocks:SetThreat(playerGuid, playerName, enemyGuid, enemyName)
	threatInfo[enemyName] = threatInfo[enemyName] or {names = {}, guids = {}}
	threatInfo[enemyName].names[playerName] = self:GetTime()
	threatInfo[enemyName].guids[playerGuid] = self:GetTime()
	threatInfo[enemyGuid] = threatInfo[enemyGuid] or {names = {}, guids = {}}
	threatInfo[enemyGuid].names[playerName] = self:GetTime()
	threatInfo[enemyGuid].guids[playerGuid] = self:GetTime()
end

function mocks.DBMNumRealAlivePlayers()
	return fakeInstanceInfo.instanceGroupSize or 10
end

local unitsInCombat = {}
function mocks.UnitAffectingCombat(unit)
	return unitsInCombat[unit]
end

function mocks:SetUnitAffectingCombat(unit, unitName, unitGuid, inCombat)
	if unit then
		unitsInCombat[unit] = inCombat
	end
	if unitGuid then
		unitsInCombat[DBM:GetUnitIdFromGUID(unitGuid)] = inCombat
	end
	if unitName then
		unitsInCombat[DBM:GetRaidUnitId(unitName)] = inCombat
	end
end

local unitAuras = {}
local function checkUnitAura(auraType, uId, spellInput1, spellInput2, spellInput3, spellInput4, spellInput5)
	if not unitAuras[uId] then
		return
	end
	return unitAuras[uId][spellInput1] and (unitAuras[uId][spellInput1].auraType == auraType or not auraType) and unitAuras[uId][spellInput1].spellName
		or unitAuras[uId][spellInput2] and (unitAuras[uId][spellInput2].auraType == auraType or not auraType) and unitAuras[uId][spellInput2].spellName
		or unitAuras[uId][spellInput3] and (unitAuras[uId][spellInput3].auraType == auraType or not auraType) and unitAuras[uId][spellInput3].spellName
		or unitAuras[uId][spellInput4] and (unitAuras[uId][spellInput4].auraType == auraType or not auraType) and unitAuras[uId][spellInput4].spellName
		or unitAuras[uId][spellInput5] and (unitAuras[uId][spellInput5].auraType == auraType or not auraType) and unitAuras[uId][spellInput5].spellName
end

function mocks.DBMUnitDebuff(_, ...)
	return checkUnitAura("DEBUFF", ...)
end

function mocks.DBMUnitBuff(_, ...)
	return checkUnitAura("BUFF", ...)
end

function mocks.DBMUnitAura(_, ...)
	return checkUnitAura(nil, ...)
end

function mocks:ApplyUnitAura(name, guid, spellId, spellName, auraType, amount)
	local uId = DBM:GetRaidUnitId(name)
	local uIdbyGuid = DBM:GetUnitIdFromGUID(guid)
	local auras = unitAuras[uId] or {}
	unitAuras[uId] = auras
	unitAuras[uIdbyGuid] = auras
	if guid == UnitGUID("player") then
		unitAuras["player"] = auras
	end
	local entry = auras[spellId] or auras[spellName] or {
		spellId = spellId,
		spellName = spellName,
	}
	auras[spellId] = entry
	auras[spellName] = entry
	entry.time = self:GetTime()
	entry.auraType = auraType
	entry.amount = amount or entry.amount
end

function mocks:RemoveUnitAura(name, guid, spellId, spellName)
	local uId = DBM:GetRaidUnitId(name)
	local uIdbyGuid = DBM:GetUnitIdFromGUID(guid)
	local auras = unitAuras[uId] or {}
	unitAuras[uId] = auras
	unitAuras[uIdbyGuid] = auras
	if guid == UnitGUID("player") then
		unitAuras["player"] = auras
	end
	auras[spellId] = nil
	auras[spellName] = nil
end

function test:HookModVar(mod, key, val)
	self.restoreModVariables = self.restoreModVariables or {}
	self.restoreModVariables[mod] = self.restoreModVariables[mod] or {}
	local old = mod[key]
	if old == nil then
		old = nilValue
	end
	self.restoreModVariables[mod][key] = old
	mod[key] = val
end

function test:HookDbmVar(key, val)
	self.restoreDbmVariables = self.restoreDbmVariables or {}
	local old = DBM[key]
	if old == nil then
		old = nilValue
	end
	self.restoreDbmVariables[key] = old
	DBM[key] = val
end

function test:SetupHooks(modUnderTest)
	self:HookPrivate("CombatLogGetCurrentEventInfo", mocks.CombatLogGetCurrentEventInfo)
	self:HookPrivate("GetInstanceInfo", mocks.GetInstanceInfo)
	mocks:SetEncounterInProgress(false)
	self:HookPrivate("IsEncounterInProgress", mocks.IsEncounterInProgress)
	self:HookPrivate("UnitDetailedThreatSituation", mocks.UnitDetailedThreatSituation)
	table.wipe(threatInfo)
	self:HookPrivate("UnitAffectingCombat", mocks.UnitAffectingCombat)
	table.wipe(unitsInCombat)
	self:HookModVar(modUnderTest, "AntiSpam", mocks.AntiSpam)
	mocks.GetTime = function() return self.timeWarper and self.timeWarper:GetTime() or GetTime() end
	self:HookModVar(modUnderTest, "GetTime", mocks.GetTime)
	self:HookDbmVar("GetRaidUnitId", mocks.DBMGetRaidUnitId)
	self:HookDbmVar("GetUnitIdFromGUID", mocks.DBMGetUnitIdFromGUID)
	self:HookDbmVar("NumRealAlivePlayers", mocks.DBMNumRealAlivePlayers)
	self:HookDbmVar("UnitBuff", mocks.DBMUnitBuff)
	self:HookDbmVar("UnitDebuff", mocks.DBMUnitDebuff)
	self:HookDbmVar("UnitAura", mocks.DBMUnitAura)
	self:HookDbmVar("GetUnitFullName", mocks.DBMGetUnitFullName)
	table.wipe(bosses)
	table.wipe(unitTargets)
	table.wipe(unitAuras)
end

function test:TeardownHooks()
	self:UnhookPrivates()
	for _, mod in ipairs(DBM.Mods) do
		if self.restoreModVariables[mod] then
			for k, v in pairs(self.restoreModVariables[mod]) do
				if v == nilValue then
					mod[k] = nil
				else
					mod[k] = v
				end
			end
		end
		self.restoreModVariables[mod] = nil
	end
	if self.restoreDbmVariables then
		for k, v in pairs(self.restoreDbmVariables) do
			if v == nilValue then
				DBM[k] = nil
			else
				DBM[k] = v
			end
		end
	end
end
