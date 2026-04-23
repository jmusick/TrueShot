-- TrueShot Profile: Feral / Druid of the Claw (Spec 103)
-- Cast-event state machine for Tiger's Fury and Berserk burst windows.
--
-- Limitations: Feral is heavily resource-dependent on Energy and Combo Points,
-- both of which are hidden from addon inspection in TrueShot's model.
-- DoT snapshot state (Rip/Rake empowerment) is also opaque. This profile
-- tracks burst cooldown windows only; AC handles the rest.

local Engine = TrueShot.Engine

local TIGERS_FURY_DURATION = 10
local BERSERK_DURATION = 15
local INCARNATION_DURATION = 20
local RAKE_DURATION = 15
local RAKE_PANDEMIC_SECONDS = 4.5
local CAT_FORM_ID = 1
local SPELLS = {
    MarkOfTheWild = 1126,
    TigerFury = 5217,
    Berserk = 106951,
    Incarnation = 102543,
    Rake = 1822,
    CatForm = 768,
}

local function GetCurrentTargetGUID()
    if not UnitExists or not UnitGUID then return nil end
    if not UnitExists("target") then return nil end
    local ok, guid = pcall(UnitGUID, "target")
    if not ok or not guid or (issecretvalue and issecretvalue(guid)) then return nil end
    return guid
end

local function IsInCatForm()
    if GetShapeshiftFormID then
        local ok, formID = pcall(GetShapeshiftFormID)
        if ok and not (issecretvalue and issecretvalue(formID)) then
            return formID == CAT_FORM_ID
        end
    end

    if not GetNumShapeshiftForms or not GetShapeshiftFormInfo then
        return false
    end

    local okCount, formCount = pcall(GetNumShapeshiftForms)
    if not okCount or type(formCount) ~= "number" then
        return false
    end

    for index = 1, formCount do
        local okInfo, _, _, active, _, spellID = pcall(GetShapeshiftFormInfo, index)
        if okInfo
            and not (issecretvalue and (issecretvalue(active) or issecretvalue(spellID)))
            and active
            and spellID == SPELLS.CatForm
        then
            return true
        end
    end

    return false
end

local function HasPlayerAura(spellID)
    if not C_UnitAuras or not C_UnitAuras.GetPlayerAuraBySpellID then
        return false
    end

    local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellID)
    if not ok or (issecretvalue and issecretvalue(aura)) then
        return false
    end

    return aura ~= nil
end

------------------------------------------------------------------------
-- Profile definition
------------------------------------------------------------------------

local Profile = {
    id = "Druid.Feral.DruidOfTheClaw",
    displayName = "Feral Druid of the Claw",
    specID = 103,
    -- Hero-tree detection: prefer Blizzard's authoritative hero-talent
    -- SubTree API when it is available. SubTreeID 21 identifies Druid of the
    -- Claw for both Feral and Guardian Druid. Keep the Ravage marker as a
    -- legacy fallback only, so activation still degrades cleanly if the
    -- C_ClassTalents surface is unavailable.
    heroTalentSubTreeID = 21,
    markerSpell = 441583, -- Ravage (Druid of the Claw exclusive)
    version = 1,

    state = {
        tigersFuryUntil = 0,
        berserkUntil = 0,
        rakeUntilByTargetGUID = {},
    },

    rules = {
        -- Filter utility spells
        { type = "BLACKLIST", spellID = 106839 }, -- Skull Bash

        -- Assisted Combat can leak Cat Form into the queue even while already
        -- shapeshifted. Suppress the duplicate suggestion locally.
        {
            type = "BLACKLIST_CONDITIONAL",
            spellID = SPELLS.CatForm,
            condition = { type = "cat_form_active" },
        },

        -- Mark of the Wild should be suppressed while the player buff is
        -- already present.
        {
            type = "BLACKLIST_CONDITIONAL",
            spellID = SPELLS.MarkOfTheWild,
            condition = { type = "mark_of_the_wild_active" },
        },

        -- Rake is a target DoT, not a same-target filler every GCD. Suppress it
        -- until the local pandemic refresh window using a per-target cast timer.
        {
            type = "BLACKLIST_CONDITIONAL",
            spellID = SPELLS.Rake,
            condition = { type = "rake_active_on_target" },
        },

        -- Apex Predator: PREFER Ferocious Bite when proc is active (glow detection)
        {
            type = "PREFER",
            spellID = 22568, -- Ferocious Bite
            reason = "Apex Predator",
            condition = { type = "spell_glowing", spellID = 22568 },
        },

        -- Prefer Berserk during Tiger's Fury for maximum burst alignment
        {
            type = "PREFER",
            spellID = SPELLS.Berserk,
            reason = "TF Burst",
            condition = {
                type = "and",
                left  = { type = "in_tigers_fury" },
                right = { type = "cd_ready", spellID = SPELLS.Berserk },
            },
        },
    },
}

