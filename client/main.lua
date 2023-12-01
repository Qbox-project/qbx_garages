local config = require 'config.client'
local sharedConfig = require 'config.shared'
local VEHICLES = exports.qbx_core:GetVehiclesByName()
local lasthouse = nil

local function doCarDamage(currentVehicle, veh)
    local engine = veh.engine + 0.0
    local body = veh.body + 0.0
    local data = json.decode(veh.mods)

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

local function checkPlayers(vehicle, garage)
    for i = -1, 5, 1 do
        local seat = GetPedInVehicleSeat(vehicle, i)
        if seat then
            TaskLeaveVehicle(seat, vehicle, 0)
            if garage then
                SetEntityCoords(seat, garage.coords.x, garage.coords.y, garage.coords.z, false, false, false, true)
            end
        end
    end
    SetVehicleDoorsLocked(vehicle, 2)
    Wait(1500)
    DeleteVehicle(vehicle)
end

local function progressColor(percent)
    if percent >= 75 then
        return 'green.5'
    elseif percent > 25 then
        return 'yellow.5'
    end
    return 'red.5'
end

local function getStateLabel(state)
    local stateLabels = {
        [0] = Lang:t('status.out'),
        [1] = Lang:t('status.garaged'),
        [2] = Lang:t('status.impound'),
    }
    
    return stateLabels[state]
end

local function displayVehicleInfo(vehicle, type, garage, indexgarage)
    local engine, body, fuel = math.round(vehicle.engine / 10), math.round(vehicle.body / 10), vehicle.fuel
    local engineColor, bodyColor, fuelColor = progressColor(engine), progressColor(body), progressColor(fuel)
    local vehLabel, stateLabel = VEHICLES[vehicle.vehicle].brand..' '..VEHICLES[vehicle.vehicle].name, getStateLabel(vehicle.state)

    local options = {
        {
            title = 'Information',
            icon = 'circle-info',
            description = string.format('Name: %s\nPlate: %s\nStatus: %s\nImpound Fee: $%s', vehLabel, vehicle.plate, stateLabel, CommaValue(vehicle.depotprice)),
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
            progress = fuel,
            colorScheme = fuelColor,
        }
    }
    
    if vehicle.state == 0 then
        if type == 'depot' then
            options[#options + 1] = {
                title = 'Take out of Impound',
                icon = 'fa-truck-ramp-box',
                description = '$'..CommaValue(vehicle.depotprice),
                event = 'qb-garages:client:TakeOutDepot',
                args = {
                    vehicle = vehicle,
                    type = type,
                    garage = garage,
                    index = indexgarage,
                },
            }
        else
            options[#options + 1] = {
                title = 'Your vehicle is already out',
                icon = 'car-on',
                readOnly = true,
            }
        end
    elseif vehicle.state == 1 then
        options[#options + 1] = {
            title = 'Take Out',
            icon = 'car-rear',
            event = 'qb-garages:client:takeOutGarage',
            args = {
                vehicle = vehicle,
                type = type,
                garage = garage,
                index = indexgarage,
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
        title = vehLabel,
        menu = 'garageMenu',
        options = options,
    })
    lib.showContext('vehicleList')
end

local function openGarageMenu(type, garage, indexgarage)
    local result = lib.callback.await('qb-garage:server:GetGarageVehicles', false, indexgarage, type, garage.vehicle)
    if not result then exports.qbx_core:Notify(Lang:t('error.no_vehicles'), 'error') return end

    local options = {}

    for _, v in pairs(result) do
        local vehLabel, stateLabel = VEHICLES[v.vehicle].brand..' '..VEHICLES[v.vehicle].name, getStateLabel(v.state)

        options[#options + 1] = {
            title = vehLabel,
            description = stateLabel..' | '..v.plate,
            onSelect = function()
                displayVehicleInfo(v, type, garage, indexgarage)
            end,
        }
    end

    lib.registerContext({
        id = 'garageMenu',
        title = garage.label,
        options = options,
    })
    lib.showContext('garageMenu')
end

RegisterNetEvent('qb-garages:client:takeOutGarage', function(data)
    if cache.vehicle then return exports.qbx_core:Notify('You\'re already in a vehicle...') end
    local type = data.type
    local vehicle = data.vehicle
    local garage = data.garage
    local index = data.index
    local spawn = lib.callback.await('qb-garage:server:IsSpawnOk', false, vehicle.plate, type)
    if not spawn then
        exports.qbx_core:Notify(Lang:t('error.not_impound'), 'error', 5000)
        return
    end

    local netId, properties = lib.callback.await('qb-garage:server:spawnvehicle', false, vehicle, type == 'house' and garage.coords or garage.spawn, true)
    local timeout = 100
    while not NetworkDoesEntityExistWithNetworkId(netId) and timeout > 0 do
        Wait(10)
        timeout -= 1
    end
    local veh = NetToVeh(netId)
    if veh == 0 then
        exports.qbx_core:Notify('Something went wrong spawning the vehicle', 'error')
        return
    end
    SetVehicleFuelLevel(veh, vehicle.fuel)
    doCarDamage(veh, vehicle)
    TriggerServerEvent('qb-garage:server:updateVehicleState', 0, vehicle.vehicle, vehicle.plate, index)
    TriggerEvent("vehiclekeys:client:SetOwner", vehicle.plate)
    SetVehicleEngineOn(veh, true, true, false)
    Wait(500)
    lib.setVehicleProperties(veh, properties)
end)

