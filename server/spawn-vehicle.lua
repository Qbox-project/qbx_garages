---@param source number
---@param garageName string
---@param garageType GarageType
---@param vehicleId string
---@return PlayerVehicle?
local function getPlayerVehicle(source, garageName, garageType, vehicleId)
    local player = exports.qbx_core:GetPlayer(source)
    local filter
    if garageType == GarageType.PUBLIC then -- Public garages give player cars in the garage only
        filter = {
            citizenid = player.PlayerData.citizenid,
            garage = garageName,
            states = VehicleState.GARAGED
        }
    elseif garageType == GarageType.DEPOT then -- Depot give player cars that are not in garage only
        filter = {
            citizenid = player.PlayerData.citizenid,
            states = VehicleState.OUT
        }
    elseif garageType == GarageType.HOUSE or not Config.sharedGarages then -- House/Personal Job/Gang garages give all cars in the garage
        filter = {
            citizenid = player.PlayerData.citizenid,
            garage = garageName,
            states = VehicleState.GARAGED
        }
    else -- Job/Gang shared garages
        filter = {
            garage = garageName,
            states = VehicleState.GARAGED
        }
    end
    return exports.qbx_vehicles:GetPlayerVehicle(vehicleId, filter)
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

    local playerVehicle = getPlayerVehicle(source, garageName, garageType, vehicleId) -- Check ownership
    if not playerVehicle then
        exports.qbx_core:Notify(source, Lang:t('error.not_owned'), 'error')
        return
    end
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