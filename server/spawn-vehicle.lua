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
lib.callback.register('qbx_garages:server:spawnVehicle', function (source, vehicleId, garageName, accessPointIndex)
    local garage = Garages[garageName]
    local accessPoint = garage.accessPoints[accessPointIndex]
    if #(GetEntityCoords(GetPlayerPed(source)) - accessPoint.coords.xyz) > 3 then
        lib.print.error(string.format("player %s attempted to spawn a vehicle but was too far from the access point", source))
        return
    end
    local garageType = GetGarageType(garageName)

    local spawnCoords = accessPoint.spawn or accessPoint.coords
    if Config.distanceCheck then
        local vec3Coords = vec3(spawnCoords.x, spawnCoords.y, spawnCoords.z)
        local nearbyVehicle = lib.getClosestVehicle(vec3Coords, Config.distanceCheck, false)
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
    if garageType == GarageType.DEPOT and FindPlateOnServer(playerVehicle.props.plate) then -- If depot, check if vehicle is not already spawned on the map
        return exports.qbx_core:Notify(source, locale('error.not_impound'), 'error', 5000)
    end

    local warpPed = Config.warpInVehicle and GetPlayerPed(source)
    local netId, veh = qbx.spawnVehicle({ spawnSource = spawnCoords, model = playerVehicle.props.model, props = playerVehicle.props, warp = warpPed})

    if Config.doorsLocked then
        SetVehicleDoorsLocked(veh, 2)
    end

    TriggerClientEvent('vehiclekeys:client:SetOwner', source, playerVehicle.props.plate)

    Entity(veh).state:set('vehicleid', vehicleId, false)
    setVehicleStateToOut(vehicleId, veh, playerVehicle.modelName)
    TriggerEvent('qbx_garages:server:vehicleSpawned', veh)
    return netId
end)