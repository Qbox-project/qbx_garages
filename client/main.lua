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

---@enum StateLabels
local StateLabels = {
    OUT = 0,
    GARAGED = 1,
    IMPOUND = 2,
}

---@param state number
---@return string
local function getStateLabel(state)
    if StateLabels.OUT == state then
        return Lang:t('status.out')
    elseif StateLabels.GARAGED == state then
        return Lang:t('status.garaged')
    elseif StateLabels.IMPOUND == state then
        return Lang:t('status.impound')
    end

    return 'Unknown'
end

local VehicleCategory = {
    all = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22},
    car = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 17, 18, 19, 20, 22},
    air = {15, 16},
    sea = {14},
}

---@param category 'all'|'car'|'air'|'sea'
---@param vehicle number
---@return boolean
local function checkVehicleClass(category, vehicle)
    local classSet = {}

    for _, class in pairs(VehicleCategory[category]) do
        classSet[class] = true
    end

    return classSet[GetVehicleClass(vehicle)] == true
end

---@param currentVehicle number
---@param vehicle table
local function doCarDamage(currentVehicle, vehicle)
    local engine = vehicle.engine + 0.0
    local body = vehicle.body + 0.0
    local data = json.decode(vehicle.mods)

    if config.visuallyDamageCars then
        for k, v in pairs(data.doors) do
            if v then
                SetVehicleDoorBroken(currentVehicle, k, true)
            end
        end
        for k, v in pairs(data.tyres) do
            if v then
                local random = math.random(1, 1000)
                SetVehicleTyreBurst(currentVehicle, k, true, random)
            end
        end
        for k, v in pairs(data.windows) do
            if not v then
                SmashVehicleWindow(currentVehicle, k)
            end
        end
    end

    SetVehicleEngineHealth(currentVehicle, engine)
    SetVehicleBodyHealth(currentVehicle, body)
end

---@param vehicle number
local function checkPlayers(vehicle)
    for i = -1, 5, 1 do
        local seat = GetPedInVehicleSeat(vehicle, i)
        if seat then
            TaskLeaveVehicle(seat, vehicle, 0)
        end
    end

    SetVehicleDoorsLocked(vehicle, 2)
    Wait(1500)
    DeleteVehicle(vehicle)
end

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

    if vehicle.state == 0 then
        if garageInfo.type == 'depot' then
            options[#options + 1] = {
                title = 'Take out',
                icon = 'fa-truck-ramp-box',
                description = ('$%s'):format(lib.math.groupdigits(vehicle.depotprice)),
                event = 'qb-garages:client:TakeOutDepot',
                arrow = true,
                args = {
                    vehicle = vehicle,
                    garageInfo = garageInfo,
                    garageName = garageName,
                },
            }
        else
            options[#options + 1] = {
                title = 'Your vehicle is already out...',
                icon = 'car',
                readOnly = true,
            }
        end
    elseif vehicle.state == 1 then
        options[#options + 1] = {
            title = 'Take out',
            icon = 'car-rear',
            event = 'qb-garages:client:takeOutGarage',
            arrow = true,
            args = {
                vehicle = vehicle,
                garageInfo = garageInfo,
                garageName = garageName,
            },
        }
    elseif vehicle.state == 2 then
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

