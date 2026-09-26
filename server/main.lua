local logger = require '@qbx_core.modules.logger'

assert(lib.checkDependency('qbx_core', '1.19.0', true))
assert(lib.checkDependency('qbx_vehicles', '1.3.1', true))
lib.versionCheck('Qbox-project/qbx_garages')

---@class ErrorResult
---@field code string
---@field message string

---@class PlayerVehicle
---@field id number
---@field citizenid? string
---@field modelName string
---@field garage string
---@field state VehicleState
---@field depotPrice integer
---@field props table ox_lib properties table

Config = require 'config.server'
VEHICLES = exports.qbx_core:GetVehiclesByName()
Storage = require 'server.storage'
---@type table<string, GarageConfig>
Garages = Config.garages
local parkingAuthorizations = {}
local parkingVehicles = {}

lib.callback.register('qbx_garages:server:getGarages', function()
    return Garages
end)

---Returns garages for use server side.
local function getGarages()
    return Garages
end
exports('GetGarages', getGarages)

---@param name string
---@param config GarageConfig
local function registerGarage(name, config)
    Garages[name] = config
    TriggerClientEvent('qbx_garages:client:garageRegistered', -1, name, config)
    TriggerEvent('qbx_garages:server:garageRegistered', name, config)
end

exports('RegisterGarage', registerGarage)

---Sets the vehicle's garage. It is the caller's responsibility to make sure the vehicle is not currently spawned in the world, or else this may have no effect.
---@param vehicleId integer
---@param garageName string
---@return boolean success, ErrorResult?
local function setVehicleGarage(vehicleId, garageName)
    local garage = Garages[garageName]
    if not garage then
        return false, {
            code = 'not_found',
            message = string.format('garage name %s not found. Did you forget to register it?', garageName)
        }
    end

    local state = garage.type == GarageType.DEPOT and VehicleState.IMPOUNDED or VehicleState.GARAGED
    local numRowsAffected = Storage.setVehicleGarage(vehicleId, garageName, state)
    if numRowsAffected == 0 then
        return false, {
            code = 'no_rows_changed',
            message = string.format('no rows were changed for vehicleId=%s', vehicleId)
        }
    end
    return true
end

exports('SetVehicleGarage', setVehicleGarage)

---Sets the vehicle's price for retrieval at a depot. Only affects vehicles that are OUT or IMPOUNDED.
---@param vehicleId integer
---@param depotPrice integer
---@return boolean success, ErrorResult?
local function setVehicleDepotPrice(vehicleId, depotPrice)
    local numRowsAffected = Storage.setVehicleDepotPrice(vehicleId, depotPrice)
    if numRowsAffected == 0 then
        return false, {
            code = 'no_rows_changed',
            message = string.format('no rows were changed for vehicleId=%s', vehicleId)
        }
    end
    return true
end

exports('SetVehicleDepotPrice', setVehicleDepotPrice)

function FindPlateOnServer(plate)
    local vehicles = GetAllVehicles()
    for i = 1, #vehicles do
        if plate == GetVehicleNumberPlateText(vehicles[i]) then
            return true
        end
    end
end

---@param garage string
---@return GarageType?
function GetGarageType(garage)
    return Garages[garage]?.type
end

---@class PlayerVehiclesFilters
---@field citizenid? string
---@field states? VehicleState|VehicleState[]
---@field garage? string

---@param source number
---@param garageName string
---@return PlayerVehiclesFilters
function GetPlayerVehicleFilter(source, garageName)
    local player = exports.qbx_core:GetPlayer(source)
    local garage = Garages[garageName]
    if not player or not garage then return {} end

    local filter = {}
    filter.citizenid = not garage.shared and player.PlayerData.citizenid or nil
    filter.states = garage.states or VehicleState.GARAGED
    filter.garage = not garage.skipGarageCheck and garageName or nil
    return filter
end

---@param source number
---@param garageName string
---@return GarageConfig?
function TryGetGarage(source, garageName)
    local garage = Garages[garageName]
    if garage then return garage end

    logger.log({
        source = source,
        event = 'error',
        message = string.format(
            'Attempted to spawn a vehicle from a non-existent garage: %s',
            garageName
        ),
        webhook = Config.logging.webhook.error,
        color = 'red'
    })
end

local function getCanAccessGarage(player, garage)
    if not player or not garage then return false end

    if garage.groups and not exports.qbx_core:HasPrimaryGroup(player.PlayerData.source, garage.groups) then
        return false
    end
    if garage.canAccess ~= nil and not garage.canAccess(player.PlayerData.source) then
        return false
    end
    return true
end

---@param playerVehicle PlayerVehicle
---@return VehicleType
local function getVehicleType(playerVehicle)
    local vehicle = playerVehicle and VEHICLES[playerVehicle.modelName]
    if not vehicle then return end

    if vehicle.category == 'helicopters' or vehicle.category == 'planes' then
        return VehicleType.AIR
    elseif vehicle.category == 'boats' then
        return VehicleType.SEA
    else
        return VehicleType.CAR
    end
end

