local player = game.Players.LocalPlayer
local running = false
local flightSpeed = 20

local SPAWN_CENTER = Vector3.new(-5000, 300, 0)
local SPAWN_RADIUS = 300

local roundStartTime = 0
local resetCooldown = 120

local inRound = false
local isAlive = false

local function isInSpawnArea(position)
    local distanceX = math.abs(position.X - SPAWN_CENTER.X)
    local distanceY = math.abs(position.Y - SPAWN_CENTER.Y) 
    local distanceZ = math.abs(position.Z - SPAWN_CENTER.Z)
    
    return distanceX <= SPAWN_RADIUS and distanceY <= SPAWN_RADIUS and distanceZ <= SPAWN_RADIUS
end

local function resetCharacter()
    local character = player.Character
    if character then
        local humanoid = character:FindFirstChild("Humanoid")
        if humanoid then
            humanoid.MaxHealth = 100
            humanoid.Health = 0
        end
    end
end

local function checkPlayerStatus()
    if not player.Character then 
        isAlive = false
        inRound = false
        return 
    end
    
    local humanoid = player.Character:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        isAlive = false
        inRound = false
        return
    end
    
    isAlive = true
    
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        inRound = false
        return
    end
    
    local currentPosition = hrp.Position
    local wasInRound = inRound
    inRound = not isInSpawnArea(currentPosition)
    
    if inRound and not wasInRound then
        roundStartTime = tick()
    end
    
    if not inRound and wasInRound then
        roundStartTime = 0
    end
end

local function checkResetTimer()
    if roundStartTime > 0 and inRound then
        local timeInRound = tick() - roundStartTime
        if timeInRound >= resetCooldown then
            resetCharacter()
            roundStartTime = 0
            return true
        end
    end
    return false
end

local function enableGodMode()
    if not player.Character then return end
    
    local humanoid = player.Character:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.MaxHealth = 10000
        humanoid.Health = 10000
        humanoid.BreakJointsOnDeath = false
        humanoid.RequiresNeck = false
        
        humanoid.HealthChanged:Connect(function()
            if humanoid.Health < 10000 and humanoid.Health > 0 then
                humanoid.Health = 10000
            end
        end)
    end
end

local activeCoins = {}
local coinsList = {}

local function removeCoin(coin)
    activeCoins[coin] = nil
    for i = #coinsList, 1, -1 do
        if coinsList[i] == coin then
            table.remove(coinsList, i)
            break
        end
    end
end

local function collectExistingCoins()
    for _, item in pairs(workspace:GetDescendants()) do
        if item.Name == "Coin_Server" and item:IsA("Part") then
            activeCoins[item] = true
            table.insert(coinsList, item)
        end
    end
end

workspace.DescendantAdded:Connect(function(item)
    if item.Name == "Coin_Server" and item:IsA("Part") then
        if not activeCoins[item] then
            activeCoins[item] = true
            table.insert(coinsList, item)
        end
    end
end)

workspace.DescendantRemoving:Connect(function(item)
    if item.Name == "Coin_Server" then
        removeCoin(item)
    end
end)

collectExistingCoins()

