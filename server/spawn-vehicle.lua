---@param source number
---@param garage string
---@param garageType GarageType
---@param vehicleId string
---@return VehicleEntity
local function validateGarageVehicle(source, garage, garageType, vehicleId)
    local player = exports.qbx_core:GetPlayer(source)
    if garageType == GarageType.PUBLIC then -- Public garages give player cars in the garage only
        local result = MySQL.query.await('SELECT * FROM player_vehicles WHERE citizenid = ? AND garage = ? AND state = ? AND id = ?', {player.PlayerData.citizenid, garage, VehicleState.GARAGED, vehicleId})
        return result[1]
    elseif garageType == GarageType.DEPOT then -- Depot give player cars that are not in garage only
        local result = MySQL.query.await('SELECT * FROM player_vehicles WHERE citizenid = ? AND (state = ? OR state = ?) AND id = ?', {player.PlayerData.citizenid, VehicleState.OUT, VehicleState.IMPOUNDED, vehicleId})
        return result[1]
    elseif garageType == GarageType.HOUSE or not Config.sharedGarages then -- House/Personal Job/Gang garages give all cars in the garage
        local result = MySQL.query.await('SELECT * FROM player_vehicles WHERE garage = ? AND state = ? AND citizenid = ? AND id = ?', {garage, VehicleState.OUT, player.PlayerData.citizenid, vehicleId})
        return result[1] and result
    else -- Job/Gang shared garages
        local result = MySQL.query.await('SELECT * FROM player_vehicles WHERE garage = ? AND state = ?', {garage, VehicleState.OUT})
        return result[1] and result
    end
end

---@param garage string
---@return GarageType
local function getGarageType(garage)
    if SharedConfig.garages[garage] then
        return SharedConfig.garages[garage].type
    else
        return GarageType.HOUSE
    end
end

---@param source number
---@param vehicleId string
---@param garage string
local function updateVehicleState(source, vehicleId, garage)
    local type = getGarageType(garage)

    local owned = validateGarageVehicle(source, garage, type, vehicleId) -- Check ownership
    if not owned then
        exports.qbx_core:Notify(source, Lang:t('error.not_owned'), 'error')
        return
    end

    local state = VehicleState.OUT
    local carInfo = MySQL.single.await('SELECT vehicle, depotprice FROM player_vehicles WHERE id = ?', {vehicleId})
    if not carInfo then return end

    local vehCost = VEHICLES[carInfo.vehicle].price
    local newPrice = qbx.math.round(vehCost * (Config.impoundFee.percentage / 100))
    if Config.impoundFee.enable then
        if carInfo.depotprice ~= newPrice then
            MySQL.update('UPDATE player_vehicles SET state = ?, depotprice = ? WHERE id = ?', {state, newPrice, vehicleId})
        else
            MySQL.update('UPDATE player_vehicles SET state = ? WHERE id = ?', {state, vehicleId})
        end
    else
        MySQL.update('UPDATE player_vehicles SET state = ?, depotprice = 0 WHERE id = ?', {state, vehicleId})
    end
end

---@param source number
---@param vehicleEntity VehicleEntity
---@param coords vector4
---@param garageType GarageType
---@param garageName string
---@return number? netId
lib.callback.register('qbx_garages:server:spawnVehicle', function (source, vehicleEntity, coords, garageType, garageName)
    local props = {}

    local result = MySQL.query.await('SELECT plate, mods FROM player_vehicles WHERE id = ? LIMIT 1', {vehicleEntity.id})

    if result[1] then
        if garageType == GarageType.DEPOT then
            if FindPlateOnServer(result[1].plate) then -- If depot, check if vehicle is not already spawned on the map
                return exports.qbx_core:Notify(source, Lang:t('error.not_impound'), 'error', 5000)
            end
        end
        props = json.decode(result[1].mods)
    end

    local warpPed = SharedConfig.takeOut.warpInVehicle and GetPlayerPed(source)
    local netId, veh = qbx.spawnVehicle({ spawnSource = coords, model = vehicleEntity.vehicle, props = props, warp = warpPed})

    if SharedConfig.takeOut.doorsLocked then
        SetVehicleDoorsLocked(veh, 2)
    end

    TriggerClientEvent('vehiclekeys:client:SetOwner', source, vehicleEntity.plate)

    Entity(veh).state:set('vehicleid', vehicleEntity.id, false)
    updateVehicleState(source, vehicleEntity.id, garageName)
    return netId
end)