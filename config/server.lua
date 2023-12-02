return {
    autoRespawn = false, -- True == auto respawn cars that are outside into your garage on script restart, false == does not put them into your garage and players have to go to the impound
    sharedGarages = false, -- True == Gang and job garages are shared, false == Gang and Job garages are personal

    impoundFee = {
        enable = true, -- If true, impound fee is calculated and applied. If false, no impound fee is applied and depotprice remains at 0

        -- Impound fee percentage, by default, is 2% of the vehicle price but this can be changed to whatever you'd like
        -- For example, if your car costs $1000 and this is set to 2, the impound fee will be $20 as that is 2% of the vehicle price
        percentage = 2,
    },
}