------------------------------------------------------------------------
-- State machine
------------------------------------------------------------------------

function Profile:ResetState()
    self.state.tigersFuryUntil = 0
    self.state.berserkUntil = 0
    self.state.rakeUntilByTargetGUID = {}
end

function Profile:OnSpellCast(spellID)
    local now = GetTime()
    local s = self.state

    if spellID == SPELLS.TigerFury then -- Tiger's Fury
        s.tigersFuryUntil = now + TIGERS_FURY_DURATION

    elseif spellID == SPELLS.Berserk then -- Berserk
        s.berserkUntil = now + BERSERK_DURATION

    elseif spellID == SPELLS.Incarnation then -- Incarnation: Avatar of Ashamane
        s.berserkUntil = now + INCARNATION_DURATION

    elseif spellID == SPELLS.Rake then -- Rake
        local guid = GetCurrentTargetGUID()
        if guid then
            s.rakeUntilByTargetGUID[guid] = now + RAKE_DURATION
        end
    end
end

function Profile:OnCombatEnd()
    self.state.tigersFuryUntil = 0
    self.state.berserkUntil = 0
    self.state.rakeUntilByTargetGUID = {}
end

------------------------------------------------------------------------
-- Profile-specific condition evaluation
------------------------------------------------------------------------

function Profile:EvalCondition(cond)
    local s = self.state

    if cond.type == "in_tigers_fury" then
        return GetTime() < s.tigersFuryUntil

    elseif cond.type == "in_berserk" then
        return GetTime() < s.berserkUntil

    elseif cond.type == "cat_form_active" then
        return IsInCatForm()

    elseif cond.type == "mark_of_the_wild_active" then
        return HasPlayerAura(SPELLS.MarkOfTheWild)

    elseif cond.type == "rake_active_on_target" then
        local guid = GetCurrentTargetGUID()
        if not guid then return false end
        local rakeUntil = s.rakeUntilByTargetGUID[guid]
        if not rakeUntil then return false end
        return (rakeUntil - GetTime()) > RAKE_PANDEMIC_SECONDS
    end

    return nil -- not handled by this profile
end

------------------------------------------------------------------------
-- Debug output
------------------------------------------------------------------------

function Profile:GetDebugLines()
    local s = self.state
    local tfRemaining = s.tigersFuryUntil - GetTime()
    local bsRemaining = s.berserkUntil - GetTime()
    local rakeStatus = "unknown"
    local guid = GetCurrentTargetGUID()
    if guid then
        local rakeUntil = s.rakeUntilByTargetGUID[guid]
        if rakeUntil and rakeUntil > GetTime() then
            rakeStatus = string.format("%.1fs remaining", rakeUntil - GetTime())
        else
            rakeStatus = "refreshable"
        end
    else
        rakeStatus = "no target"
    end
    return {
        "  Tiger's Fury: " .. (tfRemaining > 0
            and string.format("%.1fs remaining", tfRemaining)
            or "inactive"),
        "  Berserk CD: " .. (
            TrueShot.CDLedger and TrueShot.CDLedger:IsOnCooldown(SPELLS.Berserk)
            and string.format("%.1fs remaining", TrueShot.CDLedger:SecondsUntilReady(SPELLS.Berserk))
            or "ready"
        ),
        "  Berserk: " .. (bsRemaining > 0
            and string.format("%.1fs remaining", bsRemaining)
            or "inactive"),
        "  Mark of the Wild: " .. (HasPlayerAura(SPELLS.MarkOfTheWild) and "active" or "inactive"),
        "  Cat Form: " .. (IsInCatForm() and "active" or "inactive"),
        "  Rake on target: " .. rakeStatus,
    }
end

------------------------------------------------------------------------
-- Phase detection (for overlay display)
------------------------------------------------------------------------

function Profile:GetPhase()
    if not UnitAffectingCombat("player") then return nil end
    local s = self.state
    if GetTime() < s.berserkUntil then return "Berserk" end
    if GetTime() < s.tigersFuryUntil then return "Tiger's Fury" end
    return nil
end

------------------------------------------------------------------------
-- Register
------------------------------------------------------------------------

Engine:RegisterProfile(Profile)

if TrueShot.CustomProfile then
    TrueShot.CustomProfile.RegisterConditionSchema("Druid.Feral.DruidOfTheClaw", {
        { id = "in_tigers_fury", label = "In Tiger's Fury", params = {} },
        { id = "in_berserk",     label = "In Berserk",      params = {} },
        { id = "mark_of_the_wild_active", label = "Mark of the Wild Active", params = {} },
        { id = "cat_form_active", label = "Cat Form Active", params = {} },
        { id = "rake_active_on_target", label = "Rake Active On Target", params = {} },
    })
end
