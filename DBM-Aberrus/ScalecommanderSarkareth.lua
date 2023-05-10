local mod	= DBM:NewMod(2520, "DBM-Aberrus", nil, 1208)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("@file-date-integer@")
mod:SetCreatureID(203284)
mod:SetEncounterID(2685)
mod:SetUsedIcons(1, 2, 3, 4, 5, 6, 7, 8)
mod:SetHotfixNoticeRev(20230509000000)
--mod:SetMinSyncRevision(20221215000000)
--mod.respawnTime = 29

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_CAST_START 401383 401810 401500 401642 402050 401325 404027 404456 404769 411302 404754 404403 411030 407496 404288 411236 403771 405022 403625 403517 408422 401704",
--	"SPELL_CAST_SUCCESS",
	"SPELL_SUMMON 404505 404507",
	"SPELL_AURA_APPLIED 401951 401215 403997 407576 401905 401680 401330 404218 404705 407496 404288 411241 405486 403520 408429 403284 410654 410625",
	"SPELL_AURA_APPLIED_DOSE 401951 403997 407576 401330 404269 411241 408429",
	"SPELL_AURA_REMOVED 401951 401680 401330 404218 404705 407496 404288 404269 411241 403520 408429 401215 405486 410654 410625",
	"SPELL_AURA_REMOVED_DOSE 401951",
	"SPELL_PERIODIC_DAMAGE 406989",
	"SPELL_PERIODIC_MISSED 406989",
	"UNIT_DIED"
--	"UNIT_SPELLCAST_SUCCEEDED boss1"
)

--NOTE, next to no chance Mass Disteingratem Infinite Duress, and Hurtling target debuffs stay public auras by time fight is reached on mythic. Both have incoming debuff alerts out the gate
--TODO, timer track https://www.wowhead.com/ptr/spell=410247/echoing-howl ? I suspect most would ignore DBM anyways and just have a WA for this
--TODO, better handle triple breath stuff if it's incorrect
--TODO, drifting embers spawn count, if it's periodic spawn and not constant anyways https://www.wowhead.com/ptr/spell=402746/drifting-embers
--TODO, what kind of warning for flowers? Dodge for now but may be wrong
--TODO, track https://www.wowhead.com/ptr/spell=404269/ebon-might stacks? or is nameplate aura at 5 stacks enough?
--TODO, old void claws used on lfr/normal? https://www.wowhead.com/ptr/spell=403364/void-claws and 403358
--TODO, clearer understanding of Hurtling Barrage is needed (how many, how many targets, etc). Also if the target aura is hidden or not
--TODO, add incoming alert for nothingness if debuff target aura is hidden
--[[
(ability.id = 401383 or ability.id = 401810 or ability.id = 401500 or ability.id = 401642 or ability.id = 402050 or ability.id = 401325 or ability.id = 404027 or ability.id = 404456 or ability.id = 404769 or ability.id = 411302 or ability.id = 404754 or ability.id = 404403 or ability.id = 411030 or ability.id = 407496 or ability.id = 404288 or ability.id = 411236 or ability.id = 403771 or ability.id = 405022 or ability.id = 403625 or ability.id = 408422 or ability.id = 401704) and type = "begincast"
 or ability.id = 403517 and type = "cast"
 or (ability.id = 403284 or ability.id = 410654) and (type = "applybuff" or type = "removebuff")
 or (ability.id = 404505 or ability.id = 404507) and type = "summon"
 or ability.id = 410625
 or (ability.id = 401383 or ability.id = 401215 or ability.id = 403997 or ability.id = 407576 or ability.id = 401905 or ability.id = 401680 or ability.id = 401330 or ability.id = 404218 or ability.id = 404705 or ability.id = 407496 or ability.id = 404288 or ability.id = 411241 or ability.id = 405486 or ability.id = 403520 or ability.id = 408429) and type = "applydebuff"
--]]
--General
local warnOblivionStack						= mod:NewCountAnnounce(401951, 2, nil, nil, DBM_CORE_L.AUTO_ANNOUNCE_OPTIONS.stack:format(401951))
local warnMindFragment						= mod:NewAddsLeftAnnounce(403997, 1)--Not technically adds, but wording of option and alert text is ambigious that it doesn't matter, it fits
local warnEmptynessBetweenStars				= mod:NewFadesAnnounce(401215, 1)
local warnAstralFlare						= mod:NewCountAnnounce(407576, 1, nil, false, DBM_CORE_L.AUTO_ANNOUNCE_OPTIONS.stack:format(407576))--Optional, don't want it to drown out the important messages of collecting mind fragments

local specWarnOblivionStack					= mod:NewSpecialWarningStack(401951, nil, 12, nil, nil, 1, 6)
local specWarnEmptynessBetweenStars			= mod:NewSpecialWarningYou(401215, nil, nil, nil, 1, 2)
local specWarnGTFO							= mod:NewSpecialWarningGTFO(406989, nil, nil, nil, 1, 8)

local timerPhaseCD							= mod:NewPhaseTimer(30)
local timerEmptynessBetweenStars			= mod:NewBuffFadesTimer(15, 401215, nil, nil, nil, 3)
--local berserkTimer							= mod:NewBerserkTimer(600)

mod:AddInfoFrameOption(401951, false)
mod:AddMiscLine(DBM_CORE_L.OPTION_CATEGORY_DROPDOWNS)
mod:AddDropdownOption("InfoFrameBehaviorTwo", {"OblivionOnly", "HowlOnly", "Hybrid"}, "OblivionOnly", "misc")
--Stage One: The Legacy of the Dracthyr
mod:AddTimerLine(DBM:EJ_GetSectionInfo(26140))
local warnOppressingHowl						= mod:NewCountAnnounce(401383, 3)
local warnDazzled								= mod:NewTargetNoFilterAnnounce(401905, 4, nil, false)--Not entirely much you can do about it's a lot but if it's a couple, a healer might want to see this to TRY and save them
local warnMassDisintegrate						= mod:NewTargetCountAnnounce(401642, 3, nil, nil, nil, nil, nil, nil, true)
local warnBurningClaws							= mod:NewStackAnnounce(401325, 2, nil, "Tank|Healer")

