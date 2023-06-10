local QBCore = exports['qbx-core']:GetCoreObject()
local OutsideVehicles = {}

lib.callback.register("qb-garage:server:GetGarageVehicles", function(source, garage, _type, category)
    local pData = QBCore.Functions.GetPlayer(source)
    if _type == "public" then        --Public garages give player cars in the garage only
        local result = MySQL.query.await('SELECT * FROM player_vehicles WHERE citizenid = ? AND garage = ? AND state = ?', {pData.PlayerData.citizenid, garage, 1})
        return result[1] and result
    elseif _type == "depot" then    --Depot give player cars that are not in garage only
        local result = MySQL.query.await('SELECT * FROM player_vehicles WHERE citizenid = ? AND (state = ?)', {pData.PlayerData.citizenid, 0})
        local toSend = {}
        if not result[1] then return false end
        --Check vehicle type against depot type
        for _, vehicle in pairs(result) do
            if not OutsideVehicles[vehicle.plate] or not DoesEntityExist(OutsideVehicles[vehicle.plate].entity) then
                if category == "air" and ( QBCore.Shared.Vehicles[vehicle.vehicle].category == "helicopters" or QBCore.Shared.Vehicles[vehicle.vehicle].category == "planes" ) then
                    toSend[#toSend + 1] = vehicle
                elseif category == "sea" and QBCore.Shared.Vehicles[vehicle.vehicle].category == "boats" then
                    toSend[#toSend + 1] = vehicle
                elseif category == "car" and QBCore.Shared.Vehicles[vehicle.vehicle].category ~= "helicopters" and QBCore.Shared.Vehicles[vehicle.vehicle].category ~= "planes" and QBCore.Shared.Vehicles[vehicle.vehicle].category ~= "boats" then
                    toSend[#toSend + 1] = vehicle
                end
            end
        end
        return toSend
    else                            --House give all cars in the garage, Job and Gang depend of config
        local shared = SharedGarages and _type ~= 'house' and '' or " AND citizenid = '"..pData.PlayerData.citizenid.."'"
        local result = MySQL.query.await('SELECT * FROM player_vehicles WHERE garage = ? AND state = ?'..shared, {garage, 1})
        return result[1] and result
    end
end)

local function validateGarageVehicle(source, garage, _type, plate)
    local pData = QBCore.Functions.GetPlayer(source)
    if _type == "public" then --Public garages give player cars in the garage only
        local result = MySQL.query.await('SELECT * FROM player_vehicles WHERE citizenid = ? AND garage = ? AND state = ? AND plate = ?', {pData.PlayerData.citizenid, garage, 1, plate})
        return result[1]
    elseif _type == "depot" then --Depot give player cars that are not in garage only
        local result = MySQL.query.await('SELECT * FROM player_vehicles WHERE citizenid = ? AND (state = ? OR state = ?) AND plate = ?', {pData.PlayerData.citizenid, 0, 2, plate})
        return result[1]
    else
        local shared = SharedGarages and _type ~= 'house' and '' or " AND citizenid = '"..pData.PlayerData.citizenid.."'"
        local result = MySQL.query.await('SELECT * FROM player_vehicles WHERE garage = ? AND state = ? AND plate = ?'..shared, {garage, 1, plate})
        return result[1]
    end
end

lib.callback.register("qb-garage:server:validateGarageVehicle", validateGarageVehicle)

local function checkOwnership(source, plate, _type, house, gang)
    local pData = QBCore.Functions.GetPlayer(source)
    if _type == "public" then --Public garages only for player cars
        return MySQL.query.await('SELECT * FROM player_vehicles WHERE plate = ? AND citizenid = ?', {plate, pData.PlayerData.citizenid})
    elseif _type == "house" then --House garages only for player cars that have keys of the house
        local result = MySQL.query.await('SELECT * FROM player_vehicles WHERE plate = ?', {plate})
        return result[1] and exports['qb-houses']:hasKey(result[1].license, result[1].citizenid, house)
    elseif _type == "gang" then --Gang garages only for gang members cars (for sharing)
        local result = MySQL.query.await('SELECT * FROM player_vehicles WHERE plate = ?', {plate})
        if not result[1] then return false end
        --Check if found owner is part of the gang
        local resultplayer = MySQL.single.await('SELECT * FROM players WHERE citizenid = ?', { result[1].citizenid })
        if not resultplayer then return false end
        return json.decode(resultplayer.gang)?.name == gang
    else --Job garages only for cars that are owned by someone (for sharing and service) or only by player depending of config
        local shared = SharedGarages and '' or " AND citizenid = '"..pData.PlayerData.citizenid.."'"
        local result = MySQL.query.await('SELECT * FROM player_vehicles WHERE plate = ?'..shared, {plate})
        return result[1]
    end
end

lib.callback.register("qb-garage:server:checkOwnership", checkOwnership)

lib.callback.register('qb-garage:server:spawnvehicle', function (source, vehInfo, coords, warp)
    local plate = vehInfo.plate
    local veh = QBCore.Functions.SpawnVehicle(source, vehInfo.vehicle, coords, warp)
    SetEntityHeading(veh, coords.w)
    SetVehicleNumberPlateText(veh, plate)
    local vehProps = {}
    local result = MySQL.query.await('SELECT mods FROM player_vehicles WHERE plate = ?', {plate})
    if result[1] then vehProps = json.decode(result[1].mods) end
    local netId = NetworkGetNetworkIdFromEntity(veh)
    OutsideVehicles[plate] = {netID = netId, entity = veh}
    return netId, vehProps
end)

lib.callback.register("qb-garage:server:GetVehicleProperties", function(_, plate)
    local result = MySQL.query.await('SELECT mods FROM player_vehicles WHERE plate = ?', {plate})
    return result[1] and json.decode(result[1].mods) or {}
end)

lib.callback.register("qb-garage:server:IsSpawnOk", function(_, plate, _type)
    if _type == "depot" then --If depot, check if vehicle is not already spawned on the map
        return OutsideVehicles[plate] and DoesEntityExist(OutsideVehicles[plate].entity)
    end

    return true
end)

RegisterNetEvent('qb-garage:server:updateVehicle', function(state, fuel, engine, body, plate, garage, type, gang)
    local owned = checkOwnership(source, plate, type, garage, gang) --Check ownership
    if not owned then
        TriggerClientEvent('QBCore:Notify', source, Lang:t("error.not_owned"), 'error')
        return
    end

    --Check state value
    if state ~= 0 and state ~= 1 and state ~= 2 then return end

    if type ~= "house" then
        if Garages[garage] then --Check if garage is existing
            MySQL.update('UPDATE player_vehicles SET state = ?, garage = ?, fuel = ?, engine = ?, body = ? WHERE plate = ?', {state, garage, fuel, engine, body, plate})
        end
    else
        MySQL.update('UPDATE player_vehicles SET state = ?, garage = ?, fuel = ?, engine = ?, body = ? WHERE plate = ?', {state, garage, fuel, engine, body, plate})
    end
end)

RegisterNetEvent('qb-garage:server:updateVehicleState', function(state, plate, garage)
    local type
    if Garages[garage] then
        type = Garages[garage].type
    else
        type = "house"
    end

    local owned = validateGarageVehicle(source, garage, type, plate) --Check ownership
    if not owned then
        TriggerClientEvent('QBCore:Notify', source, Lang:t("error.not_owned"), 'error')
        return
    end

    --Check state value
    if state ~= 0 then return end

    MySQL.update('UPDATE player_vehicles SET state = ?, depotprice = ? WHERE plate = ?', {state, 0, plate})
end)

RegisterNetEvent('qb-garages:server:UpdateOutsideVehicle', function(plate, vehicle)
    OutsideVehicles[plate] = {netID = vehicle, entity = NetworkGetEntityFromNetworkId(vehicle)}
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Wait(100)
    if not AutoRespawn then return end

    MySQL.update('UPDATE player_vehicles SET state = 1 WHERE state = 0', {})
end)

RegisterNetEvent('qb-garage:server:PayDepotPrice', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local cashBalance = Player.PlayerData.money.cash
    local bankBalance = Player.PlayerData.money.bank
    local vehicle = data.vehicle

    MySQL.query('SELECT * FROM player_vehicles WHERE plate = ?', {vehicle.plate}, function(result)
        if result[1] then
            if cashBalance >= result[1].depotprice then
                Player.Functions.RemoveMoney("cash", result[1].depotprice, "paid-depot")
                TriggerClientEvent("qb-garages:client:takeOutGarage", src, data)
            elseif bankBalance >= result[1].depotprice then
                Player.Functions.RemoveMoney("bank", result[1].depotprice, "paid-depot")
                TriggerClientEvent("qb-garages:client:takeOutGarage", src, data)
            else
                TriggerClientEvent('QBCore:Notify', src, Lang:t("error.not_enough"), 'error')
            end
        end
    end)
end)

--External Calls
--Call from qb-vehiclesales
lib.callback.register("qb-garage:server:checkVehicleOwner", function(source, plate)
    local src = source
    local pData = QBCore.Functions.GetPlayer(src)
    local result = MySQL.query.await('SELECT * FROM player_vehicles WHERE plate = ? AND citizenid = ?',{plate, pData.PlayerData.citizenid})
    return result[1] ~= nil, result[1]?.balance
end)

--Call from qb-phone
lib.callback.register('qb-garage:server:GetPlayerVehicles', function(source)
    local player = QBCore.Functions.GetPlayer(source)
    local vehicles = {}

    local result = MySQL.query.await('SELECT * FROM player_vehicles WHERE citizenid = ?', {player.PlayerData.citizenid})
    if result[1] then
        for _, v in pairs(result) do
            local vehicleData = QBCore.Shared.Vehicles[v.vehicle]

            local vehicleGarage = Lang:t("error.no_garage")
            if v.garage then
                if Garages[v.garage] ~= nil then
                    vehicleGarage = Garages[v.garage].label
                else
                    vehicleGarage = Lang:t("info.house_garage")         -- HouseGarages[v.garage].label
                end
            end

            if v.state == 0 then
                v.state = Lang:t("status.out")
            elseif v.state == 1 then
                v.state = Lang:t("status.garaged")
            elseif v.state == 2 then
                v.state = Lang:t("status.impound")
            end

            vehicles[#vehicles + 1] = {
                fullname = vehicleData.brand and vehicleData.brand .. " " .. vehicleData.name or vehicleData.name,
                brand = vehicleData.brand,
                model = vehicleData.name,
                plate = v.plate,
                garage = vehicleGarage,
                state = v.state,
                fuel = v.fuel,
                engine = v.engine,
                body = v.body
            }
        end

        return vehicles
    end
end)
