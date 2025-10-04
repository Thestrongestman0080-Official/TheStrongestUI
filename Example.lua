local Window = Library:CreateWindow({
    Name = "My Hub",
    UIName = "TheStrongestUI",
    LoadingScreen = true,
    SaveConfig = true,
    ConfigName = "MyHubConfig"
})

local Tab = Window:CreateTab({Name = "Main", Icon = "rbxassetid://12345"})
local Section = Tab:CreateSection({Name = "Controls"})

Section:AddButton({
    Name = "Say Hello",
    Callback = function()
        print("Hello World!")
    end
})

Section:AddToggle({
    Name = "GodMode",
    Default = false,
    Flag = "GodMode",
    Callback = function(v)
        print("GodMode:", v)
    end
})