local specWarnGlitteringSurge					= mod:NewSpecialWarningCount(401810, nil, nil, nil, 2, 2)
local specWarnScorchingBomb						= mod:NewSpecialWarningCount(401500, nil, nil, nil, 2, 2)
local specWarnMassDisintegrate					= mod:NewSpecialWarningIncomingCount(401642, nil, nil, nil, 1, 14)
local specWarnMassDisintegrateYou				= mod:NewSpecialWarningYou(401642, nil, nil, nil, 1, 2)
local yellMassDisintegrate						= mod:NewShortPosYell(401642)
local yellMassDisintegrateFades					= mod:NewIconFadesYell(401642)
local specWarnSearingBreath						= mod:NewSpecialWarningCount(402050, nil, nil, nil, 2, 2)
--local specWarnDriftingEmbers					= mod:NewSpecialWarningDodgeCount(402746, nil, nil, nil, 2, 2)
local specWarnBurningClaws						= mod:NewSpecialWarningDefensive(401325, nil, nil, nil, 1, 2)
local specWarnBurningClawsTaunt					= mod:NewSpecialWarningTaunt(401325, nil, nil, nil, 1, 2)

local timerOppressingHowlCD						= mod:NewNextTimer(29.9, 401383, nil, nil, nil, 2)
local timerGlitteringSurgeCD					= mod:NewCDCountTimer(29.9, 401810, nil, nil, nil, 2)
local timerScorchingBombCD						= mod:NewCDCountTimer(29.9, 401500, nil, nil, nil, 3)
local timerMassDisintegrateCD					= mod:NewCDCountTimer(29.9, 401642, nil, nil, nil, 3)
local timerSearingBreathCD						= mod:NewCDCountTimer(29.9, 402050, nil, nil, nil, 3, nil, DBM_COMMON_L.MAGIC_ICON)
--local timerDriftingEmbersCD					= mod:NewAITimer(29.9, 402746, nil, nil, nil, 3, nil, DBM_COMMON_L.HEROIC_ICON)
local timerBurningClawsCD						= mod:NewCDCountTimer(29.9, 401325, nil, "Tank|Healer", nil, 5, nil, DBM_COMMON_L.TANK_ICON)
local timerBurningClaws							= mod:NewTargetTimer(27, 401325, nil, "Tank|Healer", nil, 2, nil, DBM_COMMON_L.TANK_ICON)--AOE damage from expiring

--mod:AddInfoFrameOption(361651, true)
--mod:AddRangeFrameOption(5, 390715)
mod:AddSetIconOption("SetIconOnMassDisintegrate", 401642, true, 0, {1, 2, 3, 4})
--mod:GroupSpells(390715, 396094)
--Stage Two: A Touch of the Forbidden
mod:AddTimerLine(DBM:EJ_GetSectionInfo(26142))
local warnVoidFracture							= mod:NewTargetAnnounce(404218, 3, nil, false)
local warnInfiniteDuress						= mod:NewTargetCountAnnounce(404288, 3, nil, nil, nil, nil, nil, nil, true)
local warnVoidClaws								= mod:NewStackAnnounce(411236, 2, nil, "Tank|Healer")

local specWarnVoidBomb							= mod:NewSpecialWarningCount(404027, nil, nil, nil, 2, 2)
local specWarnVoidFracture						= mod:NewSpecialWarningYou(404218, nil, nil, nil, 1, 2)--Maybe change to MoveTo alert to say move to emptyness?
local yellVoidFractureFades						= mod:NewShortFadesYell(404218)
local specWarnAbyssalBreath						= mod:NewSpecialWarningCount(404456, nil, nil, nil, 2, 2)
local specWarnEmptyStrike						= mod:NewSpecialWarningDefensive(404769, nil, nil, nil, 1, 2, 4)
local specWarnCosmicVolley						= mod:NewSpecialWarningInterruptCount(411302, "HasInterrupt", nil, nil, 1, 2, 4)
local specWarnBlastingScream					= mod:NewSpecialWarningInterruptCount(404754, "HasInterrupt", nil, nil, 1, 2, 4)
local specWarnDesolateBlossom					= mod:NewSpecialWarningDodgeCount(404403, nil, nil, nil, 2, 2)
local specWarnInfiniteDuress					= mod:NewSpecialWarningIncomingCount(404288, nil, nil, nil, 1, 14, 3)
local specWarnInfiniteDuressYou					= mod:NewSpecialWarningYou(404288, nil, nil, nil, 1, 2, 3)
local yellInfiniteDuress						= mod:NewShortPosYell(404288)
local yellInfiniteDuressFades					= mod:NewIconFadesYell(404288)
local specWarnVoidClaws							= mod:NewSpecialWarningDefensive(411236, nil, nil, nil, 1, 2)
local specWarnVoidClawsOut						= mod:NewSpecialWarningMoveAway(411236, nil, nil, nil, 1, 2)
local yellVoidClawsFades						= mod:NewShortFadesYell(411236)
local specWarnVoidClawsTaunt					= mod:NewSpecialWarningTaunt(411236, nil, nil, nil, 1, 2)

local timerEndExistenceCast						= mod:NewCastTimer(15, 410625, nil, "HasInterrupt", nil, 4, nil, DBM_COMMON_L.INTERRUPT_ICON)
local timerVoidBombCD							= mod:NewCDCountTimer(29.9, 404027, nil, nil, nil, 3)
local timerAbyssalBreathCD						= mod:NewCDCountTimer(29.9, 404456, nil, nil, nil, 3)
local timerEmptyStrikeCD						= mod:NewAITimer(29.9, 404769, nil, "Tank|Healer", nil, 5, nil, DBM_COMMON_L.TANK_ICON)--Mythic Add
local timerCosmicVolleyCD						= mod:NewAITimer(29.9, 411302, nil, "HasInterrupt", nil, 4, nil, DBM_COMMON_L.INTERRUPT_ICON)--Mythic Add
local timerBlastingScreamCD						= mod:NewCDTimer(8.5, 404754, nil, "HasInterrupt", nil, 4, nil, DBM_COMMON_L.INTERRUPT_ICON)
local timerDesolateBlossomCD					= mod:NewCDCountTimer(29.9, 404403, nil, nil, nil, 3)
local timerInfiniteDuressCD		 				= mod:NewCDCountTimer(29.9, 404288, nil, nil, nil, 3, nil, DBM_COMMON_L.HEROIC_ICON..DBM_COMMON_L.MAGIC_ICON)
local timerVoidClawsCD							= mod:NewCDCountTimer(29.9, 411236, nil, "Tank|Healer", nil, 5, nil, DBM_COMMON_L.TANK_ICON)
local timerVoidClaws							= mod:NewTargetTimer(18, 411236, nil, "Tank|Healer", nil, 2, nil, DBM_COMMON_L.TANK_ICON)--AOE damage from expiring

