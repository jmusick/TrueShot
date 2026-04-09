-- TrueShot Rule Builder: visual rule editor for custom profiles
-- Two-panel split frame (WeakAuras pattern)

TrueShot = TrueShot or {}
TrueShot.RuleBuilder = {}

local RuleBuilder = TrueShot.RuleBuilder
local CustomProfile = TrueShot.CustomProfile

------------------------------------------------------------------------
-- Constants
------------------------------------------------------------------------

local FRAME_WIDTH = 780
local FRAME_HEIGHT = 520
local LEFT_PANEL_WIDTH = 280
local RULE_ROW_HEIGHT = 28
local MAX_RULE_ROWS = 40

local TYPE_COLORS = {
    PIN                  = { r = 1.0, g = 0.4, b = 0.4 },
    PREFER               = { r = 0.4, g = 0.4, b = 1.0 },
    BLACKLIST             = { r = 0.6, g = 0.6, b = 0.6 },
    BLACKLIST_CONDITIONAL = { r = 0.6, g = 0.6, b = 0.6 },
}

local TYPE_LABELS = {
    PIN                  = "PIN",
    PREFER               = "PREFER",
    BLACKLIST             = "BL",
    BLACKLIST_CONDITIONAL = "BL?",
}

------------------------------------------------------------------------
-- State
------------------------------------------------------------------------

local _mainFrame = nil
local _leftScrollChild = nil
local _rightPanel = nil
local _ruleRows = {}
local _selectedIndex = nil
local _editingData = nil  -- the custom data being edited
local _isCustomized = false

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------

local function GetSpellDisplay(spellID)
    if not spellID then return nil, "Unknown" end
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID) or "Spell " .. spellID
    local icon = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID) or 134400
    return icon, name
end

------------------------------------------------------------------------
-- Frame Creation
------------------------------------------------------------------------

