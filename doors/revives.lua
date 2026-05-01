--// 
--// Revive Duper Script by upio
--// Method found by lolcat
--// 

--// ============================================================
--// CONFIGURATION
--// ============================================================
--// MainAccount: Your main account's username (receives the duped revives)
--// AltAccount:  Your alt account's username (used to dupe revives)
--//   - If left as "", the script will auto-detect the other player
--//     in-server who is also running this script (chat-based fallback)
--//   - If set, no chat communication is needed — everything is
--//     coordinated by timing and attribute polling
--// DuplicationCount: How many revives to dupe (default 1000)
--// ============================================================

local MainAccount = MainAccount or ""          -- e.g. "upio"
local AltAccount = AltAccount or ""            -- e.g. "upio_alt"
local DuplicationCount = DuplicationAmount or 1000

--// Services
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = Instance.new("VirtualInputManager")

--// Remotes
local RemotesFolder = ReplicatedStorage.RemotesFolder
local ReviveFriendEvent = RemotesFolder.ReviveFriend
local ObtainReviveEvent = RemotesFolder.ObtainGiftedRevive

--// Player Variables
local LocalPlayer = Players.LocalPlayer
local Partner -- The other account (alt or main depending on who we are)

--// Game Data
local LatestRoom = ReplicatedStorage.GameData.LatestRoom
local Revives = LocalPlayer.PlayerGui.TopbarUI.Topbar.StatsTopbarHandler.StatModules.Revives.RevivesVal

--// Determine role
local IsMain = (MainAccount ~= "" and LocalPlayer.Name == MainAccount)
local IsAlt = (AltAccount ~= "" and LocalPlayer.Name == AltAccount)

-- If neither name matches but MainAccount is set, assume we're the alt
if MainAccount ~= "" and not IsMain and not IsAlt then
    IsAlt = true
end

local Title = IsMain and "Revive Dupe (Main)" or "Revive Dupe (Alt)"

--// State
local IsPartnerReady = false
local IsGiftingRevive = false

--// ============================================================
--// PARTNER DETECTION
--// ============================================================
-- Uses direct name-based detection when AltAccount/MainAccount are
-- configured. No chat required.
local UseChatFallback = (MainAccount == "" and AltAccount == "")

local function FindPartnerByName()
    local targetName = IsMain and AltAccount or MainAccount
    if targetName == "" then return nil end
    return Players:FindFirstChild(targetName)
end

local function WaitForPartner()
    -- Try to find the partner immediately
    Partner = FindPartnerByName()
    if Partner then
        IsPartnerReady = true
        return
    end

    -- Wait for them to join
    StarterGui:SetCore("SendNotification", {
        Title = Title,
        Text = `Waiting for {IsMain and "alt" or "main"} account to join...`,
        Duration = 10
    })

    local targetName = IsMain and AltAccount or MainAccount
    local conn
    conn = Players.PlayerAdded:Connect(function(player)
        if player.Name == targetName then
            Partner = player
            IsPartnerReady = true
            conn:Disconnect()
        end
    end)

    repeat task.wait() until IsPartnerReady
end

