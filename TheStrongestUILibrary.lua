-- TheStrongestUILibrary.lua
-- TheStrongest UI — Full Orion-style single-file library
-- Compatible as a loadstring payload OR as a ModuleScript (file already returns a table).
--
-- NOTE: This file includes:
--  * Auto-refreshing elements and global RefreshAll()
--  * Search/filter system (Window:AddSearchBox)
--  * Flags system, config save/load (executor-friendly), clipboard helper
--  * All widgets: Button, Toggle, Slider, Dropdown, Textbox, Keybind, ColorPicker, Label, Paragraph, DestroyButton
--  * Notifications, Loading screen, Time/Date in header, Profile panel
--  * Responsive mobile autosizing and draggable option
--  * Server-side stubs for whitelist/premium and Discord webhook (DO NOT store secrets in client code)
--
-- USAGE (one-liner to host on GitHub raw):
-- local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/Thestrongestman0080-Official/TheStrongestUI/main/TheStrongestUILibrary.lua"))()
-- Then: local Window = Library.CreateWindow({Name="MyHub", UIName="My UI", LoadingScreen=true, ConfigName="MyHubConfig"})

local TheStrongest = {}
TheStrongest.__index = TheStrongest

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

-- Helpers
local function new(class, props)
    local inst = Instance.new(class)
    if props then
        for k,v in pairs(props) do
            if k ~= "Parent" then
                pcall(function() inst[k] = v end)
            end
        end
        if props.Parent then inst.Parent = props.Parent end
    end
    return inst
end
local function isExecutor() return type(writefile) == "function" or type(setclipboard) == "function" end
local function safeParentGui(gui)
    local ok, core = pcall(function() return game:GetService("CoreGui") end)
    if ok and core then local succ = pcall(function() gui.Parent = core end) if succ then return gui end end
    local pl = Players.LocalPlayer if pl then gui.Parent = pl:WaitForChild("PlayerGui") else gui.Parent = game:GetService("StarterGui") end
    return gui
end

-- Default theme
local Theme = { Primary = Color3.fromRGB(28,28,30), Secondary = Color3.fromRGB(40,40,45), Accent = Color3.fromRGB(0,170,255), Text = Color3.fromRGB(235,235,235), SubText = Color3.fromRGB(180,180,180) }

-- Draggable helper
local function makeDraggable(frame, handle)
    handle = handle or frame
    local dragging = false; local dragInput, mousePos, framePos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; mousePos = input.Position; framePos = frame.Position
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
        end
    end)
    handle.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - mousePos
            frame.Position = UDim2.new(framePos.X.Scale, framePos.X.Offset + delta.X, framePos.Y.Scale, framePos.Y.Offset + delta.Y)
        end
    end)
end

-- Grid helper
local function makeGrid(parent, cellX, cellY, padding)
    local grid = Instance.new("UIGridLayout")
    grid.CellSize = UDim2.new(0, cellX or 120, 0, cellY or 36)
    grid.CellPadding = UDim2.new(0, padding or 6, 0, padding or 6)
    grid.HorizontalAlignment = Enum.HorizontalAlignment.Left
    grid.SortOrder = Enum.SortOrder.LayoutOrder
    grid.Parent = parent
    return grid
end

-- Notification
local function Notify(title, text, duration)
    duration = duration or 4
    local gui = Instance.new("ScreenGui") gui.Name = "TS_Notify" safeParentGui(gui)
    local frame = new("Frame", {Parent = gui, Size = UDim2.new(0,320,0,82), Position = UDim2.new(1,-330,1,-110), BackgroundColor3 = Theme.Primary, BorderSizePixel = 0})
    new("UICorner", {Parent = frame, CornerRadius = UDim.new(0,8)})
    new("TextLabel", {Parent = frame, Size = UDim2.new(1,-16,0,26), Position = UDim2.new(0,8,0,8), BackgroundTransparency = 1, Text = title or "Notification", Font = Enum.Font.SourceSansBold, TextSize = 18, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left})
    new("TextLabel", {Parent = frame, Size = UDim2.new(1,-16,1,-36), Position = UDim2.new(0,8,0,36), BackgroundTransparency = 1, Text = text or "", TextWrapped = true, TextColor3 = Theme.SubText, TextXAlignment = Enum.TextXAlignment.Left})
    frame.AnchorPoint = Vector2.new(1,1); frame.Position = UDim2.new(1,10,1,110); frame.Size = UDim2.new(0,0,0,0)
    TweenService:Create(frame, TweenInfo.new(0.25), {Size = UDim2.new(0,320,0,82), Position = UDim2.new(1,-10,1,-110)}):Play()
    delay(duration, function() pcall(function() TweenService:Create(frame, TweenInfo.new(0.2), {Size = UDim2.new(0,0,0,0)}):Play(); wait(0.25); gui:Destroy() end) end)
