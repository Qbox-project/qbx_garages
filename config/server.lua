return {
    autoRespawn = false, -- True == auto respawn cars that are outside into your garage on script restart, false == does not put them into your garage and players have to go to the impound
    impoundFee = {
        enable = true, -- If true, impound fee is calculated and applied. If false, no impound fee is applied and depotprice remains at 0

        -- Impound fee percentage, by default, is 2% of the vehicle price but this can be changed to whatever you'd like
        -- For example, if your car costs $1000 and this is set to 2, the impound fee will be $20 as that is 2% of the vehicle price
        percentage = 2,
    },
    ---@type integer
    defaultMaxSlots = nil -- If a player does not have `maxGarageSlots` metadata set, defaults them to this value when attempting to park a vehicle in a max slots enforced garage. If a player already has the metadata field set, this config value has no effect on them.
}