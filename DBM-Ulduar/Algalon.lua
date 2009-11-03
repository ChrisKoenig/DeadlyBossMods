﻿local mod = DBM:NewMod("Algalon", "DBM-Ulduar")
local L = mod:GetLocalizedStrings()

--[[
--
--  Thanks to  Apathy @ Vek'nilash  who provided us with Informations and Combatlog about Algalon
--
--]]


mod:SetRevision(("$Revision$"):sub(12, -3))
mod:SetCreatureID(32871)

mod:RegisterCombat("combat")

mod:RegisterEvents(
	"SPELL_CAST_START",
	"SPELL_AURA_APPLIED",
	"SPELL_AURA_APPLIED_DOSE",
	"CHAT_MSG_RAID_BOSS_EMOTE",
	"UNIT_HEALTH"
)

local announceBigBang			= mod:NewSpellAnnounce(64584, 3)
local announcePreBigBang		= mod:NewAnnounce("PreWarningBigBang", 3, 64584)
local announceBlackHole			= mod:NewAnnounce("WarningBlackHole", 2, 65108)
local announceCosmicSmash		= mod:NewAnnounce("WarningCosmicSmash", 3, 62311)
local announcePhasePunch		= mod:NewAnnounce("WarningPhasePunch", 4, 65108)

local specWarnPhasePunch		= mod:NewSpecialWarning("SpecWarnPhasePunch")
local specWarnBigBang			= mod:NewSpecialWarning("SpecWarnBigBang")
local specWarnCosmicSmash		= mod:NewSpecialWarning("SpecWarnCosmicSmash")

local enrageTimer				= mod:NewEnrageTimer(366) -- combatstart take some combattime
local timerNextBigBang			= mod:NewNextTimer(90.5, 64584)
local timerBigBangCast			= mod:NewCastTimer(8, 64584)
local timerNextCollapsingStar	= mod:NewTimer(15, "NextCollapsingStar")
local timerCDCosmicSmash		= mod:NewTimer(25, "PossibleNextCosmicSmash")
local timerCastCosmicSmash		= mod:NewCastTimer(4.5, 62311)
local timerPhasePunch			= mod:NewBuffActiveTimer(45, 64412)
local timerNextPhasePunch		= mod:NewNextTimer(16, 64412)

local phase = 0

function mod:OnCombatStart(delay)
	phase = 1
	enrageTimer:Start(-delay)
	-- added 6 seconds because of +combat until spawn difference
	timerNextBigBang:Start(96.5-delay)
	announcePreBigBang:Schedule(86-delay)
	timerNextCollapsingStar:Start(21-delay)
	timerCDCosmicSmash:Start(31-delay)
end

function mod:UNIT_HEALTH(unitid)
	if phase == 1 and UnitName(unitid) == L.name then
		if UnitHealth(unitid) <= 20 then
			phase = 2
		end
	end
end

function mod:SPELL_CAST_START(args)
	if args:IsSpellID(64584, 64443) then 	-- Big Bang
		timerBigBangCast:Start()
		timerNextBigBang:Start()
		announceBigBang:Show()
		announcePreBigBang:Schedule(80)
		specWarnBigBang:Show()
	end
end


function mod:SPELL_CAST_SUCCESS(args)
	if args:IsSpellID(65108, 64122) then 	-- Black Hole Explosion
		announceBlackHole:Show()

	elseif args:IsSpellID(64598, 62301) then	-- Cosmic Smash
		timerCastCosmicSmash:Start()
		timerCDCosmicSmash:Start()
		announceCosmicSmash:Show()
		specWarnCosmicSmash:Show()
	end
end

function mod:SPELL_AURA_APPLIED(args)
	if args:IsSpellID(64412) then
		timerNextPhasePunch:Start()
		local amount = args.amount or 1
		if args:IsPlayer() and amount >= 4 then
			specWarnPhasePunch:Show()
		end
		timerPhasePunch:Start(args.destName)
		announcePhasePunch:Show(args.destName, amount)
	end
end
mod.SPELL_AURA_APPLIED_DOSE = mod.SPELL_AURA_APPLIED


function mod:CHAT_MSG_RAID_BOSS_EMOTE(msg)
	if msg == L.Emote_CollapsingStar or msg:find(L.Emote_CollapsingStar) then
		timerNextCollapsingStar:Start()
	elseif msg == L.Emote_CosmicSmash or msg:find(L.Emote_CosmicSmash) then
		timerCastCosmicSmash:Start()
		timerCDCosmicSmash:Start()
		announceCosmicSmash:Show()
		specWarnCosmicSmash:Show()
	end
end



