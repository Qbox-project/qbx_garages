Config = require 'config.server'
SharedConfig = require 'config.shared'
VEHICLES = exports.qbx_core:GetVehiclesByName()

function FindPlateOnServer(plate)
    local vehicles = GetAllVehicles()
    for i = 1, #vehicles do
        if plate == GetVehicleNumberPlateText(vehicles[i]) then
            return true
        end
    end
end

---@alias VehicleEntity table

---@param source number
---@param garage string
---@param garageType GarageType
---@param category VehicleType
---@return VehicleEntity[]?
lib.callback.register('qbx_garages:server:getGarageVehicles', function(source, garage, garageType, category)
    local player = exports.qbx_core:GetPlayer(source)
    if garageType == GarageType.PUBLIC then -- Public garages give player cars in the garage only
        local result = MySQL.query.await('SELECT * FROM player_vehicles WHERE citizenid = ? AND garage = ? AND state = ?', {player.PlayerData.citizenid, garage, VehicleState.GARAGED})
        return result[1] and result
    elseif garageType == GarageType.DEPOT then -- Depot give player cars that are not in garage only
        local result = MySQL.query.await('SELECT * FROM player_vehicles WHERE citizenid = ? AND state = ?', {player.PlayerData.citizenid, VehicleState.OUT})
        local toSend = {}
        if not result[1] then return end
        for _, vehicle in pairs(result) do -- Check vehicle type against depot type
            if not FindPlateOnServer(vehicle.plate) then
                if (category == VehicleType.AIR and (VEHICLES[vehicle.vehicle].category == 'helicopters' or VEHICLES[vehicle.vehicle].category == 'planes')) or
                   (category == VehicleType.SEA and VEHICLES[vehicle.vehicle].category == 'boats') or
                   (category == VehicleType.CAR and VEHICLES[vehicle.vehicle].category ~= 'helicopters' and VEHICLES[vehicle.vehicle].category ~= 'planes' and VEHICLES[vehicle.vehicle].category ~= 'boats') then
                    toSend[#toSend + 1] = vehicle
                end
            end
        end
        return toSend
    elseif garageType == GarageType.HOUSE or not Config.sharedGarages then -- House/Personal Job/Gang garages give all cars in the garage
        local result = MySQL.query.await('SELECT * FROM player_vehicles WHERE garage = ? AND state = ? AND citizenid = ?', {garage, VehicleState.GARAGED, player.PlayerData.citizenid})
        return result[1] and result
    else -- Job/Gang shared garages
        local result = MySQL.query.await('SELECT * FROM player_vehicles WHERE garage = ? AND state = ?', {garage, VehicleState.GARAGED})
        return result[1] and result
    end
end)

---@param source number
---@param garageType GarageType
---@param garage string
---@param gang string
---@param veh number entity
---@return boolean
local function isParkable(source, garageType, garage, gang, veh)
    local vehicleId = Entity(veh).state.vehicleid
    assert(vehicleId ~= nil, 'owned vehicles must have vehicle ids')
    local player = exports.qbx_core:GetPlayer(source)
    if garageType == GarageType.PUBLIC then -- Public garages only for player cars
         local result = MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE id = ? AND citizenid = ?', {vehicleId, player.PlayerData.citizenid})
         return not not result
    elseif garageType == GarageType.HOUSE then -- House garages only for player cars that have keys of the house
        local result = MySQL.single.await('SELECT license, citizenid FROM player_vehicles WHERE id = ?', {vehicleId})
        return result and exports['qb-houses']:hasKey(result.license, result.citizenid, garage)
    elseif garageType == GarageType.GANG then -- Gang garages only for gang members cars (for sharing)
        local citizenId = MySQL.scalar.await('SELECT citizenid FROM player_vehicles WHERE id = ?', {vehicleId})
        if not citizenId then return false end
        -- Check if found owner is part of the gang
        return player.PlayerData.gang?.name == gang
    elseif garageType == GarageType.HOUSE or not Config.sharedGarages then -- House/Personal Job/Gang garages give all cars in the garage
        local result = MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE citizenid = ? AND id = ?', {player.PlayerData.citizenid, vehicleId})
        return not not result
    else -- Job/Gang shared garages
        local result = MySQL.scalar.await('SELECT 1 FROM player_vehicles WHERE id = ?', {vehicleId})
        return not not result
    end
end

lib.callback.register('qbx_garages:server:isParkable', function(source, type, garage, gang, netId)
    return isParkable(source, type, garage, gang, NetworkGetEntityFromNetworkId(netId))
end)

---@param source number
---@param netId number
---@param props table ox_lib vehicle props https://github.com/overextended/ox_lib/blob/master/resource/vehicleProperties/client.lua#L3
---@param garage string
---@param garageType GarageType
---@param gang string
lib.callback.register('qbx_garages:server:parkVehicle', function(source, netId, props, garage, garageType, gang)
    assert(garageType == GarageType.HOUSE or SharedConfig.garages[garage] ~= nil, string.format('Garage %s not found in config', garage))
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    local owned = isParkable(source, garageType, garage, gang, vehicle) --Check ownership
    if not owned then
        exports.qbx_core:Notify(source, Lang:t('error.not_owned'), 'error')
        return
    end

    local vehicleId = Entity(vehicle).state.vehicleid
    MySQL.update('UPDATE player_vehicles SET state = ?, garage = ?, fuel = ?, engine = ?, body = ?, mods = ? WHERE id = ?', {VehicleState.GARAGED, garage, props.fuelLevel, props.engineHealth, props.bodyHealth, json.encode(props), vehicleId})
    DeleteEntity(vehicle)
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= cache.resource then return end
    Wait(100)
    if not Config.autoRespawn then return end

    MySQL.update('UPDATE player_vehicles SET state = ? WHERE state = ?', {VehicleState.GARAGED, VehicleState.OUT})
end)

---@param vehicleId string
---@param garageName string
RegisterNetEvent('qbx_garages:server:PayDepotPrice', function(vehicleId, garageName)
    local src = source
    local player = exports.qbx_core:GetPlayer(src)
    local cashBalance = player.PlayerData.money.cash
    local bankBalance = player.PlayerData.money.bank

    local depotPrice = MySQL.scalar.await('SELECT depotprice FROM player_vehicles WHERE id = ?', {vehicleId})
    if not depotPrice then return end
    if cashBalance >= depotPrice then
        player.Functions.RemoveMoney('cash', depotPrice, 'paid-depot')
        TriggerClientEvent('qbx_garages:client:takeOutGarage', src, vehicleId, garageName)
    elseif bankBalance >= depotPrice then
        player.Functions.RemoveMoney('bank', depotPrice, 'paid-depot')
        TriggerClientEvent('qbx_garages:client:takeOutGarage', src, vehicleId, garageName)
    else
        exports.qbx_core:Notify(src, Lang:t('error.not_enough'), 'error')
    end
end)
