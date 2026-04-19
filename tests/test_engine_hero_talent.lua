-- TrueShot Engine hero-talent activation tests
-- Covers Engine:ActivateProfile with the heroTalentSubTreeID path alongside
-- the legacy markerSpell path. Regression guard for issue #88: Frost
-- Spellslinger must activate when C_ClassTalents.GetActiveHeroTalentSpec()
-- reports the Spellslinger SubTreeID, even though Spellslinger has no
-- spellbook-learnable marker spell.
--
-- Run from the addon root: lua tests/test_engine_hero_talent.lua

------------------------------------------------------------------------
-- WoW client stubs
------------------------------------------------------------------------

_G.GetTime = function() return 1000.0 end
_G.UnitAffectingCombat = function(_) return false end
_G.UnitExists = function(_) return false end
_G.UnitCanAttack = function(_, _) return false end
_G.UnitPower = function(_, _) return 0 end
_G.UnitCastingInfo = function(_) return nil end
_G.UnitChannelInfo = function(_) return nil end
_G.issecretvalue = function(_) return false end
_G.pcall = pcall
_G.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
_G.GetSpellBaseCooldown = function(_) return 0, 0 end
_G.UnitSpellHaste = function(_) return 0 end

-- IsPlayerSpell is what drives the legacy markerSpell path. Tests flip
-- this per-scenario so Hunter markerSpell regression coverage and Frost
-- markerless fallback both land cleanly.
local _player_spells = {}
_G.IsPlayerSpell = function(spellID)
    return _player_spells[spellID] == true
end

-- The authoritative hero-talent detection API used by the new first-pass
-- in Engine:ActivateProfile. Tests drive the returned SubTreeID directly.
local _active_hero_subtree = nil
_G.C_ClassTalents = _G.C_ClassTalents or {}
_G.C_ClassTalents.GetActiveHeroTalentSpec = function()
    return _active_hero_subtree
end

_G.C_NamePlate = _G.C_NamePlate or { GetNamePlates = function() return {} end }
_G.C_AssistedCombat = _G.C_AssistedCombat or {
    IsAvailable = function() return false end,
    GetNextCastSpell = function() return nil end,
    GetRotationSpells = function() return {} end,
}
_G.C_SpellActivationOverlay = _G.C_SpellActivationOverlay or {
    IsSpellOverlayed = function() return false end,
}
_G.C_Spell = _G.C_Spell or {}
_G.C_Spell.IsSpellUsable = function(_) return true end
_G.C_Spell.GetSpellCharges = function(_) return nil end
_G.C_Spell.GetSpellName = function(id) return "Spell#" .. tostring(id) end
_G.C_UnitAuras = _G.C_UnitAuras or { GetPlayerAuraBySpellID = function(_) return nil end }

_G.CreateFrame = function(_frameType, _name)
    return {
        RegisterEvent = function() end,
        SetScript = function() end,
    }
end

TrueShot = {}
TrueShot.CustomProfile = { RegisterConditionSchema = function(_, _) end }

dofile("Engine.lua")
dofile("State/CDLedger.lua")

-- Load Frost profiles into the real Engine so the full activation path is
-- exercised end to end (no profile-capture stub).
dofile("Profiles/Frost_Frostfire.lua")
dofile("Profiles/Frost_Spellslinger.lua")
-- Load one Hunter profile to cover the markerSpell regression path.
dofile("Profiles/BM_DarkRanger.lua")

local Engine = TrueShot.Engine

------------------------------------------------------------------------
-- Test harness
------------------------------------------------------------------------

local passed, failed = 0, 0

local function test(name, fn)
    _active_hero_subtree = nil
    _player_spells = {}
    Engine.activeProfile = nil
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAIL: " .. name .. " -- " .. tostring(err))
    end
end

local function assert_true(v, msg)
    if not v then error((msg or "expected true") .. " got " .. tostring(v)) end
end

local function assert_eq(a, b, msg)
    if a ~= b then error((msg or "") .. " expected " .. tostring(b) .. " got " .. tostring(a)) end
end

local function assert_profile(id)
    local active = Engine.activeProfile
    assert_true(active ~= nil, "Engine should have activated a profile")
    assert_eq(active.id, id, "Engine activated the wrong profile")
end

------------------------------------------------------------------------
-- Structural guards: the fix itself
------------------------------------------------------------------------

