require 'shared.types'

return {
    takeOut = {
        warpInVehicle = false, -- If false, player will no longer warp into vehicle upon taking the vehicle out.
        doorsLocked = true, -- If true, the doors will be locked upon taking the vehicle out.
        engineOff = true, -- If true, the engine will be off upon taking the vehicle out.
    },

    ---@class GarageBlip
    ---@field name? string -- Name of the blip. Defaults to garage label.
    ---@field sprite? number -- Sprite for the blip. Defaults to 357
    ---@field color? number -- Color for the blip. Defaults to 3.

    ---The place where the player can access the garage and spawn a car
    ---@class AccessPoint
    ---@field coords vector4 where the garage menu can be accessed from
    ---@field blip? GarageBlip
    ---@field size vector3
    ---@field spawn vector4 where the vehicle will spawn

    ---@class GarageConfig
    ---@field label string -- Label for the garage
    ---@field type? GarageType -- Optional special type of garage. Currently only used to mark DEPOT garages.
    ---@field vehicleType VehicleType -- Vehicle type
    ---@field groups? string | string[] | table<string, number> job/gangs that can access the garage
    ---@field shared? boolean defaults to false. Shared garages give all players with access to the garage access to all vehicles in it. If shared is off, the garage will only give access to player's vehicles which they own.
    ---@field states? VehicleState | VehicleState[] if set, only vehicles in the given states will be retrievable from the garage. Defaults to GARAGED.
    ---@field skipGarageCheck? boolean if true, returns vehicles for retrieval regardless of if that vehicle's garage matches this garage's name
    ---@field canAccess? fun(source?: number): boolean runs on both client & server to check access as an additional guard clause. Other filter fields still need to pass in addition to this function.
    ---@field accessPoints AccessPoint[]

    ---@type table<string, GarageConfig>
    garages = {
        -- Public Garages
        motelgarage = {
            label = 'Motel Parking',
            vehicleType = VehicleType.CAR,
            accessPoints = {
                {
                    coords = vec4(275.58, -344.74, 45.17, 70.0),
                    size = vec3(10, 10, 10),
                    spawn = vec4(271.26, -342.32, 44.7, 159.97),
                }
            },
        },
        sapcounsel = {
            label = 'San Andreas Parking',
            vehicleType = VehicleType.CAR,
            accessPoints = {
                {
                    coords = vec4(-330.67, -781.12, 33.96, 40.46),
                    size = vec3(10, 10, 10),
                    spawn = vec4(-337.11, -775.34, 33.56, 132.09),
                }
            },
        },
        spanishave = {
            label = 'Spanish Ave Parking',
            vehicleType = VehicleType.CAR,
            accessPoints = {
                {
                    coords = vec4(-1160.46, -741.04, 19.95, 41.26),
                    size = vec3(10, 10, 10),
                    spawn = vec4(-1165.38, -747.65, 18.94, 40.45),
                }
            },
        },
        caears24 = {
            label = 'Caears 24 Parking',
            vehicleType = VehicleType.CAR,
            accessPoints = {
                {
                    coords = vec4(68.08, 13.15, 69.21, 160.44),
                    size = vec3(10, 10, 10),
                    spawn = vec4(72.61, 11.72, 68.47, 157.59),
                },
            },
        },
        littleseoul = {
            label = 'Little Seoul Parking',
            vehicleType = VehicleType.CAR,
            accessPoints = {
                {
                    coords = vec4(-463.51, -808.2, 30.54, 0.0),
                    size = vec3(10, 10, 10),
                    spawn = vec4(-472.24, -813.61, 30.3, 179.88),
                }
            },
        },
        lagunapi = {
            label = 'Laguna Parking',
            vehicleType = VehicleType.CAR,
            accessPoints = {
                {
                    coords = vec4(363.85, 297.97, 103.5, 341.39),
                    size = vec3(10, 10, 10),
                    spawn = vec4(367.41, 297.02, 103.2, 341.08),
                }
            },
        },
        airportp = {
            label = 'Airport Parking',
            vehicleType = VehicleType.CAR,
            accessPoints = {
                {
                    coords = vec4(-796.07, -2023.26, 9.17, 55.18),
                    size = vec3(10, 10, 10),
                    spawn = vec4(-793.35, -2020.62, 8.51, 58.42),
                }
            },
        },
        beachp = {
            label = 'Beach Parking',
            vehicleType = VehicleType.CAR,
            accessPoints = {
                {
                    coords = vec4(-1184.21, -1509.65, 4.65, 303.72),
                    size = vec3(10, 10, 10),
                    spawn = vec4(-1184.4, -1501.88, 4.39, 214.7),
                }
            },
        },
        themotorhotel = {
            label = 'The Motor Hotel Parking',
            vehicleType = VehicleType.CAR,
            accessPoints = {
                {
                    coords = vec4(1137.77, 2663.54, 37.9, 0.0),
                    size = vec3(10, 10, 10),
                    spawn = vec4(1137.56, 2674.19, 38.17, 359.95),
                }
            },
        },
        liqourparking = {
            label = 'Liqour Parking',
            vehicleType = VehicleType.CAR,
            accessPoints = {
                {
                    coords = vec4(960.68, 3609.32, 32.98, 268.97),
                    size = vec3(10, 10, 10),
                    spawn = vec4(960.48, 3605.71, 32.98, 87.09),
                }
            },
        },
        shoreparking = {
            label = 'Shore Parking',
            vehicleType = VehicleType.CAR,
            accessPoints = {
                {
                    coords = vec4(1726.9, 3710.38, 34.26, 22.54),
                    size = vec3(10, 10, 10),
                    spawn = vec4(1728.65, 3714.85, 34.18, 21.26),
                }
            },
        },
        haanparking = {
            label = 'Bell Farms Parking',
            vehicleType = VehicleType.CAR,
            accessPoints = {
                {
                    coords = vec4(78.34, 6418.74, 31.28, 0),
                    size = vec3(10, 10, 10),
                    spawn = vec4(70.71, 6425.16, 30.92, 68.5),
                }
            },
        },
        dumbogarage = {
            label = 'Dumbo Private Parking',
            vehicleType = VehicleType.CAR,
            accessPoints = {
                {
                    coords = vec4(157.26, -3240.00, 7.00, 0),
                    size = vec3(10, 10, 10),
                    spawn = vec4(165.32, -3236.10, 5.93, 268.5),
                }
            },
        },
        pillboxgarage = {
            label = 'Pillbox Garage Parking',
            vehicleType = VehicleType.CAR,
            accessPoints = {
                {
                    coords = vec4(218.66, -804.08, 30.75, 65.69),
                    size = vec3(10, 10, 10),
                    spawn = vec4(229.33, -805.01, 30.54, 156.79),
                }
            },
        },
        intairport = {
            label = 'Airport Hangar',
            vehicleType = VehicleType.AIR,
            accessPoints = {
                {
                    coords = vec4(-1025.34, -3017.0, 13.95, 331.99),
                    size = vec3(10, 10, 10),
                    spawn = vec4(-979.2, -2995.51, 13.95, 52.19),
                    blip = {
                        name = 'Hanger',
                        sprite = 360,
                    },
                }
            },
        },
        higginsheli = {
            label = 'Higgins Helitours',
            vehicleType = VehicleType.AIR,
            accessPoints = {
                {
                    coords = vec4(-722.12, -1472.74, 5.0, 140.0),
                    size = vec3(10, 10, 10),
                    spawn = vec4(-724.83, -1443.89, 5.0, 140.0),
                    blip = {
                        name = 'Hanger',
                        sprite = 360,
                    },
                }
            },
        },
        airsshores = {
            label = 'Sandy Shores Hangar',
            vehicleType = VehicleType.AIR,
            accessPoints = {
                {
                    coords = vec4(1757.74, 3296.13, 41.15, 142.6),
                    size = vec3(10, 10, 10),
                    spawn = vec4(1740.88, 3278.99, 41.09, 189.46),
                    blip = {
                        name = 'Hanger',
                        sprite = 360,
                    },
                }
            },
        },
        lsymc = {
            label = 'LSYMC Boathouse',
            vehicleType = VehicleType.SEA,
            accessPoints = {
                {
                    coords = vec4(-794.64, -1510.89, 1.6, 201.55),
                    size = vec3(10, 10, 10),
                    spawn = vec4(-793.58, -1501.4, 0.12, 111.5),
                    blip = {
                        name = 'Boathouse',
                        sprite = 356,
                    },
                }
            },
        },
        paleto = {
            label = 'Paleto Boathouse',
            vehicleType = VehicleType.SEA,
            accessPoints = {
                {
                    coords = vec4(-277.4, 6637.01, 7.5, 40.51),
                    size = vec3(10, 10, 10),
                    spawn = vec4(-289.2, 6637.96, 1.01, 45.5),
                    blip = {
                        name = 'Boathouse',
                        sprite = 356,
                    },
                }
            },
        },
        millars = {
            label = 'Millars Boathouse',
            vehicleType = VehicleType.SEA,
            accessPoints = {
                {
                    coords = vec4(1299.02, 4216.42, 33.91, 166.8),
                    size = vec3(10, 10, 10),
                    spawn = vec4(1296.78, 4203.76, 30.12, 169.03),
                    blip = {
                        name = 'Boathouse',
                        sprite = 356,
                    },
                }
            },
        },

        -- Job Garages
        police = {
            label = 'Police',
            vehicleType = VehicleType.CAR,
            group = 'police',
            accessPoints = {
                {
                    coords = vec4(454.6, -1017.4, 28.4, 0),
                    size = vec3(10, 10, 10),
                    spawn = vec4(438.4, -1018.3, 27.7, 90.0),
                }
            },
        },

        -- Gang Garages
        ballas = {
            label = 'Ballas',
            vehicleType = VehicleType.CAR,
            group = 'ballas',
            accessPoints = {
                {
                    coords = vec4(98.50, -1954.49, 20.84, 0),
                    size = vec3(10, 10, 10),
                    spawn = vec4(98.50, -1954.49, 20.75, 335.73),
                }
            },
        },
        families = {
            label = 'La Familia',
            vehicleType = VehicleType.CAR,
            group = 'families',
            accessPoints = {
                {
                    coords = vec4(-811.65, 187.49, 72.48, 0),
                    size = vec3(10, 10, 10),
                    spawn = vec4(-818.43, 184.97, 72.28, 107.85),
                }
            },
        },
        lostmc = {
            label = 'Lost MC',
            vehicleType = VehicleType.CAR,
            group = 'lostmc',
            accessPoints = {
                {
                    coords = vec4(957.25, -129.63, 74.39, 0),
                    size = vec3(10, 10, 10),
                    spawn = vec4(957.25, -129.63, 74.39, 199.21),
                }
            },
        },
        cartel = {
            label = 'Cartel',
            vehicleType = VehicleType.CAR,
            group = 'cartel',
            accessPoints = {
                {
                    coords = vec4(1407.18, 1118.04, 114.84, 0),
                    size = vec3(10, 10, 10),
                    spawn = vec4(1407.18, 1118.04, 114.84, 88.34),
                }
            },
        },

        -- Impound Lots
        impoundlot = {
            label = 'Impound Lot',
            type = GarageType.DEPOT,
            states = {VehicleState.OUT, VehicleState.IMPOUNDED},
            skipGarageCheck = true,
            vehicleType = VehicleType.CAR,
            accessPoints = {
                {
                    coords = vec4(400.45, -1630.87, 29.29, 228.88),
                    size = vec3(10, 10, 10),
                    spawn = vec4(407.2, -1645.58, 29.31, 228.28),
                    blip = {
                        sprite = 68
                    },
                }
            },
        },
        airdepot = {
            label = 'Air Depot',
            type = GarageType.DEPOT,
            states = {VehicleState.OUT, VehicleState.IMPOUNDED},
            skipGarageCheck = true,
            vehicleType = VehicleType.AIR,
            accessPoints = {
                {
                    coords = vec4(-1244.35, -3391.39, 13.94, 59.26),
                    size = vec3(10, 10, 10),
                    spawn = vec4(-1269.03, -3376.7, 13.94, 330.32),
                    blip = {
                        sprite = 359,
                    },
                }
            },
        },
        seadepot = {
            label = 'LSYMC Depot',
            type = GarageType.DEPOT,
            states = {VehicleState.OUT, VehicleState.IMPOUNDED},
            skipGarageCheck = true,
            vehicleType = VehicleType.SEA,
            accessPoints = {
                {
                    coords = vec4(-772.71, -1431.11, 1.6, 48.03),
                    size = vec3(10, 10, 10),
                    spawn = vec4(-729.77, -1355.49, 1.19, 142.5),
                    blip = {
                        sprite = 356,
                    },
                }
            },
        },
    },
}