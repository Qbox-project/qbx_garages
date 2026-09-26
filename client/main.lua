local config = require 'config.client'
if not config.enableClient then return end
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

local VehicleCategory = {
	all = {
		[0] = true, [1] = true, [2] = true, [3] = true, [4] = true, [5] = true,
		[6] = true, [7] = true, [8] = true, [9] = true, [10] = true, [11] = true,
		[12] = true, [13] = true, [14] = true, [15] = true, [16] = true, [17] = true,
		[18] = true, [19] = true, [20] = true, [21] = true, [22] = true,
	},
	car = {
		[0] = true,
		[1] = true,
		[2] = true,
		[3] = true,
		[4] = true,
		[5] = true,
		[6] = true,
		[7] = true,
		[8] = true,
		[9] = true,
		[10] = true,
		[11] = true,
		[12] = true,
		[13] = true,
		[17] = true,
		[18] = true,
		[19] = true,
		[20] = true,
		[22] = true,
	},
	air = { [15] = true, [16] = true },
	sea = { [14] = true },
}

---@param category VehicleType
---@param vehicle number
---@return boolean
local function isOfType(category, vehicle)
	local classes = VehicleCategory[category]
	return classes ~= nil and classes[GetVehicleClass(vehicle)] == true
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

local spawnLock = false

