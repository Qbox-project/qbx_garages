return {
    takeOut = {
        warpInVehicle = false, -- If false, player will no longer warp into vehicle upon taking the vehicle out.
        doorsLocked = true, -- If true, the doors will be locked upon taking the vehicle out.
        engineOff = true, -- If true, the engine will be off upon taking the vehicle out.
    },

    houseGarages = {}, -- Dont touch
    garages = {

        ---@class GarageConfig
        ---@field label string -- Label for the garage
        ---@field coords vector4 -- Coordinates for the garage
        ---@field size vector3 -- Size of the garage
        ---@field spawn vector4 -- Coordinates where the vehicle will spawn
        ---@field showBlip boolean -- Enable or disable the blip
        ---@field blipName string -- Name of the blip
        ---@field blipSprite number -- Sprite for the blip
        ---@field blipColor number -- Color for the blip
        ---@field type 'public'|'job'|'gang'|'depot' -- Type of garage
        ---@field vehicle 'car'|'air'|'sea'|'all' -- Vehicle type
        ---@field job string -- Job / Gang name

        ---@type table<string, GarageConfig>

        -- Public Garages
        motelgarage = {
            label = 'Motel Parking',
            coords = vec4(275.58, -344.74, 45.17, 70.0),
            size = vec3(10, 10, 10),
            spawn = vec4(271.26, -342.32, 44.7, 159.97),
            type = 'public',
            vehicle = 'car',
        },
        sapcounsel = {
            label = 'San Andreas Parking',
            coords = vec4(-330.67, -781.12, 33.96, 40.46),
            size = vec3(10, 10, 10),
            spawn = vec4(-337.11, -775.34, 33.56, 132.09),
            type = 'public',
            vehicle = 'car',
        },
        spanishave = {
            label = 'Spanish Ave Parking',
            coords = vec4(-1160.46, -741.04, 19.95, 41.26),
            size = vec3(10, 10, 10),
            spawn = vec4(-1165.38, -747.65, 18.94, 40.45),
            type = 'public',
            vehicle = 'car',
        },
        caears24 = {
            label = 'Caears 24 Parking',
            coords = vec4(68.08, 13.15, 69.21, 160.44),
            size = vec3(10, 10, 10),
            spawn = vec4(72.61, 11.72, 68.47, 157.59),
            type = 'public',
            vehicle = 'car',
        },
        littleseoul = {
            label = 'Little Seoul Parking',
            coords = vec4(-463.51, -808.2, 30.54, 0.0),
            size = vec3(10, 10, 10),
            spawn = vec4(-472.24, -813.61, 30.3, 179.88),
            type = 'public',
            vehicle = 'car',
        },
        lagunapi = {
            label = 'Laguna Parking',
            coords = vec4(363.85, 297.97, 103.5, 341.39),
            size = vec3(10, 10, 10),
            spawn = vec4(367.41, 297.02, 103.2, 341.08),
            type = 'public',
            vehicle = 'car',
        },
        airportp = {
            label = 'Airport Parking',
            coords = vec4(-796.07, -2023.26, 9.17, 55.18),
            size = vec3(10, 10, 10),
            spawn = vec4(-793.35, -2020.62, 8.51, 58.42),
            type = 'public',
            vehicle = 'car',
        },
        beachp = {
            label = 'Beach Parking',
            coords = vec4(-1184.21, -1509.65, 4.65, 303.72),
            size = vec3(10, 10, 10),
            spawn = vec4(-1184.4, -1501.88, 4.39, 214.7),
            type = 'public',
            vehicle = 'car',
        },
        themotorhotel = {
            label = 'The Motor Hotel Parking',
            coords = vec4(1137.77, 2663.54, 37.9, 0.0),
            size = vec3(10, 10, 10),
            spawn = vec4(1137.56, 2674.19, 38.17, 359.95),
            type = 'public',
            vehicle = 'car',
        },
        liqourparking = {
            label = 'Liqour Parking',
            coords = vec4(960.68, 3609.32, 32.98, 268.97),
            size = vec3(10, 10, 10),
            spawn = vec4(960.48, 3605.71, 32.98, 87.09),
            type = 'public',
            vehicle = 'car',
        },
        shoreparking = {
            label = 'Shore Parking',
            coords = vec4(1726.9, 3710.38, 34.26, 22.54),
            size = vec3(10, 10, 10),
            spawn = vec4(1728.65, 3714.85, 34.18, 21.26),
            type = 'public',
            vehicle = 'car',
        },
        haanparking = {
            label = 'Bell Farms Parking',
            coords = vec3(78.34, 6418.74, 31.28),
            size = vec3(10, 10, 10),
            spawn = vec4(70.71, 6425.16, 30.92, 68.5),
            type = 'public',
            vehicle = 'car',
        },
        dumbogarage = {
            label = 'Dumbo Private Parking',
            coords = vec3(157.26, -3240.00, 7.00),
            size = vec3(10, 10, 10),
            spawn = vec4(165.32, -3236.10, 5.93, 268.5),
            type = 'public',
            vehicle = 'car',
        },
        pillboxgarage = {
            label = 'Pillbox Garage Parking',
            coords = vec4(218.66, -804.08, 30.75, 65.69),
            size = vec3(10, 10, 10),
            spawn = vec4(229.33, -805.01, 30.54, 156.79),
            type = 'public',
            vehicle = 'car',
        },
        intairport = {
            label = 'Airport Hangar',
            coords = vec4(-1025.34, -3017.0, 13.95, 331.99),
            size = vec3(10, 10, 10),
            spawn = vec4(-979.2, -2995.51, 13.95, 52.19),
            blipName = 'Hanger',
            blipSprite = 360,
            type = 'public',
            vehicle = 'air',
        },
        higginsheli = {
            label = 'Higgins Helitours',
            coords = vec4(-722.12, -1472.74, 5.0, 140.0),
            size = vec3(10, 10, 10),
            spawn = vec4(-724.83, -1443.89, 5.0, 140.0),
            blipName = 'Hanger',
            blipSprite = 360,
            type = 'public',
            vehicle = 'air',
        },
        airsshores = {
            label = 'Sandy Shores Hangar',
            coords = vec4(1757.74, 3296.13, 41.15, 142.6),
            size = vec3(10, 10, 10),
            spawn = vec4(1740.88, 3278.99, 41.09, 189.46),
            blipName = 'Hanger',
            blipSprite = 360,
            type = 'public',
            vehicle = 'air',
        },
        lsymc = {
            label = 'LSYMC Boathouse',
            coords = vec4(-794.64, -1510.89, 1.6, 201.55),
            size = vec3(10, 10, 10),
            spawn = vec4(-793.58, -1501.4, 0.12, 111.5),
            blipName = 'Boathouse',
            blipSprite = 356,
            type = 'public',
            vehicle = 'sea',
        },
        paleto = {
            label = 'Paleto Boathouse',
            coords = vec4(-277.4, 6637.01, 7.5, 40.51),
            size = vec3(10, 10, 10),
            spawn = vec4(-289.2, 6637.96, 1.01, 45.5),
            blipName = 'Boathouse',
            blipSprite = 356,
            type = 'public',
            vehicle = 'sea',
        },
        millars = {
            label = 'Millars Boathouse',
            coords = vec4(1299.02, 4216.42, 33.91, 166.8),
            size = vec3(10, 10, 10),
            spawn = vec4(1296.78, 4203.76, 30.12, 169.03),
            blipName = 'Boathouse',
            blipSprite = 356,
            type = 'public',
            vehicle = 'sea',
        },

        -- Job Garages
        police = {
            label = 'Police',
            coords = vec3(454.6, -1017.4, 28.4),
            size = vec3(10, 10, 10),
            spawn = vec4(438.4, -1018.3, 27.7, 90.0),
            showBlip = false,
            blipName = 'MRPD Parking',
            blipNumber = 357,
            type = 'job',
            vehicle = 'car',
            job = 'police',
        },

        -- Gang Garages
        ballas = {
            label = 'Ballas',
            coords = vec3(98.50, -1954.49, 20.84),
            size = vec3(10, 10, 10),
            spawn = vec4(98.50, -1954.49, 20.75, 335.73),
            showBlip = false,
            blipName = 'Ballas',
            blipNumber = 357,
            type = 'gang',
            vehicle = 'car',
            job = 'ballas',
        },
        families = {
            label = 'La Familia',
            coords = vec3(-811.65, 187.49, 72.48),
            size = vec3(10, 10, 10),
            spawn = vec4(-818.43, 184.97, 72.28, 107.85),
            showBlip = false,
            blipName = 'La Familia',
            blipNumber = 357,
            type = 'gang',
            vehicle = 'car',
            job = 'families',
        },
        lostmc = {
            label = 'Lost MC',
            coords = vec3(957.25, -129.63, 74.39),
            size = vec3(10, 10, 10),
            spawn = vec4(957.25, -129.63, 74.39, 199.21),
            showBlip = false,
            blipName = 'Lost MC',
            blipNumber = 357,
            type = 'gang',
            vehicle = 'car',
            job = 'lostmc',
        },
        cartel = {
            label = 'Cartel',
            coords = vec3(1407.18, 1118.04, 114.84),
            size = vec3(10, 10, 10),
            spawn = vec4(1407.18, 1118.04, 114.84, 88.34),
            showBlip = false,
            blipName = 'Cartel',
            blipNumber = 357,
            type = 'gang',
            vehicle = 'car',
            job = 'cartel',
        },

        -- Impound Lots
        impoundlot = {
            label = 'Impound Lot',
            coords = vec4(400.45, -1630.87, 29.29, 228.88),
            size = vec3(10, 10, 10),
            spawn = vec4(407.2, -1645.58, 29.31, 228.28),
            blipName = 'Impound Lot',
            blipSprite = 68,
            type = 'depot',
            vehicle = 'car',
        },
        airdepot = {
            label = 'Air Depot',
            coords = vec4(-1244.35, -3391.39, 13.94, 59.26),
            size = vec3(10, 10, 10),
            spawn = vec4(-1269.03, -3376.7, 13.94, 330.32),
            blipName = 'Air Deot',
            blipSprite = 359,
            type = 'depot',
            vehicle = 'air',
        },
        seadepot = {
            label = 'LSYMC Depot',
            coords = vec4(-772.71, -1431.11, 1.6, 48.03),
            size = vec3(10, 10, 10),
            spawn = vec4(-729.77, -1355.49, 1.19, 142.5),
            blipName = 'LSYMC Depot',
            blipSprite = 356,
            type = 'depot',
            vehicle = 'sea',
        },
    },
}