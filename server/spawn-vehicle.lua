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
    local garage = Garages[garageName]
    local accessPoint = garage.accessPoints[accessPointIndex]
    local garageType = GetGarageType(garageName)
    local spawnCoords = accessPoint.spawn or accessPoint.coords
    local hookPayload = {
        source = source,
        vehicleId = vehicleId,
        garage = garage,
        garageName = garageName,
        accessPointIndex = accessPointIndex,
        garageType = garageType,
        spawnCoords = spawnCoords,
        distanceCheck = Config.distanceCheck,
        doorsLocked = Config.doorsLocked,
        warpPed = Config.warpInVehicle,
        vehiclekeys = true,
        veh = nil,
        netId = nil,
        playerVehicle = nil,
    }
    local filter = GetPlayerVehicleFilter(source, garageName)
    local playerVehicle = exports.qbx_vehicles:GetPlayerVehicle(vehicleId, filter)
    if not playerVehicle then
        exports.qbx_core:Notify(source, locale('error.not_owned'), 'error')
        return
    end
    hookPayload.playerVehicle = playerVehicle
    local garageZone = lib.callback.await('qbx_garages:client:getParkZoneByAccessPointIndex', source, accessPointIndex)

    local HooksSpawnVehicle = GaragesHooks('spawnVehicle', hookPayload)

    if HooksSpawnVehicle == false then
        lib.print.debug("Vehicle spawn was canceled by a hook.")
        return
    else
        if HooksSpawnVehicle and type(HooksSpawnVehicle) == 'table' then
            for _, hookResult in ipairs(HooksSpawnVehicle) do
                if hookResult.distanceCheck ~= nil then
                    hookPayload.distanceCheck = hookResult.distanceCheck
                end
                if hookResult.doorsLocked ~= nil then
                    hookPayload.doorsLocked = hookResult.doorsLocked
                end
                if hookResult.vehiclekeys ~= nil then
                    hookPayload.vehiclekeys = hookResult.vehiclekeys
                end
                if hookResult.spawnCoords ~= nil then
                    hookPayload.spawnCoords = hookResult.spawnCoords
                end
            end
        end
    end

    -- if #(GetEntityCoords(GetPlayerPed(source)) - accessPoint.coords.xyz) > 3 then
    --     lib.print.error(string.format("Player %s attempted to spawn a vehicle but was too far from the access point", source))
    --     return
    -- end
    if garageZone or garageZone:contains(vec3(1, 1, 1)) then
        lib.print.debug('point is inside zone! Player %s', source)
    else
        lib.print.error(string.format("Player %s attempted to spawn a vehicle but was not in the correct zone", source))
        return
    end

    if hookPayload.distanceCheck then
        local vec3Coords = vec3(spawnCoords.x, spawnCoords.y, spawnCoords.z)
        local nearbyVehicle = lib.getClosestVehicle(vec3Coords, hookPayload.distanceCheck, false)
        if nearbyVehicle then
            exports.qbx_core:Notify(source, locale('error.no_space'), 'error')
            return
        end
    end

    if garageType == GarageType.DEPOT and FindPlateOnServer(playerVehicle.props.plate) then
        return exports.qbx_core:Notify(source, locale('error.not_impound'), 'error', 5000)
    end

    local warpPed = hookPayload.warpPed and GetPlayerPed(source)
    local netId, veh = qbx.spawnVehicle({
        spawnSource = spawnCoords,
        model = playerVehicle.props.model,
        props = playerVehicle.props,
        warp = warpPed
    })

    hookPayload.netId = netId
    hookPayload.veh = veh

    local hooksSpawnedVehicle = GaragesHooks('spawnedVehicle', hookPayload)

    if hooksSpawnedVehicle and type(hooksSpawnedVehicle) == 'table' then
        for _, hookResult in ipairs(hooksSpawnedVehicle) do
            if hookResult.doorsLocked ~= nil then
                hookPayload.doorsLocked = hookResult.doorsLocked
            end
            if hookResult.vehiclekeys ~= nil then
                hookPayload.vehiclekeys = hookResult.vehiclekeys
            end
        end
    elseif HooksSpawnVehicle == false then
    end

    if hookPayload.doorsLocked then
        SetVehicleDoorsLocked(veh, 2)
    end

    if hookPayload.vehiclekeys then
        TriggerClientEvent('vehiclekeys:client:SetOwner', source, playerVehicle.props.plate)
    end

    -- Définir les états supplémentaires ou propriétés du véhicule
    Entity(veh).state:set('vehicleid', vehicleId, false)
    setVehicleStateToOut(vehicleId, veh, playerVehicle.modelName)

    -- Déclencher un événement après le spawn du véhicule
    TriggerEvent('qbx_garages:server:vehicleSpawned', veh)

    return netId
end)
