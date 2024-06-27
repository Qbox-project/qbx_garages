---@param vehicleId integer
---@param modelName string
local function setVehicleStateToOut(vehicleId, modelName)
    local depotPrice = Config.calculateImpoundFee(vehicleId, modelName) or 0
    Storage.setVehicleStateToOut(vehicleId, depotPrice)
end

---@param source number
---@param vehicleId integer
---@param garageName string
---@param accessPoint integer
---@return number? netId
lib.callback.register('qbx_garages:server:spawnVehicle', function (source, vehicleId, garageName, accessPoint)
    local garage = Garages[garageName]
    local garageType = GetGarageType(garageName)

    local filter = GetPlayerVehicleFilter(source, garageName)
    local playerVehicle = exports.qbx_vehicles:GetPlayerVehicle(vehicleId, filter)
    if not playerVehicle then
        exports.qbx_core:Notify(source, locale('error.not_owned'), 'error')
        return
    end
    if garageType == GarageType.DEPOT and FindPlateOnServer(playerVehicle.props.plate) then -- If depot, check if vehicle is not already spawned on the map
        return exports.qbx_core:Notify(source, locale('error.not_impound'), 'error', 5000)
    end

    local warpPed = SharedConfig.takeOut.warpInVehicle and GetPlayerPed(source)
    local netId, veh = qbx.spawnVehicle({ spawnSource = garage.accessPoints[accessPoint].spawn, model = playerVehicle.props.model, props = playerVehicle.props, warp = warpPed})

    if SharedConfig.takeOut.doorsLocked then
        SetVehicleDoorsLocked(veh, 2)
    end

    TriggerClientEvent('vehiclekeys:client:SetOwner', source, playerVehicle.props.plate)

    Entity(veh).state:set('vehicleid', vehicleId, false)
    setVehicleStateToOut(vehicleId, playerVehicle.modelName)
    return netId
end)