local logger = require '@qbx_core.modules.logger'

---Calculates a fee based on vehicle data.
---@param vehicleId number        -- ID of the vehicle (not used in this calculation)
---@param modelName string        -- model name used to look up vehicle data
---@return number                 -- calculated fee based on 2% of vehicle price
local defaultCalculateImpoundFee = function(vehicleId, modelName)
    local vehicleInfo = VEHICLES[modelName]

    if not vehicleInfo then
        logger.log({
            message = string.format(
                "The model name %s does not exist in the vehicle list. Cannot calculate impound fee.",
                modelName
            ),
            webhook = Config.logging.webhook.error,
            event = 'error',
            color = 'red'
        })

        return 0
    end

    local price = vehicleInfo.price

    -- Calculate 2% of the vehicle price and round it
    local impoundFee = qbx.math.round(price * 0.02)

    logger.log({
        message = string.format(
            "Calculated impound fee for vehicle model %s (ID: %d) is: %d, based on a price of %d.",
            modelName,
            vehicleId,
            impoundFee,
            price
        ),
        webhook = Config.logging.webhook.default,
        event = 'info',
        color = 'blue'
    })

    return impoundFee
end

return defaultCalculateImpoundFee