local function parkVehicle(veh, indexgarage, type, garage)
    local plate = GetPlate(veh)
    if GetVehicleNumberOfPassengers(veh) ~= 1 then
        local owned = lib.callback.await('qb-garage:server:checkOwnership', false, plate, type, indexgarage, QBX.PlayerData.gang.name)
        if not owned then
            exports.qbx_core:Notify(Lang:t('error.not_owned'), 'error', 5000)
            return
        end

        local bodyDamage = math.ceil(GetVehicleBodyHealth(veh))
        local engineDamage = math.ceil(GetVehicleEngineHealth(veh))
        local totalFuel = GetVehicleFuelLevel(veh)
        TriggerServerEvent('qb-vehicletuning:server:SaveVehicleProps', lib.getVehicleProperties(veh))
        TriggerServerEvent('qb-garage:server:updateVehicle', 1, totalFuel, engineDamage, bodyDamage, plate, indexgarage, type, QBX.PlayerData.gang.name)
        checkPlayers(veh, garage)

        if plate then
            TriggerServerEvent('qb-garages:server:UpdateOutsideVehicle', plate, nil)
        end
        exports.qbx_core:Notify(Lang:t('success.vehicle_parked'), 'primary', 4500)
    else
        exports.qbx_core:Notify(Lang:t('error.vehicle_occupied'), 'error', 3500)
    end
end

local function checkVehicleClass(category, vehicle)
    local classes = {
        all = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22},
        car = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 17, 18, 19, 20, 22},
        air = {15, 16},
        sea = {14},
    }

    local classSet = {}
    for _, class in ipairs(classes[category]) do
        classSet[class] = true
    end

    return classSet[GetVehicleClass(vehicle)] == true
end

local function createZones(garage, index)
    CreateThread(function()
        if not config.useTarget then
            lib.zones.box({
                coords = garage.coords.xyz,
                size = garage.size,
                rotation = 0,
                onEnter = function()
                    lib.showTextUI((garage.type == 'depot' and 'E - Open Impound') or (cache.vehicle and 'E - Store Vehicle') or 'E - Open Garage')
                end,
                onExit = function()
                    lib.hideTextUI()
                end,
                inside = function()
                    if IsControlJustReleased(0, 38) then
                        if cache.vehicle and garage.type ~= 'depot' then
                            if not checkVehicleClass(garage.vehicle, cache.vehicle) then
                                return exports.qbx_core:Notify('You can\'t park this vehicle here...', 'error')
                            end
                            parkVehicle(cache.vehicle, index, garage.type)
                        else
                            openGarageMenu(garage.type, garage, index)
                        end
                    end
                end,
                debug = config.debugPoly,
            })
        else
            exports.ox_target:addBoxZone({
                coords = garage.coords.xyz,
                size = garage.size,
                rotation = 0,
                debug = config.debugPoly,
                options = {
                    {
                        name = 'openGarage',
                        label = garage.type == 'depot' and 'Open Impound' or 'Open Garage',
                        icon = 'fas fa-car',
                        onSelect = function()
                            openGarageMenu(garage.type, garage, index)
                        end,
                        distance = 10,
                    },
                    {
                        name = 'storeVehicle',
                        label = 'Store Vehicle',
                        icon = 'fas fa-square-parking',
                        canInteract = function()
                            return garage.type ~= 'depot' and cache.vehicle
                        end,
                        onSelect = function()
                            if not checkVehicleClass(garage.vehicle, cache.vehicle) then
                                return exports.qbx_core:Notify('You can\'t park this vehicle here...', 'error')
                            end
                            parkVehicle(cache.vehicle, index, garage.type)
                        end,
                        distance = 10,
                    },
                },
            })
        end
    end)
end

local function createBlips(garage)
    local blip = AddBlipForCoord(garage.coords.x, garage.coords.y, garage.coords.z)
    SetBlipSprite(blip, garage.blipSprite or 357)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.60)
    SetBlipAsShortRange(blip, true)
    SetBlipColour(blip, garage.blipColor or 3)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(garage.blipName or 'Public Parking')
    EndTextCommandSetBlipName(blip)
end

local function createGarages()
    for index, garage in pairs(sharedConfig.garages) do
        if garage.showBlip or garage.showBlip == nil then
            createBlips(garage)
        end

        if garage.type == 'job' and (QBX.PlayerData.job.name == garage.job or QBX.PlayerData.job.type == garage.job) or
            garage.type == 'gang' and QBX.PlayerData.gang.name == garage.job or
            garage.type ~= 'job' and garage.type ~= 'gang' then
            createZones(garage, index)
        end
    end
end

RegisterNetEvent('qb-garages:client:setHouseGarage', function(house, hasKey)
    if sharedConfig.houseGarages[house] then
        if lasthouse ~= house then
            --[[if lasthouse then
                destroyZone('hmarker', lasthouse)
            end]]--
            if hasKey and sharedConfig.houseGarages[house].coords.x then
                createZones(sharedConfig.houseGarages[house], house)
                lasthouse = house
            end
        end
    end
end)

RegisterNetEvent('qb-garages:client:houseGarageConfig', function(garageConfig)
    sharedConfig.houseGarages = garageConfig
end)

RegisterNetEvent('qb-garages:client:addHouseGarage', function(house, garageInfo)
    sharedConfig.houseGarages[house] = garageInfo
end)

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    createGarages()
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    createGarages()
end)

RegisterNetEvent('qb-garages:client:TakeOutDepot', function(data)
    local vehicle = data.vehicle
    if vehicle.depotprice ~= 0 then
        TriggerServerEvent('qb-garage:server:PayDepotPrice', data)
    else
        TriggerEvent('qb-garages:client:takeOutGarage', data)
    end
end)
