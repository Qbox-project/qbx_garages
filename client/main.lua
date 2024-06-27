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

---@param vehicleId number
---@param garageName string
---@param accessPoint integer
local function takeOutOfGarage(vehicleId, garageName, accessPoint)
    if cache.vehicle then
        exports.qbx_core:Notify('You\'re already in a vehicle...')
        return
    end

    local netId = lib.callback.await('qbx_garages:server:spawnVehicle', false, vehicleId, garageName, accessPoint)
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

---@param data {vehicle: PlayerVehicle, garageName: string, accessPoint: integer}
local function takeOutDepot(data)
    if data.vehicle.depotPrice ~= 0 then
        local success = lib.callback.await('qbx_garages:server:payDepotPrice', false, data.vehicle.id)
        if not success then
            exports.qbx_core:Notify(Lang:t('error.not_enough'), 'error')
            return
        end
    end

    takeOutOfGarage(data.vehicle.id, data.garageName, data.accessPoint)
end

---@param vehicle PlayerVehicle
---@param garageName string
---@param garageInfo GarageConfig
---@param accessPoint integer
local function displayVehicleInfo(vehicle, garageName, garageInfo, accessPoint)
    local engine = qbx.math.round(vehicle.props.engineHealth / 10)
    local body = qbx.math.round(vehicle.props.bodyHealth / 10)
    local engineColor = getProgressColor(engine)
    local bodyColor = getProgressColor(body)
    local fuelColor = getProgressColor(vehicle.props.fuelLevel)
    local stateLabel = getStateLabel(vehicle.state)
    local vehicleLabel = ('%s %s'):format(VEHICLES[vehicle.modelName].brand, VEHICLES[vehicle.modelName].name)

    local options = {
        {
            title = 'Information',
            icon = 'circle-info',
            description = ('Name: %s\nPlate: %s\nStatus: %s\nImpound Fee: $%s'):format(vehicleLabel, vehicle.props.plate, stateLabel, lib.math.groupdigits(vehicle.depotPrice)),
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
            progress = vehicle.props.fuelLevel,
            colorScheme = fuelColor,
        }
    }

    if vehicle.state == VehicleState.OUT then
        if garageInfo.type == GarageType.DEPOT then
            options[#options + 1] = {
                title = 'Take out',
                icon = 'fa-truck-ramp-box',
                description = ('$%s'):format(lib.math.groupdigits(vehicle.depotPrice)),
                arrow = true,
                onSelect = function()
                    takeOutDepot({
                        vehicle = vehicle,
                        garageName = garageName,
                        accessPoint = accessPoint,
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
                takeOutOfGarage(vehicle.id, garageName, accessPoint)
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
---@param accessPoint integer
local function openGarageMenu(garageName, garageInfo, accessPoint)
    ---@type PlayerVehicle[]?
    local vehicleEntities = lib.callback.await('qbx_garages:server:getGarageVehicles', false, garageName)

    if not vehicleEntities then
        exports.qbx_core:Notify(Lang:t('error.no_vehicles'), 'error')
        return
    end

    local options = {}
    for i = 1, #vehicleEntities do
        local vehicleEntity = vehicleEntities[i]
        local vehicleLabel = ('%s %s'):format(VEHICLES[vehicleEntity.modelName].brand, VEHICLES[vehicleEntity.modelName].name)
        local stateLabel = getStateLabel(vehicleEntity.state)

        options[#options + 1] = {
            title = vehicleLabel,
            description = ('%s | %s'):format(stateLabel, vehicleEntity.props.plate),
            arrow = true,
            onSelect = function()
                displayVehicleInfo(vehicleEntity, garageName, garageInfo, accessPoint)
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
---@param accessPoint AccessPoint
---@param accessPointIndex integer
local function createZones(garageName, garage, accessPoint, accessPointIndex)
    CreateThread(function()
        lib.zones.box({
            coords = accessPoint.coords.xyz,
            size = accessPoint.size,
            rotation = accessPoint.coords.w,
            onEnter = function()
                lib.showTextUI((garage.type == GarageType.DEPOT and 'E - Open Impound') or (cache.vehicle and 'E - Store Vehicle') or 'E - Open Garage')
            end,
            onExit = function()
                lib.hideTextUI()
            end,
            inside = function()
                if IsControlJustReleased(0, 38) then
                    if garage.groups and not exports.qbx_core:HasPrimaryGroup(garage.groups, QBX.PlayerData) then
                        exports.qbx_core:Notify("You don't have access to this garage", 'error')
                        return
                    end
                    if garage.canAccess ~= nil and not garage.canAccess() then
                        exports.qbx_core:Notify("You don't have access to this garage", 'error')
                        return
                    end
                    if cache.vehicle and garage.type ~= GarageType.DEPOT then
                        if not isOfType(garage.vehicleType, cache.vehicle) then
                            return exports.qbx_core:Notify('You can\'t park this vehicle here...', 'error')
                        end
                        parkVehicle(cache.vehicle, garageName)
                    else
                        openGarageMenu(garageName, garage, accessPointIndex)
                    end
                end
            end,
            debug = config.debugPoly,
        })
    end)
end

---@param garageInfo GarageConfig
---@param accessPoint AccessPoint
local function createBlips(garageInfo, accessPoint)
    local blip = AddBlipForCoord(accessPoint.coords.x, accessPoint.coords.y, accessPoint.coords.z)
    SetBlipSprite(blip, accessPoint.blip.sprite or 357)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.60)
    SetBlipAsShortRange(blip, true)
    SetBlipColour(blip, accessPoint.blip.color or 3)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(accessPoint.blip.name or garageInfo.label)
    EndTextCommandSetBlipName(blip)
end

local function createGarage(name, garage)
    local accessPoints = garage.accessPoints
    for i = 1, #accessPoints do
        local accessPoint = accessPoints[i]

        if accessPoint.blip then
            createBlips(garage, accessPoint)
        end

        createZones(name, garage, accessPoint, i)
    end
end

local function createGarages()
    local garages = lib.callback.await('qbx_garages:server:getGarages')
    for name, garage in pairs(garages) do
        createGarage(name, garage)
    end
end

RegisterNetEvent('qbx_garages:client:garageRegistered', function(name, garage)
    createGarage(name, garage)
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    createGarages()
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= cache.resource then return end
    createGarages()
end)