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
    local warpPed = Config.warpInVehicle and GetPlayerPed(source)
    local filter = GetPlayerVehicleFilter(source, garageName)

    local hookPayload = {
        source = source,
        vehicleId = vehicleId,
        garage = garage,
        accessPointIndex = accessPointIndex,
        spawnCoords = spawnCoords,
        distanceCheck = Config.distanceCheck,
        doorsLocked = Config.doorsLocked,
        warpPed = Config.warpInVehicle,
        vehiclekeys = Config.giveKeys,
    }

    if #(GetEntityCoords(GetPlayerPed(source)) - accessPoint.coords.xyz) > 3 then
        lib.print.error(string.format("player %s attempted to spawn a vehicle but was too far from the access point", source))
        return
    end

    if Config.distanceCheck then
        local vec3Coords = vec3(spawnCoords.x, spawnCoords.y, spawnCoords.z)
        local nearbyVehicle = lib.getClosestVehicle(vec3Coords, Config.distanceCheck, false)
        if nearbyVehicle then
            exports.qbx_core:Notify(source, locale('error.no_space'), 'error')
            return
        end
    end

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

    local netId, veh = qbx.spawnVehicle({
        spawnSource = spawnCoords,
        model = playerVehicle.props.model,
        props = playerVehicle.props,
        warp = warpPed
    })

    hookPayload.netId = netId
    hookPayload.veh = veh

    if GaragesHooks('spawnedVehicle', hookPayload) == false then
        lib.print.debug("Vehicle spawned was canceled by a hook.")
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