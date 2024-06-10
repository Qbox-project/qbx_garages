Config = require 'config.server'
SharedConfig = require 'config.shared'
VEHICLES = exports.qbx_core:GetVehiclesByName()
Storage = require 'server.storage'

function FindPlateOnServer(plate)
    local vehicles = GetAllVehicles()
    for i = 1, #vehicles do
        if plate == GetVehicleNumberPlateText(vehicles[i]) then
            return true
        end
    end
end

---@param garage string
---@return GarageType
function GetGarageType(garage)
    if SharedConfig.garages[garage] then
        return SharedConfig.garages[garage].type
    else
        return GarageType.HOUSE
    end
end

---@alias VehicleEntity table

---@param source number
---@param garageName string
---@return VehicleEntity[]?
lib.callback.register('qbx_garages:server:getGarageVehicles', function(source, garageName)
    local garageType = GetGarageType(garageName)
    local player = exports.qbx_core:GetPlayer(source)
    if garageType == GarageType.PUBLIC then -- Public garages give player cars in the garage only
        local result = Storage.fetchGaragedVehicles(garageName, player.PlayerData.citizenid)
        return result[1] and result
    elseif garageType == GarageType.DEPOT then -- Depot give player cars that are not in garage only
        local result = Storage.fetchOutVehicles(player.PlayerData.citizenid)
        local toSend = {}
        if not result[1] then return end
        for _, vehicle in pairs(result) do -- Check vehicle type against depot type
            if not FindPlateOnServer(vehicle.plate) then
                local vehicleType = SharedConfig.garages[garageName].vehicleType
                if (vehicleType == VehicleType.AIR and (VEHICLES[vehicle.vehicle].category == 'helicopters' or VEHICLES[vehicle.vehicle].category == 'planes')) or
                   (vehicleType == VehicleType.SEA and VEHICLES[vehicle.vehicle].category == 'boats') or
                   (vehicleType == VehicleType.CAR and VEHICLES[vehicle.vehicle].category ~= 'helicopters' and VEHICLES[vehicle.vehicle].category ~= 'planes' and VEHICLES[vehicle.vehicle].category ~= 'boats') then
                    toSend[#toSend + 1] = vehicle
                end
            end
        end
        return toSend
    elseif garageType == GarageType.HOUSE or not Config.sharedGarages then -- House/Personal Job/Gang garages give all cars in the garage
        local result = Storage.fetchGaragedVehicles(garageName, player.PlayerData.citizenid)
        return result[1] and result
    else -- Job/Gang shared garages
        local result = Storage.fetchGaragedVehicles(garageName)
        return result[1] and result
    end
end)

---@param source number
---@param vehicleId string
---@param garageName string
---@return boolean
local function isParkable(source, vehicleId, garageName)
    local garageType = GetGarageType(garageName)
    assert(vehicleId ~= nil, 'owned vehicles must have vehicle ids')
    local player = exports.qbx_core:GetPlayer(source)
    local garage = SharedConfig.garages[garageName]
    if garageType == GarageType.PUBLIC then -- All players can park in public garages
        return true
    elseif garageType == GarageType.HOUSE then -- House garages only for player cars that have keys of the house
        local owner = Storage.fetchVehicleOwner(vehicleId)
        return Config.hasHouseGarageKey(garageName, owner)
    elseif garageType == GarageType.JOB then
        if player.PlayerData.job?.name ~= garage.group then return false end
        if Config.sharedGarages then
            return true
        else
            local owner = Storage.fetchVehicleOwner(vehicleId)
            return owner == player.PlayerData.citizenid
        end
    elseif garageType == GarageType.GANG then
        if player.PlayerData.gang?.name ~= garage.group then return false end
        if Config.sharedGarages then
            return true
        else
            local owner = Storage.fetchVehicleOwner(vehicleId)
            return owner == player.PlayerData.citizenid
        end
    end
    error("Unhandled GarageType: " .. garageType)
end

lib.callback.register('qbx_garages:server:isParkable', function(source, garage, netId)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    local vehicleId = Entity(vehicle).state.vehicleid
    return isParkable(source, vehicleId, garage)
end)

---@param source number
---@param netId number
---@param props table ox_lib vehicle props https://github.com/overextended/ox_lib/blob/master/resource/vehicleProperties/client.lua#L3
---@param garage string
lib.callback.register('qbx_garages:server:parkVehicle', function(source, netId, props, garage)
    local garageType = GetGarageType(garage)
    assert(garageType == GarageType.HOUSE or SharedConfig.garages[garage] ~= nil, string.format('Garage %s not found in config', garage))
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    local owned = isParkable(source, Entity(vehicle).state.vehicleid, garage) --Check ownership
    if not owned then
        exports.qbx_core:Notify(source, Lang:t('error.not_owned'), 'error')
        return
    end

    local vehicleId = Entity(vehicle).state.vehicleid
    Storage.saveVehicle(vehicleId, props, garage)
    DeleteEntity(vehicle)
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= cache.resource then return end
    Wait(100)
    if Config.autoRespawn then
        Storage.moveOutVehiclesIntoGarages()
    end
end)

---@param vehicleId string
---@return boolean? success true if successfully paid
lib.callback.register('qbx_garages:server:payDepotPrice', function(source, vehicleId)
    local player = exports.qbx_core:GetPlayer(source)
    local cashBalance = player.PlayerData.money.cash
    local bankBalance = player.PlayerData.money.bank

    local depotPrice = Storage.fetchVehicleDepotPrice(vehicleId)
    if not depotPrice or depotPrice == 0 then return true end
    if cashBalance >= depotPrice then
        player.Functions.RemoveMoney('cash', depotPrice, 'paid-depot')
        return true
    elseif bankBalance >= depotPrice then
        player.Functions.RemoveMoney('bank', depotPrice, 'paid-depot')
        return true
    end
end)
