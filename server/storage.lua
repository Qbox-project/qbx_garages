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
    saveVehicle = saveVehicle,
    moveOutVehiclesIntoGarages = moveOutVehiclesIntoGarages,
    setVehicleStateToOut = setVehicleStateToOut,
}