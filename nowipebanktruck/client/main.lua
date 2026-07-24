-- Shared client-side namespace used by truck.lua / c4.lua / loot.lua
BT = {
    QBCore        = nil,
    ped           = nil,
    blip          = nil,
    heistId       = nil,
    isDirector    = false,
    truck         = nil,
    driver        = nil,
    guards        = {},
    lockedOut     = false, -- true while a heist we started is running, blocks re-triggering the ped
}

if Config.Core == 'qbx_core' then
    BT.QBCore = exports.qbx_core:GetCoreObject()
else
    BT.QBCore = exports['qb-core']:GetCoreObject()
end

function BT.Notify(msg, type)
    TriggerEvent('QBCore:Notify', msg, type or 'primary')
end

function BT.HasTarget()
    return GetResourceState('qb-target') == 'started' or GetResourceState('ox_target') == 'started'
end

-- ============================================================
--  MISSION PED
-- ============================================================
local function spawnPed()
    local model = Config.Ped.model
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end

    local c = Config.Ped.coords
    BT.ped = CreatePed(4, model, c.x, c.y, c.z - 1.0, c.w, false, true)
    SetEntityInvincible(BT.ped, true)
    FreezeEntityPosition(BT.ped, true)
    SetBlockingOfNonTemporaryEvents(BT.ped, true)
    TaskStartScenarioInPlace(BT.ped, Config.Ped.scenario, 0, true)
    SetModelAsNoLongerNeeded(model)

    if Config.Blip.show then
        BT.blip = AddBlipForCoord(c.x, c.y, c.z)
        SetBlipSprite(BT.blip, Config.Blip.sprite)
        SetBlipColour(BT.blip, Config.Blip.color)
        SetBlipScale(BT.blip, Config.Blip.scale)
        SetBlipAsShortRange(BT.blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString(Config.Blip.label)
        EndTextCommandSetBlipName(BT.blip)
    end

    if BT.HasTarget() then
        if GetResourceState('qb-target') == 'started' then
            exports['qb-target']:AddTargetEntity(BT.ped, {
                options = {
                    {
                        type = 'client',
                        event = 'nowipebanktruck:client:openMenu',
                        icon = 'fas fa-truck-ramp-box',
                        label = Config.Ped.label,
                    },
                },
                distance = Config.Ped.interactDistance,
            })
        elseif GetResourceState('ox_target') == 'started' then
            exports.ox_target:addLocalEntity(BT.ped, {
                {
                    name = 'nowipebanktruck_start',
                    icon = 'fas fa-truck-ramp-box',
                    label = Config.Ped.label,
                    distance = Config.Ped.interactDistance,
                    onSelect = function()
                        TriggerEvent('nowipebanktruck:client:openMenu')
                    end,
                },
            })
        end
    end
end

CreateThread(function()
    spawnPed()
end)

-- Fallback E-to-interact prompt when no target resource is present
CreateThread(function()
    while true do
        Wait(0)
        if not BT.HasTarget() and BT.ped and DoesEntityExist(BT.ped) then
            local pcoords = GetEntityCoords(PlayerPedId())
            local dist = #(pcoords - GetEntityCoords(BT.ped))
            if dist < Config.Ped.interactDistance then
                DrawText3D(GetEntityCoords(BT.ped), ('[E] %s'):format(Config.Ped.label))
                if IsControlJustReleased(0, 38) then
                    TriggerEvent('nowipebanktruck:client:openMenu')
                end
            else
                Wait(500)
            end
        else
            Wait(500)
        end
    end
end)

function DrawText3D(coords, text)
    local onScreen, sx, sy = World3dToScreen2d(coords.x, coords.y, coords.z + 1.0)
    if onScreen then
        SetTextScale(0.35, 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry('STRING')
        SetTextCentre(true)
        AddTextComponentString(text)
        DrawText(sx, sy)
    end
end

-- Simple blocking "hold to do X" helper shared by c4.lua / loot.lua.
-- Disables movement/combat controls and draws a floating countdown above
-- the player's head for `duration` ms.
function BT.Progress(duration, label)
    local start = GetGameTimer()
    while GetGameTimer() - start < duration do
        Wait(0)
        DisableControlAction(0, 24, true) -- attack
        DisableControlAction(0, 25, true) -- aim
        DisableControlAction(0, 30, true) -- move lr
        DisableControlAction(0, 31, true) -- move ud
        DisableControlAction(0, 21, true) -- sprint
        DisableControlAction(0, 22, true) -- jump
        local remaining = math.ceil((duration - (GetGameTimer() - start)) / 1000)
        DrawText3D(GetEntityCoords(PlayerPedId()), ('%s... %ds'):format(label, remaining))
    end
    return true
end

RegisterNetEvent('nowipebanktruck:client:openMenu', function()
    if BT.lockedOut then
        BT.Notify('Nothing for you right now.', 'error')
        return
    end
    TriggerServerEvent('nowipebanktruck:server:requestStart')
end)

RegisterNetEvent('nowipebanktruck:client:notify', function(msg, type)
    BT.Notify(msg, type)
end)

-- ============================================================
--  Broadcast entity blip so the whole server can see the truck once it's rolling
-- ============================================================
RegisterNetEvent('nowipebanktruck:client:trackEntity', function(netId)
    CreateThread(function()
        local attempts = 0
        while not NetworkDoesEntityExistWithNetworkId(netId) and attempts < 100 do
            Wait(100)
            attempts += 1
        end
        if not NetworkDoesEntityExistWithNetworkId(netId) then return end

        local entity = NetworkGetEntityFromNetworkId(netId)
        BT.truckNetId = netId
        BT.truck = entity

        local blip = AddBlipForEntity(entity)
        SetBlipSprite(blip, 826)
        SetBlipColour(blip, 1)
        SetBlipScale(blip, 0.9)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentString('Bank Truck')
        EndTextCommandSetBlipName(blip)

        if BT.HasTarget() then
            if GetResourceState('qb-target') == 'started' then
                exports['qb-target']:AddTargetEntity(entity, {
                    options = {
                        {
                            type = 'client',
                            event = 'nowipebanktruck:client:tryPlantC4',
                            icon = 'fas fa-bomb',
                            label = 'Plant C4 on back doors',
                            canInteract = function(ent) return Entity(ent).state['nowipebanktruck:stage'] == 'cleared' end,
                        },
                        {
                            type = 'client',
                            event = 'nowipebanktruck:client:tryLoot',
                            icon = 'fas fa-sack-dollar',
                            label = 'Loot bank truck',
                            canInteract = function(ent) return Entity(ent).state['nowipebanktruck:stage'] == 'breached' end,
                        },
                    },
                    distance = 3.0,
                })
            elseif GetResourceState('ox_target') == 'started' then
                exports.ox_target:addLocalEntity(entity, {
                    {
                        name = 'nowipebanktruck_c4',
                        icon = 'fas fa-bomb',
                        label = 'Plant C4 on back doors',
                        distance = 3.0,
                        canInteract = function(ent) return Entity(ent).state['nowipebanktruck:stage'] == 'cleared' end,
                        onSelect = function() TriggerEvent('nowipebanktruck:client:tryPlantC4') end,
                    },
                    {
                        name = 'nowipebanktruck_loot',
                        icon = 'fas fa-sack-dollar',
                        label = 'Loot bank truck',
                        distance = 3.0,
                        canInteract = function(ent) return Entity(ent).state['nowipebanktruck:stage'] == 'breached' end,
                        onSelect = function() TriggerEvent('nowipebanktruck:client:tryLoot') end,
                    },
                })
            end
        end

        while DoesEntityExist(entity) do
            Wait(1000)
        end
        RemoveBlip(blip)
    end)
end)

RegisterNetEvent('nowipebanktruck:client:setLockout', function(state)
    BT.lockedOut = state
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if BT.ped and DoesEntityExist(BT.ped) then DeleteEntity(BT.ped) end
    if BT.blip then RemoveBlip(BT.blip) end
end)
