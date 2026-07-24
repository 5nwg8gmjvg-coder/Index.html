local function loadModel(model)
    RequestModel(model)
    local attempts = 0
    while not HasModelLoaded(model) and attempts < 200 do
        Wait(10)
        attempts += 1
    end
end

local function breakBackDoors(vehicle)
    if Config.C4.doorIndices then
        for _, idx in ipairs(Config.C4.doorIndices) do
            SetVehicleDoorBroken(vehicle, idx, true)
        end
        return
    end

    local doorCount = GetNumberOfVehicleDoors(vehicle)
    if doorCount >= 2 then
        SetVehicleDoorBroken(vehicle, doorCount - 2, true)
        SetVehicleDoorBroken(vehicle, doorCount - 1, true)
    elseif doorCount == 1 then
        SetVehicleDoorBroken(vehicle, 0, true)
    end
end

RegisterNetEvent('nowipebanktruck:client:tryPlantC4', function()
    if not BT.truck or not DoesEntityExist(BT.truck) then return end
    if Entity(BT.truck).state['nowipebanktruck:stage'] ~= 'cleared' then
        BT.Notify('Nothing to breach right now.', 'error')
        return
    end

    local ped = PlayerPedId()
    local backCoords = GetOffsetFromEntityInWorldCoords(BT.truck, 0.0, -3.2, 0.0)
    if #(GetEntityCoords(ped) - backCoords) > 4.0 then
        BT.Notify('Get to the back doors first.', 'error')
        return
    end

    TriggerServerEvent('nowipebanktruck:server:requestC4', Entity(BT.truck).state['nowipebanktruck:heistId'])
end)

RegisterNetEvent('nowipebanktruck:client:c4Result', function(success)
    if not success then
        BT.Notify('You need a C4 charge to breach the doors.', 'error')
        return
    end

    if not BT.truck or not DoesEntityExist(BT.truck) then return end
    local vehicle = BT.truck
    local backCoords = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, -3.2, 0.0)

    TaskTurnPedToFaceCoord(PlayerPedId(), backCoords.x, backCoords.y, backCoords.z, 1000)
    Wait(1000)

    BT.Progress(Config.C4.plantTime, 'Planting charge')

    if not DoesEntityExist(vehicle) then return end

    loadModel(Config.C4.prop)
    local prop = CreateObject(Config.C4.prop, backCoords.x, backCoords.y, backCoords.z, true, true, false)
    SetModelAsNoLongerNeeded(Config.C4.prop)
    AttachEntityToEntity(prop, vehicle, 0, 0.0, -1.4, 0.1, 0.0, 0.0, 0.0, true, true, false, true, 1, true)

    BT.Notify('Charge armed. Get clear!', 'primary')

    Wait(Config.C4.armTime)

    if DoesEntityExist(prop) then
        local blast = GetEntityCoords(prop)
        AddExplosion(blast.x, blast.y, blast.z, 2, 1.2, true, false, 1.0, false)
        DeleteEntity(prop)
    end

    if DoesEntityExist(vehicle) then
        breakBackDoors(vehicle)
        local heistId = Entity(vehicle).state['nowipebanktruck:heistId']
        Entity(vehicle).state:set('nowipebanktruck:stage', 'breached', true)
        TriggerServerEvent('nowipebanktruck:server:log', heistId, 'breached')
    end
end)