---@param source number
---@param garageName string
---@return PlayerVehicle[]?
lib.callback.register('qbx_garages:server:getGarageVehicles', function(source, garageName)
    local player = exports.qbx_core:GetPlayer(source)
    local garage = TryGetGarage(source, garageName)
    if not garage then return end
    if not getCanAccessGarage(player, garage) then return end
    local filter = GetPlayerVehicleFilter(source, garageName)
    local playerVehicles = exports.qbx_vehicles:GetPlayerVehicles(filter)
    local toSend = {}
    if not playerVehicles[1] then return end

    local vehicleType = garage.vehicleType
    for _, vehicle in pairs(playerVehicles) do
        if not FindPlateOnServer(vehicle.props.plate) then
            if vehicleType == getVehicleType(vehicle) then
                OverrideFreeDepotPriceForOutVehicle(vehicle)
                toSend[#toSend + 1] = vehicle
            end
        end
    end
    return toSend
end)

---@param source number
---@param vehicleId string
---@param garageName string
---@return boolean
local function isParkable(source, vehicleId, garageName)
    local garage = Garages[garageName]
    --- DEPOTS are only for retrieving, not storing
    if not garage or garage.type == GarageType.DEPOT then return false end
    if not vehicleId then return false end

    local player = exports.qbx_core:GetPlayer(source)
    if not getCanAccessGarage(player, garage) then
        return false
    end
    ---@type PlayerVehicle
    local playerVehicle = exports.qbx_vehicles:GetPlayerVehicle(vehicleId)
    if not playerVehicle then return false end

    if getVehicleType(playerVehicle) ~= garage.vehicleType then
        return false
    end
    if not garage.shared then
        if playerVehicle.citizenid ~= player.PlayerData.citizenid then
            return false
        end
    end
    return true
end

---@param source number
---@param netId any
---@return number?
local function getDrivenVehicle(source, netId)
    if type(netId) ~= 'number' or netId % 1 ~= 0 then return end

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    local playerPed = GetPlayerPed(source)
    if vehicle == 0 or playerPed <= 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then return end
    if GetPedInVehicleSeat(vehicle, -1) ~= playerPed then return end
    return vehicle
end

---@param vehicle number
---@param garage GarageConfig
---@return boolean
local function isNearGarageDropPoint(vehicle, garage)
    local vehicleCoords = GetEntityCoords(vehicle)
    for i = 1, #garage.accessPoints do
        local accessPoint = garage.accessPoints[i]
        local dropPoint = accessPoint.dropPoint or accessPoint.spawn or accessPoint.coords
        local hasDropPoint = accessPoint.dropPoint or accessPoint.spawn
        local radius = hasDropPoint and accessPoint.dropUseRadius or accessPoint.useRadius
        if #(vehicleCoords - dropPoint.xyz) <= (radius or 1.5) + 1.0 then
            return true
        end
    end
    return false
end

---@param plate string
---@return string
local function normalizePlate(plate)
    return plate:match('^%s*(.-)%s*$'):upper()
end

---@param props any
---@param vehicle number
---@return boolean
local function areValidProperties(props, vehicle)
    if type(props) ~= 'table' or type(props.plate) ~= 'string' or type(props.model) ~= 'number' then return false end
    if normalizePlate(props.plate) ~= normalizePlate(GetVehicleNumberPlateText(vehicle)) then return false end
    if props.model ~= GetEntityModel(vehicle) then return false end

    local success, encoded = pcall(json.encode, props)
    return success and type(encoded) == 'string' and #encoded <= 65536
end

lib.callback.register('qbx_garages:server:isParkable', function(source, garage, netId)
    parkingAuthorizations[source] = nil
    local vehicle = getDrivenVehicle(source, netId)
    local garageConfig = type(garage) == 'string' and Garages[garage]
    if not vehicle or not garageConfig or not isNearGarageDropPoint(vehicle, garageConfig) then return false end

    local vehicleId = Entity(vehicle).state.vehicleid or exports.qbx_vehicles:GetVehicleIdByPlate(GetVehicleNumberPlateText(vehicle))
    if not isParkable(source, vehicleId, garage) then return false end
    parkingAuthorizations[source] = {vehicle = vehicle, garage = garage, expires = os.time() + 15}
    return true
end)

---@param source number
---@param netId number
---@param props table ox_lib vehicle props https://github.com/communityox/ox_lib/blob/master/resource/vehicleProperties/client.lua#L3
---@param garage string
lib.callback.register('qbx_garages:server:parkVehicle', function(source, netId, props, garage)
    local authorization = parkingAuthorizations[source]
    parkingAuthorizations[source] = nil
    if not authorization or authorization.expires < os.time() or authorization.garage ~= garage then return false end
    if type(netId) ~= 'number' or netId % 1 ~= 0 then return false end
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if vehicle ~= authorization.vehicle or not DoesEntityExist(vehicle) or parkingVehicles[vehicle] then return false end
    local ped = GetPlayerPed(source)
    if ped <= 0 or #(GetEntityCoords(ped) - GetEntityCoords(vehicle)) > 10.0 then return false end
    if GetEntityRoutingBucket(vehicle) ~= GetPlayerRoutingBucket(source) then return false end

    local garageConfig = type(garage) == 'string' and Garages[garage]
    if not garageConfig or not isNearGarageDropPoint(vehicle, garageConfig) or not areValidProperties(props, vehicle) then return false end

    parkingVehicles[vehicle] = true
    local success, parked = pcall(function()
        local vehicleId = Entity(vehicle).state.vehicleid or exports.qbx_vehicles:GetVehicleIdByPlate(GetVehicleNumberPlateText(vehicle))
        if not isParkable(source, vehicleId, garage) then return false end

        local saved = exports.qbx_vehicles:SaveVehicle(vehicle, {
            garage = garage,
            state = VehicleState.GARAGED,
            props = props
        })
        if not saved then return false end

        exports.qbx_core:DeleteVehicle(vehicle)
        return true
    end)
    parkingVehicles[vehicle] = nil
    if not success then lib.print.error(parked) end
    return success and parked == true
end)

AddEventHandler('playerDropped', function()
    parkingAuthorizations[source] = nil
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= cache.resource then return end
    Wait(100)
    if Config.autoRespawn then
        Storage.moveOutVehiclesIntoGarages()
    end
end)