local function CreateMainFrame()
    local f = CreateFrame("Frame", "TrueShotRuleBuilder", UIParent, "BackdropTemplate")
    f:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0.08, 0.08, 0.12, 0.95)
    f:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

    -- Title bar (draggable)
    local titleBar = CreateFrame("Frame", nil, f)
    titleBar:SetHeight(28)
    titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -4)
    titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() f:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)

    local titleText = titleBar:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    titleText:SetPoint("LEFT", titleBar, "LEFT", 8, 0)
    titleText:SetText("|cffabd473TrueShot|r Rule Builder")
    f._titleText = titleText

    -- Close button
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- Profile name label
    local profileLabel = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    profileLabel:SetPoint("LEFT", titleText, "RIGHT", 12, 0)
    f._profileLabel = profileLabel

    -- Divider line below title
    local divider = f:CreateTexture(nil, "ARTWORK")
    divider:SetHeight(1)
    divider:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -34)
    divider:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -34)
    divider:SetColorTexture(0.3, 0.3, 0.3, 1)

    -- Left panel (rule list)
    local leftPanel = CreateFrame("Frame", nil, f)
    leftPanel:SetPoint("TOPLEFT", f, "TOPLEFT", 8, -38)
    leftPanel:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 44)
    leftPanel:SetWidth(LEFT_PANEL_WIDTH)

    local leftScroll = CreateFrame("ScrollFrame", "TrueShotRBLeftScroll", leftPanel, "UIPanelScrollFrameTemplate")
    leftScroll:SetPoint("TOPLEFT", leftPanel, "TOPLEFT", 0, 0)
    leftScroll:SetPoint("BOTTOMRIGHT", leftPanel, "BOTTOMRIGHT", -22, 0)

    _leftScrollChild = CreateFrame("Frame", nil, leftScroll)
    _leftScrollChild:SetWidth(LEFT_PANEL_WIDTH - 22)
    _leftScrollChild:SetHeight(1)
    leftScroll:SetScrollChild(_leftScrollChild)

    -- Vertical divider between panels
    local vdivider = f:CreateTexture(nil, "ARTWORK")
    vdivider:SetWidth(1)
    vdivider:SetPoint("TOPLEFT", leftPanel, "TOPRIGHT", 4, 0)
    vdivider:SetPoint("BOTTOMLEFT", leftPanel, "BOTTOMRIGHT", 4, 0)
    vdivider:SetColorTexture(0.3, 0.3, 0.3, 1)

    -- Right panel
    _rightPanel = CreateFrame("Frame", nil, f)
    _rightPanel:SetPoint("TOPLEFT", leftPanel, "TOPRIGHT", 10, 0)
    _rightPanel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 44)

    -- Bottom bar
    local bottomBar = CreateFrame("Frame", nil, f)
    bottomBar:SetHeight(36)
    bottomBar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 8, 4)
    bottomBar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 4)

    -- Bottom divider
    local bdivider = f:CreateTexture(nil, "ARTWORK")
    bdivider:SetHeight(1)
    bdivider:SetPoint("BOTTOMLEFT", bottomBar, "TOPLEFT", 0, 0)
    bdivider:SetPoint("BOTTOMRIGHT", bottomBar, "TOPRIGHT", 0, 0)
    bdivider:SetColorTexture(0.3, 0.3, 0.3, 1)

    -- Customize / Apply / Reset buttons
    local customizeBtn = CreateFrame("Button", nil, bottomBar, "UIPanelButtonTemplate")
    customizeBtn:SetSize(100, 22)
    customizeBtn:SetPoint("LEFT", bottomBar, "LEFT", 0, 0)
    customizeBtn:SetText("Customize")
    customizeBtn:SetScript("OnClick", function()
        RuleBuilder:OnCustomize()
    end)
    f._customizeBtn = customizeBtn

    local applyBtn = CreateFrame("Button", nil, bottomBar, "UIPanelButtonTemplate")
    applyBtn:SetSize(80, 22)
    applyBtn:SetPoint("RIGHT", bottomBar, "RIGHT", 0, 0)
    applyBtn:SetText("Apply")
    applyBtn:SetScript("OnClick", function()
        RuleBuilder:OnApply()
    end)
    f._applyBtn = applyBtn

    local resetBtn = CreateFrame("Button", nil, bottomBar, "UIPanelButtonTemplate")
    resetBtn:SetSize(110, 22)
    resetBtn:SetPoint("RIGHT", applyBtn, "LEFT", -6, 0)
    resetBtn:SetText("Reset to Built-in")
    resetBtn:SetScript("OnClick", function()
        StaticPopup_Show("TRUESHOT_RESET_CUSTOM")
    end)
    f._resetBtn = resetBtn

    local addRuleBtn = CreateFrame("Button", nil, bottomBar, "UIPanelButtonTemplate")
    addRuleBtn:SetSize(80, 22)
    addRuleBtn:SetPoint("LEFT", customizeBtn, "RIGHT", 6, 0)
    addRuleBtn:SetText("+ Add Rule")
    addRuleBtn:SetScript("OnClick", function()
        RuleBuilder:OnAddRule()
    end)
    f._addRuleBtn = addRuleBtn

    local addVarBtn = CreateFrame("Button", nil, bottomBar, "UIPanelButtonTemplate")
    addVarBtn:SetSize(100, 22)
    addVarBtn:SetPoint("LEFT", addRuleBtn, "RIGHT", 6, 0)
    addVarBtn:SetText("+ State Var")
    addVarBtn:SetScript("OnClick", function()
        RuleBuilder:OnAddStateVar()
    end)
    f._addVarBtn = addVarBtn

    f:Hide()
    return f
end