end

-- Clipboard helper
local function TryCopy(text) if type(setclipboard) == "function" then pcall(setclipboard, text); return true end; return false end

-- Responsive
local function ApplyResponsive(container)
    local function apply()
        local cam = workspace.CurrentCamera
        local view = cam and cam.ViewportSize or Vector2.new(1280,720)
        local width = view.X
        if width <= 600 then container.Size = UDim2.new(0.94,0,0.86,0); container.Position = UDim2.new(0.03,0,0.07,0)
        elseif width <= 900 then container.Size = UDim2.new(0.86,0,0.82,0); container.Position = UDim2.new(0.07,0,0.09,0)
        else container.Size = UDim2.new(0,700,0,450); container.Position = UDim2.new(0.5,-350,0.5,-225) end
    end
    apply(); if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(apply) end
end

-- Config helpers
local Config = {}
function Config:Save(name, data) if not isExecutor() then return false end; local ok,err = pcall(function() writefile("TSUI_"..name..".json", HttpService:JSONEncode(data)) end); return ok,err end
function Config:Load(name) if not isExecutor() then return nil end; if isfile and isfile("TSUI_"..name..".json") then local s = readfile("TSUI_"..name..".json") local ok,data = pcall(function() return HttpService:JSONDecode(s) end) if ok then return data end end; return nil end

-- Search helper (filters items by name / text)
local function applySearchFilter(rootContent, query)
    query = (query or ""):lower()
    for _, child in pairs(rootContent:GetDescendants()) do
        if child:IsA("TextButton") or child:IsA("TextLabel") or child:IsA("TextBox") then
            if child.Text and #child.Text > 0 then
                local visible = (query == "") or (string.find(string.lower(child.Text), query) ~= nil)
                -- If it's part of a control, show its parent container element
                local parentElem = child
                while parentElem and parentElem ~= rootContent and not parentElem:IsA("Frame") do parentElem = parentElem.Parent end
                if parentElem and parentElem.Parent then
                    parentElem.Visible = visible
                else
                    child.Visible = visible
                end
            end
        end
    end
end

-- Auto-refresh: we store weak refs of created elements and provide Refresh methods
local function makeRefreshable(obj)
    obj._ts_refresh = function() end -- placeholder, can be overridden
    function obj:Refresh() if obj._ts_refresh then pcall(obj._ts_refresh, obj) end end
    return obj
end

