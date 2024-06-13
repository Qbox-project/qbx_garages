---@param source number
---@param garageName string
---@param garageType GarageType
---@param vehicleId string
---@return boolean
local function checkHasAccessToVehicle(source, garageName, garageType, vehicleId)
    local player = exports.qbx_core:GetPlayer(source)
    local result
    if garageType == GarageType.PUBLIC then -- Public garages give player cars in the garage only
        result = MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE citizenid = ? AND garage = ? AND state = ? AND id = ? LIMIT 1', {player.PlayerData.citizenid, garageName, VehicleState.GARAGED, vehicleId})
    elseif garageType == GarageType.DEPOT then -- Depot give player cars that are not in garage only
        result = MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE citizenid = ? AND (state = ? OR state = ?) AND id = ? LIMIT 1', {player.PlayerData.citizenid, VehicleState.OUT, VehicleState.IMPOUNDED, vehicleId})
    elseif garageType == GarageType.HOUSE or not Config.sharedGarages then -- House/Personal Job/Gang garages give all cars in the garage
        result = MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE garage = ? AND state = ? AND citizenid = ? AND id = ? LIMIT 1', {garageName, VehicleState.OUT, player.PlayerData.citizenid, vehicleId})
    else -- Job/Gang shared garages
        result = MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE garage = ? AND state = ? AND id = ? LIMIT 1', {garageName, VehicleState.OUT, vehicleId})
    end
    return result ~= nil
end

---@param vehicleId string
---@param modelName string
local function setVehicleStateToOut(vehicleId, modelName)
    local vehCost = VEHICLES[modelName].price
    local depotPrice = Config.impoundFee.enable and qbx.math.round(vehCost * (Config.impoundFee.percentage / 100)) or 0
    Storage.setVehicleStateToOut(vehicleId, depotPrice)
end

---@param source number
---@param vehicleId string
---@param garageName string
---@return number? netId
lib.callback.register('qbx_garages:server:spawnVehicle', function (source, vehicleId, garageName)
    local garage = SharedConfig.garages[garageName]
    local garageType = GetGarageType(garageName)

    local owned = checkHasAccessToVehicle(source, garageName, garageType, vehicleId) -- Check ownership
    if not owned then
        exports.qbx_core:Notify(source, Lang:t('error.not_owned'), 'error')
        return
    end

    local playerVehicle = exports.qbx_vehicles:GetPlayerVehicles({
        vehicleId = vehicleId
    })
    if garageType == GarageType.DEPOT and FindPlateOnServer(playerVehicle.props.plate) then -- If depot, check if vehicle is not already spawned on the map
        return exports.qbx_core:Notify(source, Lang:t('error.not_impound'), 'error', 5000)
    end

    local warpPed = SharedConfig.takeOut.warpInVehicle and GetPlayerPed(source)
    local netId, veh = qbx.spawnVehicle({ spawnSource = garage.spawn, model = playerVehicle.props.model, props = playerVehicle.props, warp = warpPed})

    if SharedConfig.takeOut.doorsLocked then
        SetVehicleDoorsLocked(veh, 2)
    end

    TriggerClientEvent('vehiclekeys:client:SetOwner', source, playerVehicle.props.plate)

    Entity(veh).state:set('vehicleid', vehicleId, false)
    setVehicleStateToOut(vehicleId, playerVehicle.modelName)
    return netId
end)