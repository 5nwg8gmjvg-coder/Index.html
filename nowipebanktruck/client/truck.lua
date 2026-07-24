-- Director-only logic: spawns the truck/driver/guards and runs the patrol,
-- stop-detection and combat state machine. Every other client just reacts
-- to the vehicle's state bag (see the AddStateBagChangeHandler below).

local RELATIONSHIP_GROUP = `bt_hostile`

local function setupRelationshipGroup()
    AddRelationshipGroup(RELATIONSHIP_GROUP)
    SetRelationshipBetweenGroups(5, RELATIONSHIP_GROUP, `PLAYER`)
    SetRelationshipBetweenGroups(5, `PLAYER`, RELATIONSHIP_GROUP)
end

local function loadModel(model)
    RequestModel(model)
    local attempts = 0
    while not HasModelLoaded(model) and attempts < 200 do
        Wait(10)
        attempts += 1
    end
end

local function createGuard(coords, heading, visible)
    local model = Config.Guards.models[math.random(#Config.Guards.models)]
    loadModel(model)
    local ped = CreatePed(4, model, coords.x, coords.y, coords.z, heading, true, true)
    SetModelAsNoLongerNeeded(model)
    SetEntityAsMissionEntity(ped, true, true)

    SetPedRelationshipGroupHash(ped, RELATIONSHIP_GROUP)
    SetPedCombatAttributes(ped, 46, true)
    SetPedCombatAttributes(ped, 5, true) -- can use cover
    SetPedCombatAbility(ped, 2)
    SetPedCombatRange(ped, 2)
    SetPedAccuracy(ped, Config.Guards.accuracy)
    SetPedArmour(ped, Config.Guards.armor)
    SetEntityMaxHealth(ped, Config.Guards.health)
    SetEntityHealth(ped, Config.Guards.health)
    GiveWeaponToPed(ped, Config.Guards.weapon, 250, false, true)
    SetCurrentPedWeapon(ped, Config.Guards.weapon, true)
    SetEntityVisible(ped, visible, false)
    SetEntityCollision(ped, visible, visible)
    SetBlockingOfNonTemporaryEvents(ped, true)

    return ped
end

local function beginPatrol(vehicle, driver, route)
    local idx = 1
    while BT.truck == vehicle and DoesEntityExist(vehicle) do
        local point = route[idx]
        if not DoesEntityExist(driver) or IsEntityDead(driver) then return end

        TaskVehicleDriveToCoordLongrange(driver, vehicle, point.x, point.y, point.z, Config.PatrolSpeed, Config.DriveStyle, 5.0)

        local waited = 0
        while waited < 90000 do
            Wait(500)
            waited += 500
            if not DoesEntityExist(vehicle) then return end
            if BT.stage ~= 'patrol' then return end
            local dist = #(GetEntityCoords(vehicle) - point)
            if dist < 8.0 then break end
        end

        idx += 1
        if idx > #route then idx = 1 end
    end
end

local function setStage(vehicle, stage)
    BT.stage = stage
    Entity(vehicle).state:set('nowipebanktruck:stage', stage, true)
end

local function bailOutAndFight(vehicle)
    setStage(vehicle, 'combat')

    local backCoords = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, -3.5, 0.0)

    if DoesEntityExist(BT.driver) and not IsEntityDead(BT.driver) then
        ClearPedTasksImmediately(BT.driver)
        TaskLeaveVehicle(BT.driver, vehicle, 0)
        Wait(1500)
        TaskCombatHatedTargetsAroundPed(BT.driver, 100.0, 0)
    end

    for _, guard in ipairs(BT.guards) do
        if DoesEntityExist(guard) and not IsEntityDead(guard) then
            if IsPedInAnyVehicle(guard, false) then
                ClearPedTasksImmediately(guard)
                TaskLeaveVehicle(guard, vehicle, 0)
            else
                if IsEntityAttachedToEntity(guard, vehicle) then
                    DetachEntity(guard, true, true)
                end
                SetEntityVisible(guard, true, false)
                SetEntityCollision(guard, true, true)
                SetEntityCoords(guard, backCoords.x, backCoords.y, backCoords.z)
            end
            Wait(300)
            TaskCombatHatedTargetsAroundPed(guard, 100.0, 0)
        end
    end

    -- Monitor deaths, transition to 'cleared' once every guard (incl. driver) is down
    CreateThread(function()
        while true do
            Wait(1000)
            local allDead = true
            if DoesEntityExist(BT.driver) and not IsEntityDead(BT.driver) then allDead = false end
            for _, guard in ipairs(BT.guards) do
                if DoesEntityExist(guard) and not IsEntityDead(guard) then allDead = false end
            end
            if allDead then
                setStage(vehicle, 'cleared')
                TriggerServerEvent('nowipebanktruck:server:log', BT.heistId, 'cleared')
                break
            end
            if not DoesEntityExist(vehicle) then break end
        end
    end)
end

local function monitorStopDetection(vehicle)
    local stoppedFor = 0
    while BT.truck == vehicle and DoesEntityExist(vehicle) do
        Wait(250)
        if BT.stage == 'patrol' then
            local speed = GetEntitySpeed(vehicle)
            if speed < Config.StopDetection.speedThreshold then
                stoppedFor += 250
                if stoppedFor >= Config.StopDetection.timeStopped then
                    bailOutAndFight(vehicle)
                    break
                end
            else
                stoppedFor = 0
            end
        end
    end
end

RegisterNetEvent('nowipebanktruck:client:beginHeist', function(spawnIndex, heistId)
    BT.isDirector = true
    BT.heistId = heistId
    BT.stage = 'patrol'
    BT.guards = {}

    setupRelationshipGroup()

    local spawnData = Config.TruckSpawns[spawnIndex]
    if not spawnData then return end

    loadModel(Config.TruckModel)
    local s = spawnData.spawn
    local vehicle = CreateVehicle(Config.TruckModel, s.x, s.y, s.z, s.w, true, false)
    SetModelAsNoLongerNeeded(Config.TruckModel)
    SetVehicleOnGroundProperly(vehicle)
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleDoorsLocked(vehicle, 2)
    SetVehicleNumberPlateText(vehicle, ('BNK%04d'):format(math.random(0, 9999)))

    BT.truck = vehicle
    Entity(vehicle).state:set('nowipebanktruck:heistId', heistId, true)
    setStage(vehicle, 'patrol')

    -- driver
    local driver = createGuard(s, s.w, true)
    TaskWarpPedIntoVehicle(driver, vehicle, -1)
    SetPedKeepTask(driver, true)
    BT.driver = driver

    -- remaining guards: one rides shotgun (visible), the rest hide until the truck is stopped
    for i = 2, Config.Guards.count do
        local visible = i == 2
        local guard = createGuard(s, s.w, visible)
        if visible then
            TaskWarpPedIntoVehicle(guard, vehicle, 0)
        else
            AttachEntityToEntity(guard, vehicle, 0, 0.0, -1.0, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
        end
        table.insert(BT.guards, guard)
    end

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    TriggerServerEvent('nowipebanktruck:server:announceTruck', netId)
    TriggerServerEvent('nowipebanktruck:server:log', heistId, 'start')

    CreateThread(function() beginPatrol(vehicle, driver, spawnData.route) end)
    CreateThread(function() monitorStopDetection(vehicle) end)
end)

-- Reacts to stage changes on ANY client (notifications only, no authority)
AddStateBagChangeHandler('nowipebanktruck:stage', nil, function(bagName, key, value)
    local entity = GetEntityFromStateBagName(bagName)
    if not DoesEntityExist(entity) then return end

    local pcoords = GetEntityCoords(PlayerPedId())
    if #(pcoords - GetEntityCoords(entity)) > 150.0 then return end

    if value == 'combat' then
        BT.Notify('The bank truck guards are fighting back!', 'error')
    elseif value == 'cleared' then
        BT.Notify('Guards down. Plant C4 on the back doors to breach the truck.', 'success')
    elseif value == 'breached' then
        BT.Notify('The back doors are blown open. Loot the truck!', 'success')
    end
end)

RegisterNetEvent('nowipebanktruck:client:cleanupTruck', function()
    if BT.truck and DoesEntityExist(BT.truck) then DeleteEntity(BT.truck) end
    if BT.driver and DoesEntityExist(BT.driver) then DeleteEntity(BT.driver) end
    for _, guard in ipairs(BT.guards) do
        if DoesEntityExist(guard) then DeleteEntity(guard) end
    end
    BT.truck, BT.driver, BT.guards, BT.isDirector, BT.heistId, BT.stage = nil, nil, {}, false, nil, nil
end)

RegisterNetEvent('nowipebanktruck:client:heistOver', function()
    BT.lockedOut = false
end)
