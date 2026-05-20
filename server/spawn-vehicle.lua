local logger = require '@qbx_core.modules.logger'

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
local function payDepotPrice(player, depotPrice)
    local cashBalance = player.PlayerData.money.cash
    local bankBalance = player.PlayerData.money.bank

    if cashBalance >= depotPrice then
        player.Functions.RemoveMoney('cash', depotPrice, 'paid-depot')
        return true
    elseif bankBalance >= depotPrice then
        player.Functions.RemoveMoney('bank', depotPrice, 'paid-depot')
        return true
    end
    return false
end

---@param source number
---@param vehicleId integer
---@param garageName string
---@param accessPointIndex integer
---@return number? netId
lib.callback.register('qbx_garages:server:spawnVehicle', function (source, vehicleId, garageName, accessPointIndex)
    local garage = TryGetGarage(source, garageName)
    if not garage then return end

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
    if garageType == GarageType.DEPOT and FindPlateOnServer(playerVehicle.props.plate) then -- If depot, check if vehicle is not already spawned on the map
        return exports.qbx_core:Notify(source, locale('error.not_impound'), 'error')
    end

    if garageType == GarageType.DEPOT and playerVehicle.depotPrice and playerVehicle.depotPrice > 0 then
        local player = exports.qbx_core:GetPlayer(source)
        local canPay = payDepotPrice(player, playerVehicle.depotPrice)

        if not canPay then
            exports.qbx_core:Notify(source, locale('error.not_enough'), 'error')
            return
        end
    end

    playerVehicle.props.lockState = 1 -- Modify the veh props lock state here to avoid conflicts with the vehicleConfig.noLock system.

    local warpPed = Config.warpInVehicle and GetPlayerPed(source)
    local netId, veh = qbx.spawnVehicle({ spawnSource = spawnCoords, model = playerVehicle.props.model, props = playerVehicle.props, warp = warpPed})

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
