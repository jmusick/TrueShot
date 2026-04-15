-- Tests for condition schema registry (Fix 1: per-source keying)
-- Run: lua tests/test_condition_registry.lua

-- Minimal WoW API stubs
TrueShot = TrueShot or {}
TrueShot.Engine = { ActivateProfile = function() end }

-- Stub WoW globals used by CustomProfile
TrueShot_DB = TrueShot_DB or {}

-- Load the module under test
dofile("CustomProfile.lua")

local CP = TrueShot.CustomProfile
local passed, failed = 0, 0

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAIL: " .. name .. " -- " .. tostring(err))
    end
end

local function assert_eq(a, b, msg)
    if a ~= b then
        error((msg or "") .. " expected " .. tostring(b) .. " got " .. tostring(a))
    end
end

------------------------------------------------------------------------
-- Tests
------------------------------------------------------------------------

test("duplicate condition IDs across profiles coexist", function()
    -- Register same ID from two different profiles
    CP.RegisterConditionSchema("Hunter.BM.DarkRanger", {
        { id = "ba_ready", label = "Black Arrow Ready", params = {} },
        { id = "unique_dr", label = "DR Only", params = {} },
    })
    CP.RegisterConditionSchema("Hunter.MM.DarkRanger", {
        { id = "ba_ready", label = "Black Arrow Ready", params = {} },
        { id = "unique_mm", label = "MM Only", params = {} },
    })

    -- GetConditionSchemasForProfile should return the right set
    local bm = CP.GetConditionSchemasForProfile("Hunter.BM.DarkRanger")
    local mm = CP.GetConditionSchemasForProfile("Hunter.MM.DarkRanger")

    -- BM should see: engine conditions + ba_ready + unique_dr
    local bm_ids = {}
    for _, s in ipairs(bm) do bm_ids[s.id] = true end
    assert(bm_ids["ba_ready"], "BM should see ba_ready")
    assert(bm_ids["unique_dr"], "BM should see unique_dr")
    assert(not bm_ids["unique_mm"], "BM should NOT see unique_mm")

    -- MM should see: engine conditions + ba_ready + unique_mm
    local mm_ids = {}
    for _, s in ipairs(mm) do mm_ids[s.id] = true end
    assert(mm_ids["ba_ready"], "MM should see ba_ready")
    assert(mm_ids["unique_mm"], "MM should see unique_mm")
    assert(not mm_ids["unique_dr"], "MM should NOT see unique_dr")
end)

test("GetAllConditionSchemas returns all unique IDs", function()
    local all = CP.GetAllConditionSchemas()
    assert(all["ba_ready"], "ba_ready should be in flat view")
    assert(all["unique_dr"], "unique_dr should be in flat view")
    assert(all["unique_mm"], "unique_mm should be in flat view")
end)

test("engine conditions visible to all profiles", function()
    local schemas = CP.GetConditionSchemasForProfile("Hunter.BM.DarkRanger")
    local ids = {}
    for _, s in ipairs(schemas) do ids[s.id] = true end
    -- Engine conditions registered at load time
    assert(ids["ac_suggested"], "engine condition ac_suggested should be visible")
    assert(ids["spell_glowing"], "engine condition spell_glowing should be visible")
end)

test("_custom source conditions visible to profile", function()
    CP.RegisterConditionSchema("Hunter.BM.DarkRanger_custom", {
        { id = "custom_state", label = "Custom State Var", params = {} },
    })
    local schemas = CP.GetConditionSchemasForProfile("Hunter.BM.DarkRanger")
    local ids = {}
    for _, s in ipairs(schemas) do ids[s.id] = true end
    assert(ids["custom_state"], "_custom conditions should be visible")
end)

test("RegisterCustomConditions adds state var conditions", function()
    CP.RegisterCustomConditions("Hunter.BM.DarkRanger", {
        { name = "state_x", label = "State X" },
        { name = "state_y", label = "State Y" },
    })
    local schemas = CP.GetConditionSchemasForProfile("Hunter.BM.DarkRanger")
    local ids = {}
    for _, s in ipairs(schemas) do ids[s.id] = true end
    assert(ids["state_x"], "RegisterCustomConditions should make state_x visible")
    assert(ids["state_y"], "RegisterCustomConditions should make state_y visible")
end)

