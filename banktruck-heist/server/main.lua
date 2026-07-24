local QBCore
if Config.Core == 'qbx_core' then
    QBCore = exports.qbx_core:GetCoreObject()
else
    QBCore = exports['qb-core']:GetCoreObject()
end

local state = {
    active        = false,
    heistId       = nil,
    director      = nil,
    truckNetId    = nil,
    stage         = nil,
    looted        = false,
    cooldownUntil = 0,
}

local function getOnDutyPoliceCount()
    local count = 0
    for _, player in pairs(QBCore.Functions.GetQBPlayers()) do
        local job = player.PlayerData.job
        if job and job.onduty then
            for _, jobName in ipairs(Config.PoliceJobs) do
                if job.name == jobName then
                    count += 1
                    break
                end
            end
        end
    end
    return count
end

local function sendWebhook(title, description, fields)
    if not Config.Webhook.url or Config.Webhook.url == '' then return end
    PerformHttpRequest(Config.Webhook.url, function() end, 'POST', json.encode({
        username = Config.Webhook.botName,
        avatar_url = (Config.Webhook.botAvatar ~= '' and Config.Webhook.botAvatar) or nil,
        embeds = {
            {
                title = title,
                description = description,
                color = Config.Webhook.color,
                fields = fields or {},
                footer = { text = os.date('%Y-%m-%d %H:%M:%S') },
            },
        },
    }), { ['Content-Type'] = 'application/json' })
end

local function resetState(cooldown)
    state.active = false
    state.director = nil
    state.heistId = nil
    state.stage = nil
    state.truckNetId = nil
    state.looted = false
    if cooldown then
        state.cooldownUntil = os.time() + (Config.Cooldown * 60)
    end
end

RegisterNetEvent('banktruck:server:requestStart', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    if Config.OneAtATime and state.active then
        TriggerClientEvent('banktruck:client:notify', src, 'A bank truck heist is already underway.', 'error')
        return
    end

    if os.time() < state.cooldownUntil then
        local mins = math.ceil((state.cooldownUntil - os.time()) / 60)
        TriggerClientEvent('banktruck:client:notify', src, ('The route is on cooldown for %d more minute(s).'):format(mins), 'error')
        return
    end

    local police = getOnDutyPoliceCount()
    if police < Config.RequiredPolice then
        TriggerClientEvent('banktruck:client:notify', src, ('At least %d police must be on duty to attempt this.'):format(Config.RequiredPolice), 'error')
        return
    end

    state.active = true
    state.looted = false
    state.director = src
    state.heistId = ('bt-%s-%s'):format(src, os.time())
    state.stage = 'patrol'

    TriggerClientEvent('banktruck:client:setLockout', src, true)

    local spawnIndex = math.random(#Config.TruckSpawns)
    TriggerClientEvent('banktruck:client:beginHeist', src, spawnIndex, state.heistId)

    if Config.Webhook.logStart then
        sendWebhook('Bank Truck Heist Started', 'A crew has set off to intercept a bank truck.', {
            { name = 'Started By', value = GetPlayerName(src) or ('Player %s'):format(src), inline = true },
            { name = 'On-Duty Police', value = tostring(police), inline = true },
        })
    end
end)

RegisterNetEvent('banktruck:server:announceTruck', function(netId)
    local src = source
    if src ~= state.director then return end
    state.truckNetId = netId
    TriggerClientEvent('banktruck:client:trackEntity', -1, netId)
end)

RegisterNetEvent('banktruck:server:log', function(heistId, stage)
    local src = source
    if src ~= state.director or heistId ~= state.heistId then return end
    state.stage = stage

    if stage == 'cleared' and Config.Webhook.logCleared then
        sendWebhook('Bank Truck Heist - Guards Down', 'All guards have been eliminated. The crew is moving to breach the truck.')
    elseif stage == 'breached' and Config.Webhook.logBreached then
        sendWebhook('Bank Truck Heist - Doors Breached', 'The back doors have been blown open with C4.')
    end
end)

RegisterNetEvent('banktruck:server:requestC4', function(heistId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    if not state.active or heistId ~= state.heistId or state.stage ~= 'cleared' then
        TriggerClientEvent('banktruck:client:c4Result', src, false)
        return
    end

    local removed = exports[Config.InventoryResource]:RemoveItem(src, Config.C4.item, 1)
    TriggerClientEvent('banktruck:client:c4Result', src, removed and true or false)
end)

RegisterNetEvent('banktruck:server:loot', function(heistId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    if not state.active or heistId ~= state.heistId or state.stage ~= 'breached' or state.looted then
        TriggerClientEvent('banktruck:client:lootResult', src, false, 'Nothing left to loot.')
        return
    end

    state.looted = true -- lock immediately, before any awaits, to prevent a double-loot race

    local money = math.random(Config.Loot.moneyMin, Config.Loot.moneyMax)
    Player.Functions.AddMoney(Config.Loot.moneyType, money, 'banktruck-heist-loot')

    local droppedItems = {}
    for _, entry in ipairs(Config.Loot.items) do
        if math.random(1, 100) <= entry.chance then
            local amount = math.random(entry.min, entry.max)
            exports[Config.InventoryResource]:AddItem(src, entry.item, amount)
            table.insert(droppedItems, ('%dx %s'):format(amount, entry.item))
        end
    end

    TriggerClientEvent('banktruck:client:lootResult', src, true)

    if Config.Loot.giveTruckKeys and state.truckNetId then
        local vehicle = NetworkGetEntityFromNetworkId(state.truckNetId)
        if DoesEntityExist(vehicle) then
            local plate = GetVehicleNumberPlateText(vehicle)
            local model = GetEntityModel(vehicle)
            TriggerClientEvent('banktruck:client:giveKeys', src, plate, model)
        end
    end

    if Config.Webhook.logLoot then
        sendWebhook('Bank Truck Heist - Looted', ('%s looted the bank truck.'):format(GetPlayerName(src) or tostring(src)), {
            { name = 'Cash', value = ('$%d'):format(money), inline = true },
            { name = 'Items', value = #droppedItems > 0 and table.concat(droppedItems, ', ') or 'None', inline = true },
        })
    end

    local director = state.director
    TriggerClientEvent('banktruck:client:cleanupTruck', director)
    TriggerClientEvent('banktruck:client:heistOver', -1)

    resetState(true)
end)

AddEventHandler('playerDropped', function()
    local src = source
    if state.active and src == state.director then
        TriggerClientEvent('banktruck:client:heistOver', -1)
        resetState(true)
    end
end)

exports('IsBankTruckHeistActive', function()
    return state.active
end)
