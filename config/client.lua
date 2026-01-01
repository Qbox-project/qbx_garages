return {
    enableClient = true, -- disable to create your own client interface
    engineOn = true, -- If true, the engine will be on upon taking the vehicle out.
    debugPoly = false,

    --- called every frame when player is near the garage and there is a separate drop off marker
    ---@param coords vector3
    ---@param radius? number
    drawDropOffMarker = function(coords, radius)
        local size = (radius or 1.5) * 2
        local baseSize = 3.0
        local baseOffset = 2.9
        local zOffset = baseOffset
        local hasWater, waterZ = GetWaterHeight(coords.x, coords.y, coords.z)
        local hasNoWaves, waterZNoWaves = GetWaterHeightNoWaves(coords.x, coords.y, coords.z)
        if hasNoWaves and (not hasWater or waterZNoWaves > waterZ) then
            hasWater = true
            waterZ = waterZNoWaves
        end
        local waterSurfaceOffset = 1.0 -- to make sure marker is above water surface
        local drawZ = hasWater and (waterZ - baseSize + waterSurfaceOffset) or (coords.z - zOffset)
        DrawMarker(0, coords.x, coords.y, drawZ, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, size, size, baseSize, 242, 0, 48, 255, false, false, 0, false, nil, nil, false)
    end,

    --- called every frame when player is near the garage to draw the garage marker
    ---@param coords vector3
    ---@param radius? number
    drawGarageMarker = function(coords, radius)
        local size = (radius or 1.0) * 2
        local baseSize = 2.0
        local baseOffset = 2.3
        local zOffset = baseOffset
        DrawMarker(0, coords.x, coords.y, coords.z - zOffset, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, size, size, baseSize, 20, 246, 12, 255, false, false, 0, false, nil, nil, false)
    end,
}
