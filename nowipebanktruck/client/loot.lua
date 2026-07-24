RegisterNetEvent('nowipebanktruck:client:tryLoot', function()
    if not BT.truck or not DoesEntityExist(BT.truck) then return end
    if Entity(BT.truck).state['nowipebanktruck:stage'] ~= 'breached' then
        BT.Notify('The truck is still locked up.', 'error')
        return
    end

    local ped = PlayerPedId()
    local backCoords = GetOffsetFromEntityInWorldCoords(BT.truck, 0.0, -3.2, 0.0)
    if #(GetEntityCoords(ped) - backCoords) > 4.0 then
        BT.Notify('Get closer to the truck.', 'error')
        return
    end

    BT.Progress(Config.Loot.lootTime, 'Looting truck')

    if not BT.truck or not DoesEntityExist(BT.truck) then return end
    local heistId = Entity(BT.truck).state['nowipebanktruck:heistId']
    TriggerServerEvent('nowipebanktruck:server:loot', heistId)
end)

RegisterNetEvent('nowipebanktruck:client:giveKeys', function(plate, model)
    if GetResourceState(Config.KeysResource) ~= 'started' then return end
    local ok = pcall(function()
        exports[Config.KeysResource]:GiveKeys(plate, model)
    end)
    if not ok then
        -- export name/signature differs between qs-keys forks (some use qs-vehiclekeys) -
        -- adjust Config.KeysResource or this call to match what's installed.
    end
end)

RegisterNetEvent('nowipebanktruck:client:lootResult', function(success, reason)
    if success then
        BT.Notify('You looted the bank truck.', 'success')
    else
        BT.Notify(reason or 'Nothing left to loot.', 'error')
    end
end)

-- Fallback E-to-interact prompt for the C4/loot actions when no target resource is present
CreateThread(function()
    while true do
        Wait(0)
        if not BT.HasTarget() and BT.truck and DoesEntityExist(BT.truck) then
            local stage = Entity(BT.truck).state['nowipebanktruck:stage']
            if stage == 'cleared' or stage == 'breached' then
                local backCoords = GetOffsetFromEntityInWorldCoords(BT.truck, 0.0, -3.2, 0.0)
                local dist = #(GetEntityCoords(PlayerPedId()) - backCoords)
                if dist < 3.0 then
                    local label = stage == 'cleared' and 'Plant C4 on back doors' or 'Loot bank truck'
                    DrawText3D(backCoords, ('[E] %s'):format(label))
                    if IsControlJustReleased(0, 38) then
                        if stage == 'cleared' then
                            TriggerEvent('nowipebanktruck:client:tryPlantC4')
                        else
                            TriggerEvent('nowipebanktruck:client:tryLoot')
                        end
                    end
                else
                    Wait(500)
                end
            else
                Wait(1000)
            end
        else
            Wait(1000)
        end
    end
end)