local function enableNoClip()
    if not player.Character then return end
    for _, part in pairs(player.Character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
end

local function findNearestCoin()
    if not player.Character then return nil end
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil end
    
    local nearestCoin = nil
    local nearestDistance = math.huge
    local currentPos = hrp.Position
    
    for i = #coinsList, 1, -1 do
        local coin = coinsList[i]
        
        if coin and coin.Parent then
            local distance = (currentPos - coin.Position).Magnitude
            if distance < nearestDistance then
                nearestDistance = distance
                nearestCoin = coin
            end
        else
            removeCoin(coin)
        end
    end
    
    return nearestCoin
end

local function waitForRound()
    local waitStart = tick()
    local lastRoundState = false
    
    while running do
        checkPlayerStatus()
        
        if inRound ~= lastRoundState then
            lastRoundState = inRound
        end
        
        if inRound and isAlive then
            return true
        else
            local waitTime = tick() - waitStart
            if waitTime > 30 then
                waitStart = tick()
            end
            task.wait(1)
        end
    end
    return false
end

local function instantFly()
    while running do
        if not waitForRound() then
            break
        end
        
        local character = player.Character
        if not character then 
            task.wait(0.01)
            continue 
        end
        
        local hrp = character:FindFirstChild("HumanoidRootPart")
        local humanoid = character:FindFirstChild("Humanoid")
        if not hrp or not humanoid then 
            task.wait(0.01)
            continue 
        end
        
        enableGodMode()
        
        local bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.MaxForce = Vector3.new(40000, 40000, 40000)
        bodyVelocity.Parent = hrp
        
        humanoid.PlatformStand = true
        
        local currentTarget = nil
        local lastCoinCheck = 0
        local coinCheckInterval = 0.05
        local lastStatusCheck = 0
        local statusCheckInterval = 1
        local lastTimerCheck = 0
        local timerCheckInterval = 1
        
        while running and character.Parent do
            enableNoClip()
            
            local now = tick()
            
            if now - lastStatusCheck > statusCheckInterval then
                lastStatusCheck = now
                checkPlayerStatus()
                
                if not inRound then
                    break
                end
                
                if not isAlive then
                    break
                end
            end
            
            if now - lastTimerCheck > timerCheckInterval then
                lastTimerCheck = now
                if checkResetTimer() then
                    break
                end
            end
            
            if now - lastCoinCheck > coinCheckInterval then
                lastCoinCheck = now
                
                local nearestCoin = findNearestCoin()
                
                if nearestCoin then
                    if not currentTarget or not currentTarget.Parent or currentTarget ~= nearestCoin then
                        currentTarget = nearestCoin
                    end
                else
                    currentTarget = nil
                end
            end
            
            if currentTarget and currentTarget.Parent then
                local direction = (currentTarget.Position - hrp.Position)
                local distance = direction.Magnitude
                
                if distance > 2 then
                    bodyVelocity.Velocity = direction.Unit * flightSpeed
                    
                    if distance < 5 and currentTarget.Parent then
                        bodyVelocity.Velocity = direction.Unit * (flightSpeed * 1.5)
                    end
                else
                    if currentTarget.Parent then
                        removeCoin(currentTarget)
                    end
                    currentTarget = nil
                    bodyVelocity.Velocity = Vector3.new(0, 0, 0)
                    lastCoinCheck = 0
                end
            else
                bodyVelocity.Velocity = Vector3.new(0, 0, 0)
                currentTarget = nil
            end
            
            task.wait()
        end
        
        bodyVelocity:Destroy()
        if humanoid and humanoid.Parent then
            humanoid.PlatformStand = false
        end
    end
end

local gui = Instance.new("ScreenGui")
gui.Parent = game.CoreGui

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 120, 0, 80)
frame.Position = UDim2.new(1, -140, 0.5, -40)
frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = frame

local button = Instance.new("TextButton")
button.Size = UDim2.new(0, 100, 0, 40)
button.Position = UDim2.new(0, 10, 0, 10)
button.Text = "START"
button.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
button.TextColor3 = Color3.new(1, 1, 1)
button.Font = Enum.Font.GothamBold
button.TextSize = 12
button.Parent = frame

local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 6)
buttonCorner.Parent = button

local credit = Instance.new("TextLabel")
credit.Size = UDim2.new(0, 100, 0, 20)
credit.Position = UDim2.new(0, 10, 0, 55)
credit.Text = "by risze"
credit.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
credit.TextColor3 = Color3.new(0.8, 0.8, 0.8)
credit.Font = Enum.Font.Gotham
credit.TextSize = 10
credit.Parent = frame

local creditCorner = Instance.new("UICorner")
creditCorner.CornerRadius = UDim.new(0, 4)
creditCorner.Parent = credit

button.MouseButton1Click:Connect(function()
    if not running then
        running = true
        button.Text = "STOP"
        button.BackgroundColor3 = Color3.fromRGB(170, 0, 0)
        task.spawn(instantFly)
    else
        running = false
        button.Text = "START"
        button.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
        roundStartTime = 0
    end
end)

task.spawn(function()
    while true do
        if running then
            enableGodMode()
        end
        task.wait(1)
    end
end)

player.CharacterAdded:Connect(function(character)
    task.wait(2)
    if running then
        enableGodMode()
        roundStartTime = 0
    end
end)
