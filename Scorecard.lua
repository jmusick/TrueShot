-- TrueShot Scorecard: post-combat alignment report
-- Consumes CombatTrace fight summary and outputs to chat

TrueShot = TrueShot or {}
TrueShot.Scorecard = {}

local Scorecard = TrueShot.Scorecard

------------------------------------------------------------------------
-- Configuration
------------------------------------------------------------------------

local MIN_COMBAT_DURATION = 8    -- seconds
local MIN_SCORED_CASTS = 5       -- minimum casts to generate report
local MAX_HISTORY = 100          -- max persisted fight summaries

------------------------------------------------------------------------
-- Chat report
------------------------------------------------------------------------

function Scorecard:OnCombatEnd(combatDuration)
    if not TrueShot.GetOpt("showScorecard") then return end

    local trace = TrueShot.CombatTrace
    if not trace then return end

    -- Gating: skip short fights
    if (combatDuration or 0) < MIN_COMBAT_DURATION then return end

    local summary = trace:GetFightSummary()
    if summary.scoredCasts < MIN_SCORED_CASTS then return end

    -- Format chat message
    local score = math.floor(summary.alignmentScore + 0.5)
    local parts = {
        string.format("|cff00ff00[TrueShot]|r Alignment: |cffffff00%d%%|r", score),
        string.format("%d/%d matched", summary.matches, summary.scoredCasts),
    }

    if summary.softMatches > 0 then
        parts[#parts + 1] = string.format("%d soft", summary.softMatches)
    end

    if summary.totalGapTime > 0.5 then
        parts[#parts + 1] = string.format("%.1fs idle", summary.totalGapTime)
    end

    print(table.concat(parts, " | "))

    -- Persist summary
    self:SaveFightSummary(summary, combatDuration)
end

------------------------------------------------------------------------
-- Persistence
------------------------------------------------------------------------

function Scorecard:SaveFightSummary(summary, combatDuration)
    if not TrueShotDB then return end
    if not TrueShotDB.scorecardHistory then
        TrueShotDB.scorecardHistory = {}
    end

    local history = TrueShotDB.scorecardHistory
    local profile = TrueShot.Engine and TrueShot.Engine.activeProfile

    history[#history + 1] = {
        timestamp = time(),
        duration = math.floor(combatDuration or 0),
        alignmentScore = math.floor(summary.alignmentScore + 0.5),
        matches = summary.matches,
        softMatches = summary.softMatches,
        misses = summary.misses,
        scoredCasts = summary.scoredCasts,
        gapTime = math.floor((summary.totalGapTime or 0) * 10 + 0.5) / 10,
        profileID = profile and profile.id or "unknown",
    }

    -- FIFO cap
    while #history > MAX_HISTORY do
        table.remove(history, 1)
    end
end

------------------------------------------------------------------------
-- Slash command: /ts score
------------------------------------------------------------------------

function Scorecard:PrintHistory(count)
    if not TrueShotDB or not TrueShotDB.scorecardHistory then
        print("|cff00ff00[TrueShot]|r No scorecard history yet.")
        return
    end

    local history = TrueShotDB.scorecardHistory
    count = math.min(count or 5, #history)

    print("|cff00ff00[TrueShot]|r Last " .. count .. " fights:")
    for i = #history, #history - count + 1, -1 do
        local h = history[i]
        local dt = date("%H:%M", h.timestamp)
        print(string.format(
            "  %s | %d%% | %d/%d matched | %.1fs idle | %ds | %s",
            dt, h.alignmentScore, h.matches, h.scoredCasts,
            h.gapTime or 0, h.duration or 0, h.profileID or "?"
        ))
    end
end