--// ============================================================
--// CHAT FALLBACK (only used if both MainAccount and AltAccount are empty)
--// ============================================================
if UseChatFallback then
    local TextChatService = game:GetService("TextChatService")
    local Communication = TextChatService.TextChannels.RBXGeneral
    local PacketPrefix = "ReviveDupe_"

    local function SendPacket(PacketName)
        local PacketData = `{PacketPrefix}{PacketName}`
        Communication:SendAsync("", PacketData)
        return PacketData
    end

    TextChatService.MessageReceived:Connect(function(message: TextChatMessage)
        local packetData = message.Metadata
        local textSource = message.TextSource

        if
            not packetData or not textSource or
            packetData:sub(1, #PacketPrefix) ~= PacketPrefix or
            textSource.UserId == LocalPlayer.UserId
        then
            return
        end

        local sender = Players:GetPlayerByUserId(textSource.UserId)
        local packetName = packetData:sub(#PacketPrefix + 1)

        if packetName == "Init" then
            if IsPartnerReady then
                return
            end

            IsPartnerReady = true
            Partner = sender

            SendPacket("Init")

            StarterGui:SetCore("SendNotification", {
                Title = Title,
                Text = `{sender.Name} initialized, starting dupe process...`,
                Duration = 5
            })
        end

        if not IsPartnerReady then
            return
        end

        if packetName == "SendReviveStandardToMe" then
            IsGiftingRevive = true

            if Partner:GetAttribute("Alive") == true then
                StarterGui:SetCore("SendNotification", {
                    Title = Title,
                    Text = "Waiting for the other account to die...",
                    Duration = 5
                })

                Partner:GetAttributeChangedSignal("Alive"):Wait()
            end

            task.wait(2.5)
            ReviveFriendEvent:FireServer(Partner.Name)

            StarterGui:SetCore("SendNotification", {
                Title = Title,
                Text = "Revive sent to alt account. Now rejoin a new game with your alt account.",
                Duration = 5
            })
        end
    end)

    SendPacket("Init")

    StarterGui:SetCore("SendNotification", {
        Title = Title,
        Text = "Waiting for other account to initialize...",
        Duration = 5
    })

    repeat task.wait() until IsPartnerReady
else
    --// Name-based detection — no chat needed
    WaitForPartner()

    StarterGui:SetCore("SendNotification", {
        Title = Title,
        Text = `{Partner.Name} found in server, starting dupe process...`,
        Duration = 5
    })
end

--// ============================================================
--// HELPER FUNCTIONS
--// ============================================================
local function AttemptToKillLocalPlayer()
    if LatestRoom.Value == 0 then
        StarterGui:SetCore("SendNotification", {
            Title = Title,
            Text = "Please open a door first",
            Duration = 5
        })

        LatestRoom:GetPropertyChangedSignal("Value"):Wait()
    end

    if replicatesignal then
        replicatesignal(LocalPlayer.Kill)
    else
        StarterGui:SetCore("SendNotification", {
            Title = Title,
            Text = "Your executor does not support replicatesignal, please die manually",
            Duration = 5
        })
        LocalPlayer.Character.Humanoid.Died:Wait()
    end

    StarterGui:SetCore("SendNotification", {
        Title = Title,
        Text = "Make your alt account try and revive you (click more than once)",
        Duration = 5
    })
end

--// ============================================================
--// MAIN LOGIC
--// ============================================================

--// Alt account needs 1 revive gifted to it first
if Revives.Value == 0 and not IsMain then
    if UseChatFallback then
        -- Chat mode: tell the main account to send us a revive
        local TextChatService = game:GetService("TextChatService")
        local Communication = TextChatService.TextChannels.RBXGeneral
        Communication:SendAsync("", "ReviveDupe_SendReviveStandardToMe")
    else
        -- Name-based mode: the main account will detect we're dead and
        -- gift us a revive automatically after a short delay
        StarterGui:SetCore("SendNotification", {
            Title = Title,
            Text = "Need a revive — main account will gift one automatically.",
            Duration = 5
        })
    end

    IsGiftingRevive = true
    AttemptToKillLocalPlayer()

    StarterGui:SetCore("SendNotification", {
        Title = Title,
        Text = "Waiting for main account to gift you a revive...",
        Duration = 5
    })

    local AcceptReviveThread = task.spawn(function()
        while task.wait() do
            VirtualInputManager:SendKeyEvent(
                true,
                Enum.KeyCode.Return,
                false,
                game
            )
        end
    end)

    Revives:GetPropertyChangedSignal("Value"):Wait()
    coroutine.close(AcceptReviveThread)
    task.wait(0.05)
    game:Shutdown()
    return
end

--// Coordination delay to ensure both clients are synced
StarterGui:SetCore("SendNotification", {
    Title = Title,
    Text = "Waiting 5 seconds to sync with the other account...",
    Duration = 5
})
task.wait(5)

--// If we're in the middle of gifting a revive, don't continue
if IsGiftingRevive then
    return
end

--// In name-based mode: if the alt has 0 revives, gift one first
if not UseChatFallback and IsMain and Partner:GetAttribute("Alive") ~= true then
    task.wait(2.5)
    ReviveFriendEvent:FireServer(Partner.Name)

    StarterGui:SetCore("SendNotification", {
        Title = Title,
        Text = "Gifted a revive to alt account. They will rejoin shortly.",
        Duration = 5
    })
    return
end

--// Main dupe process
if IsMain then
    local ReviveObtainedAmount = 0
    local function OnObtainRevive(...)
        ReviveObtainedAmount += 1

        if ReviveObtainedAmount > (DuplicationCount * 0.85) then
            return true
        end

        task.wait(9e9)

        return true
    end

    if hookmetamethod then
        local mtHook; mtHook = hookmetamethod(game, "__newindex", function(...)
            local self, key = ...
    
            if rawequal(self, ObtainReviveEvent) and key == "OnClientInvoke" then
                if not checkcaller() then
                    return
                end
            end
    
            return mtHook(...)
        end)
    else
        -- might not work i have no clue honestly
        task.defer(function()
            while task.wait() do
                ObtainReviveEvent.OnClientInvoke = OnObtainRevive
            end
        end)
    end

    ObtainReviveEvent.OnClientInvoke = OnObtainRevive

    AttemptToKillLocalPlayer()
else
    if Partner:GetAttribute("Alive") then
        StarterGui:SetCore("SendNotification", {
            Title = Title,
            Text = "Waiting for main account to die...",
            Duration = 5
        })

        Partner:GetAttributeChangedSignal("Alive"):Wait()
    end

    for i = 1, 5 do
        StarterGui:SetCore("SendNotification", {
            Title = Title,
            Text = `Duping in {6 - i} seconds...`,
            Duration = 1
        })
        task.wait(1)
    end

    for i = 1, DuplicationCount do
        ReviveFriendEvent:FireServer(Partner.Name)
    end

    StarterGui:SetCore("SendNotification", {
        Title = Title,
        Text = "Duping completed!",
        Duration = 5
    })
end