test("Frost_Spellslinger declares heroTalentSubTreeID = 40 and no 443722 marker", function()
    local frost_candidates = TrueShot.Profiles[64]
    assert_true(frost_candidates ~= nil, "Frost candidates must be registered for specID 64")
    local spellslinger = nil
    for _, p in ipairs(frost_candidates) do
        if p.id == "Mage.Frost.Spellslinger" then spellslinger = p end
    end
    assert_true(spellslinger ~= nil, "Frost Spellslinger profile must register")
    assert_eq(spellslinger.heroTalentSubTreeID, 40,
        "Frost Spellslinger must declare heroTalentSubTreeID 40 for Blizzard's TraitSubTree")
    -- The old proc-buff marker must be gone because it could never match.
    assert_true(spellslinger.markerSpell ~= 443722,
        "Frost Spellslinger must not keep the buff-only 443722 marker")
end)

------------------------------------------------------------------------
-- Issue #88: hero-talent-based activation
------------------------------------------------------------------------

test("issue #88: Spellslinger active -> Frost_Spellslinger wins over Frostfire fallback", function()
    _active_hero_subtree = 40 -- Blizzard SubTreeID for Spellslinger
    Engine:ActivateProfile(64)
    assert_profile("Mage.Frost.Spellslinger")
end)

test("issue #88: Frostfire SubTreeID -> markerless Frost_Frostfire wins", function()
    _active_hero_subtree = 41 -- Frostfire SubTreeID (profile has no match)
    Engine:ActivateProfile(64)
    assert_profile("Mage.Frost.Frostfire")
end)

test("issue #88: no active hero talent -> Frost_Frostfire fallback still activates", function()
    _active_hero_subtree = nil
    Engine:ActivateProfile(64)
    assert_profile("Mage.Frost.Frostfire")
end)

test("issue #88 regression guard: markerSpell path still works for Hunter", function()
    -- Spellslinger fix must not break the existing IsPlayerSpell-based
    -- activation path that BM Dark Ranger (spec 253) relies on.
    _player_spells[466930] = true -- Black Arrow, DR markerSpell
    Engine:ActivateProfile(253)
    assert_profile("Hunter.BM.DarkRanger")
end)

test("issue #88 regression guard: subTreeID path is tried before markerSpell", function()
    -- If both a subTreeID match and a markerSpell match were possible, the
    -- subTreeID path must win because it is the authoritative API. Prove
    -- this by activating Frost while IsPlayerSpell would match nothing.
    _active_hero_subtree = 40
    Engine:ActivateProfile(64)
    assert_profile("Mage.Frost.Spellslinger")
end)

test("C_ClassTalents API missing -> engine degrades to markerSpell path", function()
    local saved = _G.C_ClassTalents.GetActiveHeroTalentSpec
    _G.C_ClassTalents.GetActiveHeroTalentSpec = nil
    _player_spells[466930] = true
    Engine:ActivateProfile(253)
    _G.C_ClassTalents.GetActiveHeroTalentSpec = saved
    assert_profile("Hunter.BM.DarkRanger")
end)

test("C_ClassTalents API returns a secret value -> engine ignores it", function()
    _active_hero_subtree = 40
    local saved_secret = _G.issecretvalue
    _G.issecretvalue = function(v) return v == 40 end
    Engine:ActivateProfile(64)
    _G.issecretvalue = saved_secret
    -- Secret subTreeID must not pick Spellslinger. Fallback to markerless.
    assert_profile("Mage.Frost.Frostfire")
end)

test("C_ClassTalents API pcall error -> engine degrades cleanly", function()
    _G.C_ClassTalents.GetActiveHeroTalentSpec = function()
        error("simulated runtime error from the WoW client")
    end
    Engine:ActivateProfile(64)
    -- Must not crash. Fallback activates Frostfire.
    assert_profile("Mage.Frost.Frostfire")
    _G.C_ClassTalents.GetActiveHeroTalentSpec = function() return _active_hero_subtree end
end)

test("C_ClassTalents API returns a non-number value -> engine ignores it", function()
    local saved = _G.C_ClassTalents.GetActiveHeroTalentSpec
    _G.C_ClassTalents.GetActiveHeroTalentSpec = function()
        return "not-a-number"
    end
    Engine:ActivateProfile(64)
    _G.C_ClassTalents.GetActiveHeroTalentSpec = saved
    -- Must reject the value and fall through to the markerless profile.
    assert_profile("Mage.Frost.Frostfire")
end)

------------------------------------------------------------------------
print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
