local config = require 'config.client'
local sharedConfig = require 'config.shared'
local VEHICLES = exports.qbx_core:GetVehiclesByName()

---@enum ProgressColor
local ProgressColor = {
    GREEN = 'green.5',
    YELLOW = 'yellow.5',
    RED = 'red.5'
}

---@param percent number
---@return string
local function getProgressColor(percent)
    if percent >= 75 then
        return ProgressColor.GREEN
    elseif percent > 25 then
        return ProgressColor.YELLOW
    else
        return ProgressColor.RED
    end
end

---@type table<VehicleState, string>
local stateLabels = {
    [VehicleState.OUT] = Lang:t('status.out'),
    [VehicleState.GARAGED] = Lang:t('status.garaged'),
    [VehicleState.IMPOUNDED] = Lang:t('status.impound')
}

---@param state VehicleState
---@return string
local function getStateLabel(state)
    return stateLabels[state] or 'Unknown'
end

local VehicleCategory = {
    all = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22},
    car = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 17, 18, 19, 20, 22},
    air = {15, 16},
    sea = {14},
}

---@param category VehicleType
---@param vehicle number
---@return boolean
local function isOfType(category, vehicle)
    local classSet = {}

    for _, class in pairs(VehicleCategory[category]) do
        classSet[class] = true
    end

    return classSet[GetVehicleClass(vehicle)] == true
end

---@param vehicle number
local function kickOutPeds(vehicle)
    for i = -1, 5, 1 do
        local seat = GetPedInVehicleSeat(vehicle, i)
        if seat then
            TaskLeaveVehicle(seat, vehicle, 0)
        end
    end
end

---@param vehicleId string
---@param garageName string
local function takeOutOfGarage(vehicleId, garageName)
    if cache.vehicle then
        exports.qbx_core:Notify('You\'re already in a vehicle...')
        return
    end

    local netId = lib.callback.await('qbx_garages:server:spawnVehicle', false, vehicleId, garageName)
    if not netId then return end

    local veh = lib.waitFor(function()
        if NetworkDoesEntityExistWithNetworkId(netId) then
            return NetToVeh(netId)
        end
    end)

    if veh == 0 then
        exports.qbx_core:Notify('Something went wrong spawning the vehicle', 'error')
        return
    end

    if not sharedConfig.takeOut.engineOff then
        SetVehicleEngineOn(veh, true, true, false)
    end
end

---@param data {vehicle: VehicleEntity, garageName: string}
local function takeOutDepot(data)
    if data.vehicle.depotprice ~= 0 then
        local success = lib.callback.await('qbx_garages:server:payDepotPrice', data.vehicle.id)
        if not success then
            exports.qbx_core:Notify(Lang:t('error.not_enough'), 'error')
            return
        end
    end

    takeOutOfGarage(data.vehicle.id, data.garageName)
end

---@param vehicle VehicleEntity
---@param garageName string
---@param garageInfo GarageConfig
local function displayVehicleInfo(vehicle, garageName, garageInfo)
    local engine = qbx.math.round(vehicle.engine / 10)
    local body = qbx.math.round(vehicle.body / 10)
    local engineColor = getProgressColor(engine)
    local bodyColor = getProgressColor(body)
    local fuelColor = getProgressColor(vehicle.fuel)
    local stateLabel = getStateLabel(vehicle.state)
    local vehicleLabel = ('%s %s'):format(VEHICLES[vehicle.vehicle].brand, VEHICLES[vehicle.vehicle].name)

    local options = {
        {
            title = 'Information',
            icon = 'circle-info',
            description = ('Name: %s\nPlate: %s\nStatus: %s\nImpound Fee: $%s'):format(vehicleLabel, vehicle.plate, stateLabel, lib.math.groupdigits(vehicle.depotprice)),
            readOnly = true,
        },
        {
            title = 'Body',
            icon = 'car-side',
            readOnly = true,
            progress = body,
            colorScheme = bodyColor,
        },
        {
            title = 'Engine',
            icon = 'oil-can',
            readOnly = true,
            progress = engine,
            colorScheme = engineColor,
        },
        {
            title = 'Fuel',
            icon = 'gas-pump',
            readOnly = true,
            progress = vehicle.fuel,
            colorScheme = fuelColor,
        }
    }

    if vehicle.state == VehicleState.OUT then
        if garageInfo.type == GarageType.DEPOT then
            options[#options + 1] = {
                title = 'Take out',
                icon = 'fa-truck-ramp-box',
                description = ('$%s'):format(lib.math.groupdigits(vehicle.depotprice)),
                arrow = true,
                onSelect = function()
                    takeOutDepot({
                        vehicle = vehicle,
                        garageName = garageName
                    })
                end,
            }
        else
            options[#options + 1] = {
                title = 'Your vehicle is already out...',
                icon = VehicleType.CAR,
                readOnly = true,
            }
        end
    elseif vehicle.state == VehicleState.GARAGED then
        options[#options + 1] = {
            title = 'Take out',
            icon = 'car-rear',
            arrow = true,
            onSelect = function()
                takeOutOfGarage(vehicle.id, garageName)
            end,
        }
    elseif vehicle.state == VehicleState.IMPOUNDED then
        options[#options + 1] = {
            title = 'Your vehicle has been impounded by the police',
            icon = 'building-shield',
            readOnly = true,
        }
    end

    lib.registerContext({
        id = 'vehicleList',
        title = garageInfo.label,
        menu = 'garageMenu',
        options = options,
    })

    lib.showContext('vehicleList')