local function openGarageMenu(garageName, garageInfo)
    local result = lib.callback.await('qb-garage:server:GetGarageVehicles', false, garageName, garageInfo.type, garageInfo.vehicle)

    if not result then
        exports.qbx_core:Notify(Lang:t('error.no_vehicles'), 'error')
        return
    end

    local options = {}

    for _, v in pairs(result) do
        local vehicleLabel = ('%s %s'):format(VEHICLES[v.vehicle].brand, VEHICLES[v.vehicle].name)
        local stateLabel = getStateLabel(v.state)

        options[#options + 1] = {
            title = vehicleLabel,
            description = ('%s | %s'):format(stateLabel, v.plate),
            arrow = true,
            onSelect = function()
                displayVehicleInfo(v, garageName, garageInfo)
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

RegisterNetEvent('qb-garages:client:takeOutGarage', function(data)
    if cache.vehicle then
        exports.qbx_core:Notify('You\'re already in a vehicle...')
        return
    end

    local spawn = lib.callback.await('qb-garage:server:IsSpawnOk', false, data.vehicle.plate, data.garageInfo.type)

    if not spawn then
        exports.qbx_core:Notify(Lang:t('error.not_impound'), 'error', 5000)
        return
    end

    local netId = lib.callback.await('qb-garage:server:spawnvehicle', false, data.vehicle, data.garageInfo.spawn)

    local veh = lib.waitFor(function()
        if NetworkDoesEntityExistWithNetworkId(netId) then
            return NetToVeh(netId)
        end
    end)

    if veh == 0 then
        exports.qbx_core:Notify('Something went wrong spawning the vehicle', 'error')
        return
    end

    SetVehicleFuelLevel(veh, data.vehicle.fuel)
    doCarDamage(veh, data.vehicle)
    TriggerServerEvent('qb-garage:server:updateVehicleState', 0, data.vehicle.plate, data.garageName)

    if not sharedConfig.takeOut.engineOff then
        SetVehicleEngineOn(veh, true, true, false)
    end
end)

local function parkVehicle(vehicle, garageName, garageInfo)
    local plate = qbx.getVehiclePlate(vehicle)

    if GetVehicleNumberOfPassengers(vehicle) ~= 1 then
        local owned = lib.callback.await('qb-garage:server:checkOwnership', false, plate, garageInfo.type, garageName, QBX.PlayerData.gang.name)

        if not owned then
            exports.qbx_core:Notify(Lang:t('error.not_owned'), 'error', 5000)
            return
        end

        local bodyDamage = math.ceil(GetVehicleBodyHealth(vehicle))
        local engineDamage = math.ceil(GetVehicleEngineHealth(vehicle))
        local totalFuel = GetVehicleFuelLevel(vehicle)

        TriggerServerEvent('qb-vehicletuning:server:SaveVehicleProps', lib.getVehicleProperties(vehicle))
        TriggerServerEvent('qb-garage:server:updateVehicle', 1, totalFuel, engineDamage, bodyDamage, plate, garageName, garageInfo.type, QBX.PlayerData.gang.name)
        checkPlayers(vehicle)

        if plate then
            TriggerServerEvent('qb-garages:server:UpdateOutsideVehicle', plate, nil)
        end

        exports.qbx_core:Notify(Lang:t('success.vehicle_parked'), 'primary', 4500)
    else
        exports.qbx_core:Notify(Lang:t('error.vehicle_occupied'), 'error', 3500)
    end
end

local function createZones(garageName, garageInfo)
    CreateThread(function()
        if not config.useTarget then
            lib.zones.box({
                coords = garageInfo.coords.xyz,
                size = garageInfo.size,
                rotation = garageInfo.coords.w,
                onEnter = function()
                    lib.showTextUI((garageInfo.type == 'depot' and 'E - Open Impound') or (cache.vehicle and 'E - Store Vehicle') or 'E - Open Garage')
                end,
                onExit = function()
                    lib.hideTextUI()
                end,
                inside = function()
                    if IsControlJustReleased(0, 38) then
                        if cache.vehicle and garageInfo.type ~= 'depot' then
                            if not checkVehicleClass(garageInfo.vehicle, cache.vehicle) then
                                return exports.qbx_core:Notify('You can\'t park this vehicle here...', 'error')
                            end
                            parkVehicle(cache.vehicle, garageName, garageInfo)
                        else
                            openGarageMenu(garageName, garageInfo)
                        end
                    end
                end,
                debug = config.debugPoly,
            })
        else
            exports.ox_target:addBoxZone({
                coords = garageInfo.coords.xyz,
                size = garageInfo.size,
                rotation = garageInfo.coords.w,
                debug = config.debugPoly,
                options = {
                    {
                        name = 'openGarage',
                        label = garageInfo.type == 'depot' and 'Open Impound' or 'Open Garage',
                        icon = 'fas fa-car',
                        onSelect = function()
                            openGarageMenu(garageName, garageInfo)
                        end,
                        distance = 10,
                    },
                    {
                        name = 'storeVehicle',
                        label = 'Store Vehicle',
                        icon = 'fas fa-square-parking',
                        canInteract = function()
                            return garageInfo.type ~= 'depot' and cache.vehicle
                        end,
                        onSelect = function()
                            if not checkVehicleClass(garageInfo.vehicle, cache.vehicle) then
                                return exports.qbx_core:Notify('You can\'t park this vehicle here...', 'error')
                            end
                            parkVehicle(cache.vehicle, garageName, garageInfo)
                        end,
                        distance = 10,
                    },
                },
            })
        end
    end)
end

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
    for name, info in pairs(sharedConfig.garages) do
        if info.showBlip or info.showBlip == nil then
            createBlips(info)
        end

        if info.type == 'job' and (QBX.PlayerData.job.name == info.job or QBX.PlayerData.job.type == info.job) or
            info.type == 'gang' and QBX.PlayerData.gang.name == info.job or
            info.type ~= 'job' and info.type ~= 'gang' then
            createZones(name, info)
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

RegisterNetEvent('qb-garages:client:TakeOutDepot', function(data)
    if data.vehicle.depotprice ~= 0 then
        TriggerServerEvent('qb-garage:server:PayDepotPrice', data)
    else
        TriggerEvent('qb-garages:client:takeOutGarage', data)
    end
end)