mod:AddSetIconOption("SetIconOnEmptyRecollection", 404505, true, 5, {8})
mod:AddSetIconOption("SetIconOnNullGlimmer", 404507, true, 5, {7, 6, 5, 4, 3})
mod:AddSetIconOption("SetIconOnInfiniteDuress", 404288, true, 0, {1})
mod:AddNamePlateOption("NPAuraOnRescind", 404705)
mod:AddNamePlateOption("NPAuraOnMight", 404269)
--Stage Three: The Seas of Infinity
mod:AddTimerLine(DBM:EJ_GetSectionInfo(26145))
local warnEmbraceofNothingness					= mod:NewTargetCountAnnounce(403517, 3, nil, nil, nil, nil, nil, nil, true)
local warnVoidSlash								= mod:NewStackAnnounce(408422, 2, nil, "Tank|Healer")
local warnHurtlingBarrage						= mod:NewTargetCountAnnounce(405022, 3, nil, nil, nil, nil, nil, nil, true)

local specWarnCosmicAscension					= mod:NewSpecialWarningDodgeCount(403771, nil, nil, nil, 2, 2)
local specWarnHurtlingBarrageIncoming			= mod:NewSpecialWarningIncomingCount(405022, nil, nil, nil, 1, 14)
local specWarnHurtlingBarrage					= mod:NewSpecialWarningYou(405022, nil, nil, nil, 1, 2)
local yellHurtlingBarrage						= mod:NewShortPosYell(405022)
local yellHurtlingBarrageFades					= mod:NewIconFadesYell(405022)
local specWarnScouringEternity					= mod:NewSpecialWarningDodgeCount(403625, nil, nil, nil, 3, 2)
local specWarnEmbraceofNothingness				= mod:NewSpecialWarningYou(403517, nil, nil, nil, 1, 2)
local yellEmbraceofNothingness					= mod:NewShortYell(403517, nil, nil, nil, "YELL")
local yellEmbraceofNothingnessFades				= mod:NewShortFadesYell(403517, nil, nil, nil, "YELL")
--local specWarnMotesofOblivion					= mod:NewSpecialWarningDodgeCount(406428, nil, nil, nil, 2, 2)
local specWarnVoidSlash							= mod:NewSpecialWarningDefensive(408422, nil, nil, nil, 1, 2)
local specWarnVoidSlashOut						= mod:NewSpecialWarningMoveAway(408422, nil, nil, nil, 1, 2)
local yellVoidSlashFades						= mod:NewShortFadesYell(408422)
local specWarnVoidSlashTaunt					= mod:NewSpecialWarningTaunt(408422, nil, nil, nil, 1, 2)

local timerCosmicAscensionCD					= mod:NewCDCountTimer(29.9, 403771, nil, nil, nil, 3)
local timerHurtlingBarrageCD					= mod:NewCDCountTimer(29.9, 405022, nil, nil, nil, 3)
local timerScouringEternityCD					= mod:NewCDCountTimer(29.9, 403625, nil, nil, nil, 3, nil, DBM_COMMON_L.DEADLY_ICON)
local timerEmbraceofNothingnessCD				= mod:NewCDCountTimer(29.9, 403517, nil, nil, nil, 3)
--local timerMotesofOblivionCD					= mod:NewAITimer(29.9, 406428, nil, nil, nil, 3)
local timerVoidSlashCD							= mod:NewCDCountTimer(29.9, 408422, nil, "Tank|Healer", nil, 5, nil, DBM_COMMON_L.TANK_ICON)
local timerVoidSlash							= mod:NewTargetTimer(18, 408422, nil, "Tank|Healer", nil, 2, nil, DBM_COMMON_L.TANK_ICON)--AOE damage from expiring

mod:AddSetIconOption("SetIconOnHurtling", 405022, true, 0, {3, 4})--2 on heroic