---@param vehicleId number
---@param garageName string
---@param accessPoint integer
local function takeOutOfGarage(vehicleId, garageName, accessPoint)
    if spawnLock then
        exports.qbx_core:Notify(locale('error.spawn_in_progress'), 'error')
        return
    end
    spawnLock = true

    local success, result = pcall(function()
        if cache.vehicle then
            exports.qbx_core:Notify(locale('error.in_vehicle'), 'error')
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
            exports.qbx_core:Notify(locale('error.spawn_failed'), 'error')
            return
        end

        if config.engineOn then
            SetVehicleEngineOn(veh, true, true, false)
        end
    end)
    spawnLock = false
    assert(success, result)
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
    local vehicleLabel = ('%s %s'):format(VEHICLES[vehicle.modelName].brand, VEHICLES[vehicle.modelName].name)

    local options = {
        {
            title = locale('menu.information'),
            icon = 'circle-info',
            description = locale('menu.description', vehicleLabel, vehicle.props.plate, lib.math.groupdigits(vehicle.depotPrice)),
            readOnly = true,
        },
        {
            title = locale('menu.body'),
            icon = 'car-side',
            readOnly = true,
            progress = body,
            colorScheme = bodyColor,
        },
        {
            title = locale('menu.engine'),
            icon = 'oil-can',
            readOnly = true,
            progress = engine,
            colorScheme = engineColor,
        },
        {
            title = locale('menu.fuel'),
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
                    takeOutOfGarage(vehicle.id, garageName, accessPoint)
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
            title = locale('menu.take_out'),
            icon = 'car-rear',
            arrow = true,
            onSelect = function()
                takeOutOfGarage(vehicle.id, garageName, accessPoint)
            end,
        }
    elseif vehicle.state == VehicleState.IMPOUNDED then
        options[#options + 1] = {
            title = locale('menu.veh_impounded'),
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
        exports.qbx_core:Notify(locale('error.no_vehicles'), 'error')
        return
    end

    table.sort(vehicleEntities, function(a, b)
        return a.modelName < b.modelName
    end)

    local options = {}
    for i = 1, #vehicleEntities do
        local vehicleEntity = vehicleEntities[i]
        local vehicleLabel = ('%s %s'):format(VEHICLES[vehicleEntity.modelName].brand, VEHICLES[vehicleEntity.modelName].name)

        options[#options + 1] = {
            title = vehicleLabel,
            description = vehicleEntity.props.plate,
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
            exports.qbx_core:Notify(locale('error.not_owned'), 'error', 5000)
            return
        end

        kickOutPeds(vehicle)
        SetVehicleDoorsLocked(vehicle, 2)
        Wait(1500)
        local parked = lib.callback.await('qbx_garages:server:parkVehicle', false, NetworkGetNetworkIdFromEntity(vehicle), lib.getVehicleProperties(vehicle), garageName)
        if parked then
            exports.qbx_core:Notify(locale('success.vehicle_parked'), 'primary', 4500)
        end
    else
        exports.qbx_core:Notify(locale('error.vehicle_occupied'), 'error', 3500)
    end
end

---@param garage GarageConfig
---@return boolean
local function checkCanAccess(garage)
    if garage.groups and not exports.qbx_core:HasPrimaryGroup(garage.groups, QBX.PlayerData) then
        exports.qbx_core:Notify(locale('error.no_access'), 'error')
        return false
    end
    if cache.vehicle and not isOfType(garage.vehicleType, cache.vehicle) then
        exports.qbx_core:Notify(locale('error.not_correct_type'), 'error')
        return false
    end
    return true
end

local activeRadialItems = {}

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    for id in pairs(activeRadialItems) do lib.removeRadialItem(id) end
end)

---@param garageName string
---@param garage GarageConfig
---@param accessPoint AccessPoint
---@param accessPointIndex integer
local function createZones(garageName, garage, accessPoint, accessPointIndex)
    CreateThread(function()
        accessPoint.dropPoint = accessPoint.dropPoint or accessPoint.spawn
        local drawRadius = accessPoint.drawRadius or 60
        local dropDrawRadius = accessPoint.dropDrawRadius or 60
        local useRadius = accessPoint.useRadius or 1
        local dropUseRadius = accessPoint.dropUseRadius or 1.5
        local dropZone, coordsZone
        local useRadial = config.interact == 'radialmenu'

        local function createInteractionZone(coords, radius, isDrop)
            local id = ('qbx_garages:%s:%s:%s'):format(garageName, accessPointIndex, isDrop and 'drop' or 'menu')
            local shownAction

            local function getAction()
                if useRadial and not LocalPlayer.state.isLoggedIn then return end
                if isDrop then return cache.vehicle and 'park' or nil end
                if accessPoint.dropPoint and cache.vehicle then return end
                return garage.type == GarageType.DEPOT and 'impound' or cache.vehicle and 'park' or 'car'
            end

            local function selectAction()
                if #(GetEntityCoords(cache.ped) - vec3(coords.x, coords.y, coords.z)) > radius then return end
                local action = getAction()
                if not action or not checkCanAccess(garage) then return end
                if action == 'park' then
                    parkVehicle(cache.vehicle, garageName)
                else
                    openGarageMenu(garageName, garage, accessPointIndex)
                end
            end

            local function clearInteraction()
                if useRadial then
                    lib.removeRadialItem(id)
                    activeRadialItems[id] = nil
                elseif shownAction then
                    lib.hideTextUI()
                end
                shownAction = nil
            end

            local function updateInteraction()
                local action = getAction()
                if action == shownAction then return end
                clearInteraction()
                shownAction = action
                if not action then return end
                if useRadial then
                    activeRadialItems[id] = true
                    lib.addRadialItem({
                        id = id,
                        label = locale('info.' .. action .. '_radial'),
                        icon = action == 'park' and 'square-parking' or 'warehouse',
                        onSelect = selectAction,
                    })
                else
                    lib.showTextUI(locale('info.' .. action .. '_e'))
                end
            end

            return lib.zones.sphere({
                coords = coords,
                radius = radius,
                onEnter = updateInteraction,
                onExit = clearInteraction,
                inside = function()
                    updateInteraction()
                    if not useRadial and IsControlJustReleased(0, 38) then selectAction() end
                end,
                debug = config.debugPoly,
            })
        end

        local function createDropZone()
            if dropZone then return end
            dropZone = createInteractionZone(accessPoint.dropPoint, dropUseRadius, true)
        end

        local function createCoordsZone()
            if coordsZone then return end
            coordsZone = createInteractionZone(accessPoint.coords, useRadius, false)
        end
        lib.zones.sphere({
            coords = accessPoint.coords,
            radius = drawRadius,
            onEnter = function()
                createCoordsZone()
            end,
            onExit = function()
                if coordsZone then
                    coordsZone.onExit()
                    coordsZone:remove()
                    coordsZone = nil
                end
            end,
            inside = function()
                config.drawGarageMarker(accessPoint.coords.xyz, useRadius)
            end,
            debug = config.debugPoly,
        })

        if accessPoint.dropPoint and garage.type ~= GarageType.DEPOT then
            lib.zones.sphere({
                coords = accessPoint.dropPoint,
                radius = dropDrawRadius,
                onEnter = function()
                    createDropZone()
                end,
                onExit = function()
                    if dropZone then
                        dropZone.onExit()
                        dropZone:remove()
                        dropZone = nil
                    end
                end,
                inside = function()
                    config.drawDropOffMarker(accessPoint.dropPoint, dropUseRadius)
                end,
                debug = config.debugPoly,
            })
        end
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

CreateThread(function()
    createGarages()
end)
