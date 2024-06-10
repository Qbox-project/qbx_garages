---Fetches vehicles by citizenid
---@param garageName string
---@param citizenId? string
---@return VehicleEntity[]
local function fetchGaragedVehicles(garageName, citizenId)
    if citizenId then
        return MySQL.query.await('SELECT * FROM player_vehicles WHERE citizenid = ? AND garage = ? AND state = ?', {citizenId, garageName, VehicleState.GARAGED})
    else
        return MySQL.query.await('SELECT * FROM player_vehicles WHERE garage = ? AND state = ?', {garageName, VehicleState.GARAGED})
    end
end

---@param citizenId string
---@return VehicleEntity[]
local function fetchOutVehicles(citizenId)
    return MySQL.query.await('SELECT * FROM player_vehicles WHERE citizenid = ? AND state = ?', {citizenId, VehicleState.OUT})
end

---@alias CitizenId string

---@param vehicleId string
---@return CitizenId owner
local function fetchVehicleOwner(vehicleId)
    return MySQL.scalar.await('SELECT citizenid FROM player_vehicles WHERE id = ?', {vehicleId})
end

---@param vehicleId string
---@return number
local function fetchVehicleDepotPrice(vehicleId)
    return MySQL.scalar.await('SELECT depotprice FROM player_vehicles WHERE id = ?', {vehicleId})
end

---@param vehicleId string
---@return {props: table, modelName: string}
local function fetchVehicleProps(vehicleId)
    local vehicle = MySQL.single.await('SELECT mods, vehicle FROM player_vehicles WHERE id = ?', {vehicleId})
    assert(vehicle.mods ~= nil, "vehicle mods is nil for vehicleId=" .. vehicleId)
    return {
        props = json.decode(vehicle.mods),
        modelName = vehicle.vehicle
    }
end

---@async
---@param vehicleId string
---@param props table ox_lib vehicle properties table
---@param garageName string
local function saveVehicle(vehicleId, props, garageName)
    MySQL.update('UPDATE player_vehicles SET state = ?, garage = ?, fuel = ?, engine = ?, body = ?, mods = ? WHERE id = ?', {VehicleState.GARAGED, garageName, props.fuelLevel, props.engineHealth, props.bodyHealth, json.encode(props), vehicleId})
end

---@async
local function moveOutVehiclesIntoGarages()
    MySQL.update('UPDATE player_vehicles SET state = ? WHERE state = ?', {VehicleState.GARAGED, VehicleState.OUT})
end

---@async
---@param vehicleId string
---@param depotPrice number
local function setVehicleStateToOut(vehicleId, depotPrice)
    local state = VehicleState.OUT
    MySQL.update('UPDATE player_vehicles SET state = ?, depotprice = ? WHERE id = ?', {state, depotPrice, vehicleId})
end

return {
    fetchGaragedVehicles = fetchGaragedVehicles,
    fetchOutVehicles = fetchOutVehicles,
    fetchVehicleOwner = fetchVehicleOwner,
    fetchVehicleDepotPrice = fetchVehicleDepotPrice,
    fetchVehicleProps = fetchVehicleProps,
    saveVehicle = saveVehicle,
    moveOutVehiclesIntoGarages = moveOutVehiclesIntoGarages,
    setVehicleStateToOut = setVehicleStateToOut,
}