test("ClearCustomConditions removes state var conditions", function()
    CP.RegisterCustomConditions("Hunter.BM.DarkRanger", {
        { name = "state_z", label = "State Z" },
    })
    CP.ClearCustomConditions("Hunter.BM.DarkRanger")
    local schemas = CP.GetConditionSchemasForProfile("Hunter.BM.DarkRanger")
    local ids = {}
    for _, s in ipairs(schemas) do ids[s.id] = true end
    assert(not ids["state_z"], "ClearCustomConditions should remove state_z")
end)

test("RegisterCustomConditions replaces previous custom conditions", function()
    CP.RegisterCustomConditions("Hunter.MM.DarkRanger", {
        { name = "old_state", label = "Old" },
    })
    CP.RegisterCustomConditions("Hunter.MM.DarkRanger", {
        { name = "new_state", label = "New" },
    })
    local schemas = CP.GetConditionSchemasForProfile("Hunter.MM.DarkRanger")
    local ids = {}
    for _, s in ipairs(schemas) do ids[s.id] = true end
    assert(ids["new_state"], "new_state should be visible after re-register")
    assert(not ids["old_state"], "old_state should be gone after re-register")
end)

test("profile does not see unrelated profile conditions", function()
    CP.RegisterConditionSchema("Warlock.Demo.Tyrant", {
        { id = "tyrant_active", label = "Tyrant Active", params = {} },
    })
    local schemas = CP.GetConditionSchemasForProfile("Hunter.BM.DarkRanger")
    local ids = {}
    for _, s in ipairs(schemas) do ids[s.id] = true end
    assert(not ids["tyrant_active"], "BM Hunter should not see Warlock conditions")
end)

test("schemas sorted alphabetically by label", function()
    local schemas = CP.GetConditionSchemasForProfile("Hunter.BM.DarkRanger")
    for i = 2, #schemas do
        assert(schemas[i - 1].label <= schemas[i].label,
            "sort order violated: " .. schemas[i-1].label .. " > " .. schemas[i].label)
    end
end)

test("HasConditionForSource finds condition in correct source", function()
    -- ba_ready registered by both BM and MM DarkRanger (from earlier tests)
    assert(CP.HasConditionForSource("Hunter.BM.DarkRanger", "ba_ready"),
        "BM should have ba_ready")
    assert(CP.HasConditionForSource("Hunter.MM.DarkRanger", "ba_ready"),
        "MM should have ba_ready")
end)

test("HasConditionForSource returns false for wrong source", function()
    assert(not CP.HasConditionForSource("Hunter.MM.DarkRanger", "unique_dr"),
        "MM should not have unique_dr (belongs to BM)")
    assert(not CP.HasConditionForSource("Hunter.BM.DarkRanger", "unique_mm"),
        "BM should not have unique_mm (belongs to MM)")
end)

test("HasConditionForSource detects conflict even with duplicate IDs across profiles", function()
    -- Regression: with flat GetAllConditionSchemas(), if ba_ready's last registrant
    -- was MM, checking source==BM against the flat view would miss the conflict.
    -- HasConditionForSource queries the per-source table directly.
    CP.RegisterConditionSchema("Profile.A", {
        { id = "shared_cond", label = "Shared", params = {} },
    })
    CP.RegisterConditionSchema("Profile.B", {
        { id = "shared_cond", label = "Shared", params = {} },
    })
    -- Both profiles must detect the conflict independently
    assert(CP.HasConditionForSource("Profile.A", "shared_cond"),
        "Profile.A should detect shared_cond")
    assert(CP.HasConditionForSource("Profile.B", "shared_cond"),
        "Profile.B should detect shared_cond")
    -- And neither sees the other's unique conditions
    assert(not CP.HasConditionForSource("Profile.A", "unique_mm"),
        "Profile.A should not see MM-specific conditions")
end)

------------------------------------------------------------------------
print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
