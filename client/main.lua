local config = require 'config.client'
local sharedConfig = require 'config.shared'
local VEHICLES = exports.qbx_core:GetVehiclesByName()
local Markers = false
local HouseMarkers = false
local InputIn = false
local InputOut = false
local currentGarage = nil
local currentGarageIndex = nil
local garageZones = {}
local lasthouse = nil
local blipsZonesLoaded = false

local function destroyZone(type, index)
    if garageZones[type .. '_' .. index] then
        garageZones[type .. '_' .. index].zone:remove()
    end
end

local function createZone(type, garage, index)
    local size
    local coords
    local heading

    if type == 'in' then
        size = vec3(4, 4, 4)
        coords = vector3(garage.putVehicle.x, garage.putVehicle.y, garage.putVehicle.z)
        heading = garage.spawnPoint.w
    elseif type == 'out' then
        size = vec3(2, 2, 4)
        coords = vector3(garage.takeVehicle.x, garage.takeVehicle.y, garage.takeVehicle.z)
        heading = garage.spawnPoint.w
    elseif type == 'marker' then
        size = vec3(60, 60, 4)
        coords = vector3(garage.takeVehicle.x, garage.takeVehicle.y, garage.takeVehicle.z)
        heading = garage.spawnPoint.w
    elseif type == 'hmarker' then
        size = vec3(20, 20, 4)
        coords = vector3(garage.takeVehicle.x, garage.takeVehicle.y, garage.takeVehicle.z)
        heading = 0
    elseif type == 'house' then
        size = vec3(2, 2, 4)
        coords = vector3(garage.takeVehicle.x, garage.takeVehicle.y, garage.takeVehicle.z)
        heading = 0
    end

    garageZones[type .. '_' .. index] = {}
    garageZones[type .. '_' .. index].zone = lib.zones.box({
        coords = coords,
        size = size,
        rotation = heading,
        debug = false,
        onEnter = function()
            local text
            if type == 'in' then
                if garage.type == 'house' then
                    text = Lang:t('info.park_e')
                else
                    text = Lang:t('info.park_e') .. '  \n' .. garage.label
                end
                lib.showTextUI(text, {position = 'left-center'})
                InputIn = true
            elseif type == 'out' then
                if garage.type == 'house' then
                    text = Lang:t('info.car_e')
                else
                    text = Lang:t('info.' .. garage.vehicle .. '_e') .. '  \n' .. garage.label
                end

                lib.showTextUI(text, {position = 'left-center'})
                InputOut = true
            elseif type == 'marker' then
                currentGarage = garage
                currentGarageIndex = index
                createZone('out', garage, index)
                if garage.type ~= 'depot' then
                    createZone('in', garage, index)
                    Markers = true
                else
                    HouseMarkers = true
                end
            elseif type == 'hmarker' then
                currentGarage = garage
                currentGarage.type = 'house'
                currentGarageIndex = index
                createZone('house', garage, index)
                HouseMarkers = true
            elseif type == 'house' then
                if cache.vehicle then
                    lib.showTextUI(Lang:t('info.park_e'), {position = 'left-center'})
                    InputIn = true
                else
                    lib.showTextUI(Lang:t('info.car_e'), {position = 'left-center'})
                    InputOut = true
                end
            end
        end,
        onExit = function()
            if type == 'marker' then
                if currentGarage == garage then
                    if garage.type ~= 'depot' then
                        Markers = false
                    else
                        HouseMarkers = false
                    end
                    destroyZone('in', index)
                    destroyZone('out', index)
                    currentGarage = nil
                    currentGarageIndex = nil
                end
            elseif type == 'hmarker' then
                HouseMarkers = false
                destroyZone('house', index)
            elseif type == 'house' then
                lib.hideTextUI()
                InputIn = false
                InputOut = false
            elseif type == 'in' then
                lib.hideTextUI()
                InputIn = false
            elseif type == 'out' then
                lib.hideTextUI()
                InputOut = false
            end
        end,
    })
end

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
                SetEntityCoords(seat, garage.takeVehicle.x, garage.takeVehicle.y, garage.takeVehicle.z, false, false, false, true)
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
    
    return stateLabels[state] or 'Unknown'
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

local function menuGarage(type, garage, indexgarage)
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
    local type = data.type
    local vehicle = data.vehicle
    local garage = data.garage
    local index = data.index
    local spawn = lib.callback.await('qb-garage:server:IsSpawnOk', false, vehicle.plate, type)
    if not spawn then
        exports.qbx_core:Notify(Lang:t('error.not_impound'), 'error', 5000)
        return
    end

    local netId, properties = lib.callback.await('qb-garage:server:spawnvehicle', false, vehicle, type == 'house' and garage.takeVehicle or garage.spawnPoint, true)
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
    TriggerServerEvent('qb-garage:server:updateVehicleState', 0, vehicle.plate, index)
    TriggerEvent("vehiclekeys:client:SetOwner", vehicle.plate)
    SetVehicleEngineOn(veh, true, true, false)
    Wait(500)
    lib.setVehicleProperties(veh, properties)

    if type ~= 'house' then return end
    lib.showTextUI(Lang:t('info.park_e'), {position = 'left-center'})
    InputOut = false
    InputIn = true
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
        if type == 'house' then
            lib.showTextUI(Lang:t('info.car_e'), {position = 'left-center'})
            InputOut = true
            InputIn = false
        end

        if plate then
            TriggerServerEvent('qb-garages:server:UpdateOutsideVehicle', plate, nil)
        end
        exports.qbx_core:Notify(Lang:t('success.vehicle_parked'), 'primary', 4500)
    else
        exports.qbx_core:Notify(Lang:t('error.vehicle_occupied'), 'error', 3500)
    end
end