-- Core: CreateWindow
function TheStrongest.CreateWindow(opts)
    opts = opts or {}
    local name = opts.Name or "The Strongest UI"; local uiName = opts.UIName or name
    local showLoading = opts.LoadingScreen == nil and true or opts.LoadingScreen
    local configName = opts.ConfigName or (name:gsub("%s+","_"))

    local screenGui = Instance.new("ScreenGui"); screenGui.Name = "TS_UI_"..(name:gsub("%s+","_")); safeParentGui(screenGui)
    local container = new("Frame", {Parent = screenGui, Name = "MainContainer", Size = UDim2.new(0,700,0,450), Position = UDim2.new(0.5,-350,0.5,-225), BackgroundColor3 = Theme.Primary, BorderSizePixel = 0})
    new("UICorner", {Parent = container, CornerRadius = UDim.new(0,10)})

    -- Header
    local header = new("Frame", {Parent = container, Name = "Header", Size = UDim2.new(1,0,0,48), BackgroundTransparency = 1})
    local titleLabel = new("TextLabel", {Parent = header, Name = "TitleLabel", Size = UDim2.new(0.68,0,1,0), Position = UDim2.new(0,12,0,0), BackgroundTransparency = 1, Text = uiName, TextColor3 = Theme.Text, Font = Enum.Font.SourceSansBold, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left})
    local dateLabel = new("TextLabel", {Parent = header, Name = "DateLabel", Size = UDim2.new(0.28,-20,1,0), Position = UDim2.new(0.72,0,0,0), BackgroundTransparency = 1, Text = "", TextColor3 = Theme.SubText, Font = Enum.Font.SourceSans, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Right})
    local toggleBtn = new("TextButton", {Parent = header, Name = "ToggleBtn", Size = UDim2.new(0,40,0,28), Position = UDim2.new(1,-52,0,10), Text = "—", BackgroundColor3 = Theme.Secondary, TextColor3 = Theme.Text, AutoButtonColor = true})

    -- Mini open box
    local miniBox = new("Frame", {Parent = screenGui, Name = "MiniBox", Size = UDim2.new(0,46,0,28), Position = UDim2.new(0,12,0,12), BackgroundColor3 = Theme.Secondary})
    new("UICorner", {Parent = miniBox, CornerRadius = UDim.new(0,6)})
    new("TextLabel", {Parent = miniBox, Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1, Text = "UI", TextColor3 = Theme.Text, Font = Enum.Font.SourceSansBold})

    -- Left tabs and right content
    local left = new("Frame", {Parent = container, Name = "Left", Size = UDim2.new(0,180,1,-48), Position = UDim2.new(0,0,0,48), BackgroundTransparency = 1})
    local right = new("Frame", {Parent = container, Name = "Right", Size = UDim2.new(1,-180,1,-48), Position = UDim2.new(0,180,0,48), BackgroundTransparency = 1})
    new("UIListLayout", {Parent = left, Padding = UDim.new(0,8)})
    local contentHolder = new("Frame", {Parent = right, Name = "ContentHolder", Size = UDim2.new(1,0,1,0), BackgroundTransparency = 1})

    -- make draggable and responsive
    makeDraggable(container, header)
    miniBox.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then container.Visible = not container.Visible end end)
    toggleBtn.MouseButton1Click:Connect(function() container.Visible = not container.Visible end)

    -- date loop
    spawn(function() while container.Parent do local t = os.date("*t") if t then dateLabel.Text = string.format("%04d-%02d-%02d  %02d:%02d:%02d", t.year,t.month,t.day,t.hour,t.min,t.sec) end wait(1) end end)

    -- storage for refresh/search
    local registry = { tabs = {}, elements = {}, sections = {} }

    -- tab creator
    local function createTab(opt)
        opt = opt or {}
        local btn = new("TextButton", {Parent = left, Size = UDim2.new(1,-12,0,44), Text = " "..(opt.Name or "Tab"), BackgroundColor3 = Theme.Secondary, TextColor3 = Theme.Text, AutoButtonColor = true})
        if opt.Icon then new("ImageLabel", {Parent = btn, Size = UDim2.new(0,34,0,34), Position = UDim2.new(0,6,0,5), BackgroundTransparency = 1, Image = opt.Icon}); btn.TextXAlignment = Enum.TextXAlignment.Left end
        local page = new("ScrollingFrame", {Parent = contentHolder, Size = UDim2.new(1,0,1,0), CanvasSize = UDim2.new(0,0,0,0), ScrollBarThickness = 6, BackgroundTransparency = 1}); page.Visible = false
        local layout = new("UIListLayout", {Parent = page}); layout.Padding = UDim.new(0,8)

        btn.MouseButton1Click:Connect(function()
            for _,c in pairs(contentHolder:GetChildren()) do if c:IsA("ScrollingFrame") then c.Visible = false end end
            page.Visible = true
        end)

        local tab = { Button = btn, Page = page, Sections = {} }

        function tab:CreateSection(opt2)
            opt2 = opt2 or {}
            local sec = new("Frame", {Parent = page, Size = UDim2.new(1,-20,0,36), BackgroundTransparency = 1})
            sec.LayoutOrder = #self.Sections + 1
            local title = new("TextLabel", {Parent = sec, Size = UDim2.new(1,0,0,18), Position = UDim2.new(0,0,0,0), BackgroundTransparency = 1, Text = opt2.Name or "Section", TextColor3 = Theme.Text, Font = Enum.Font.SourceSansBold, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left})
            local holder = new("Frame", {Parent = sec, Size = UDim2.new(1,0,0,0), Position = UDim2.new(0,0,0,20), BackgroundTransparency = 1})
            local grid = makeGrid(holder, opt2.CellX or 130, opt2.CellY or 36, opt2.Padding or 6)

            local function updateSize()
                local cols = math.max(1, math.floor((holder.AbsoluteSize.X + grid.CellPadding.X.Offset) / (grid.CellSize.X.Offset + grid.CellPadding.X.Offset)))
                local items = 0
                for _,c in pairs(holder:GetChildren()) do if c:IsA("GuiObject") and c ~= grid then items = items + 1 end end
                local rows = math.ceil(items / cols)
                holder.Size = UDim2.new(1,0,0, rows * (grid.CellSize.Y.Offset + grid.CellPadding.Y.Offset))
                sec.Size = UDim2.new(1,-20,0, 20 + holder.Size.Y.Offset)
                page.CanvasSize = UDim2.new(0,0,0, page.CanvasSize.Y.Offset + sec.Size.Y.Offset)
            end
            holder.ChildAdded:Connect(updateSize); holder.ChildRemoved:Connect(updateSize)

            local sAPI = {}
            -- AddButton
            function sAPI:AddButton(o)
                o = o or {}
                local btn = new("TextButton", {Parent = holder, Size = UDim2.new(0, grid.CellSize.X.Offset, 0, grid.CellSize.Y.Offset), Text = o.Name or "Button", BackgroundColor3 = o.Color or Theme.Secondary, TextColor3 = Theme.Text, AutoButtonColor = true})
                if o.Image then new("ImageLabel", {Parent = btn, Size = UDim2.new(0,18,0,18), Position = UDim2.new(1,-22,0,8), BackgroundTransparency = 1, Image = o.Image}) end
                btn.MouseButton1Click:Connect(function() if o.Callback then pcall(o.Callback) end end)
                -- refresh hook
                registry.elements[btn] = {type = "button", label = o.Name}
                makeRefreshable(btn)
                btn._ts_refresh = function(self) -- keep simple: update text
                    self.Text = o.Name or self.Text
                end
                return btn
            end
            -- AddToggle
            function sAPI:AddToggle(o)
                o = o or {}
                local fr = new("Frame", {Parent = holder, Size = UDim2.new(0, grid.CellSize.X.Offset, 0, grid.CellSize.Y.Offset), BackgroundTransparency = 1})
                local label = new("TextLabel", {Parent = fr, Size = UDim2.new(0.65,0,1,0), BackgroundTransparency = 1, Text = o.Name or "Toggle", TextColor3 = Theme.Text})
                local box = new("TextButton", {Parent = fr, Size = UDim2.new(0,28,0,20), Position = UDim2.new(1,-34,0,8), Text = "", BackgroundColor3 = o.Default and Theme.Accent or Theme.Secondary})
                local val = o.Default or false
                box.MouseButton1Click:Connect(function()
                    val = not val; box.BackgroundColor3 = val and Theme.Accent or Theme.Secondary
                    if o.Callback then pcall(o.Callback, val) end
                end)
                registry.elements[fr] = {type = "toggle", label = o.Name, get = function() return val end}
                makeRefreshable(fr)
                fr._ts_refresh = function(self) end
                return {Frame = fr, Get = function() return val end}
            end
            -- AddSlider
            function sAPI:AddSlider(o)
                o = o or {}
                local fr = new("Frame", {Parent = holder, Size = UDim2.new(0, grid.CellSize.X.Offset, 0, grid.CellSize.Y.Offset), BackgroundTransparency = 1})
                new("TextLabel", {Parent = fr, Size = UDim2.new(1,0,0,14), BackgroundTransparency = 1, Text = o.Name or "Slider", TextColor3 = Theme.Text, Font = Enum.Font.SourceSans, TextSize = 14})
                local bg = new("Frame", {Parent = fr, Size = UDim2.new(1,-10,0,12), Position = UDim2.new(0,5,0,18), BackgroundColor3 = Theme.Secondary})
                local fill = new("Frame", {Parent = bg, Size = UDim2.new(((o.Default or o.Min or 0) - (o.Min or 0))/((o.Max or 100)-(o.Min or 0)),0,1,0), BackgroundColor3 = Theme.Accent})
                local dragging = false
                bg.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end end)
                bg.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
                UserInputService.InputChanged:Connect(function(i) if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then local rel = math.clamp((i.Position.X - bg.AbsolutePosition.X)/bg.AbsoluteSize.X,0,1); fill.Size = UDim2.new(rel,0,1,0); local value = (o.Min or 0) + rel * ((o.Max or 100) - (o.Min or 0)); if o.Callback then pcall(o.Callback, value) end end end)
                registry.elements[fr] = {type = "slider", label = o.Name}
                makeRefreshable(fr)
                fr._ts_refresh = function(self) end
                return {Frame = fr}
            end
            -- AddTextbox
            function sAPI:AddTextbox(o)
                o = o or {}
                local fr = new("Frame", {Parent = holder, Size = UDim2.new(0, grid.CellSize.X.Offset, 0, grid.CellSize.Y.Offset), BackgroundTransparency = 1})
                new("TextLabel", {Parent = fr, Size = UDim2.new(0.3,0,1,0), BackgroundTransparency = 1, Text = o.Name or "Text", TextColor3 = Theme.Text})
                local tb = new("TextBox", {Parent = fr, Size = UDim2.new(0.65,-8,1,0), Position = UDim2.new(0.35,4,0,0), Text = o.Default or "", TextColor3 = Theme.Text, BackgroundColor3 = Theme.Secondary})
                tb.FocusLost:Connect(function(enter) if o.Callback then pcall(o.Callback, tb.Text) end end)
                registry.elements[tb] = {type = "textbox", label = o.Name}
                makeRefreshable(tb)
                tb._ts_refresh = function(self) end
                return tb
            end
            -- AddDropdown
            function sAPI:AddDropdown(o)
                o = o or {}
                o.Options = o.Options or {}
                local fr = new("Frame", {Parent = holder, Size = UDim2.new(0, grid.CellSize.X.Offset, 0, grid.CellSize.Y.Offset), BackgroundTransparency = 1})
                new("TextLabel", {Parent = fr, Size = UDim2.new(1,0,0,14), BackgroundTransparency = 1, Text = o.Name or "Dropdown", TextColor3 = Theme.Text})
                local btn = new("TextButton", {Parent = fr, Size = UDim2.new(1,0,0,20), Position = UDim2.new(0,0,0,14), Text = o.Default or (o.Options[1] or "Select"), BackgroundColor3 = Theme.Secondary, TextColor3 = Theme.Text})
                local menu = new("Frame", {Parent = fr, Size = UDim2.new(1,0,0,#o.Options*24), Position = UDim2.new(0,0,0,34), BackgroundColor3 = Theme.Secondary, Visible = false})
                for i,op in ipairs(o.Options) do local it = new("TextButton", {Parent = menu, Size = UDim2.new(1,0,0,24), Position = UDim2.new(0,0,0,(i-1)*24), Text = op, BackgroundTransparency = 1, TextColor3 = Theme.Text}); it.MouseButton1Click:Connect(function() btn.Text = op; menu.Visible = false; if o.Callback then pcall(o.Callback, op) end end) end
                btn.MouseButton1Click:Connect(function() menu.Visible = not menu.Visible end)
                registry.elements[fr] = {type = "dropdown", label = o.Name}
                makeRefreshable(fr)
                fr._ts_refresh = function(self) end
                return {Button = btn, Menu = menu}
            end
            -- AddColorPicker
            function sAPI:AddColorPicker(o)
                o = o or {}
                local fr = new("Frame", {Parent = holder, Size = UDim2.new(0, grid.CellSize.X.Offset, 0, grid.CellSize.Y.Offset), BackgroundTransparency = 1})
                new("TextLabel", {Parent = fr, Size = UDim2.new(0.6,0,1,0), BackgroundTransparency = 1, Text = o.Name or "Color", TextColor3 = Theme.Text})
                local preview = new("ImageButton", {Parent = fr, Size = UDim2.new(0,26,0,26), Position = UDim2.new(1,-34,0,5), BackgroundColor3 = o.Default or Theme.Accent})
                preview.MouseButton1Click:Connect(function()
                    local picker = new("Frame", {Parent = screenGui, Size = UDim2.new(0,260,0,140), Position = UDim2.new(0.5,-130,0.5,-70), BackgroundColor3 = Theme.Primary})
                    new("UICorner", {Parent = picker, CornerRadius = UDim.new(0,8)})
                    local rLbl = new("TextLabel", {Parent = picker, Text = "R", Position = UDim2.new(0,6,0,6), Size = UDim2.new(0,20,0,20), BackgroundTransparency = 1, TextColor3 = Theme.Text})
                    local rBox = new("TextBox", {Parent = picker, Text = tostring(math.floor(preview.BackgroundColor3.R*255)), Position = UDim2.new(0,30,0,6), Size = UDim2.new(0,60,0,20)})
                    local gLbl = new("TextLabel", {Parent = picker, Text = "G", Position = UDim2.new(0,6,0,36), Size = UDim2.new(0,20,0,20), BackgroundTransparency = 1, TextColor3 = Theme.Text})
                    local gBox = new("TextBox", {Parent = picker, Text = tostring(math.floor(preview.BackgroundColor3.G*255)), Position = UDim2.new(0,30,0,36), Size = UDim2.new(0,60,0,20)})
                    local bLbl = new("TextLabel", {Parent = picker, Text = "B", Position = UDim2.new(0,6,0,66), Size = UDim2.new(0,20,0,20), BackgroundTransparency = 1, TextColor3 = Theme.Text})
                    local bBox = new("TextBox", {Parent = picker, Text = tostring(math.floor(preview.BackgroundColor3.B*255)), Position = UDim2.new(0,30,0,66), Size = UDim2.new(0,60,0,20)})
                    local apply = new("TextButton", {Parent = picker, Text = "Apply", Position = UDim2.new(1,-70,1,-36), Size = UDim2.new(0,60,0,28), BackgroundColor3 = Theme.Accent, TextColor3 = Theme.Text})
                    apply.MouseButton1Click:Connect(function() local rr = tonumber(rBox.Text) or 0; local gg = tonumber(gBox.Text) or 0; local bb = tonumber(bBox.Text) or 0; local col = Color3.fromRGB(math.clamp(rr,0,255), math.clamp(gg,0,255), math.clamp(bb,0,255)); preview.BackgroundColor3 = col; pcall(function() picker:Destroy() end); if o.Callback then pcall(o.Callback, col) end end)
                end)
                registry.elements[fr] = {type = "color", label = o.Name}
                makeRefreshable(fr)
                fr._ts_refresh = function(self) end
                return preview
            end
            -- AddKeybind
            function sAPI:AddKeybind(o)
                o = o or {}
                local fr = new("Frame", {Parent = holder, Size = UDim2.new(0, grid.CellSize.X.Offset, 0, grid.CellSize.Y.Offset), BackgroundTransparency = 1})
                new("TextLabel", {Parent = fr, Size = UDim2.new(0.6,0,1,0), BackgroundTransparency = 1, Text = o.Name or "Keybind", TextColor3 = Theme.Text})
                local btn = new("TextButton", {Parent = fr, Size = UDim2.new(0,70,0,24), Position = UDim2.new(1,-76,0,6), Text = tostring(o.Default or "None"), BackgroundColor3 = Theme.Secondary, TextColor3 = Theme.Text})
                local bound = o.Default; local listening = false
                btn.MouseButton1Click:Connect(function() btn.Text = "Press..."; listening = true end)
                local conn = UserInputService.InputBegan:Connect(function(input, gp) if listening and input.UserInputType == Enum.UserInputType.Keyboard then bound = input.KeyCode.Name; btn.Text = bound; listening = false; if o.Callback then pcall(o.Callback, bound) end end end)
                registry.elements[fr] = {type = "keybind", label = o.Name}
                makeRefreshable(fr); fr._ts_refresh = function(self) end
                return {Button = btn, Get = function() return bound end}
            end
            -- AddLabel / Paragraph / Destroy
            function sAPI:AddLabel(txt) local lbl = new("TextLabel", {Parent = holder, Size = UDim2.new(0, grid.CellSize.X.Offset, 0, grid.CellSize.Y.Offset), BackgroundTransparency = 1, Text = txt or "", TextColor3 = Theme.SubText, TextWrapped = true}); registry.elements[lbl] = {type="label", label=txt}; return lbl end
            function sAPI:AddParagraph(txt) local p = new("TextLabel", {Parent = holder, Size = UDim2.new(0, grid.CellSize.X.Offset, 0, grid.CellSize.Y.Offset*2), BackgroundTransparency = 1, Text = txt or "", TextWrapped = true, TextColor3 = Theme.SubText}); registry.elements[p] = {type="paragraph", label=txt}; return p end
            function sAPI:AddDestroyButton() return sAPI:AddButton({Name = "Destroy UI", Callback = function() screenGui:Destroy() end}) end

            table.insert(self.Sections, sAPI)
            registry.sections[sec] = {title = opt2.Name}
            return sAPI
        end

        table.insert(registry.tabs, tab)
        return tab
    end

    -- Search box addition
    local function addSearchBox()
        local sb = new("TextBox", {Parent = header, Name = "SearchBox", Size = UDim2.new(0.3, -20, 0, 28), Position = UDim2.new(0.68, 4, 0, 10), Text = "", PlaceholderText = "Search...", BackgroundColor3 = Theme.Secondary, TextColor3 = Theme.Text})
        sb.FocusLost:Connect(function() applySearchFilter(contentHolder, sb.Text) end)
        sb:GetPropertyChangedSignal("Text"):Connect(function() applySearchFilter(contentHolder, sb.Text) end)
        return sb
    end

    -- API
    local API = {}
    function API:CreateTab(o) return createTab(o) end
    function API:EnableResponsive() ApplyResponsive(container) end
    function API:ToggleDraggable(enabled) if enabled then makeDraggable(container, header) end end
    function API:Notify(t,m,d) Notify(t,m,d) end
    function API:Copy(text) return TryCopy(text) end
    function API:GetScreenGui() return screenGui end
    function API:SetTheme(t) for k,v in pairs(t) do Theme[k] = v end; container.BackgroundColor3 = Theme.Primary end

    -- Flags
    local flags = {}
    function API:SetFlag(k,v) flags[k]=v end
    function API:GetFlag(k) return flags[k] end
    function API:SaveFlags() return Config:Save(configName.."_flags", flags) end
    function API:LoadFlags() local d = Config:Load(configName.."_flags"); if d then flags=d end; return flags end

    -- Save/Load full config
    function API:SaveConfig() local data = {Theme = Theme, Flags = flags}; return Config:Save(configName, data) end
    function API:LoadConfig() local d = Config:Load(configName); if d and d.Theme then API:SetTheme(d.Theme) end; if d and d.Flags then flags = d.Flags end; return d end

    -- Add profile panel
    function API:AddProfilePanel()
        local panel = new("Frame", {Parent = container, Name = "ProfilePanel", Size = UDim2.new(0,200,0,110), Position = UDim2.new(1,-210,0,10), BackgroundColor3 = Theme.Secondary})
        new("UICorner", {Parent = panel, CornerRadius = UDim.new(0,8)})
        local pl = Players.LocalPlayer
        local thumb = new("ImageLabel", {Parent = panel, Size = UDim2.new(0,64,0,64), Position = UDim2.new(0,8,0,8), BackgroundTransparency = 1})
        local nameLbl = new("TextLabel", {Parent = panel, Size = UDim2.new(1,-84,0,30), Position = UDim2.new(0,80,0,8), BackgroundTransparency = 1, Text = pl and pl.Name or "Player", TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left, Font = Enum.Font.SourceSansBold})
        local infoLbl = new("TextLabel", {Parent = panel, Size = UDim2.new(1,-84,0,60), Position = UDim2.new(0,80,0,36), BackgroundTransparency = 1, Text = "Loading...", TextColor3 = Theme.SubText, TextWrapped = true})
        if pl then spawn(function() local ok,url = pcall(function() return Players:GetUserThumbnailAsync(pl.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420) end) if ok and url then thumb.Image = url end end)
            spawn(function() local ok,res = pcall(function() return HttpService:JSONDecode(HttpService:GetAsync(("https://users.roblox.com/v1/users/%d"):format(pl.UserId))) end) if ok and res and res.created then local created = res.created; local y,m,d = created:match("^(%d+)%-(%d+)%-(%d+)"); local age = "?"; if y then age = math.floor((os.time() - os.time{year=tonumber(y),month=tonumber(m),day=tonumber(d)}) / 86400) .. " days" end; infoLbl.Text = ("UserId: %d
Created: %s
Age: %s"):format(pl.UserId, created:sub(1,10), age) else infoLbl.Text = "Could not fetch public info (HttpService may be disabled)." end end)
        end
        return panel
    end

    -- Set appearance helper
    function API:SetElementAppearance(path, props)
        local node = screenGui
        for _,name in ipairs(path) do node = node:FindFirstChild(name); if not node then return false end end
        for k,v in pairs(props) do pcall(function() node[k]=v end) end
        return true
    end

    -- Check access (server-side RemoteFunction expected)
    function API:CheckAccess(password)
        local ok, remote = pcall(function() return game:GetService("ReplicatedStorage"):WaitForChild("TS_RequestAccess",1) end)
        if not ok or not remote then return {allowed=false, reason="no_remote"} end
        local res = nil; pcall(function() res = remote:InvokeServer("CheckAccess", {password = password}) end)
        return res
    end

    -- Search box add
    function API:AddSearchBox()
        return addSearchBox()
    end

    -- Refresh functions
    function API:RefreshAll()
        -- call refresh on all registered elements
        for obj,info in pairs(registry.elements) do
            if obj and obj.Refresh then pcall(function() obj:Refresh() end) end
        end
    end

    -- Destroy
    function API:Destroy() screenGui:Destroy() end

    -- Loading screen
    if showLoading then local lg = Instance.new("ScreenGui") lg.Name = "TS_Loading" safeParentGui(lg) local lf = new("Frame", {Parent = lg, Size = UDim2.new(1,0,1,0), BackgroundColor3 = Theme.Primary}) new("TextLabel", {Parent = lf, Text = opts.LoadingText or "Loading...", Size = UDim2.new(1,0,0,60), Position = UDim2.new(0,0,0.5,-30), BackgroundTransparency = 1, Font = Enum.Font.SourceSansBold, TextSize = 28, TextColor3 = Theme.Text}) delay(1.2, function() pcall(function() lg:Destroy() end) end) end

    return API
end

-- Server examples (ServerScriptService) - keep secrets server-side
--[[
-- RemoteFunction for access checks
local Players = game:GetService("Players")
local Remote = Instance.new("RemoteFunction") Remote.Name = "TS_RequestAccess" Remote.Parent = game:GetService("ReplicatedStorage")
local WHITELIST = { [123456] = true }
local BLACKLIST = {}
local SERVER_PASSWORD = "CHANGE_THIS_SECRET"
Remote.OnServerInvoke = function(player, method, data)
    if method == "CheckAccess" then
        if BLACKLIST[player.UserId] then return {allowed=false, reason="blacklisted"} end
        if WHITELIST[player.UserId] then return {allowed=true, reason="whitelisted"} end
        if data and data.password == SERVER_PASSWORD then WHITELIST[player.UserId] = true; return {allowed=true, reason="password"} end
        return {allowed=false, reason="not_allowed"}
    end
end

-- Discord webhook poster (ServerScriptService)
local HttpService = game:GetService("HttpService")
local RemoteEvent = Instance.new("RemoteEvent") RemoteEvent.Name = "TS_PostDiscord" RemoteEvent.Parent = game:GetService("ReplicatedStorage")
local WEBHOOK_URL = "https://discord.com/api/webhooks/XXXXX/XXXXX" -- set this on server
RemoteEvent.OnServerEvent:Connect(function(player, payload)
    local ok, res = pcall(function()
        return HttpService:PostAsync(WEBHOOK_URL, HttpService:JSONEncode({content = payload.content}), Enum.HttpContentType.ApplicationJson)
    end)
end)
]]--

-- README (full) - save as README.md in your repo
--[[
# TheStrongestUILibrary

## Quick start
1. Create a GitHub repo named `TheStrongestUI` under your account `Thestrongestman0080-Official`.
2. Add `TheStrongestUILibrary.lua` (this file) to the repo, commit to `main`.
3. Users can load with the raw link:
```
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/Thestrongestman0080-Official/TheStrongestUI/main/TheStrongestUILibrary.lua"))()
```

## Usage
```lua
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/Thestrongestman0080-Official/TheStrongestUI/main/TheStrongestUILibrary.lua"))()
local Window = Library.CreateWindow({Name = "MyHub", UIName = "My UI", LoadingScreen = true, ConfigName = "MyHubConfig"})
local Tab = Window:CreateTab({Name = "Main", Icon = "rbxassetid://12345"})
local Section = Tab:CreateSection({Name = "Controls", CellX = 140, CellY = 36})
Section:AddButton({Name = "Say Hello", Callback = function() print('Hello') end, Image = "rbxassetid://..."})
local t = Section:AddToggle({Name = "AutoFarm", Default = false, Callback = function(v) print(v) end})
Section:AddSlider({Name = "WalkSpeed", Min = 16, Max = 200, Default = 16, Callback = function(v) game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = v end})
Section:AddDropdown({Name = "Select", Options = {"A","B"}, Default = "A", Callback = function(v) print(v) end})
Section:AddTextbox({Name = "Say", Default = "Hello", Callback = function(txt) print(txt) end})
Section:AddColorPicker({Name = "Theme", Default = Color3.fromRGB(0,170,255), Callback = function(c) Window:SetTheme({Accent = c}) end})
local kb = Section:AddKeybind({Name = "Open", Default = Enum.KeyCode.RightControl, Callback = function(k) print(k) end})
Window:AddProfilePanel()
Window:EnableResponsive()
Window:AddSearchBox()
```

## API Reference
- `Library.CreateWindow(opts)` - returns a Window API.
  - `Window:CreateTab(opts)` - returns a Tab.
  - `Tab:CreateSection(opts)` - returns a Section API.
  - Section methods: `AddButton`, `AddToggle`, `AddSlider`, `AddDropdown`, `AddTextbox`, `AddColorPicker`, `AddKeybind`, `AddLabel`, `AddParagraph`, `AddDestroyButton`.
  - Window methods: `EnableResponsive`, `ToggleDraggable`, `Notify`, `Copy`, `GetScreenGui`, `SetTheme`, `SaveConfig`, `LoadConfig`, `SetFlag`, `GetFlag`, `SaveFlags`, `LoadFlags`, `AddProfilePanel`, `SetElementAppearance`, `CheckAccess`, `AddSearchBox`, `RefreshAll`, `Destroy`.

## Server Setup (required for secure features)
- Implement a `RemoteFunction` named `TS_RequestAccess` in `ReplicatedStorage` to handle whitelist/premium/password checks server-side.
- Implement a `RemoteEvent` named `TS_PostDiscord` to safely post to Discord webhooks from the server (keep webhook URL secret).

## Notes
- `loadstring` and file I/O (`writefile`) are available in executor environments — for public games convert this file into a `ModuleScript` and use `require` and server-side HttpService.
- Avoid storing secrets (webhook URLs, passwords) in client code — use server scripts.

## License
- Use as you like for legitimate development. Consider adding an explicit license file.
]]--

return TheStrongest
