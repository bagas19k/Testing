-- Initializing global variables to store the latest game state and game host process.
LatestGameState = LatestGameState or nil

CRED = CRED or "Sa0iBLPNyJQrwpTTG-tWLQU-1QeUAJA73DdxGGiKoJc"
Counter = Counter or 0

colors = {
    red = "\27[31m",
    green = "\27[32m",
    blue = "\27[34m",
    reset = "\27[0m",
    gray = "\27[90m"
}

-- Checks if two points are within a given range.
-- @param x1, y1: Coordinates of the first point.
-- @param x2, y2: Coordinates of the second point.
-- @param range: The maximum allowed distance between the points.
-- @return: Boolean indicating if the points are within the specified range.
function inRange(x1, y1, x2, y2, range)
    return math.abs(x1 - x2) <= range and math.abs(y1 - y2) <= range
end

-- Decides the next action based on player proximity, energy, and health.
-- Implements strategies like targeting weaker opponents, energy management, and evasive maneuvers.
function decideNextAction()
    local player = LatestGameState.Players[ao.id]
    local targets = {}
    local closestTarget = nil
    local closestDistance = math.huge

    -- Find the closest target
    for target, state in pairs(LatestGameState.Players) do
        if target ~= ao.id then
            local distance = math.sqrt((player.x - state.x) ^ 2 + (player.y - state.y) ^ 2)
            if distance < closestDistance then
                closestTarget = target
                closestDistance = distance
            end
            table.insert(targets, { target = target, state = state, distance = distance })
        end
    end

    -- Sort targets by health and distance
    table.sort(targets, function(a, b)
        if a.state.health == b.state.health then
            return a.distance < b.distance
        else
            return a.state.health < b.state.health
        end
    end)

    -- Prioritize attacking the weakest target first
    for _, target in ipairs(targets) do
        if inRange(player.x, player.y, target.state.x, target.state.y, 3) then
            if player.energy > 10 and target.state.health < player.health then
                print(colors.red .. "Attacking weak target: " .. target.target .. colors.reset)
                ao.send({ Target = Game, Action = "PlayerAttack", AttackEnergy = tostring(player.energy * 0.8) }) -- Use 80% of energy for attack
                return
            end
        end
    end

    -- If no weak targets are in range, move towards the closest target
    if closestTarget then
        local closestTargetState = LatestGameState.Players[closestTarget]
        local dx = closestTargetState.x - player.x
        local dy = closestTargetState.y - player.y
        local direction
        if math.abs(dx) > math.abs(dy) then
            direction = dx > 0 and "Right" or "Left"
        else
            direction = dy > 0 and "Down" or "Up"
        end
        print(colors.blue .. "Moving towards closest target: " .. closestTarget .. colors.reset)
        ao.send({ Target = Game, Action = "PlayerMove", Direction = direction })
    else
        -- If no targets are available, move randomly
        local directionMap = { "Up", "Down", "Left", "Right", "UpRight", "UpLeft", "DownRight", "DownLeft" }
        local randomIndex = math.random(#directionMap)
        ao.send({ Target = Game, Action = "PlayerMove", Direction = directionMap[randomIndex] })
    end
end

-- Handler to print game announcements and trigger game state updates.
Handlers.add(
    "PrintAnnouncements",
    Handlers.utils.hasMatchingTag("Action", "Announcement"),
    function(msg)
        ao.send({ Target = Game, Action = "GetGameState" })
        print(colors.green .. msg.Event .. ": " .. msg.Data .. colors.reset)
        print("Location: " .. "row: " .. LatestGameState.Players[ao.id].x .. ' col: ' .. LatestGameState.Players[ao.id]
            .y)
    end
)

-- Handler to trigger game state updates.
Handlers.add(
    "GetGameStateOnTick",
    Handlers.utils.hasMatchingTag("Action", "Tick"),
    function()
        -- print(colors.gray .. "Getting game state..." .. colors.reset)
        ao.send({ Target = Game, Action = "GetGameState" })
    end
)

-- Handler to update the game state upon receiving game state information.
Handlers.add(
    "UpdateGameState",
    Handlers.utils.hasMatchingTag("Action", "GameState"),
    function(msg)
        local json = require("json")
        LatestGameState = json.decode(msg.Data)
        ao.send({ Target = ao.id, Action = "UpdatedGameState" })
        --print("Game state updated. Print \'LatestGameState\' for detailed view.")
        print("Location: " .. "row: " .. LatestGameState.Players[ao.id].x .. ' col: ' .. LatestGameState.Players[ao.id]
            .y)
    end
)

-- Handler to decide the next best action.
Handlers.add(
    "decideNextAction",
    Handlers.utils.hasMatchingTag("Action", "UpdatedGameState"),
    function()
        --print("Deciding next action...")
        decideNextAction()
        ao.send({ Target = ao.id, Action = "Tick" })
    end
)

-- Handler to automatically attack when hit by another player.
Handlers.add(
    "ReturnAttack",
    Handlers.utils.hasMatchingTag("Action", "Hit"),
    function(msg)
        local playerEnergy = LatestGameState.Players[ao.id].energy
        if playerEnergy == undefined then
            print(colors.red .. "Unable to read energy." .. colors.reset)
            ao.send({ Target = Game, Action = "Attack-Failed", Reason = "Unable to read energy." })
        elseif playerEnergy > 10 then
            print(colors.red .. "Player has insufficient energy." .. colors.reset)
            ao.send({ Target = Game, Action = "Attack-Failed", Reason = "Player has no energy." })
        else
            print(colors.red .. "Returning attack..." .. colors.reset)
            ao.send({ Target = Game, Action = "PlayerAttack", AttackEnergy = tostring(playerEnergy) })
        end
        ao.send({ Target = ao.id, Action = "Tick" })
    end
)

Handlers.add(
    "ReSpawn",
    Handlers.utils.hasMatchingTag("Action", "Eliminated"),
    function(msg)
        print("Elminated! " .. "Playing again!")
        Send({ Target = CRED, Action = "Transfer", Quantity = "1000", Recipient = Game })
    end
)

Handlers.add(
    "StartTick",
    Handlers.utils.hasMatchingTag("Action", "Payment-Received"),
    function(msg)
        Send({ Target = Game, Action = "GetGameState", Name = Name, Owner = Owner })
        print('Start Moooooving!')
    end
)

Prompt = function() return Name .. "> " end
