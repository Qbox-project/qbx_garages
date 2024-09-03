local triggerEventHooks = lib.load('@qbx_core.modules.hooks')

---@param vehicleId integer
---@param modelName string
local function setVehicleStateToOut(vehicleId, vehicle, modelName)
    local depotPrice = Config.calculateImpoundFee(vehicleId, modelName) or 0
    exports.qbx_vehicles:SaveVehicle(vehicle, {
        state = VehicleState.OUT,
        depotPrice = depotPrice
    })
end

---@param source number
---@param vehicleId integer
---@param garageName string
---@param accessPointIndex integer
---@return number? netId
lib.callback.register('qbx_garages:server:spawnVehicle', function(source, vehicleId, garageName, accessPointIndex)
    -- Prepare the hook payload with the possibility to override configurations
    local hookPayload = {
        source = source,
        vehicleId = vehicleId,
        garageName = garageName,
        accessPointIndex = accessPointIndex,
        distanceCheck = Config.distanceCheck, -- Default value from config
        doorsLocked = Config.doorsLocked, -- Default value from config
        cancel = false,
        veh = nil,
        netId = nil,
        vehiclekeys = true,
        Notify = { -- For custom notifications
            description = nil,
            type = 'inform'
        },
    }

    -- Trigger the hook and allow it to modify the payload (optional)
    if triggerEventHooks('garages:spawnVehicle', hookPayload) == false then
        lib.print.debug("Vehicle spawn was canceled by a hook.")
        if hookPayload.Notify.description then
            return exports.qbx_core:Notify(source, hookPayload.Notify.description, hookPayload.Notify.type)
        end
        return
    end

    -- Proceed with the vehicle spawn
    local garage = Garages[garageName]
    local accessPoint = garage.accessPoints[accessPointIndex]
    if #(GetEntityCoords(GetPlayerPed(source)) - accessPoint.coords.xyz) > 3 then
        lib.print.error(string.format("Player %s attempted to spawn a vehicle but was too far from the access point", source))
        return
    end

    local garageType = GetGarageType(garageName)
    local spawnCoords = accessPoint.spawn or accessPoint.coords

    -- Use the distanceCheck value from the payload (which may have been modified by a hook)
    if hookPayload.distanceCheck then
        local vec3Coords = vec3(spawnCoords.x, spawnCoords.y, spawnCoords.z)
        local nearbyVehicle = lib.getClosestVehicle(vec3Coords, hookPayload.distanceCheck, false)
        if nearbyVehicle then
            exports.qbx_core:Notify(source, locale('error.no_space'), 'error')
            return
        end
    end

    local filter = GetPlayerVehicleFilter(source, garageName)
    local playerVehicle = exports.qbx_vehicles:GetPlayerVehicle(vehicleId, filter)
    if not playerVehicle then
        exports.qbx_core:Notify(source, locale('error.not_owned'), 'error')
        return
    end

    if garageType == GarageType.DEPOT and FindPlateOnServer(playerVehicle.props.plate) then
        return exports.qbx_core:Notify(source, locale('error.not_impound'), 'error', 5000)
    end

    local warpPed = Config.warpInVehicle and GetPlayerPed(source)
    local netId, veh = qbx.spawnVehicle({
        spawnSource = spawnCoords,
        model = playerVehicle.props.model,
        props = playerVehicle.props,
        warp = warpPed
    })

    hookPayload.netId = netId
    hookPayload.veh = veh

    -- Trigger the spawnedVehicle hook
    triggerEventHooks('garages:spawnedVehicle', hookPayload)

    -- Use the doorsLocked value from the payload (which may have been modified by a hook)
    if hookPayload.doorsLocked then
        SetVehicleDoorsLocked(veh, 2)
    end

    -- Use the key system from the payload (which may have been modified by a hook)
    if hookPayload.vehiclekeys then
        TriggerClientEvent('vehiclekeys:client:SetOwner', source, playerVehicle.props.plate)
    end

    -- Set additional vehicle states or properties
    Entity(veh).state:set('vehicleid', vehicleId, false)
    setVehicleStateToOut(vehicleId, veh, playerVehicle.modelName)

    -- Trigger an event after the vehicle has been spawned
    TriggerEvent('qbx_garages:server:vehicleSpawned', veh)

    -- Send notification if defined in the hookPayload
    if hookPayload.Notify.description then
        exports.qbx_core:Notify(source, hookPayload.Notify.description, hookPayload.Notify.type)
    end

    return netId
end)

-- EXEMPLE
-- Register the hook with qbx_garages
exports.qbx_garages:registerHook('garages:spawnVehicle', function(payload)
    -- Check if the vehicle is being spawned from the 'impound_lspd' garage
    if payload.garageName == 'impound_lspd' then
        lib.print.info('Canceling spawn for impound_lspd')
        payload.cancel = true
        -- payload.Notify = {description = 'You must request your vehicle from the impound.', type = 'error'}
        payload.Notify.description = 'You must request your vehicle from the impound.'
        payload.Notify.type = 'error'
        return false -- Cancels the spawn
    end

    return true -- Continue with the spawn
end)

exports.qbx_garages:registerHook('garages:spawnedVehicle', function(payload)
    -- Check if the vehicle is being spawned from the 'impound_lspd' garage
    payload.Notify = {description = 'Enjoy your trip.', type = 'inform'}
    return true -- Continue with the spawn
end)


-- exports.qbx_garages:registerHook('garages:spawnedVehicle', function(payload)
--     if payload.veh and payload.netId then
--         Entity(payload.veh).state:set('vehicleLock', {
--             lock = 2, -- 1 for unlocked, 2 for locked
--             sound = true -- play lock sound
--         }, true)
--         exports['Renewed-Vehiclekeys']:addKey(payload.source, payload.playerVehicle.props.plate)
--         payload.Notify = {description = 'Keys have been given to the player for vehicle plate: '..payload.playerVehicle.props.plate, type = 'inform'}
--     else
--         payload.Notify = {description = 'Failed to spawn the vehicle, no keys were given.', type = 'error'}
--     end
--     return true
-- end)
-- Register a hook for after the vehicle is spawned
-- exports.qbx_garages:registerHook('garages:spawnedVehicle', function(payload)
--     if payload.veh and payload.netId then
--         -- Set vehicle lock state using statebag
--         Entity(payload.veh).state:set('vehicleLock', {
--             lock = 2, -- Locked
--             sound = true -- Play sound
--         }, true)

--         -- Optionally, give vehicle keys to the player
--         TriggerClientEvent('vehiclekeys:client:SetOwner', payload.source, payload.playerVehicle.props.plate)

--         -- Set a notification for successful key give
--         payload.Notify = {description = 'Keys have been given to the player for vehicle plate: ' .. payload.playerVehicle.props.plate, type = 'inform'}
--     else
--         -- If something went wrong
--         payload.Notify = {description = 'Failed to spawn the vehicle, no keys were given.', type = 'error'}
--     end
--     return true
-- end, {
--     print = true -- This will print to the console whenever this hook is triggered
-- })
