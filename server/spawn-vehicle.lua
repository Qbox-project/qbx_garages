local logger = require '@qbx_core.modules.logger'
local spawningVehicles = {}

---@param player table
---@param garage GarageConfig
---@return boolean
local function canAccessGarage(player, garage)
    if garage.groups and not exports.qbx_core:HasPrimaryGroup(player.PlayerData.source, garage.groups) then
        return false
    end
    if garage.canAccess ~= nil and not garage.canAccess(player.PlayerData.source) then
        return false
    end
    return true
end

---@param vehicleId integer
---@param modelName string
local function setVehicleStateToOut(vehicleId, vehicle, modelName)
    local depotPrice = Config.calculateImpoundFee(vehicleId, modelName) or 0
    exports.qbx_vehicles:SaveVehicle(vehicle, {
        state = VehicleState.OUT,
        depotPrice = depotPrice
    })
end

---@param player table
---@param depotPrice integer
---@return string?
local function payDepotPrice(player, depotPrice)
    local cashBalance = player.PlayerData.money.cash
    local bankBalance = player.PlayerData.money.bank

    if cashBalance >= depotPrice then
        return player.Functions.RemoveMoney('cash', depotPrice, 'paid-depot') and 'cash'
    elseif bankBalance >= depotPrice then
        return player.Functions.RemoveMoney('bank', depotPrice, 'paid-depot') and 'bank'
    end
end

---@param source number
---@param vehicleId integer
---@param garageName string
---@param accessPointIndex integer
---@return number? netId
lib.callback.register('qbx_garages:server:spawnVehicle', function (source, vehicleId, garageName, accessPointIndex)
    if type(vehicleId) ~= 'number' or vehicleId % 1 ~= 0 then return end
    if type(garageName) ~= 'string' then return end
    if type(accessPointIndex) ~= 'number' or accessPointIndex % 1 ~= 0 then return end

    local player = exports.qbx_core:GetPlayer(source)
    local garage = TryGetGarage(source, garageName)
    if not player or not garage or not canAccessGarage(player, garage) then return end

    local accessPoint = garage.accessPoints[accessPointIndex]
    if not accessPoint then
        logger.log({
            source = source,
            message = string.format(
                'Attempted to spawn a vehicle from a non-existent access point index: %d for garage: %s',
                accessPointIndex,
                garageName
            ),
            webhook = Config.logging.webhook.error,
            event = 'error',
            color = 'red'
        })

        return
    end

    local distanceBetweenPlayerAndAccessPoint = #(GetEntityCoords(GetPlayerPed(source)) - accessPoint.coords.xyz)
    if distanceBetweenPlayerAndAccessPoint > 3 then
        logger.log({
            source = source,
            message = string.format(
                'Player attempted to spawn a vehicle but was too far from the access point. Distance: %.2f, Access Point Index: %d, Garage: %s',
                distanceBetweenPlayerAndAccessPoint,
                accessPointIndex,
                garageName
            ),
            webhook = Config.logging.webhook.anticheat,
            event = 'suspicious',
            color = 'white'
        })

        return
    end
    local garageType = GetGarageType(garageName)

    local spawnCoords = accessPoint.spawn or accessPoint.coords
    if Config.distanceCheck then
        local nearbyVehicle = lib.getClosestVehicle(spawnCoords.xyz, Config.distanceCheck, false)
        if nearbyVehicle then
            exports.qbx_core:Notify(source, locale('error.no_space'), 'error')
            return
        end
    end

    local filter = GetPlayerVehicleFilter(source, garageName)
    local playerVehicle = exports.qbx_vehicles:GetPlayerVehicle(vehicleId, filter)
    if not playerVehicle then
        exports.qbx_core:Notify(source, locale('error.not_owned'), 'error')
        return
    end
    if type(playerVehicle.props) ~= 'table' or type(playerVehicle.props.plate) ~= 'string'
        or type(playerVehicle.props.model) ~= 'number' then return end

    if garageType == GarageType.DEPOT and FindPlateOnServer(playerVehicle.props.plate) then -- If depot, check if vehicle is not already spawned on the map
        return exports.qbx_core:Notify(source, locale('error.not_impound'), 'error')
    end

    if spawningVehicles[vehicleId] then return end
    spawningVehicles[vehicleId] = true

    local paidFrom
    local depotPrice
    if garageType == GarageType.DEPOT then
        OverrideFreeDepotPriceForOutVehicle(playerVehicle)
        depotPrice = tonumber(playerVehicle.depotPrice) or 0
        if depotPrice ~= depotPrice or depotPrice < 0 or depotPrice > 100000000 then
            spawningVehicles[vehicleId] = nil
            return
        end

        if depotPrice > 0 then
            paidFrom = payDepotPrice(player, depotPrice)
            if not paidFrom then
                spawningVehicles[vehicleId] = nil
                exports.qbx_core:Notify(source, locale('error.not_enough'), 'error')
                return
            end
        end
    end

    playerVehicle.props.lockState = 1 -- Modify the veh props lock state here to avoid conflicts with the vehicleConfig.noLock system.

    local warpPed = Config.warpInVehicle and GetPlayerPed(source)
    local success, netId, veh = pcall(qbx.spawnVehicle, {
        spawnSource = spawnCoords,
        model = playerVehicle.props.model,
        props = playerVehicle.props,
        warp = warpPed,
    })
    spawningVehicles[vehicleId] = nil

    if not success or not netId or not veh or veh == 0 or not DoesEntityExist(veh) then
        if paidFrom then
            player.Functions.AddMoney(paidFrom, depotPrice, 'depot-spawn-refund')
        end
        return
    end

    if Config.doorsLocked then
        if GetResourceState('qbx_vehiclekeys') == 'started' then
            TriggerEvent('qb-vehiclekeys:server:setVehLockState', netId, 2)
        else
            SetVehicleDoorsLocked(veh, 2)
        end
    end

    TriggerClientEvent('vehiclekeys:client:SetOwner', source, playerVehicle.props.plate)

    Entity(veh).state:set('vehicleid', vehicleId, false)
    setVehicleStateToOut(vehicleId, veh, playerVehicle.modelName)
    TriggerEvent('qbx_garages:server:vehicleSpawned', veh)
    return netId
end)

function OverrideFreeDepotPriceForOutVehicle(vehicle)
    if VehicleState.OUT ~= vehicle.state then return end
    if vehicle.depotPrice and vehicle.depotPrice > 0 then return end

    vehicle.depotPrice = Config.calculateImpoundFee(vehicle.id, vehicle.modelName)
end
