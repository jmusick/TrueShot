-- Tests for Base64Decode hardening (Fix 2: reject invalid characters/structure)
-- Run: lua tests/test_base64_decode.lua

-- Minimal WoW API stubs
TrueShot = TrueShot or {}
TrueShot.Engine = { ActivateProfile = function() end }
TrueShot_DB = TrueShot_DB or {}

-- Load ProfileIO (needs CustomProfile for GetAllConditionSchemas)
dofile("CustomProfile.lua")
dofile("ProfileIO.lua")

local ProfileIO = TrueShot.ProfileIO
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

------------------------------------------------------------------------
-- Roundtrip test: Encode -> Decode must be lossless
------------------------------------------------------------------------

test("valid roundtrip encode/decode", function()
    -- Build a minimal valid profile
    local profile = {
        schemaVersion = 1,
        profileId = "Test.Profile",
        specID = 253,
        markerSpell = 12345,
        displayName = "Test Profile",
        rules = {},
    }
    local encoded = ProfileIO.Encode(profile)
    assert(encoded, "Encode should succeed")
    assert(encoded:match("^!TS1!"), "Should have version header")

    local decoded, err = ProfileIO.Decode(encoded)
    assert(decoded, "Decode should succeed: " .. tostring(err))
    assert(decoded.profileId == "Test.Profile", "profileId should roundtrip")
    assert(decoded.specID == 253, "specID should roundtrip")
end)

------------------------------------------------------------------------
-- Invalid character rejection
------------------------------------------------------------------------

test("invalid base64 character rejected", function()
    -- $ is not in the base64 alphabet
    local bad = "!TS1!AAAA$$$$BBBB"
    local data, err = ProfileIO.Decode(bad)
    assert(not data, "Should reject invalid characters")
    assert(err:find("base64") or err:find("Base64"),
        "Error should mention base64: " .. tostring(err))
end)

test("unicode character in base64 rejected", function()
    local bad = "!TS1!AAAA\xC3\xA9\xC3\xA9BB"
    local data, err = ProfileIO.Decode(bad)
    assert(not data, "Should reject unicode characters")
end)

------------------------------------------------------------------------
-- Invalid structure
------------------------------------------------------------------------

test("empty payload rejected", function()
    local data, err = ProfileIO.Decode("!TS1!")
    assert(not data, "Should reject empty payload")
end)

test("single character payload rejected (invalid length)", function()
    -- After stripping padding, length 1 mod 4 is invalid in base64
    local data, err = ProfileIO.Decode("!TS1!A")
    assert(not data, "Should reject length-1 payload")
    assert(err:find("length") or err:find("base64"),
        "Error should mention length or base64: " .. tostring(err))
end)

test("padding-only payload rejected", function()
    local data, err = ProfileIO.Decode("!TS1!====")
    assert(not data, "Should reject padding-only payload")
end)

------------------------------------------------------------------------
-- Valid edge cases that must still work
------------------------------------------------------------------------

test("base64 with padding accepted", function()
    -- "Hi" encodes to "SGk=" in base64
    -- We can't test this directly through Decode (needs valid serialized data),
    -- but we can verify the encoder produces valid output
    local profile = {
        schemaVersion = 1,
        profileId = "X",
        specID = 1,
        markerSpell = 1,
        displayName = "X",
        rules = {},
    }
    local encoded = ProfileIO.Encode(profile)
    -- Re-decode should work
    local decoded, err = ProfileIO.Decode(encoded)
    assert(decoded, "Padded base64 should decode: " .. tostring(err))
end)

test("base64 with whitespace in payload accepted", function()
    local profile = {
        schemaVersion = 1,
        profileId = "Test.WS",
        specID = 253,
        markerSpell = 1,
        displayName = "WS Test",
        rules = {},
    }
    local encoded = ProfileIO.Encode(profile)
    -- Insert whitespace into the payload
    local header, payload = encoded:match("^(!TS1!)(.+)$")
    local spaced = header .. payload:sub(1, 4) .. " \n " .. payload:sub(5)
    local decoded, err = ProfileIO.Decode(spaced)
    assert(decoded, "Whitespace in base64 should be stripped: " .. tostring(err))
    assert(decoded.profileId == "Test.WS", "Data should survive whitespace")
end)

------------------------------------------------------------------------
print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then os.exit(1) end