local function createBlipsZones()
    if blipsZonesLoaded then return end

    for index, garage in pairs(sharedConfig.garages) do
        if garage.showBlip then
            local Garage = AddBlipForCoord(garage.takeVehicle.x, garage.takeVehicle.y, garage.takeVehicle.z)
            SetBlipSprite(Garage, garage.blipNumber)
            SetBlipDisplay(Garage, 4)
            SetBlipScale(Garage, 0.60)
            SetBlipAsShortRange(Garage, true)
            SetBlipColour(Garage, 3)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(garage.blipName)
            EndTextCommandSetBlipName(Garage)
        end
        if garage.type == 'job' then
            if QBX.PlayerData.job.name == garage.job then
                createZone('marker', garage, index)
            end
        elseif garage.type == 'gang' then
            if QBX.PlayerData.gang.name == garage.job then
                createZone('marker', garage, index)
            end
        else
            createZone('marker', garage, index)
        end
    end
    blipsZonesLoaded = true
end

RegisterNetEvent('qb-garages:client:setHouseGarage', function(house, hasKey)
    if sharedConfig.houseGarages[house] then
        if lasthouse ~= house then
            if lasthouse then
                destroyZone('hmarker', lasthouse)
            end
            if hasKey and sharedConfig.houseGarages[house].takeVehicle.x then
                createZone('hmarker', sharedConfig.houseGarages[house], house)
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
    createBlipsZones()
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    createBlipsZones()
end)

RegisterNetEvent('qb-garages:client:TakeOutDepot', function(data)
    local vehicle = data.vehicle
    if vehicle.depotprice ~= 0 then
        TriggerServerEvent('qb-garage:server:PayDepotPrice', data)
    else
        TriggerEvent('qb-garages:client:takeOutGarage', data)
    end
end)

CreateThread(function()
    local sleep
    while true do
        sleep = 2000
        if Markers then
            DrawMarker(2, currentGarage.putVehicle.x, currentGarage.putVehicle.y, currentGarage.putVehicle.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.2, 0.15, 255, 255, 255, 255, false, false, 0, true, false, false, false)
            DrawMarker(2, currentGarage.takeVehicle.x, currentGarage.takeVehicle.y, currentGarage.takeVehicle.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.2, 0.15, 200, 0, 0, 222, false, false, 0, true, false, false, false)
            sleep = 0
        elseif HouseMarkers then
            DrawMarker(2, currentGarage.takeVehicle.x, currentGarage.takeVehicle.y, currentGarage.takeVehicle.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.2, 0.15, 200, 0, 0, 222, false, false, 0, true, false, false, false)
            sleep = 0
        end
        if InputIn or InputOut then
            if IsControlJustReleased(0, 38) then
                if InputIn then
                    local curVeh = cache.vehicle
                    local vehClass = GetVehicleClass(curVeh)
                    --Check vehicle type for garage
                    if currentGarage.vehicle == 'car' or not currentGarage.vehicle then
                        if vehClass ~= 14 and vehClass ~= 15 and vehClass ~= 16 then
                            if currentGarage.type == 'job' then
                                if QBX.PlayerData.job.name == currentGarage.job then
                                    parkVehicle(curVeh, currentGarageIndex, currentGarage.type)
                                end
                            elseif currentGarage.type == 'gang' then
                                if QBX.PlayerData.gang.name == currentGarage.job then
                                    parkVehicle(curVeh, currentGarageIndex, currentGarage.type)
                                end
                            else
                                parkVehicle(curVeh, currentGarageIndex, currentGarage.type)
                            end
                        else
                            exports.qbx_core:Notify(Lang:t('error.not_correct_type'), 'error', 3500)
                        end
                    elseif currentGarage.vehicle == 'air' then
                        if vehClass == 15 or vehClass == 16 then
                            if currentGarage.type == 'job' then
                                if QBX.PlayerData.job.name == currentGarage.job then
                                    parkVehicle(curVeh, currentGarageIndex, currentGarage.type)
                                end
                            elseif currentGarage.type == 'gang' then
                                if QBX.PlayerData.gang.name == currentGarage.job then
                                    parkVehicle(curVeh, currentGarageIndex, currentGarage.type)
                                end
                            else
                                parkVehicle(curVeh, currentGarageIndex, currentGarage.type)
                            end
                        else
                            exports.qbx_core:Notify(Lang:t('error.not_correct_type'), 'error', 3500)
                        end
                    elseif currentGarage.vehicle == 'sea' then
                        if vehClass == 14 then
                            if currentGarage.type == 'job' then
                                if QBX.PlayerData.job.name == currentGarage.job then
                                    parkVehicle(curVeh, currentGarageIndex, currentGarage.type, currentGarage)
                                end
                            elseif currentGarage.type == 'gang' then
                                if QBX.PlayerData.gang.name == currentGarage.job then
                                    parkVehicle(curVeh, currentGarageIndex, currentGarage.type, currentGarage)
                                end
                            else
                                parkVehicle(curVeh, currentGarageIndex, currentGarage.type, currentGarage)
                            end
                        else
                            exports.qbx_core:Notify(Lang:t('error.not_correct_type'), 'error', 3500)
                        end
                    end
                elseif InputOut then
                    if currentGarage.type == 'job' then
                        if QBX.PlayerData.job.name == currentGarage.job then
                            menuGarage(currentGarage.type, currentGarage, currentGarageIndex)
                        end
                    elseif currentGarage.type == 'gang' then
                        if QBX.PlayerData.gang.name == currentGarage.job then
                            menuGarage(currentGarage.type, currentGarage, currentGarageIndex)
                        end
                    else
                        menuGarage(currentGarage.type, currentGarage, currentGarageIndex)
                    end
                end
            end
            sleep = 0
        end
        Wait(sleep)
    end
end)