-- Static popup for reset confirmation
StaticPopupDialogs["TRUESHOT_RESET_CUSTOM"] = {
    text = "Reset to built-in profile? All custom rules and state variables will be deleted.",
    button1 = "Reset",
    button2 = "Cancel",
    OnAccept = function()
        RuleBuilder:OnReset()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

------------------------------------------------------------------------
-- Rule Row Pool
------------------------------------------------------------------------

local function CreateRuleRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(LEFT_PANEL_WIDTH - 22, RULE_ROW_HEIGHT)
    row:EnableMouse(true)

    -- Selection highlight
    local highlight = row:CreateTexture(nil, "BACKGROUND")
    highlight:SetAllPoints()
    highlight:SetColorTexture(1, 1, 1, 0.08)
    highlight:Hide()
    row._highlight = highlight

    -- Selected indicator
    local selected = row:CreateTexture(nil, "BACKGROUND")
    selected:SetAllPoints()
    selected:SetColorTexture(0.3, 0.5, 0.3, 0.2)
    selected:Hide()
    row._selected = selected

    -- Type badge
    local badge = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    badge:SetPoint("LEFT", row, "LEFT", 4, 0)
    badge:SetWidth(30)
    badge:SetJustifyH("LEFT")
    row._badge = badge

    -- Spell icon
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("LEFT", badge, "RIGHT", 4, 0)
    row._icon = icon

    -- Spell name + reason
    local nameText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    nameText:SetPoint("LEFT", icon, "RIGHT", 4, 0)
    nameText:SetPoint("RIGHT", row, "RIGHT", -50, 0)
    nameText:SetJustifyH("LEFT")
    nameText:SetWordWrap(false)
    row._nameText = nameText

    -- Up button
    local upBtn = CreateFrame("Button", nil, row)
    upBtn:SetSize(14, 14)
    upBtn:SetPoint("RIGHT", row, "RIGHT", -18, 4)
    upBtn:SetNormalTexture("Interface\\Buttons\\Arrow-Up-Up")
    upBtn:SetHighlightTexture("Interface\\Buttons\\Arrow-Up-Highlight")
    upBtn:SetScript("OnClick", function()
        RuleBuilder:MoveRule(index, -1)
    end)
    row._upBtn = upBtn

    -- Down button
    local downBtn = CreateFrame("Button", nil, row)
    downBtn:SetSize(14, 14)
    downBtn:SetPoint("RIGHT", row, "RIGHT", -18, -4)
    downBtn:SetNormalTexture("Interface\\Buttons\\Arrow-Down-Up")
    downBtn:SetHighlightTexture("Interface\\Buttons\\Arrow-Down-Highlight")
    downBtn:SetScript("OnClick", function()
        RuleBuilder:MoveRule(index, 1)
    end)
    row._downBtn = downBtn

    -- Delete button
    local delBtn = CreateFrame("Button", nil, row)
    delBtn:SetSize(14, 14)
    delBtn:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    local delTex = delBtn:CreateTexture(nil, "ARTWORK")
    delTex:SetAllPoints()
    delTex:SetColorTexture(0.8, 0.2, 0.2, 0.6)
    delBtn:SetScript("OnClick", function()
        RuleBuilder:DeleteRule(index)
    end)
    row._delBtn = delBtn

    -- Hover scripts
    row:SetScript("OnEnter", function() highlight:Show() end)
    row:SetScript("OnLeave", function() highlight:Hide() end)
    row:SetScript("OnClick", function()
        RuleBuilder:SelectRule(index)
    end)

    row:Hide()
    return row
end

------------------------------------------------------------------------
-- Rule List Rendering
------------------------------------------------------------------------

function RuleBuilder:RefreshRuleList()
    local rules = _editingData and _editingData.rules or {}

    -- Ensure enough rows
    while #_ruleRows < math.min(#rules, MAX_RULE_ROWS) do
        local idx = #_ruleRows + 1
        _ruleRows[idx] = CreateRuleRow(_leftScrollChild, idx)
    end

    -- Update rows
    for i = 1, MAX_RULE_ROWS do
        local row = _ruleRows[i]
        if not row then break end

        if i <= #rules then
            local rule = rules[i]
            local tc = TYPE_COLORS[rule.type] or TYPE_COLORS.BLACKLIST
            local tl = TYPE_LABELS[rule.type] or "?"

            row._badge:SetText("|cff" .. string.format("%02x%02x%02x", tc.r * 255, tc.g * 255, tc.b * 255) .. tl .. "|r")

            local spellIcon, spellName = GetSpellDisplay(rule.spellID)
            row._icon:SetTexture(spellIcon)
            row._nameText:SetText(spellName .. (rule.reason and (" - " .. rule.reason) or ""))

            -- Selection state
            if i == _selectedIndex then
                row._selected:Show()
            else
                row._selected:Hide()
            end

            -- Show/hide reorder buttons based on customization state
            if _isCustomized then
                row._upBtn:SetShown(i > 1)
                row._downBtn:SetShown(i < #rules)
                row._delBtn:Show()
            else
                row._upBtn:Hide()
                row._downBtn:Hide()
                row._delBtn:Hide()
            end

            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", _leftScrollChild, "TOPLEFT", 0, -(i - 1) * RULE_ROW_HEIGHT)
            row:Show()
        else
            row:Hide()
        end
    end

    -- Update scroll child height
    _leftScrollChild:SetHeight(math.max(1, #rules * RULE_ROW_HEIGHT))
end

------------------------------------------------------------------------
-- Public API
------------------------------------------------------------------------

function RuleBuilder:Toggle()
    if not _mainFrame then
        _mainFrame = CreateMainFrame()
    end
    if _mainFrame:IsShown() then
        _mainFrame:Hide()
    else
        self:Open()
    end
end

function RuleBuilder:Open()
    if not _mainFrame then
        _mainFrame = CreateMainFrame()
    end

    local Engine = TrueShot.Engine
    local profile = Engine and Engine.activeProfile
    if not profile then
        print("|cffff0000[TS]|r No active profile.")
        return
    end

    -- Determine base profile (unwrap if customized)
    local baseProfile = profile._baseProfile or profile
    local profileId = baseProfile.id

    -- Update title
    _mainFrame._profileLabel:SetText("|cffaaaaaa" .. (baseProfile.displayName or profileId) .. "|r")

    -- Load existing custom data or show built-in rules read-only
    local customData = CustomProfile.GetCustomData(profileId)
    if customData then
        _editingData = customData
        _isCustomized = true
    else
        -- Read-only view of built-in rules
        _editingData = {
            rules = baseProfile.rules or {},
            stateVarDefs = {},
            triggers = {},
            rotationalSpells = baseProfile.rotationalSpells or {},
        }
        _isCustomized = false
    end

    _selectedIndex = nil
    self:RefreshRuleList()
    self:UpdateButtonStates()
    self:ClearRightPanel()
    _mainFrame:Show()
end

function RuleBuilder:UpdateButtonStates()
    if not _mainFrame then return end
    _mainFrame._customizeBtn:SetShown(not _isCustomized)
    _mainFrame._applyBtn:SetShown(_isCustomized)
    _mainFrame._resetBtn:SetShown(_isCustomized)
    _mainFrame._addRuleBtn:SetShown(_isCustomized)
    _mainFrame._addVarBtn:SetShown(_isCustomized)
end

function RuleBuilder:ClearRightPanel()
    -- Clear all children of the right panel
    if not _rightPanel then return end
    for _, child in pairs({ _rightPanel:GetChildren() }) do
        child:Hide()
        child:SetParent(nil)
    end

    if not _isCustomized then
        local hint = _rightPanel:CreateFontString(nil, "ARTWORK", "GameFontDisable")
        hint:SetPoint("CENTER")
        hint:SetText("Read-only view.\nClick 'Customize' to edit.")
    elseif not _selectedIndex then
        local hint = _rightPanel:CreateFontString(nil, "ARTWORK", "GameFontDisable")
        hint:SetPoint("CENTER")
        hint:SetText("Select a rule to edit,\nor add a new one.")
    end
end

------------------------------------------------------------------------
-- Actions
------------------------------------------------------------------------

function RuleBuilder:OnCustomize()
    local Engine = TrueShot.Engine
    local profile = Engine and Engine.activeProfile
    if not profile then return end

    local baseProfile = profile._baseProfile or profile
    local customData = CustomProfile.ForkProfile(baseProfile)
    _editingData = customData
    _isCustomized = true
    _selectedIndex = nil
    self:RefreshRuleList()
    self:UpdateButtonStates()
    self:ClearRightPanel()
    print("|cff00ff00[TS]|r Profile customized. Edit rules and click Apply.")
end

function RuleBuilder:OnApply()
    if not _editingData or not _isCustomized then return end

    local Engine = TrueShot.Engine
    local profile = Engine and Engine.activeProfile
    if not profile then return end

    local baseProfile = profile._baseProfile or profile
    CustomProfile.SaveCustomData(baseProfile.id, _editingData)
    CustomProfile.InvalidateWrapper(baseProfile.id)

    -- Register custom conditions
    CustomProfile.RegisterCustomConditions(baseProfile.id, _editingData.stateVarDefs)

    -- Re-activate to pick up changes
    local specID = baseProfile.specID
    Engine:ActivateProfile(specID)

    print("|cff00ff00[TS]|r Custom rules applied.")
end

function RuleBuilder:OnReset()
    local Engine = TrueShot.Engine
    local profile = Engine and Engine.activeProfile
    if not profile then return end

    local baseProfile = profile._baseProfile or profile
    CustomProfile.DeleteCustomData(baseProfile.id)
    CustomProfile.InvalidateWrapper(baseProfile.id)

    -- Re-activate to revert to built-in
    Engine:ActivateProfile(baseProfile.specID)

    -- Refresh UI
    self:Open()
    print("|cff00ff00[TS]|r Reset to built-in profile.")
end

function RuleBuilder:SelectRule(index)
    _selectedIndex = index
    self:RefreshRuleList()
    self:ShowRuleEditor(index)
end

function RuleBuilder:MoveRule(index, direction)
    if not _editingData or not _isCustomized then return end
    local rules = _editingData.rules
    local newIndex = index + direction
    if newIndex < 1 or newIndex > #rules then return end
    rules[index], rules[newIndex] = rules[newIndex], rules[index]
    _selectedIndex = newIndex
    self:RefreshRuleList()
    -- Update row click handlers for swapped indices
    if _ruleRows[index] then
        _ruleRows[index]:SetScript("OnClick", function() RuleBuilder:SelectRule(index) end)
    end
    if _ruleRows[newIndex] then
        _ruleRows[newIndex]:SetScript("OnClick", function() RuleBuilder:SelectRule(newIndex) end)
    end
end

function RuleBuilder:DeleteRule(index)
    if not _editingData or not _isCustomized then return end
    table.remove(_editingData.rules, index)
    if _selectedIndex == index then
        _selectedIndex = nil
        self:ClearRightPanel()
    elseif _selectedIndex and _selectedIndex > index then
        _selectedIndex = _selectedIndex - 1
    end
    self:RefreshRuleList()
end

function RuleBuilder:OnAddRule()
    if not _editingData or not _isCustomized then return end
    local newRule = {
        type = "PIN",
        spellID = nil,
        reason = "",
        condition = nil,
    }
    table.insert(_editingData.rules, newRule)
    _selectedIndex = #_editingData.rules
    self:RefreshRuleList()
    self:ShowRuleEditor(_selectedIndex)
end

function RuleBuilder:OnAddStateVar()
    -- Placeholder: Task 8 implements the state variable editor
end

function RuleBuilder:ShowRuleEditor(index)
    -- Placeholder: Task 7 implements the right panel editor
    self:ClearRightPanel()
end
