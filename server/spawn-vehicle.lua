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
        vehiclekeys = Config.giveKeys,
    }

    local parkZone = lib.callback.await('qbx_garages:client:getParkZoneByAccessPointIndex', accessPointIndex)

    if not parkZone or not parkZone:contains(vec3(1, 1, 1)) then
        lib.print.error(string.format("Le joueur %s a essayé de faire spawn un véhicule mais est trop loin du point d'accès", source))
        return
    end

    local filter = GetPlayerVehicleFilter(source, garageName)
    local playerVehicle = exports.qbx_vehicles:GetPlayerVehicle(vehicleId, filter)
    if not playerVehicle then
        exports.qbx_core:Notify(source, locale('error.not_owned'), 'error')
        return
    end

    if garageType == GarageType.DEPOT and FindPlateOnServer(playerVehicle.props.plate) then -- If depot, check if vehicle is not already spawned on the map
        return exports.qbx_core:Notify(source, locale('error.not_impound'), 'error', 5000)
    end

    hookPayload.playerVehicle = playerVehicle

    if GaragesHooks('spawnVehicle', hookPayload) == false then
        lib.print.debug("Vehicle spawn was canceled by a hook.")
        return
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

    if GaragesHooks('spawnedVehicle', hookPayload) == false then
        DeleteEntity(veh)
        return
    end

    if hookPayload.doorsLocked then
        SetVehicleDoorsLocked(veh, 2)
    end

    if hookPayload.vehiclekeys then
        TriggerClientEvent('vehiclekeys:client:SetOwner', source, playerVehicle.props.plate)
    end

    Entity(veh).state:set('vehicleid', vehicleId, false)
    setVehicleStateToOut(vehicleId, veh, playerVehicle.modelName)
    TriggerEvent('qbx_garages:server:vehicleSpawned', veh)

    return netId
end)