end

---@param garageName string
---@param garageInfo GarageConfig
local function openGarageMenu(garageName, garageInfo)
    local vehicleEntities = lib.callback.await('qbx_garages:server:getGarageVehicles', false, garageName)

    if not vehicleEntities then
        exports.qbx_core:Notify(Lang:t('error.no_vehicles'), 'error')
        return
    end

    local options = {}
    for i = 1, #vehicleEntities do
        local vehicleEntity = vehicleEntities[i]
        local vehicleLabel = ('%s %s'):format(VEHICLES[vehicleEntity.vehicle].brand, VEHICLES[vehicleEntity.vehicle].name)
        local stateLabel = getStateLabel(vehicleEntity.state)

        options[#options + 1] = {
            title = vehicleLabel,
            description = ('%s | %s'):format(stateLabel, vehicleEntity.plate),
            arrow = true,
            onSelect = function()
                displayVehicleInfo(vehicleEntity, garageName, garageInfo)
            end,
        }
    end

    lib.registerContext({
        id = 'garageMenu',
        title = garageInfo.label,
        options = options,
    })

    lib.showContext('garageMenu')
end

---@param vehicle number
---@param garageName string
local function parkVehicle(vehicle, garageName)
    if GetVehicleNumberOfPassengers(vehicle) ~= 1 then
        local isParkable = lib.callback.await('qbx_garages:server:isParkable', false, garageName, NetworkGetNetworkIdFromEntity(vehicle))

        if not isParkable then
            exports.qbx_core:Notify(Lang:t('error.not_owned'), 'error', 5000)
            return
        end

        kickOutPeds(vehicle)
        SetVehicleDoorsLocked(vehicle, 2)
        Wait(1500)
        lib.callback.await('qbx_garages:server:parkVehicle', false, NetworkGetNetworkIdFromEntity(vehicle), lib.getVehicleProperties(vehicle), garageName)
        exports.qbx_core:Notify(Lang:t('success.vehicle_parked'), 'primary', 4500)
    else
        exports.qbx_core:Notify(Lang:t('error.vehicle_occupied'), 'error', 3500)
    end
end

---@param garageName string
---@param garage GarageConfig
local function createZones(garageName, garage)
    CreateThread(function()
        if not config.useTarget then
            lib.zones.box({
                coords = garage.coords.xyz,
                size = garage.size,
                rotation = garage.coords.w,
                onEnter = function()
                    lib.showTextUI((garage.type == GarageType.DEPOT and 'E - Open Impound') or (cache.vehicle and 'E - Store Vehicle') or 'E - Open Garage')
                end,
                onExit = function()
                    lib.hideTextUI()
                end,
                inside = function()
                    if IsControlJustReleased(0, 38) then
                        if cache.vehicle and garage.type ~= GarageType.DEPOT then
                            if not isOfType(garage.vehicleType, cache.vehicle) then
                                return exports.qbx_core:Notify('You can\'t park this vehicle here...', 'error')
                            end
                            parkVehicle(cache.vehicle, garageName)
                        else
                            openGarageMenu(garageName, garage)
                        end
                    end
                end,
                debug = config.debugPoly,
            })
        else
            exports.ox_target:addBoxZone({
                coords = garage.coords.xyz,
                size = garage.size,
                rotation = garage.coords.w,
                debug = config.debugPoly,
                options = {
                    {
                        name = 'openGarage',
                        label = garage.type == GarageType.DEPOT and 'Open Impound' or 'Open Garage',
                        icon = 'fas fa-car',
                        onSelect = function()
                            openGarageMenu(garageName, garage)
                        end,
                        distance = 10,
                    },
                    {
                        name = 'storeVehicle',
                        label = 'Store Vehicle',
                        icon = 'fas fa-square-parking',
                        canInteract = function()
                            return garage.type ~= GarageType.DEPOT and cache.vehicle
                        end,
                        onSelect = function()
                            if not isOfType(garage.vehicleType, cache.vehicle) then
                                return exports.qbx_core:Notify('You can\'t park this vehicle here...', 'error')
                            end
                            parkVehicle(cache.vehicle, garageName)
                        end,
                        distance = 10,
                    },
                },
            })
        end
    end)
end

---@param garageInfo GarageConfig
local function createBlips(garageInfo)
    local blip = AddBlipForCoord(garageInfo.coords.x, garageInfo.coords.y, garageInfo.coords.z)
    SetBlipSprite(blip, garageInfo.blipSprite or 357)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.60)
    SetBlipAsShortRange(blip, true)
    SetBlipColour(blip, garageInfo.blipColor or 3)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(garageInfo.blipName or garageInfo.label)
    EndTextCommandSetBlipName(blip)
end

local function createGarages()
    for name, garage in pairs(sharedConfig.garages) do
        -- default to showing blips if showBlip is not set
        if garage.showBlip or garage.showBlip == nil then
            createBlips(garage)
        end

        if garage.type == GarageType.JOB and (QBX.PlayerData.job.name == garage.group or QBX.PlayerData.job.type == garage.group) or
            garage.type == GarageType.GANG and QBX.PlayerData.gang.name == garage.group or
            garage.type ~= GarageType.JOB and garage.type ~= GarageType.GANG then
            createZones(name, garage)
        end
    end
end

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    createGarages()
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= cache.resource then return end
    createGarages()
end)