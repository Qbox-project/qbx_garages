local QBCore = exports['qb-core']:GetCoreObject()
local OutsideVehicles = {}

QBCore.Functions.CreateCallback("qb-garage:server:GetGarageVehicles", function(source, cb, garage, type, category)
    local Player = QBCore.Functions.GetPlayer(source)

    if type == "public" then -- Public garages give player cars in the garage only
        MySQL.query('SELECT * FROM player_vehicles WHERE citizenid = ? AND garage = ? AND state = ?', {
            Player.PlayerData.citizenid,
            garage,
            1
        }, function(result)
            if result then
                cb(result)
            else
                cb(nil)
            end
        end)
    elseif type == "depot" then -- Depot give player cars that are not in garage only
        MySQL.query('SELECT * FROM player_vehicles WHERE citizenid = ? AND (state = ?)', {
            Player.PlayerData.citizenid,
            0
        }, function(result)
            local tosend = {}

            if result then
                -- Check vehicle type against depot type
                for _, vehicle in pairs(result) do
                    if not OutsideVehicles[vehicle.plate] or not DoesEntityExist(OutsideVehicles[vehicle.plate].entity) then
                        if category == "air" and (QBCore.Shared.Vehicles[vehicle.vehicle].category == "helicopters" or QBCore.Shared.Vehicles[vehicle.vehicle].category == "planes") then
                            tosend[#tosend + 1] = vehicle
                        elseif category == "sea" and QBCore.Shared.Vehicles[vehicle.vehicle].category == "boats" then
                            tosend[#tosend + 1] = vehicle
                        elseif category == "car" and QBCore.Shared.Vehicles[vehicle.vehicle].category ~= "helicopters" and QBCore.Shared.Vehicles[vehicle.vehicle].category ~= "planes" and QBCore.Shared.Vehicles[vehicle.vehicle].category ~= "boats" then
                            tosend[#tosend + 1] = vehicle
                        end
                    end
                end

                cb(tosend)
            else
                cb(nil)
            end
        end)
    else -- House give all cars in the garage, Job and Gang depend of config
        local shared = ''

        if not Config.SharedGarages and type ~= "house" then
            shared = " AND citizenid = '" .. Player.PlayerData.citizenid .. "'"
        end

        MySQL.query('SELECT * FROM player_vehicles WHERE garage = ? AND state = ?' .. shared, {
            garage,
            1
        }, function(result)
            if result then
                cb(result)
            else
                cb(nil)
            end
        end)
    end
end)

QBCore.Functions.CreateCallback("qb-garage:server:validateGarageVehicle", function(source, cb, garage, type, plate)
    local Player = QBCore.Functions.GetPlayer(source)

    if type == "public" then -- Public garages give player cars in the garage only
        MySQL.query('SELECT * FROM player_vehicles WHERE citizenid = ? AND garage = ? AND state = ? AND plate = ?', {
            Player.PlayerData.citizenid,
            garage,
            1,
            plate
        }, function(result)
            if result then
                cb(true)
            else
                cb(false)
            end
        end)
    elseif type == "depot" then -- Depot give player cars that are not in garage only
        MySQL.query('SELECT * FROM player_vehicles WHERE citizenid = ? AND (state = ? OR state = ?) AND plate = ?', {
            Player.PlayerData.citizenid,
            0,
            2,
            plate
        }, function(result)
            if result then
                cb(true)
            else
                cb(false)
            end
        end)
    else
        local shared = ''

        if not Config.SharedGarages and type ~= "house" then
            shared = " AND citizenid = '" .. Player.PlayerData.citizenid .. "'"
        end

        MySQL.query('SELECT * FROM player_vehicles WHERE garage = ? AND state = ? AND plate = ?' .. shared, {
            garage,
            1,
            plate
        }, function(result)
            if result then
                cb(true)
            else
                cb(false)
            end
        end)
    end
end)

QBCore.Functions.CreateCallback("qb-garage:server:checkOwnership", function(source, cb, plate, type, house, gang)
    local Player = QBCore.Functions.GetPlayer(source)

    if type == "public" then -- Public garages only for player cars
        MySQL.query('SELECT * FROM player_vehicles WHERE plate = ? AND citizenid = ?', {
            plate,
            Player.PlayerData.citizenid
        }, function(result)
            if result then
                cb(true)
            else
                cb(false)
            end
        end)
    elseif type == "house" then -- House garages only for player cars that have keys of the house
        MySQL.single('SELECT * FROM player_vehicles WHERE plate = ?', {
            plate
        }, function(result)
            if result then
                local hasHouseKey = exports['qb-houses']:hasKey(result.license, result.citizenid, house)

                if hasHouseKey then
                    cb(true)
                else
                    cb(false)
                end
            else
                cb(false)
            end
        end)
    elseif type == "gang" then -- Gang garages only for gang members cars (for sharing)
        MySQL.single('SELECT * FROM player_vehicles WHERE plate = ?', {
            plate
        }, function(result)
            if result then
                -- Check if found owner is part of the gang
                local playerData = MySQL.single.await('SELECT * FROM players WHERE citizenid = ?', {
                    result.citizenid
                })

                if playerData then
                    local playerGang = json.decode(playerData.gang)

                    if playerGang.name == gang then
                        cb(true)
                    else
                        cb(false)
                    end
                else
                    cb(false)
                end
            else
                cb(false)
            end
        end)
    else -- Job garages only for cars that are owned by someone (for sharing and service) or only by player depending of config
        local shared = ''

        if not Config.SharedGarages then
            shared = " AND citizenid = '" .. Player.PlayerData.citizenid .. "'"
        end

        MySQL.query('SELECT * FROM player_vehicles WHERE plate = ?' .. shared, {
            plate
        }, function(result)
            if result then
                cb(true)
            else
                cb(false)
            end
        end)
    end
end)

QBCore.Functions.CreateCallback('qb-garage:server:spawnvehicle', function(source, cb, vehInfo, coords, warp)
    local plate = vehInfo.plate
    local veh = QBCore.Functions.SpawnVehicle(source, vehInfo.vehicle, coords, warp)

    SetEntityHeading(veh, coords.w)
    SetVehicleNumberPlateText(veh, plate)

    local vehProps = {}
    local result = MySQL.single.await('SELECT mods FROM player_vehicles WHERE plate = ?', {
        plate
    })

    if result then
        vehProps = json.decode(result.mods)
    end

    local netId = NetworkGetNetworkIdFromEntity(veh)

    OutsideVehicles[plate] = {
        netID = netId,
        entity = veh
    }

    cb(netId, vehProps)
end)

QBCore.Functions.CreateCallback("qb-garage:server:GetVehicleProperties", function(_, cb, plate)
    local properties = {}
    local result = MySQL.single.await('SELECT mods FROM player_vehicles WHERE plate = ?', {
        plate
    })

    if result then
        properties = json.decode(result.mods)
    end

    cb(properties)
end)

QBCore.Functions.CreateCallback("qb-garage:server:IsSpawnOk", function(_, cb, plate, type)
    if type == "depot" then -- If depot, check if vehicle is not already spawned on the map
        if OutsideVehicles[plate] and DoesEntityExist(OutsideVehicles[plate].entity) then
            cb(false)
        else
            cb(true)
        end
    else
        cb(true)
    end
end)

RegisterNetEvent('qb-garage:server:updateVehicle', function(state, fuel, engine, body, plate, garage, type, gang)
    local src = source

    QBCore.Functions.TriggerCallback('qb-garage:server:checkOwnership', src, function(owned) -- Check ownership
        if owned then
            if state == 0 or state == 1 or state == 2 then -- Check state value
                if type ~= "house" then
                    if Config.Garages[garage] then -- Check if garage is existing
                        MySQL.update('UPDATE player_vehicles SET state = ?, garage = ?, fuel = ?, engine = ?, body = ? WHERE plate = ?', {
                            state,
                            garage,
                            fuel,
                            engine,
                            body,
                            plate
                        })
                    end
                else
                    MySQL.update('UPDATE player_vehicles SET state = ?, garage = ?, fuel = ?, engine = ?, body = ? WHERE plate = ?', {
                        state,
                        garage,
                        fuel,
                        engine,
                        body,
                        plate
                    })
                end
            end
        else
            TriggerClientEvent('QBCore:Notify', src, Lang:t("error.not_owned"), 'error')
        end
    end, plate, type, garage, gang)
end)

RegisterNetEvent('qb-garage:server:updateVehicleState', function(state, plate, garage)
    local src = source
    local type = "house"

    if Config.Garages[garage] then
        type = Config.Garages[garage].type
    end

    QBCore.Functions.TriggerCallback('qb-garage:server:validateGarageVehicle', src, function(owned) -- Check ownership
        if owned then
            if state == 0 then -- Check state value
                MySQL.update('UPDATE player_vehicles SET state = ?, depotprice = ? WHERE plate = ?', {
                    state,
                    0,
                    plate
                })
            end
        else
            TriggerClientEvent('QBCore:Notify', src, Lang:t("error.not_owned"), 'error')
        end
    end, garage, type, plate)
end)

RegisterNetEvent('qb-garages:server:UpdateOutsideVehicle', function(plate, vehicle)
    local entity = NetworkGetEntityFromNetworkId(vehicle)

    OutsideVehicles[plate] = {
        netID = vehicle,
        entity = entity
    }
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then
        return
    end

    Wait(100)

    if Config.AutoRespawn then
        MySQL.update('UPDATE player_vehicles SET state = 1 WHERE state = 0')
    end
end)

RegisterNetEvent('qb-garage:server:PayDepotPrice', function(data)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local cashBalance = Player.PlayerData.money.cash
    local bankBalance = Player.PlayerData.money.bank
    local vehicle = data.vehicle

    MySQL.query('SELECT * FROM player_vehicles WHERE plate = ?', {
        vehicle.plate
    }, function(result)
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

-- External Calls
-- Call from qb-vehiclesales
QBCore.Functions.CreateCallback("qb-garage:server:checkVehicleOwner", function(source, cb, plate)
    local Player = QBCore.Functions.GetPlayer(source)

    MySQL.single('SELECT * FROM player_vehicles WHERE plate = ? AND citizenid = ?', {
        plate,
        Player.PlayerData.citizenid
    }, function(result)
        if result then
            cb(true, result.balance)
        else
            cb(false)
        end
    end)
end)

-- Call from qb-phone
QBCore.Functions.CreateCallback('qb-garage:server:GetPlayerVehicles', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    local Vehicles = {}

    MySQL.query('SELECT * FROM player_vehicles WHERE citizenid = ?', {
        Player.PlayerData.citizenid
    }, function(result)
        if result then
            for _, v in pairs(result) do
                local VehicleData = QBCore.Shared.Vehicles[v.vehicle]
                local VehicleGarage = Lang:t("error.no_garage")

                if v.garage then
                    if Config.Garages[v.garage] then
                        VehicleGarage = Config.Garages[v.garage].label
                    else
                        VehicleGarage = Lang:t("info.house_garage")
                    end
                end

                if v.state == 0 then
                    v.state = Lang:t("status.out")
                elseif v.state == 1 then
                    v.state = Lang:t("status.garaged")
                elseif v.state == 2 then
                    v.state = Lang:t("status.impound")
                end

                Vehicles[#Vehicles + 1] = {
                    brand = VehicleData.brand,
                    model = VehicleData.name,
                    plate = v.plate,
                    garage = VehicleGarage,
                    state = v.state,
                    fuel = v.fuel,
                    engine = v.engine,
                    body = v.body
                }
            end

            cb(Vehicles)
        else
            cb(nil)
        end
    end)
end)