--P1 Variables
mod.vb.surgeCount = 0
mod.vb.bombCount = 0
mod.vb.disintegrateCount = 0
mod.vb.disintegrateIcon = 1--Also used for infinite
mod.vb.breathCount = 0
--mod.vb.embersCount = 0
mod.vb.tankCount = 0
--P2 Variables
mod.vb.addIcon = 7
mod.vb.blossomCount = 0
--P3 Variables
mod.vb.nothingnessCount = 0
mod.vb.hurtlingIcon = 3
--Non Synced Variables
local oblivionStacks = {}
local castsPerGUID = {}
local oblivionDisabled = false--Cache to avoid constant option table spamming
local difficultyName = "easy"
local allTimers = {
	["mythic"] = {
		[1] = {--Heroic filler timers for now
			--Scorching Bomb
			[401500] = {1, 32.2, 26.6, 18.9},
			--Glittering Surge
			[401810] = {3.3, 97.6},
			--Burning Claws
			[401325] = {20, 18.8, 18.8, 16.6},
			--Mass Disintegrate
			[401642] = {23.3, 24, 22.6, 21.1},
			--Searing Breath
			[402050] = {26.6, 15.5, 19.9},
		},
		[2] = {
			--Abyssal Breath
			[404456] = {3.5, 43.5, 35.3},
			--Desolate Blossom
			[404403] = {10.6, 43.4, 37.6},
			--Void Bomb
			[404027] = {15.3, 59.9},
			--Void Claws
			[411236] = {18.8, 17.6, 21.2},
			--Infinite Duress
			[407496] = {29.4, 35.2},
		},
		[3] = {
			--Infinite Duress (P2 ability returning)
			[407496] = {4.7, 56.2},
			--Void Bomb (P2 ability returning)
			[404027] = {28.5},
			--Cosmic Ascension
			[403771] = {9.2, 61.2},
			--Hurtling Barrage
			[405022] = {19.7},
			--Void Slash
			[408422] = {21, 36.2},
			--Scouring Eternity
			[403625] = {46.2},
			--Embrace of Nothingness
			[403517] = {24.7},
		},
	},
	["heroic"] = {--Heroic Confirmed
		[1] = {
			--Scorching Bomb
			[401500] = {1, 32.2, 26.6, 18.9},
			--Glittering Surge
			[401810] = {3.3, 97.6},
			--Burning Claws
			[401325] = {20, 18.8, 18.8, 16.6},
			--Mass Disintegrate
			[401642] = {23.3, 24, 22.6, 21.1},
			--Searing Breath
			[402050] = {26.6, 15.5, 19.9},
		},
		[2] = {
			--Abyssal Breath
			[404456] = {3.5, 43.5, 35.3},
			--Desolate Blossom
			[404403] = {10.6, 43.4, 37.6},
			--Void Bomb
			[404027] = {15.3, 59.9},
			--Void Claws
			[411236] = {18.8, 17.6, 21.2},
			--Infinite Duress
			[407496] = {29.4, 35.2},
		},
		[3] = {
			--Infinite Duress (P2 ability returning)
			[407496] = {4.7, 56.2},
			--Void Bomb (P2 ability returning)
			[404027] = {28.5},
			--Cosmic Ascension
			[403771] = {9.2, 61.2},
			--Hurtling Barrage
			[405022] = {19.7},
			--Void Slash
			[408422] = {21, 36.2},
			--Scouring Eternity
			[403625] = {46.2},
			--Embrace of Nothingness
			[403517] = {24.7},
		},
	},
	["easy"] = {--Normal confirmed, LFR assumed
		[1] = {
			--Scorching Bomb
			[401500] = {1, 58.8},
			--Glittering Surge
			[401810] = {3.3, 97.6},
			--Burning Claws
			[401325] = {20, 18.8, 18.8, 16.6},
			--Mass Disintegrate
			[401642] = {23.3, 23.3, 44.4},
			--Searing Breath
			[402050] = {26.6, 35.5},
		},
		[2] = {
			--Abyssal Breath
			[404456] = {3.7, 46.2},
			--Desolate Blossom
			[404403] = {11.2, 46.2, 39.9},
			--Void Bomb
			[404027] = {16.2, 63.7},
			--Void Claws
			[411236] = {19.9, 18.7, 22.4, 22.5, 22.5},
			--Infinite Duress (Doesn't exist on normal/LFR)
		},
		[3] = {
			--Infinite Duress (P2 ability that still isn't in normal/LFR)
			--Void Bomb (P2 ability returning)
			[404027] = {30.3, 65.3, 65.3},
			--Cosmic Ascension
			[403771] = {9.7, 65.3, 105.3},
			--Hurtling Barrage
			[405022] = {21, 46.6, 102.6, 65.3},
			--Void Slash
			[408422] = {22.3, 38.6, 39.9, 90.6, 11.9, 25.3},
			--Scouring Eternity
			[403625] = {49.7, 82.5, 86.1},
			--Embrace of Nothingness
			[403517] = {26.3, 118.6, 53.3},
		},
	},
}

function mod:OnCombatStart(delay)
	table.wipe(oblivionStacks)
	table.wipe(castsPerGUID)
	self:SetStage(1)
	self.vb.surgeCount = 0
	self.vb.bombCount = 0
	self.vb.disintegrateCount = 0
	self.vb.breathCount = 0
	--self.vb.embersCount = 0
	self.vb.tankCount = 0
	self.vb.blossomCount = 0
	self.vb.nothingnessCount = 0
	self.vb.hurtlingIcon = 3
--	timerScorchingBombCD:Start(1-delay, 1)--Used 1 second into pull
	timerGlitteringSurgeCD:Start(3.3-delay, 1)
	timerOppressingHowlCD:Start(14.4-delay)
	timerBurningClawsCD:Start(20-delay, 1)
	timerMassDisintegrateCD:Start(23.3-delay, 1)
	timerSearingBreathCD:Start(26.6-delay, 1)
	--timerDriftingEmbersCD:Start(1-delay)
	timerPhaseCD:Start(112)--Normal and heroic confirmed, LFR and mythic unknown
	if self.Options.NPAuraOnRescind or self.Options.NPAuraOnMight then
		DBM:FireEvent("BossMod_EnableHostileNameplates")
	end
	if self:IsMythic() then
		difficultyName = "mythic"
	elseif self:IsHeroic() then
		difficultyName = "heroic"
	else
		difficultyName = "easy"
	end
	if self.Options.InfoFrame then
		if self.Options.InfoFrameBehaviorTwo == "OblivionOnly" then
			oblivionDisabled = false
			DBM.InfoFrame:SetHeader(DBM:GetSpellInfo(401951))
			DBM.InfoFrame:Show(20, "table", oblivionStacks, 1)
		else
			if self.Options.InfoFrameBehaviorTwo == "HowlOnly" then
				oblivionDisabled = true--Means in phase 2 and 3 infoframe just closes
				--If hybrid is enabled, oblivionDisabled will be set to false on stage 2 trigger
			end
			DBM.InfoFrame:SetHeader(DBM:GetSpellInfo(401383))
			DBM.InfoFrame:Show(20, "playerdebuffstacks", 401383)--Stacks aren't in combat log so has to use less efficient UnitAura method
		end
	end
end

function mod:OnTimerRecovery()
	if self:IsMythic() then
		difficultyName = "mythic"
	elseif self:IsHeroic() then
		difficultyName = "heroic"
	else
		difficultyName = "easy"
	end
end

function mod:OnCombatEnd()
--	if self.Options.RangeFrame then
--		DBM.RangeCheck:Hide()
--	end
	if self.Options.InfoFrame then
		DBM.InfoFrame:Hide()
	end
	if self.Options.NPAuraOnRescind or self.Options.NPAuraOnMight then
		DBM.Nameplate:Hide(true, nil, nil, nil, true, true)
	end
end


function mod:SPELL_CAST_START(args)
	local spellId = args.spellId
	if spellId == 401383 then
		warnOppressingHowl:Show()
	elseif spellId == 401810 then
		self.vb.surgeCount = self.vb.surgeCount + 1
		specWarnGlitteringSurge:Show(self.vb.surgeCount)
		specWarnGlitteringSurge:Play("aesoon")
		local timer = self:GetFromTimersTable(allTimers, difficultyName, self.vb.phase, spellId, self.vb.surgeCount+1)
		if timer then
			timerGlitteringSurgeCD:Start(timer, self.vb.surgeCount+1)
		end
	elseif spellId == 401500 then
		self.vb.bombCount = self.vb.bombCount + 1
		specWarnScorchingBomb:Show(self.vb.bombCount)
		specWarnScorchingBomb:Play("bombsoon")
		local timer = self:GetFromTimersTable(allTimers, difficultyName, self.vb.phase, spellId, self.vb.bombCount+1)
		if timer then
			timerScorchingBombCD:Start(timer, self.vb.bombCount+1)
		end
	elseif (spellId == 401642 or spellId == 401704) and self:AntiSpam(8, 1) then
		self.vb.disintegrateCount = self.vb.disintegrateCount + 1
		self.vb.disintegrateIcon = 1
		specWarnMassDisintegrate:Show(self.vb.disintegrateCount)
		specWarnMassDisintegrate:Play("incomingdebuff")
		local timer = self:GetFromTimersTable(allTimers, difficultyName, self.vb.phase, 401642, self.vb.disintegrateCount+1)
		if timer then
			timerMassDisintegrateCD:Start(timer, self.vb.disintegrateCount+1)
		end
	elseif spellId == 402050 then
		self.vb.breathCount = self.vb.breathCount + 1
		specWarnSearingBreath:Show(self.vb.breathCount)
		specWarnSearingBreath:Play("breathsoon")
		local timer = self:GetFromTimersTable(allTimers, difficultyName, self.vb.phase, spellId, self.vb.breathCount+1)
		if timer then
			timerSearingBreathCD:Start(timer, self.vb.breathCount+1)
		end
	elseif spellId == 401325 then
		self.vb.tankCount = self.vb.tankCount + 1
		local timer = self:GetFromTimersTable(allTimers, difficultyName, self.vb.phase, spellId, self.vb.tankCount+1)
		if timer then
			timerBurningClawsCD:Start(timer, self.vb.tankCount+1)
		end
		if self:IsTanking("player", nil, nil, true, args.sourceGUID) then
			specWarnBurningClaws:Show()
			specWarnBurningClaws:Play("defensive")
		end
	elseif spellId == 404027 then
		self.vb.bombCount = self.vb.bombCount + 1
		specWarnVoidBomb:Show(self.vb.bombCount)
		specWarnVoidBomb:Play("bombsoon")
		local timer = self:GetFromTimersTable(allTimers, difficultyName, self.vb.phase, spellId, self.vb.bombCount+1)
		if timer then
			timerVoidBombCD:Start(timer, self.vb.bombCount+1)
		end
	elseif spellId == 404456 then
		self.vb.addIcon = 7
		self.vb.breathCount = self.vb.breathCount + 1
		specWarnAbyssalBreath:Show(self.vb.breathCount)
		specWarnAbyssalBreath:Play("breathsoon")
		local timer = self:GetFromTimersTable(allTimers, difficultyName, self.vb.phase, spellId, self.vb.breathCount+1)
		if timer then
			timerAbyssalBreathCD:Start(timer, self.vb.breathCount+1)
		end
	elseif spellId == 411302 then
		if not castsPerGUID[args.sourceGUID] then
			castsPerGUID[args.sourceGUID] = 0
			if self.Options.SetIconOnEmptyRecollection then
				self:ScanForMobs(args.sourceGUID, 2, 8, 1, nil, 12, "SetIconOnEmptyRecollection")
			end
		end
		castsPerGUID[args.sourceGUID] = castsPerGUID[args.sourceGUID] + 1
		local count = castsPerGUID[args.sourceGUID]
		if self:CheckInterruptFilter(args.sourceGUID, false, false) then--Count interrupt, so cooldown is not checked
			specWarnCosmicVolley:Show(args.sourceName, count)
			if count < 6 then
				specWarnCosmicVolley:Play("kick"..count.."r")
			else
				specWarnCosmicVolley:Play("kickcast")
			end
		end
		timerCosmicVolleyCD:Start(nil, args.sourceGUID)
	elseif spellId == 404754 then
		if not castsPerGUID[args.sourceGUID] then
			castsPerGUID[args.sourceGUID] = 0
			if self.Options.SetIconOnNullGlimmer then
				self:ScanForMobs(args.sourceGUID, 2, self.vb.addIcon, 1, nil, 12, "SetIconOnNullGlimmer")
			end
			self.vb.addIcon = self.vb.addIcon - 1
		end
		castsPerGUID[args.sourceGUID] = castsPerGUID[args.sourceGUID] + 1
		local count = castsPerGUID[args.sourceGUID]
		if self:CheckInterruptFilter(args.sourceGUID, false, false) then--Count interrupt, so cooldown is not checked
			specWarnBlastingScream:Show(args.sourceName, count)
			if count < 6 then
				specWarnBlastingScream:Play("kick"..count.."r")
			else
				specWarnBlastingScream:Play("kickcast")
			end
		end
		timerBlastingScreamCD:Start(nil, args.sourceGUID)
	elseif spellId == 404769 then
		timerEmptyStrikeCD:Start(nil, args.sourceGUID)
		if self:IsTanking("player", nil, nil, true, args.sourceGUID) then
			specWarnEmptyStrike:Show()
			specWarnEmptyStrike:Play("defensive")
		end
	elseif spellId == 404403 or spellId == 411030 then--404403 confirmed, 411030 unknown (probably LFR)
		self.vb.blossomCount = self.vb.blossomCount + 1
		specWarnDesolateBlossom:Show(self.vb.blossomCount)
		specWarnDesolateBlossom:Play("watchstep")
		local timer = self:GetFromTimersTable(allTimers, difficultyName, self.vb.phase, 404403, self.vb.blossomCount+1)
		if timer then
			timerDesolateBlossomCD:Start(timer, self.vb.blossomCount+1)
		end
	elseif spellId == 407496 or spellId == 404288 then--407496 confirmed, 404288 unknown (mythic?)
		self.vb.disintegrateCount = self.vb.disintegrateCount + 1
		self.vb.disintegrateIcon = 1
		specWarnInfiniteDuress:Show(self.vb.disintegrateCount)
		specWarnInfiniteDuress:Play("incomingdebuff")
		local timer = self:GetFromTimersTable(allTimers, difficultyName, self.vb.phase, 407496, self.vb.disintegrateCount+1)
		if timer then
			timerInfiniteDuressCD:Start(timer, self.vb.disintegrateCount+1)
		end
	elseif spellId == 411236 then
		self.vb.tankCount = self.vb.tankCount + 1
		local timer = self:GetFromTimersTable(allTimers, difficultyName, self.vb.phase, spellId, self.vb.tankCount+1)
		if timer then
			timerVoidClawsCD:Start(timer, self.vb.tankCount+1)
		end
		if self:IsTanking("player", nil, nil, true, args.sourceGUID) then
			specWarnVoidClaws:Show()
			specWarnVoidClaws:Play("defensive")
		end
	elseif spellId == 403771 then
		self.vb.breathCount = self.vb.breathCount + 1
		specWarnCosmicAscension:Show(self.vb.breathCount)
		specWarnCosmicAscension:Play("watchstep")
		local timer = self:GetFromTimersTable(allTimers, difficultyName, self.vb.phase, spellId, self.vb.breathCount+1)
		if timer then
			timerCosmicAscensionCD:Start(timer, self.vb.breathCount+1)
		end
	elseif spellId == 405022 then
		self.vb.surgeCount = self.vb.surgeCount + 1
		self.vb.hurtlingIcon = 3
		specWarnHurtlingBarrageIncoming:Show(self.vb.surgeCount)
		specWarnHurtlingBarrageIncoming:Play("incomingdebuff")
		local timer = self:GetFromTimersTable(allTimers, difficultyName, self.vb.phase, spellId, self.vb.surgeCount+1)
		if timer then
			timerHurtlingBarrageCD:Start(timer, self.vb.surgeCount+1)
		end
	elseif spellId == 403625 then
		self.vb.blossomCount = self.vb.blossomCount + 1
		specWarnScouringEternity:Show(self.vb.blossomCount)
		specWarnScouringEternity:Play("watchstep")
		local timer = self:GetFromTimersTable(allTimers, difficultyName, self.vb.phase, spellId, self.vb.blossomCount+1)
		if timer then
			timerScouringEternityCD:Start(timer, self.vb.blossomCount+1)
		end
	elseif spellId == 403517 then
		self.vb.nothingnessCount = self.vb.nothingnessCount + 1
		--TODO, add incoming debuff alert if target aura is hidden
		local timer = self:GetFromTimersTable(allTimers, difficultyName, self.vb.phase, spellId, self.vb.nothingnessCount+1)
		if timer then
			timerEmbraceofNothingnessCD:Start(timer, self.vb.nothingnessCount+1)
		end
	elseif spellId == 408422 then
		self.vb.tankCount = self.vb.tankCount + 1
		local timer = self:GetFromTimersTable(allTimers, difficultyName, self.vb.phase, spellId, self.vb.tankCount+1)
		if timer then
			timerVoidSlashCD:Start(timer, self.vb.tankCount+1)
		end
		if self:IsTanking("player", nil, nil, true, args.sourceGUID) then
			specWarnVoidSlash:Show()
			specWarnVoidSlash:Play("defensive")
		end
	end
end

--[[
function mod:SPELL_CAST_SUCCESS(args)
	local spellId = args.spellId
	if spellId == 394917 then

	end
end
--]]

function mod:SPELL_SUMMON(args)
	local spellId = args.spellId
	if spellId == 404505 then--Empty Recollection (Mythic Add)
		if not castsPerGUID[args.destGUID] then
			castsPerGUID[args.destGUID] = 0
			if self.Options.SetIconOnEmptyRecollection then
				self:ScanForMobs(args.destGUID, 2, 8, 1, nil, 12, "SetIconOnEmptyRecollection")
			end
		end
		timerEmptyStrikeCD:Start(1, args.destGUID)
		timerCosmicVolleyCD:Start(1, args.destGUID)
	elseif spellId == 404507 then--Null Glimmer (regular adds)
		if not castsPerGUID[args.destGUID] then
			castsPerGUID[args.destGUID] = 0
			if self.Options.SetIconOnNullGlimmer then--Only use up to 5 icons
				self:ScanForMobs(args.destGUID, 2, self.vb.addIcon, 1, nil, 12, "SetIconOnNullGlimmer")
			end
			self.vb.addIcon = self.vb.addIcon - 1
		end
		timerBlastingScreamCD:Start(8.7, args.destGUID)
	end
end

function mod:SPELL_AURA_APPLIED(args)
	local spellId = args.spellId
	if spellId == 401951 then
		local amount = args.amount or 1
		oblivionStacks[args.destName] = amount
		if args:IsPlayer() and amount % 3 == 0 then--3, 6, 9
			if amount < 6 then--3
				warnOblivionStack:Show(amount)
			else--6 and 9
				specWarnOblivionStack:Show(amount)
				specWarnOblivionStack:Play("stackhigh")
			end
		end
		if self.Options.InfoFrame and not oblivionDisabled then
			DBM.InfoFrame:UpdateTable(oblivionStacks, 0.2)
		end
	elseif spellId == 401215 then
		if args:IsPlayer() then
			specWarnEmptynessBetweenStars:Show()
			specWarnEmptynessBetweenStars:Play("stilldanger")
			yellVoidFractureFades:Cancel()
			local _, _, _, _, _, expireTime = DBM:UnitDebuff("player", spellId)
			if expireTime then--Buff has various durations based on difficulty, 15-25, this is just easiest
				local remaining = expireTime-GetTime()
				timerEmptynessBetweenStars:Start(remaining)
			end
		end
	elseif spellId == 403997 and args:IsPlayer() then
		local amount = args.amount or 1
		if amount < 3 then
			warnMindFragment:Show(3-amount)
		end
	elseif spellId == 407576 and args:IsPlayer() then
		local amount = args.amount or 1
		if amount % 2 == 0 then
			warnAstralFlare:Show(amount)
		end
	elseif spellId == 404269 then
		if (args.amount or 1) == 5 then
			if self.Options.NPAuraOnMight then
				DBM.Nameplate:Show(true, args.destGUID, spellId)
			end
		end
	elseif spellId == 401905 then
		warnDazzled:CombinedShow(0.5, args.destName)
	elseif spellId == 401680 then
		local icon = self.vb.disintegrateIcon
		if self.Options.SetIconOnMassDisintegrate then
			self:SetIcon(args.destName, icon)
		end
		if args:IsPlayer() then
			specWarnMassDisintegrateYou:Show()
			specWarnMassDisintegrateYou:Play("targetyou")
			yellMassDisintegrate:Yell(icon, icon)
			yellMassDisintegrateFades:Countdown(spellId, nil, icon)
		end
		warnMassDisintegrate:CombinedShow(0.3, self.vb.disintegrateCount, args.destName)
		self.vb.disintegrateIcon = self.vb.disintegrateIcon + 1
	elseif spellId == 407496 or spellId == 404288 then
		local icon = self.vb.disintegrateIcon
		if self.Options.SetIconOnInfiniteDuress then
			self:SetIcon(args.destName, icon)
		end
		if args:IsPlayer() then
			specWarnInfiniteDuressYou:Show()
			specWarnInfiniteDuressYou:Play("targetyou")
			yellInfiniteDuress:Yell(icon, icon)
			yellInfiniteDuressFades:Countdown(spellId, nil, icon)
		end
		warnInfiniteDuress:CombinedShow(0.3, self.vb.disintegrateCount, args.destName)
		self.vb.disintegrateIcon = self.vb.disintegrateIcon + 1
	elseif spellId == 401330 then
		local amount = args.amount or 1
		if amount >= 1 then
			if not args:IsPlayer() and not UnitIsDeadOrGhost("player") then--and not DBM:UnitDebuff("player", spellId)
				specWarnBurningClawsTaunt:Show(args.destName)
				specWarnBurningClawsTaunt:Play("tauntboss")
			else
				warnBurningClaws:Show(args.destName, amount)
			end
		else
			warnBurningClaws:Show(args.destName, amount)
		end
		timerBurningClaws:Restart(27, args.destName)
	elseif spellId == 411241 then
		local amount = args.amount or 1
		if amount >= 1 then
			if not args:IsPlayer() and not UnitIsDeadOrGhost("player") then--and not DBM:UnitDebuff("player", spellId)
				specWarnVoidClawsTaunt:Show(args.destName)
				specWarnVoidClawsTaunt:Play("tauntboss")
			else
				warnVoidClaws:Show(args.destName, amount)
				if args:IsPlayer() then
					specWarnVoidClawsOut:Cancel()
					specWarnVoidClawsOut:Schedule(12)
					specWarnVoidClawsOut:ScheduleVoice(12, "runout")
					yellVoidClawsFades:Cancel()
					yellVoidClawsFades:Countdown(spellId)
				end
			end
		else
			warnVoidClaws:Show(args.destName, amount)
		end
		timerVoidClaws:Restart(18, args.destName)
	elseif spellId == 408429 then
		local uId = DBM:GetRaidUnitId(args.destName)
		if self:IsTanking(uId) then--Frontal filter, in case it can hit anyone that's in front of boss
			local amount = args.amount or 1
			if amount >= 1 then
				if not args:IsPlayer() and not UnitIsDeadOrGhost("player") then--and not DBM:UnitDebuff("player", spellId)
					specWarnVoidSlashTaunt:Show(args.destName)
					specWarnVoidSlashTaunt:Play("tauntboss")
				else
					warnVoidSlash:Show(args.destName, amount)
					if args:IsPlayer() then
						specWarnVoidSlashOut:Cancel()
						specWarnVoidSlashOut:Schedule(12)
						specWarnVoidSlashOut:ScheduleVoice(12, "runout")
						yellVoidClawsFades:Cancel()
						yellVoidClawsFades:Countdown(spellId)
					end
				end
			else
				warnVoidSlash:Show(args.destName, amount)
			end
		end
		timerVoidSlash:Restart(21, args.destName)--Needs to show for even non tanks getting hit though
	elseif spellId == 404218 then
		if args:IsPlayer() then
			specWarnVoidFracture:Show()
			specWarnVoidFracture:Play("bombyou")
			if self:IsMythic() then
				--schedule for Dimensional Puncture
				yellVoidFractureFades:Countdown(spellId)
			end
		else
			warnVoidFracture:Show(args.destName)
		end
	elseif spellId == 404705 then
		if self.Options.NPAuraOnRescind then
			DBM.Nameplate:Show(true, args.destGUID, spellId)
		end
	elseif spellId == 405486 then
		local icon = self.vb.hurtlingIcon
		if self.Options.SetIconOnHurtling then
			self:SetIcon(args.destName, icon)
		end
		if args:IsPlayer() then
			specWarnHurtlingBarrage:Show()
			specWarnHurtlingBarrage:Play("targetyou")
			yellHurtlingBarrage:Yell(icon, icon-2)
			yellHurtlingBarrageFades:Countdown(spellId, nil, icon)
		end
		warnHurtlingBarrage:CombinedShow(0.3, self.vb.surgeCount, args.destName)
		self.vb.hurtlingIcon = self.vb.hurtlingIcon + 1
	elseif spellId == 403520 then
		if args:IsPlayer() then
			specWarnEmbraceofNothingness:Show()
			specWarnEmbraceofNothingness:Play("gathershare")
			yellEmbraceofNothingness:Yell()
			yellEmbraceofNothingnessFades:Countdown(spellId)
		else
			warnEmbraceofNothingness:Show(self.vb.nothingnessCount, args.destName)
		end
	elseif spellId == 403284 then--Stage 1-2 Intermission
		timerOppressingHowlCD:Stop()
		timerGlitteringSurgeCD:Stop()
		timerScorchingBombCD:Stop()
		timerMassDisintegrateCD:Stop()
		timerSearingBreathCD:Stop()
		--timerDriftingEmbersCD:Stop()
		timerBurningClawsCD:Stop()
	elseif spellId == 410654 then--Stage 2-3 Intermission
		timerVoidBombCD:Stop()
		timerAbyssalBreathCD:Stop()
		timerDesolateBlossomCD:Stop()
		timerInfiniteDuressCD:Stop()
		timerVoidClawsCD:Stop()
		timerPhaseCD:Start(10)
	elseif spellId == 410625 then
		timerEndExistenceCast:Start()
	end
end
mod.SPELL_AURA_APPLIED_DOSE = mod.SPELL_AURA_APPLIED

function mod:SPELL_AURA_REMOVED(args)
	local spellId = args.spellId
	if spellId == 401951 then
		oblivionStacks[args.destName] = nil
		if self.Options.InfoFrame and not oblivionDisabled then
			DBM.InfoFrame:UpdateTable(oblivionStacks, 0.2)
		end
	elseif spellId == 401215 then
		if args:IsPlayer() then
			warnEmptynessBetweenStars:Show()
			timerEmptynessBetweenStars:Stop()
		end
	elseif spellId == 401680 then
		if self.Options.SetIconOnMassDisintegrate then
			self:SetIcon(args.destName, 0)
		end
		if args:IsPlayer() then
			yellMassDisintegrateFades:Cancel()
		end
	elseif spellId == 407496 or spellId == 404288 then
		if self.Options.SetIconOnInfiniteDuress then
			self:SetIcon(args.destName, 0)
		end
		if args:IsPlayer() then
			yellInfiniteDuressFades:Cancel()
		end
	elseif spellId == 401330 then
		timerBurningClaws:Stop(args.destName)
	elseif spellId == 411241 then
		if args:IsPlayer() then
			specWarnVoidClawsOut:Cancel()
			specWarnVoidClawsOut:CancelVoice()
			yellVoidClawsFades:Cancel()
		end
		timerVoidClaws:Stop(args.destName)
	elseif spellId == 408429 then
		if args:IsPlayer() then
			specWarnVoidSlashOut:Cancel()
			specWarnVoidSlashOut:CancelVoice()
			yellVoidClawsFades:Cancel()
		end
		timerVoidSlash:Stop(args.destName)--Needs to show for even non tanks getting hit though
	elseif spellId == 404218 then
		if args:IsPlayer() then
			yellVoidFractureFades:Cancel()
		end
	elseif spellId == 404705 then
		if self.Options.NPAuraOnRescind then
			DBM.Nameplate:Hide(true, args.destGUID, spellId)
		end
	elseif spellId == 404269 then
		if self.Options.NPAuraOnMight then
			DBM.Nameplate:Show(true, args.destGUID, spellId)
		end
	elseif spellId == 403520 then
		if args:IsPlayer() then
			yellEmbraceofNothingnessFades:Cancel()
		end
	elseif spellId == 405486 then
		if self.Options.SetIconOnHurtling then
			self:SetIcon(args.destName, 0)
		end
		if args:IsPlayer() then
			yellHurtlingBarrageFades:Cancel()
		end
	elseif spellId == 410654 then--Stage 3 Begin
		self:SetStage(3)
		self.vb.bombCount = 0--Reused for Void Bombs
		self.vb.breathCount = 0--Reused for Cosmic Ascension
		self.vb.surgeCount = 0--Reused for Hurtling Barrage
		self.vb.blossomCount = 0--Reused for Scouring Eternity
		self.vb.disintegrateCount = 0--Reused for Inifinite Duress
		--self.vb.embersCount--Reused for Motes of Oblivion
		self.vb.tankCount = 0----Reused for Void Slash
		if self:IsHard() then
			timerInfiniteDuressCD:Start(4.7, 1)
			timerCosmicAscensionCD:Start(9.2, 1)
			timerHurtlingBarrageCD:Start(19.7, 1)
			timerVoidSlashCD:Start(21, 1)
			timerEmbraceofNothingnessCD:Start(24.7, 1)
			timerVoidBombCD:Start(28.5, 1)
			timerScouringEternityCD:Start(46.2, 1)
			--timerMotesofOblivionCD:Start(3)
		else--Easy
			timerCosmicAscensionCD:Start(9.7, 1)
			timerHurtlingBarrageCD:Start(21, 1)
			timerVoidSlashCD:Start(22.3, 1)
			timerVoidBombCD:Start(30.3, 1)
			timerScouringEternityCD:Start(49.7, 1)
			timerEmbraceofNothingnessCD:Start(26.3, 1)
			--timerMotesofOblivionCD:Start(3)
		end
	elseif spellId == 410625 then
		timerEndExistenceCast:Stop()
		--True start of phase 2 timers
		self:SetStage(2)
		self.vb.bombCount = 0--Reused for Void Bombs
		self.vb.breathCount = 0--Reused for Abyssal Breath
		self.vb.disintegrateCount = 0--Reused for Inifinite Duress
		self.vb.tankCount = 0----Reused for Void Claws
		if self:IsHard() then
			timerAbyssalBreathCD:Start(3.5, 1)
			timerDesolateBlossomCD:Start(10.6, 1)
			timerVoidBombCD:Start(15.3, 1)
			timerVoidClawsCD:Start(18.8, 1)
			timerInfiniteDuressCD:Start(29.4, 1)
		else--Easy
			timerAbyssalBreathCD:Start(3.7, 1)
			timerDesolateBlossomCD:Start(11.2, 1)
			timerVoidBombCD:Start(16.2, 1)
			timerVoidClawsCD:Start(19.9, 1)
		end
		if self.Options.InfoFrame then
			--If oblivion only, no changes need to run on Phase 2
			if self.Options.InfoFrameBehaviorTwo == "Hybrid" then
				--Transition from Howl to Oblivion for phase 2 and phase 3
				oblivionDisabled = false
				DBM.InfoFrame:SetHeader(DBM:GetSpellInfo(401951))
				DBM.InfoFrame:Show(20, "table", oblivionStacks, 1)
			else
				--Just close it out, It was howl only
				if self.Options.InfoFrameBehaviorTwo == "HowlOnly" then
					DBM.InfoFrame:Hide()
				end
			end
		end
	end
end

function mod:SPELL_AURA_REMOVED_DOSE(args)
	local spellId = args.spellId
	if spellId == 401951 then
		oblivionStacks[args.destName] = args.amount or 1
		if self.Options.InfoFrame and not oblivionDisabled then
			DBM.InfoFrame:UpdateTable(oblivionStacks, 0.2)
		end
	end
end


function mod:SPELL_PERIODIC_DAMAGE(_, _, _, _, destGUID, _, _, _, spellId, spellName)
	if spellId == 406989 and destGUID == UnitGUID("player") and self:AntiSpam(3, 3) then
		specWarnGTFO:Show(spellName)
		specWarnGTFO:Play("watchfeet")
	end
end
mod.SPELL_PERIODIC_MISSED = mod.SPELL_PERIODIC_DAMAGE

function mod:UNIT_DIED(args)
	local cid = self:GetCIDFromGUID(args.destGUID)
	if cid == 202971 then--Null Glimmer
		castsPerGUID[args.destGUID] = nil
		timerBlastingScreamCD:Stop(args.destGUID)
	elseif cid == 202969 then--Empty Recollection
		castsPerGUID[args.destGUID] = nil
		timerEmptyStrikeCD:Stop(args.destGUID)
		timerCosmicVolleyCD:Stop(args.destGUID)
	end
end

--https://www.wowhead.com/ptr/spell=402736/drifting-embers
--https://www.wowhead.com/ptr/spell=403308/void-empowerment
--https://www.wowhead.com/ptr/spell=404564/void-empowerment

--[[
function mod:UNIT_SPELLCAST_SUCCEEDED(uId, _, spellId)
--	if spellId == 402736 then--Drifting Embers
--		self.vb.embersCount = self.vb.embersCount + 1
--		specWarnDriftingEmbers:Show(self.vb.embersCount)
--		specWarnDriftingEmbers:Play("watchstep")
--		timerDriftingEmbersCD:Start()
--	elseif spellId == 406427 then--Motesof Oblivion
--		self.vb.embersCount = self.vb.embersCount + 1
--		specWarnMotesofOblivion:Show(self.vb.embersCount)
--		specWarnMotesofOblivion:Play("watchstep")
--		timerMotesofOblivionCD:Start()
	end
end
--]]