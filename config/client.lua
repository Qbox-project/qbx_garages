return {
    enableClient = true, -- disable to create your own client interface
    engineOn = true, -- If true, the engine will be on upon taking the vehicle out.
    debugPoly = false,

    --- called every frame when player is near the garage and there is a separate drop off marker
    ---@param coords vector3
    drawDropOffMarker = function(coords)
        DrawMarker(0, coords.x, coords.y, coords.z - 2.9, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 3.0, 3.0, 3.0, 242, 0, 48, 255, false, false, 0, false, nil, nil, false)
    end,

    --- called every frame when player is near the garage to draw the garage marker
    ---@param coords vector3
    drawGarageMarker = function(coords)
        DrawMarker(0, coords.x, coords.y, coords.z - 2.3, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 2.0, 2.0, 20, 246, 12, 255, false, false, 0, false, nil, nil, false)
    end,
}