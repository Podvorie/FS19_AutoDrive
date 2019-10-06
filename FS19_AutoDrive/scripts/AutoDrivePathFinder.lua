AutoDrive.MAX_PATHFINDER_STEPS_PER_FRAME = 20;
AutoDrive.MAX_PATHFINDER_STEPS_TOTAL = 400;
AutoDrive.PATHFINDER_FOLLOW_DISTANCE = 44;
AutoDrive.PATHFINDER_TARGET_DISTANCE = 14;
AutoDrive.PATHFINDER_START_DISTANCE = 4; --15;
AutoDrive.PP_UP = 0;
AutoDrive.PP_UP_RIGHT = 1;
AutoDrive.PP_RIGHT = 2;
AutoDrive.PP_DOWN_RIGHT = 3;
AutoDrive.PP_DOWN = 4;
AutoDrive.PP_DOWN_LEFT = 5;
AutoDrive.PP_LEFT = 6;
AutoDrive.PP_UP_LEFT = 7;

AutoDrive.PP_MIN_DISTANCE = 20;
AutoDrive.PP_CELL_X = 6;
AutoDrive.PP_CELL_Z = 6;
AutoDrivePathFinder = {};


function AutoDrivePathFinder:startPathPlanningToCombine(driver, combine, dischargeNode)       
    --print("startPathPlanningToCombine " .. driver.ad.driverName );
    local worldX,worldY,worldZ = getWorldTranslation( combine.components[1].node );
	local rx,ry,rz = localDirectionToWorld(combine.components[1].node, 0,0,1);	
    local combineVector = {x= rx ,z=rz};	
    local combineNormalVector = {x= -combineVector.z ,z= combineVector.x};	
    
    local wpAhead;
    local wpCurrent;
    local wpBehind_close;
    local wpBehind;

    if dischargeNode == nil then
        local followDistance = AutoDrive.PATHFINDER_FOLLOW_DISTANCE;
        local fillLevel, leftCapacity = getFilteredFillLevelAndCapacityOfAllUnits(combine);
        local maxCapacity = fillLevel + leftCapacity;
        local combineFillLevel = (fillLevel / maxCapacity);

        if combineFillLevel <= 0.80 or combine:getIsBufferCombine() then
            followDistance = 0;
        end;

        local leftBlocked = combine.ad.sensors.leftSensorFruit:pollInfo() or combine.ad.sensors.leftSensor:pollInfo();
        local rightBlocked = combine.ad.sensors.rightSensorFruit:pollInfo() or combine.ad.sensors.rightSensor:pollInfo();      

        local leftFrontBlocked = combine.ad.sensors.leftFrontSensorFruit:pollInfo();
        local rightFrontBlocked = combine.ad.sensors.rightFrontSensorFruit:pollInfo();

        if (not leftBlocked) and (not rightBlocked) then
            if (not leftFrontBlocked) and rightFrontBlocked then
                rightBlocked = true;
            elseif leftFrontBlocked and (not rightFrontBlocked) then
                leftBlocked = true;
            end;
        end;

        local pipeChasePos, _ = AutoDrive:getPipeChasePosition(driver, combine, combine:getIsBufferCombine(), leftBlocked, rightBlocked)
        wpAhead = {x= pipeChasePos.x, y = pipeChasePos.y, z = pipeChasePos.z};
        
        wpBehind = {x= pipeChasePos.x - 7 * rx, y = pipeChasePos.y, z = pipeChasePos.z - 7 * rz};
        driver.ad.waitForPreDriveTimer = 10000;
    else
        local nodeX,nodeY,nodeZ = getWorldTranslation(dischargeNode);       
        local pipeOffset = AutoDrive:getSetting("pipeOffset", driver);     
        local trailerOffset = AutoDrive:getSetting("trailerOffset", driver);
        wpAhead = {x= (nodeX + (driver.sizeLength/2 + 5 + trailerOffset)*rx) - pipeOffset * combineNormalVector.x, y = worldY, z = nodeZ + (driver.sizeLength/2 + 5 + trailerOffset)*rz  - pipeOffset * combineNormalVector.z};
        wpCurrent = {x= (nodeX - pipeOffset * combineNormalVector.x ), y = worldY, z = nodeZ - pipeOffset * combineNormalVector.z};
        wpBehind_close = {x= (nodeX - 10*rx - pipeOffset * combineNormalVector.x), y = worldY, z = nodeZ - 10*rz - pipeOffset * combineNormalVector.z };
        
        wpBehind = {x= (nodeX - AutoDrive.PATHFINDER_TARGET_DISTANCE*rx - pipeOffset * combineNormalVector.x), y = worldY, z = nodeZ - AutoDrive.PATHFINDER_TARGET_DISTANCE*rz - pipeOffset * combineNormalVector.z }; --make this target
    end;
    
    
    local driverWorldX,driverWorldY,driverWorldZ = getWorldTranslation( driver.components[1].node );
	local driverRx,driverRy,driverRz = localDirectionToWorld(driver.components[1].node, 0,0,1);	
    local driverVector = {x= math.sin(driverRx) ,z= math.sin(driverRz)};	
    
    local startDistance = AutoDrive.PATHFINDER_START_DISTANCE;
    if dischargeNode == nil then
        startDistance = 4;
    end;

	local startX = driverWorldX + startDistance*driverRx;
	local startZ = driverWorldZ + startDistance*driverRz;
	
    local atan = normalizeAngle(math.atan2(driverVector.z, driverVector.x));
	
	local sin = math.sin(atan);
	local cos = math.cos(atan);

    local minTurnRadius = (AIVehicleUtil.getAttachedImplementsMaxTurnRadius(driver) + 3) / 2;
    if minTurnRadius < 0 then --default for no implement == -1
        minTurnRadius = AutoDrive.PP_CELL_X;
    end;

	local vectorX = {};
	vectorX.x = cos * minTurnRadius; --AutoDrive.PP_CELL_X;
	vectorX.z = sin * minTurnRadius; --AutoDrive.PP_CELL_X;

	local vectorZ = {};
	vectorZ.x = -sin * minTurnRadius; --AutoDrive.PP_CELL_Z;
    vectorZ.z = cos * minTurnRadius; --AutoDrive.PP_CELL_Z;
    
    -- AutoDrivePathFinder:init(driver, startX, startZ, targetX, targetY, targetVector, vectorX, vectorZ)
    AutoDrivePathFinder:init(driver, startX, startZ, wpBehind.x, wpBehind.z, combineVector, vectorX, vectorZ, combine) 
    
    driver.ad.pf.minTurnRadius = minTurnRadius;
    driver.ad.pf.appendWayPoints = {};
    local appendCount = 1;
    if wpBehind_close ~= nil then
        driver.ad.pf.appendWayPoints[appendCount] = wpBehind_close;
        appendCount = appendCount + 1;
    end;
    if wpCurrent ~= nil then
        driver.ad.pf.appendWayPoints[appendCount] = wpCurrent;
        appendCount = appendCount + 1;
    end;
    if wpAhead ~= nil then
        driver.ad.pf.appendWayPoints[appendCount] = wpAhead;
    end;
    driver.ad.pf.appendWayPointCount = appendCount;	   
    
    driver.ad.pf.goingToCombine = true;

    if combine.spec_combine ~= nil then
        if combine.spec_combine.fillUnitIndex ~= nil and combine.spec_combine.fillUnitIndex ~= 0 then
            local fillType = g_fruitTypeManager:getFruitTypeIndexByFillTypeIndex(combine:getFillUnitFillType(combine.spec_combine.fillUnitIndex))
            if fillType ~= nil and (not combine:getIsBufferCombine()) then
                driver.ad.pf.fruitToCheck = fillType;
                driver.ad.combineFruitToCheck = driver.ad.pf.fruitToCheck;
                --print("Got fill type from combine: " .. driver.ad.pf.fruitToCheck .. ": " .. g_fillTypeManager:getFillTypeByIndex(combine:getFillUnitFillType(combine.spec_combine.fillUnitIndex)).title);
            end;
        end;
    end;    
    
    driver.ad.pf.quickCheckActive = false;
end;

function AutoDrivePathFinder:startPathPlanningToStartPosition(driver, combine, ignoreFruit)       
    --print("startPathPlanningToStartPosition " .. driver.ad.driverName );
    local driverWorldX,driverWorldY,driverWorldZ = getWorldTranslation( driver.components[1].node );
	local driverRx,driverRy,driverRz = localDirectionToWorld(driver.components[1].node, 0,0,1);	
	local driverVector = {x= math.sin(driverRx) ,z= math.sin(driverRz)};	
	local startX = driverWorldX + AutoDrive.PATHFINDER_START_DISTANCE*driverRx;
	local startZ = driverWorldZ + AutoDrive.PATHFINDER_START_DISTANCE*driverRz;
	
	local atan = normalizeAngle(math.atan2(driverVector.z, driverVector.x));
	
	local sin = math.sin(atan);
    local cos = math.cos(atan);
    
    local minTurnRadius =  (AIVehicleUtil.getAttachedImplementsMaxTurnRadius(driver) + 3) / 2;
    if minTurnRadius < 0 then --default for no implement == -1
        minTurnRadius = AutoDrive.PP_CELL_X;
    end;

	local vectorX = {};
	vectorX.x = cos * minTurnRadius;
	vectorX.z = sin * minTurnRadius;

	local vectorZ = {};
	vectorZ.x = -sin * minTurnRadius;
    vectorZ.z = cos * minTurnRadius;

    local targetPoint = AutoDrive.mapWayPoints[AutoDrive.mapMarker[driver.ad.mapMarkerSelected].id]
	local preTargetPoint = AutoDrive.mapWayPoints[targetPoint.incoming[1]];
	local targetVector = {};
    local waypointsToUnload = AutoDrive:FastShortestPath(AutoDrive.mapWayPoints, AutoDrive.mapMarker[driver.ad.mapMarkerSelected].id, AutoDrive.mapMarker[driver.ad.mapMarkerSelected_Unload].name, AutoDrive.mapMarker[driver.ad.mapMarkerSelected_Unload].id);
    if waypointsToUnload ~= nil and waypointsToUnload[6] ~= nil then
        preTargetPoint = AutoDrive.mapWayPoints[waypointsToUnload[1].id];
        targetPoint = AutoDrive.mapWayPoints[waypointsToUnload[2].id];
    end;    

    local exitStrategy =  AutoDrive:getSetting("exitField");
    if exitStrategy == 1 and driver.ad.combineState ~= AutoDrive.DRIVE_TO_PARK_POS then
        if waypointsToUnload ~= nil and waypointsToUnload[6] ~= nil then
            preTargetPoint = AutoDrive.mapWayPoints[waypointsToUnload[5].id];
            targetPoint = AutoDrive.mapWayPoints[waypointsToUnload[6].id];
        end;
    elseif exitStrategy == 2 and driver.ad.combineState ~= AutoDrive.DRIVE_TO_PARK_POS  then
        local closest = AutoDrive:findClosestWayPoint(driver);
        local waypointsToUnload = AutoDrive:FastShortestPath(AutoDrive.mapWayPoints, closest, AutoDrive.mapMarker[driver.ad.mapMarkerSelected_Unload].name, AutoDrive.mapMarker[driver.ad.mapMarkerSelected_Unload].id);
        if waypointsToUnload ~= nil and waypointsToUnload[2] ~= nil then
            preTargetPoint = AutoDrive.mapWayPoints[waypointsToUnload[1].id];
            targetPoint = AutoDrive.mapWayPoints[waypointsToUnload[2].id];
        end;
    end;
    
	targetVector.x = preTargetPoint.x - targetPoint.x
	targetVector.z = preTargetPoint.z - targetPoint.z

	local angleRad = math.atan2(targetVector.z, targetVector.x);

	angleRad = normalizeAngle(angleRad);

	local targetX = preTargetPoint.x + math.cos(angleRad) * AutoDrive.PATHFINDER_TARGET_DISTANCE; --Make the target a few meters ahead of the road to the start point
	local targetZ = preTargetPoint.z + math.sin(angleRad) * AutoDrive.PATHFINDER_TARGET_DISTANCE;
    
    targetVector.x = -targetVector.x;
	targetVector.z = -targetVector.z;

    -- AutoDrivePathFinder:init(driver, startX, startZ, targetX, targetY, targetVector, vectorX, vectorZ)
    AutoDrivePathFinder:init(driver, startX, startZ, targetX, targetZ, targetVector, vectorX, vectorZ, combine) 
    
    driver.ad.pf.minTurnRadius = minTurnRadius;
	driver.ad.pf.appendWayPoints = {};
	driver.ad.pf.appendWayPoints[1] = preTargetPoint;
    driver.ad.pf.appendWayPoints[2] = targetPoint;
    driver.ad.pf.appendWayPointCount = 2;

    if driver.ad.mode ~= AutoDrive.MODE_UNLOAD then --add waypoints to actual target
        local nextPoints = {};
        if driver.ad.skipStart == true then
            driver.ad.skipStart = false;
            if AutoDrive.mapMarker[driver.ad.mapMarkerSelected_Unload] == nil then
                return;
            end;
            nextPoints = AutoDrive:FastShortestPath(AutoDrive.mapWayPoints, targetPoint.id, AutoDrive.mapMarker[driver.ad.mapMarkerSelected_Unload].name, AutoDrive.mapMarker[driver.ad.mapMarkerSelected_Unload].id);
        else
            if AutoDrive.mapMarker[driver.ad.mapMarkerSelected] == nil then
                return;
            end;
            nextPoints = AutoDrive:FastShortestPath(AutoDrive.mapWayPoints, targetPoint.id, AutoDrive.mapMarker[driver.ad.mapMarkerSelected].name, driver.ad.targetSelected);
        end;

        local i = 2;
        for _,point in pairs(nextPoints) do
            driver.ad.pf.appendWayPoints[i] = point;
            driver.ad.pf.appendWayPointCount = i;
            i = i+1;
        end;
    end;

    driver.ad.pf.goingToCombine = false;
    driver.ad.pf.ignoreFruit = ignoreFruit;
end;

function AutoDrivePathFinder:init(driver, startX, startZ, targetX, targetZ, targetVector, vectorX, vectorZ, combine)    
    startCell = {x=0, z=0};
    startCell.direction = AutoDrive.PP_UP;
    startCell.visited = false;
    startCell.isRestricted = false;
    startCell.hasCollision = false;
    startCell.hasInfo = true;
    startCell.hasFruit = false;
    startCell.steps = 0;

    driver.ad.pf = {};
    driver.ad.pf.driver = driver;    
	--driver.ad.combineUnloadInFruit = false;
	driver.ad.combineUnloadInFruitWaitTimer = AutoDrive.UNLOAD_WAIT_TIMER;
    driver.ad.pf.grid = {};
    driver.ad.pf.startX = startX;
    driver.ad.pf.startZ = startZ;
    driver.ad.pf.vectorX = vectorX;
    driver.ad.pf.vectorZ = vectorZ;
    driver.ad.pf.targetVector = targetVector;
    driver.ad.pf.startCell = startCell;
    driver.ad.pf.steps = 0;
    driver.ad.pf.isFinished = false;
    driver.ad.pf.fallBackMode = false;
    driver.ad.pf.combine = combine;
    driver.ad.pf.fruitToCheck = driver.ad.combineFruitToCheck;
    if (driver.ad.combineFruitToCheck == nil) and (driver.ad.pf.combine ~= nil) then
        driver.ad.pf.fruitToCheck = nil;
    end;
    
    driver.ad.currentTrailer = 1;
    driver.ad.designatedTrailerFillLevel = math.huge;
    
    driver.ad.pf.targetCell = AutoDrivePathFinder:worldLocationToGridLocation(driver.ad.pf, targetX, targetZ);
    local targetDirection = AutoDrivePathFinder:worldDirectionToGridDirection(driver.ad.pf, targetVector)
    AutoDrivePathFinder:determineBlockedCells(driver.ad.pf, targetDirection, driver.ad.pf.targetCell);

    table.insert(driver.ad.pf.grid, startCell);
    driver.ad.pf.smoothStep = 0;
    driver.ad.pf.smoothDone = false;
    driver.ad.pf.target = {x=targetX, z=targetZ};
end;

function AutoDrivePathFinder:quickCheck(driver, target, targetVector, combine)
    local driverX, driverY, driverZ = getWorldTranslation( driver.components[1].node );
    local distance = MathUtil.vector2Length(driverX - target.x, driverZ - target.z);

    if distance > 100 then
        return;
    end;

    local driverRx,driverRy,driverRz = localDirectionToWorld(driver.components[1].node, 0,0,1);	

    local worldX,worldY,worldZ = getWorldTranslation( combine.components[1].node );
	local rx,ry,rz = localDirectionToWorld(combine.components[1].node, 0,0,1);	
    local combineVector = {x= rx ,z=rz};	
    
    local minTurnRadius =  (AIVehicleUtil.getAttachedImplementsMaxTurnRadius(driver) + 3) / 2;
    if minTurnRadius < 0 then --default for no implement == -1
        minTurnRadius = AutoDrive.PP_CELL_X;
    end;
    local widthOfColBox = math.sqrt(math.pow(minTurnRadius, 2) + math.pow(minTurnRadius, 2));
    local sideLength = widthOfColBox/4;


    local vectorX = target.x - driverX;
    local vectorZ = target.z - driverZ;
    local angleRad = math.atan2(-vectorZ, vectorX);
    angleRad = normalizeAngle(angleRad);

    local driverFrontOffset = driver.sizeLength/2 + 2;
    local combineRearOffset = -combine.sizeLength/2 - 2;

    local offsetPointDriver = {x = driverX + driverRx * driverFrontOffset, z=driverZ + driverRz * driverFrontOffset }
    local offsetPointCombine = {x = worldX + targetVector.x * combineRearOffset, z=worldZ + targetVector.z * combineRearOffset }
    local offsetPointCombinePreTarget = {x = target.x - targetVector.x * 6, z=target.z - targetVector.z * 6}
    
    --check angle to target
    local angleTarget = math.atan2(-targetVector.z, targetVector.x);
    local angleBetween = AutoDriveBGA:getAngleBetweenTwoRadValues(angleRad, angleTarget);
    --print("Found angle between driver and target vector: " .. angleBetween);
    --required distance = minRadius * math.pi
    if distance < (minTurnRadius * (angleBetween/math.pi)) then
        --print("quick check angle is too steep");
        return;
    end;

    vectorX = offsetPointCombine.x - offsetPointDriver.x;
    vectorZ = offsetPointCombine.z - offsetPointDriver.z;

    angleRad = math.atan2(-vectorZ, vectorX);
    angleRad = normalizeAngle(angleRad);

    local length = math.sqrt(math.pow(vectorX, 2) + math.pow(vectorZ, 2)); -- + widthOfColBox;
    
    local leftAngle = normalizeAngle(angleRad + math.rad(-90));
    local rightAngle = normalizeAngle(angleRad + math.rad(90));

    local cornerX = offsetPointDriver.x - math.cos(leftAngle) * sideLength;
    local cornerZ = offsetPointDriver.z + math.sin(leftAngle) * sideLength;

    local corner2X = offsetPointCombine.x - math.cos(leftAngle) * sideLength;
    local corner2Z = offsetPointCombine.z + math.sin(leftAngle) * sideLength;
    
    local corner3X = offsetPointCombine.x - math.cos(rightAngle) * sideLength;
    local corner3Z = offsetPointCombine.z + math.sin(rightAngle) * sideLength;

    local corner4X = offsetPointDriver.x - math.cos(rightAngle) * sideLength;
    local corner4Z = offsetPointDriver.z + math.sin(rightAngle) * sideLength;

    local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, offsetPointDriver.x + vectorX/2, 1, offsetPointDriver.z + vectorZ/2);

    local shapes = overlapBox(offsetPointDriver.x + vectorX/2,y+3,offsetPointDriver.z + vectorZ/2, 0,angleRad,0, length/2,2.85,widthOfColBox/2, "collisionTestCallbackIgnore", nil, AIVehicleUtil.COLLISION_MASK, true, true, true)
    local red = 0;    
    if (shapes > 0) then
        --print("quickCheck coll test triggered collision!");
        red = 1;
    end;
    --DebugUtil.drawOverlapBox(offsetPointDriver.x + vectorX/2,y+3,offsetPointDriver.z + vectorZ/2, 0,angleRad,0, length/2,2.85,widthOfColBox/2, red, 0, 0);
    
    --local point1 = { x=cornerX, y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, cornerX, 1, cornerZ), z=cornerZ };
    --local point2 = { x=corner2X, y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, corner2X, 1, corner2Z), z=corner2Z };
    --local point3 = { x=corner3X, y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, corner3X, 1, corner3Z), z=corner3Z };
    --local point4 = { x=corner4X, y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, corner4X, 1, corner4Z), z=corner4Z };

    --AutoDrive:drawLine(point1, point2, red, 1, 1, 1);
    --AutoDrive:drawLine(point2, point3, red, 1, 1, 1);
    --AutoDrive:drawLine(point3, point4, red, 1, 1, 1);
    --AutoDrive:drawLine(point4, point1, red, 1, 1, 1);
    --local driverHead = { x=offsetPointDriver.x, y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, offsetPointDriver.x, 1, offsetPointDriver.z), z=offsetPointDriver.z };
    --local combineRear = { x=offsetPointCombine.x, y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, offsetPointCombine.x, 1, offsetPointCombine.z), z=offsetPointCombine.z };
    --local combinePreTarget = { x=offsetPointCombinePreTarget.x, y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, offsetPointCombinePreTarget.x, 1, offsetPointCombinePreTarget.z), z=offsetPointCombinePreTarget.z };

    --AutoDrive:drawLine(driverHead, combineRear, red, 1, 0, 1);
    --AutoDrive:drawLine(driverHead, combinePreTarget, red, 1, 0, 1);

    local pf = driver.ad.pf;

    local foundFruit = false;
    -- if (pf.ignoreFruit == nil or pf.ignoreFruit == false) and AutoDrive:getSetting("avoidFruit", pf.driver) then
    --     if pf.fruitToCheck == nil then
    --         for i = 1, #g_fruitTypeManager.fruitTypes do
    --             if i ~= g_fruitTypeManager.nameToIndex['GRASS'] and i ~= g_fruitTypeManager.nameToIndex['DRYGRASS'] then 
    --                 local fruitType = g_fruitTypeManager.fruitTypes[i].index;      

    --                 local fruitValue = 0;
    --                 if fruitType == 9 or fruitType == 22 then
    --                     fruitValue, _, _, _ = FSDensityMapUtil.getFruitArea(fruitType, cornerX, cornerZ, corner2X, corner2Z, corner3X, corner3Z, true, true);
    --                 else
    --                     fruitValue , _, _, _ = FSDensityMapUtil.getFruitArea(fruitType, cornerX, cornerZ, corner2X, corner2Z, corner3X, corner3Z, nil, false);
    --                 end;
                    
    --                 if (fruitValue > 50) then
    --                     foundFruit = true;
    --                 end;
    --             end;
    --         end;
    --     else
    --         local fruitValue = 0;
    --         if fruitType == 9 or fruitType == 22 then
    --             fruitValue, _, _, _ = FSDensityMapUtil.getFruitArea(pf.fruitToCheck, cornerX, cornerZ, corner2X, corner2Z, corner3X, corner3Z, true, true);
    --         else
    --             fruitValue , _, _, _ = FSDensityMapUtil.getFruitArea(pf.fruitToCheck, cornerX, cornerZ, corner2X, corner2Z, corner3X, corner3Z, nil, false);
    --         end;
            
    --         if (fruitValue > 50) then
    --             foundFruit = true;
    --         end;
    --     end;  
    -- end;

    --if foundFruit then
       --print("Quick check found fruit");
    --end;

    local foundVehicleColl = false;
    local boundingBox = {};
    boundingBox[1] ={ 	x = cornerX,
                        y = 0,
                        z = cornerZ; };
    boundingBox[2] ={ 	x = corner2X,
                        y = 0,
                        z = corner2Z; };
    boundingBox[3] ={ 	x = corner4X,
                        y = 0,
                        z = corner4Z; };
    boundingBox[4] ={ 	x = corner3X,
                        y = 0,
                        z = corner3Z; };
    
    for _,other in pairs(g_currentMission.vehicles) do
        if other ~= pf.driver and not AutoDrive:checkIsConnected(pf.driver, other) then -- and other ~= combine and not AutoDrive:checkIsConnected(combine, other) --try this with every vehicle from now on --and (other == pf.driver.ad.currentCombine or AutoDrive:checkIsConnected(pf.driver.ad.currentCombine, other))
            if other.components ~= nil and other.sizeWidth ~= nil and other.sizeLength ~= nil and other.rootNode ~= nil then     
                local otherWidth = other.sizeWidth;
                local otherLength = other.sizeLength;
                local otherPos = {};
                otherPos.x,otherPos.y,otherPos.z = getWorldTranslation( other.components[1].node ); 

                local rx,ry,rz = localDirectionToWorld(other.components[1].node, 0, 0, 1);

                local otherVectorToWp = {};
                otherVectorToWp.x = rx;
                otherVectorToWp.z = rz;

                local otherPos2 = {};
                otherPos2.x = otherPos.x + (otherLength/2) * (otherVectorToWp.x/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z)));
                otherPos2.y = 0;
                otherPos2.z = otherPos.z + (otherLength/2) * (otherVectorToWp.z/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z)));
                local otherOrtho = { x=-otherVectorToWp.z, z=otherVectorToWp.x };

                local otherBoundingBox = {};
                otherBoundingBox[1] ={ 	x = otherPos.x + (otherWidth/2) * ( otherOrtho.x / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) + (otherLength/2) * (otherVectorToWp.x/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z))),
                                        y = 0,
                                        z = otherPos.z + (otherWidth/2) * ( otherOrtho.z / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) + (otherLength/2) * (otherVectorToWp.z/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z)))};

                otherBoundingBox[2] ={ 	x = otherPos.x - (otherWidth/2) * ( otherOrtho.x / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) + (otherLength/2) * (otherVectorToWp.x/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z))),
                                        y = 0,
                                        z = otherPos.z - (otherWidth/2) * ( otherOrtho.z / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) + (otherLength/2) * (otherVectorToWp.z/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z)))};
                otherBoundingBox[3] ={ 	x = otherPos.x - (otherWidth/2) * ( otherOrtho.x / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) - (otherLength/2) * (otherVectorToWp.x/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z))),
                                        y = 0,
                                        z = otherPos.z - (otherWidth/2) * ( otherOrtho.z / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) - (otherLength/2) * (otherVectorToWp.z/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z)))};

                otherBoundingBox[4] ={ 	x = otherPos.x + (otherWidth/2) * ( otherOrtho.x / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) - (otherLength/2) * (otherVectorToWp.x/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z))),
                                        y = 0,
                                        z = otherPos.z + (otherWidth/2) * ( otherOrtho.z / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) - (otherLength/2) * (otherVectorToWp.z/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z)))};
                
                if AutoDrive:BoxesIntersect(boundingBox, otherBoundingBox) == true then
                    foundVehicleColl = true;
                end;
            end;
        end;
    end;         

    --if foundVehicleColl then
        --print("Quick check found vehicle coll");
    --end;

    --print("Quick check distance: " .. distance);
    if (shapes <= 0 and (not foundFruit) and (not foundVehicleColl)) then
        --print("Quick check would release direct course");
        pf.wayPoints = {};
        pf.wayPoints[1] = {x=driverX, y=driverY, z=driverZ};        
        pf.wayPoints[2] = {x=offsetPointCombinePreTarget.x, y=getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, offsetPointCombinePreTarget.x, 1, offsetPointCombinePreTarget.z), z=offsetPointCombinePreTarget.z};
        pf.wayPoints[3] = {x=target.x, y=getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, target.x, 1, target.z), z=target.z};
        
        if pf.appendWayPointCount ~= nil and (pf.driver.ad.combineState ~= AutoDrive.PREDRIVE_COMBINE) then
            for i=1, pf.appendWayPointCount, 1 do
                pf.wayPoints[ADTableLength(pf.wayPoints)+1] = pf.appendWayPoints[i];
            end;
        end;

        for i, waypoint in pairs(pf.wayPoints) do
            if i>1 then
                AutoDrive:drawLine(waypoint, pf.wayPoints[i-1], 0, 1, 1, 1);
            end;
        end;

        pf.isFinished = true;
        pf.smoothDone = true;
    end;
end;

function AutoDrivePathFinder:updatePathPlanning(driver)    
    local pf = driver.ad.pf;
    --if driver.ad.createMapPoints then
      --AutoDrivePathFinder:drawDebugForPF(pf);
    --end;
    pf.steps = pf.steps + 1;

    if pf.isFinished and pf.smoothDone == true then
        return;
    end;

    if pf.isFinished and pf.smoothDone == false then
        AutoDrivePathFinder:createWayPoints(pf);
        return;
    end;

    if pf.quickCheckActive then
        AutoDrivePathFinder:quickCheck(driver, pf.target, pf.targetVector, pf.combine);
        pf.quickCheckActive = false;
        return;
    end;
        

    if pf.steps > (AutoDrive.MAX_PATHFINDER_STEPS_TOTAL * AutoDrive:getSetting("pathFinderTime")) then
        if not pf.fallBackMode then --look for path through fruit
            pf.fallBackMode = true;
            pf.steps = 0;
            pf.grid = {};
            pf.startCell.visited = false;
            pf.currentCell = nil;
            table.insert(pf.grid, pf.startCell)
            local targetDirection = AutoDrivePathFinder:worldDirectionToGridDirection(pf, pf.targetVector)
            AutoDrivePathFinder:determineBlockedCells(pf, targetDirection, pf.targetCell); 
            pf.smoothStep = 0;
            smoothDone = false;
            print("Going into fallback mode - no fruit free path found in reasonable time");
        else
            --stop searching
            pf.isFinished = true;
            pf.smoothDone = true;
            pf.wayPoints = {};
            print("Stop searching - no path found in reasonable time");
        end;
    end;    

    for i=1,AutoDrive.MAX_PATHFINDER_STEPS_PER_FRAME,1 do
        if pf.currentCell == nil then            
            local minDistance = math.huge;
            local bestCell = nil;
            local bestSteps = math.huge;

            local bestCellRatio = nil;
            local minRatio = 0;

            local grid = pf.grid; 
            for _,cell in pairs(grid) do
                if not cell.visited and ((not cell.isRestricted) or pf.fallBackMode) and (not cell.hasCollision) and cell.hasInfo == true then
                    local distance = cellDistance(pf, cell);
                    local originalDistance = cellDistance(pf, pf.startCell);
                    local ratio = (originalDistance - distance) / cell.steps;

                    if distance < minDistance then
                        minDistance = distance;
                        bestCell = cell;
                        bestSteps = cell.steps;
                    elseif distance == minDistance and cell.steps < bestSteps then
                        minDistance = distance;
                        bestCell = cell;
                        bestSteps = cell.steps;
                    end;

                    if ratio > minRatio then
                        minRatio = ratio;
                        bestCellRatio = cell;
                    end;
                end;
            end;
        
            if bestCellRatio ~= nil and math.random() > 1 then --0.4 then
                pf.currentCell = bestCellRatio;     
            else
                pf.currentCell = bestCell;
            end;         

            if pf.currentCell ~= nil and cellDistance(pf, pf.currentCell) == 0 then
                pf.isFinished = true;
                pf.targetCell.incoming = pf.currentCell.incoming;
                if pf.currentCell.hasFruit ~= nil then
                    pf.driver.ad.combineUnloadInFruit = pf.currentCell.hasFruit;                        
                end;
                AutoDrivePathFinder:createWayPoints(pf);
            end;

            if pf.currentCell == nil then
                pf.grid = {};
                pf.startCell.visited = false;
                table.insert(pf.grid, pf.startCell)
                local targetDirection = AutoDrivePathFinder:worldDirectionToGridDirection(pf, pf.targetVector)
                AutoDrivePathFinder:determineBlockedCells(pf, targetDirection, pf.targetCell);
            end;
        else
            if pf.currentCell.out == nil then
                AutoDrivePathFinder:determineNextGridCells(pf, pf.currentCell);
            end;
            AutoDrivePathFinder:testNextCells(pf, pf.currentCell);
        end;
    end;
    driver.ad.pf = pf;
end;

function AutoDrivePathFinder:isPathPlanningFinished(driver)
	if driver.ad.pf ~= nil then
        if driver.ad.pf.isFinished == true and driver.ad.pf.smoothDone == true then
            --if driver.ad.createMapPoints then
                --drawDebugForCreatedRoute(driver.ad.pf);
            --else
                return true;
            --end;
		end;
	end;
	return false;
end;

function AutoDrivePathFinder:determineNextGridCells(pf, cell)
	cell.out = {};
	if cell.direction == AutoDrive.PP_UP then
		cell.out[1] = {x=cell.x + 1, z=cell.z - 1};
		cell.out[1].direction = AutoDrive.PP_UP_LEFT;
		cell.out[2] = {x=cell.x + 1, z=cell.z + 0};
		cell.out[2].direction = AutoDrive.PP_UP;
		cell.out[3] = {x=cell.x + 1, z=cell.z + 1};
		cell.out[3].direction = AutoDrive.PP_UP_RIGHT;
	elseif cell.direction == AutoDrive.PP_UP_RIGHT then
		cell.out[1] = {x=cell.x + 1, z=cell.z + 0};
		cell.out[1].direction = AutoDrive.PP_UP;
		cell.out[2] = {x=cell.x + 1, z=cell.z + 1};
		cell.out[2].direction = AutoDrive.PP_UP_RIGHT;
		cell.out[3] = {x=cell.x + 0, z=cell.z + 1};
		cell.out[3].direction = AutoDrive.PP_RIGHT;
	elseif cell.direction == AutoDrive.PP_RIGHT then
		cell.out[1] = {x=cell.x + 1, z=cell.z + 1};
		cell.out[1].direction = AutoDrive.PP_UP_RIGHT;
		cell.out[2] = {x=cell.x + 0, z=cell.z + 1};
		cell.out[2].direction = AutoDrive.PP_RIGHT;
		cell.out[3] = {x=cell.x - 1, z=cell.z + 1};
		cell.out[3].direction = AutoDrive.PP_DOWN_RIGHT;
	elseif cell.direction == AutoDrive.PP_DOWN_RIGHT then
		cell.out[1] = {x=cell.x + 0, z=cell.z + 1};
		cell.out[1].direction = AutoDrive.PP_RIGHT;
		cell.out[2] = {x=cell.x - 1, z=cell.z + 1};
		cell.out[2].direction = AutoDrive.PP_DOWN_RIGHT;
		cell.out[3] = {x=cell.x - 1, z=cell.z + 0};
		cell.out[3].direction = AutoDrive.PP_DOWN;
	elseif cell.direction == AutoDrive.PP_DOWN then
		cell.out[1] = {x=cell.x - 1, z=cell.z + 1};
		cell.out[1].direction = AutoDrive.PP_DOWN_RIGHT;
		cell.out[2] = {x=cell.x - 1, z=cell.z + 0};
		cell.out[2].direction = AutoDrive.PP_DOWN;
		cell.out[3] = {x=cell.x - 1, z=cell.z - 1};
		cell.out[3].direction = AutoDrive.PP_DOWN_LEFT;
	elseif cell.direction == AutoDrive.PP_DOWN_LEFT then
		cell.out[1] = {x=cell.x - 1, z=cell.z - 0};
		cell.out[1].direction = AutoDrive.PP_DOWN;
		cell.out[2] = {x=cell.x - 1, z=cell.z - 1};
		cell.out[2].direction = AutoDrive.PP_DOWN_LEFT;
		cell.out[3] = {x=cell.x - 0, z=cell.z - 1};
		cell.out[3].direction = AutoDrive.PP_LEFT;
	elseif cell.direction == AutoDrive.PP_LEFT then
		cell.out[1] = {x=cell.x - 1, z=cell.z - 1};
		cell.out[1].direction = AutoDrive.PP_DOWN_LEFT;
		cell.out[2] = {x=cell.x - 0, z=cell.z - 1};
		cell.out[2].direction = AutoDrive.PP_LEFT;
		cell.out[3] = {x=cell.x + 1, z=cell.z - 1};
		cell.out[3].direction = AutoDrive.PP_UP_LEFT;
	elseif cell.direction == AutoDrive.PP_UP_LEFT then
		cell.out[1] = {x=cell.x - 0, z=cell.z - 1};
		cell.out[1].direction = AutoDrive.PP_LEFT;
		cell.out[2] = {x=cell.x + 1, z=cell.z - 1};
		cell.out[2].direction = AutoDrive.PP_UP_LEFT;
		cell.out[3] = {x=cell.x + 1, z=cell.z + 0};
		cell.out[3].direction = AutoDrive.PP_UP;
    end;	

    for _, outGoing in pairs(cell.out) do
        outGoing.incoming = cell;
        outGoing.steps = cell.steps + 1;
    end;
end;

function AutoDrivePathFinder:testNextCells(pf, cell)
    local allResultsIn = true;
    for _,location in pairs(cell.out) do
        local createPoint = true;
        local grid = pf.grid;
        for _, c in pairs(grid) do
            if c.x == location.x and c.z == location.z and c.direction == location.direction then
                createPoint = false;
                if c.steps > (cell.steps + 1) then --found shortcut
                    c.incoming = cell;
                    c.steps = cell.steps + 1;
                end;
                location.hasInfo = c.hasInfo;
                location.isRestricted = c.isRestricted;
                location.hasFruit = c.hasFruit;
                location.hasCollision = c.hasCollision;
            end;

            if c.x == location.x and c.z == location.z and c.direction == -1 then
                location.isRestricted = true;
                location.hasInfo = true;
                location.hasFruit = true;
                location.hasCollision = true;
                createPoint = false;
            end;
        end;

		if createPoint then			
            AutoDrivePathFinder:createGridCells(pf, location);
        end;

        if not location.hasInfo then
            AutoDrivePathFinder:checkGridCell(pf, location)
        end;

        allResultsIn = allResultsIn and location.hasInfo;
    end;

    if allResultsIn then
        --print("All result are in for: " .. cell.x .. "/" .. cell.z);
        cell.visited = true;
        pf.currentCell = nil;
    end;
end;

function AutoDrivePathFinder:createGridCells(pf, location)	
    location.visited=false;
    location.isRestricted=false;
    location.hasInfo=false;
    location.hasCollision = false;
    location.hasFruit = true;
    table.insert(pf.grid, location);
end;

function AutoDrivePathFinder:checkGridCell(pf, cell)
    if cell.hasInfo == false then       
        if cell.x == pf.targetCell.x and cell.z == pf.targetCell.z then
            cell.isRestricted = false;
            cell.hasCollision = false;
            cell.hasFruit = false;
            cell.hasInfo = true;
            return;
        end;

        local worldPos = AutoDrivePathFinder:gridLocationToWorldLocation(pf, cell);

        local cornerX = worldPos.x + (-pf.vectorX.x - pf.vectorZ.x)/2
        local cornerZ = worldPos.z + (-pf.vectorX.z - pf.vectorZ.z)/2

        local corner2X = worldPos.x + (pf.vectorX.x - pf.vectorZ.x)/2
        local corner2Z = worldPos.z + (pf.vectorX.z - pf.vectorZ.z)/2

        local corner3X = worldPos.x + (-pf.vectorX.x + pf.vectorZ.x)/2
        local corner3Z = worldPos.z + (-pf.vectorX.z + pf.vectorZ.z)/2

        local corner4X = worldPos.x + (pf.vectorX.x + pf.vectorZ.x)/2
        local corner4Z = worldPos.z + (pf.vectorX.z + pf.vectorZ.z)/2

        local shapeDefinition = getShapeDefByDirectionType(pf, cell);

        local angleRad = math.atan2(pf.targetVector.z, pf.targetVector.x);
        angleRad = normalizeAngle(angleRad);
        local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, worldPos.x, 1, worldPos.z)
        local shapes = overlapBox(shapeDefinition.x,shapeDefinition.y+3,shapeDefinition.z, 0,shapeDefinition.angleRad,0, shapeDefinition.widthX,shapeDefinition.height,shapeDefinition.widthZ, "collisionTestCallbackIgnore", nil, AIVehicleUtil.COLLISION_MASK, true, true, true)
        
        cell.hasCollision = (shapes > 0);

        local previousCell = cell.incoming
        local worldPosPrevious = AutoDrivePathFinder:gridLocationToWorldLocation(pf, previousCell);
        local vectorFromPrevious = {x=worldPos.x-worldPosPrevious.x, z=worldPos.z-worldPosPrevious.z}
        local worldPosMiddle = {x=worldPosPrevious.x + vectorFromPrevious.x/2, z=worldPosPrevious.z + vectorFromPrevious.z/2}
        
        local terrain1 = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, worldPos.x, 0, worldPos.z)
        local terrain2 = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, worldPosPrevious.x, 0, worldPosPrevious.z)
        local terrain3 = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, worldPosMiddle.x, 0, worldPosMiddle.z)
        local length = MathUtil.vector3Length(worldPos.x-worldPosPrevious.x, terrain1-terrain2, worldPos.z-worldPosPrevious.z)
        local lengthMiddle = MathUtil.vector3Length(worldPosMiddle.x-worldPosPrevious.x, terrain3-terrain2, worldPosMiddle.z-worldPosPrevious.z)
        local angleBetween = math.atan(math.abs(terrain1-terrain2)/length)
        local angleBetweenCenter = math.atan(math.abs(terrain3-terrain2)/lengthMiddle)

        if (angleBetween * 3) > AITurnStrategy.SLOPE_DETECTION_THRESHOLD or (angleBetweenCenter * 3) > AITurnStrategy.SLOPE_DETECTION_THRESHOLD then
            cell.hasCollision = true;
        end  

        --allow collision in the first few grid. as it also detects the driver and trailer itself
        --if ((math.abs(cell.x) <= 2) and (math.abs(cell.z) <= 2)) or cellDistance(pf, cell) <= 2 then --also allow collision at the end if other drivers are waiting in line
            --cell.hasCollision = false;
        --end;

        if (pf.ignoreFruit == nil or pf.ignoreFruit == false) and AutoDrive:getSetting("avoidFruit", pf.driver) then
            if pf.fruitToCheck == nil then
                for i = 1, #g_fruitTypeManager.fruitTypes do
                    if i ~= g_fruitTypeManager.nameToIndex['GRASS'] and i ~= g_fruitTypeManager.nameToIndex['DRYGRASS'] then 
                        local fruitType = g_fruitTypeManager.fruitTypes[i].index;                            
                        if cell.isRestricted == false and pf.fruitToCheck == nil then --stop if cell is already restricted and/or fruit type is now known
                            checkForFruitTypeInArea(pf, cell, fruitType, cornerX, cornerZ, corner2X, corner2Z, corner3X, corner3Z);
                        end;
                    end;
                end;
            else
                checkForFruitTypeInArea(pf, cell, pf.fruitToCheck, cornerX, cornerZ, corner2X, corner2Z, corner3X, corner3Z);
            end;                
        else
            cell.isRestricted = false;
            cell.hasFruit = not AutoDrive:getSetting("avoidFruit", pf.driver); --make sure that on fallback mode or when fruit avoidance is off, we don't park in the fruit next to the combine!
        end;
        
        cell.hasInfo = true;
        --if pf.driver.ad.currentCombine == nil then
            --return;
        --end;

        local boundingBox = {};
        boundingBox[1] ={ 	x = cornerX,
                            y = 0,
                            z = cornerZ; };
        boundingBox[2] ={ 	x = corner2X,
                            y = 0,
                            z = corner2Z; };
        boundingBox[3] ={ 	x = corner4X,
                            y = 0,
                            z = corner4Z; };
        boundingBox[4] ={ 	x = corner3X,
                            y = 0,
                            z = corner3Z; };
        
        for _,other in pairs(g_currentMission.vehicles) do
            if other ~= pf.driver and not AutoDrive:checkIsConnected(pf.driver, other) then --try this with every vehicle from now on --and (other == pf.driver.ad.currentCombine or AutoDrive:checkIsConnected(pf.driver.ad.currentCombine, other))
                if other.components ~= nil and other.sizeWidth ~= nil and other.sizeLength ~= nil and other.rootNode ~= nil then     
                    local otherWidth = other.sizeWidth;
                    local otherLength = other.sizeLength;
                    local otherPos = {};
                    otherPos.x,otherPos.y,otherPos.z = getWorldTranslation( other.components[1].node ); 

                    local rx,ry,rz = localDirectionToWorld(other.components[1].node, 0, 0, 1);

                    local otherVectorToWp = {};
                    otherVectorToWp.x = rx;
                    otherVectorToWp.z = rz;

                    local otherPos2 = {};
                    otherPos2.x = otherPos.x + (otherLength/2) * (otherVectorToWp.x/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z)));
                    otherPos2.y = 0;
                    otherPos2.z = otherPos.z + (otherLength/2) * (otherVectorToWp.z/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z)));
                    local otherOrtho = { x=-otherVectorToWp.z, z=otherVectorToWp.x };

                    local otherBoundingBox = {};
                    otherBoundingBox[1] ={ 	x = otherPos.x + (otherWidth/2) * ( otherOrtho.x / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) + (otherLength/2) * (otherVectorToWp.x/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z))),
                                            y = 0,
                                            z = otherPos.z + (otherWidth/2) * ( otherOrtho.z / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) + (otherLength/2) * (otherVectorToWp.z/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z)))};

                    otherBoundingBox[2] ={ 	x = otherPos.x - (otherWidth/2) * ( otherOrtho.x / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) + (otherLength/2) * (otherVectorToWp.x/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z))),
                                            y = 0,
                                            z = otherPos.z - (otherWidth/2) * ( otherOrtho.z / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) + (otherLength/2) * (otherVectorToWp.z/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z)))};
                    otherBoundingBox[3] ={ 	x = otherPos.x - (otherWidth/2) * ( otherOrtho.x / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) - (otherLength/2) * (otherVectorToWp.x/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z))),
                                            y = 0,
                                            z = otherPos.z - (otherWidth/2) * ( otherOrtho.z / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) - (otherLength/2) * (otherVectorToWp.z/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z)))};

                    otherBoundingBox[4] ={ 	x = otherPos.x + (otherWidth/2) * ( otherOrtho.x / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) - (otherLength/2) * (otherVectorToWp.x/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z))),
                                            y = 0,
                                            z = otherPos.z + (otherWidth/2) * ( otherOrtho.z / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) - (otherLength/2) * (otherVectorToWp.z/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z)))};
                    
                    if AutoDrive:BoxesIntersect(boundingBox, otherBoundingBox) == true then
                        cell.isRestricted = true;
                        cell.hasCollision = true;
                    end;
                end;
            end;
        end;                    
    end;
end;

function getShapeDefByDirectionType(pf, cell)
    local shapeDefinition = {};
    shapeDefinition.angleRad = math.atan2(-pf.targetVector.z, pf.targetVector.x);
    shapeDefinition.angleRad = normalizeAngle(shapeDefinition.angleRad);
    local worldPos = AutoDrivePathFinder:gridLocationToWorldLocation(pf, cell);
    shapeDefinition.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, worldPos.x, 1, worldPos.z)
    shapeDefinition.height = 2.85;

    if cell.direction == AutoDrive.PP_UP or cell.direction == AutoDrive.PP_DOWN or cell.direction == AutoDrive.PP_RIGHT or cell.direction == AutoDrive.PP_LEFT then
        --default size:
        shapeDefinition.x = worldPos.x;
        shapeDefinition.z = worldPos.z;
        shapeDefinition.widthX = pf.minTurnRadius/2;
        shapeDefinition.widthZ = pf.minTurnRadius/2;
    elseif cell.direction == AutoDrive.PP_UP_RIGHT then
        local offsetX = (-pf.vectorX.x)/2 + (-pf.vectorZ.x)/4;     
        local offsetZ = (-pf.vectorX.z)/2 + (-pf.vectorZ.z)/4;    
        shapeDefinition.x = worldPos.x + offsetX;
        shapeDefinition.z = worldPos.z + offsetZ;
        shapeDefinition.widthX = (pf.minTurnRadius/2) + math.abs(offsetX);
        shapeDefinition.widthZ = pf.minTurnRadius/2 + math.abs(offsetZ);
    elseif cell.direction == AutoDrive.PP_UP_LEFT then
        local offsetX = (-pf.vectorX.x)/2 + (pf.vectorZ.x)/4;     
        local offsetZ = (-pf.vectorX.z)/2 + (pf.vectorZ.z)/4;    
        shapeDefinition.x = worldPos.x + offsetX;
        shapeDefinition.z = worldPos.z + offsetZ;
        shapeDefinition.widthX = pf.minTurnRadius/2 + math.abs(offsetX);
        shapeDefinition.widthZ = pf.minTurnRadius/2 + math.abs(offsetZ);
    elseif cell.direction == AutoDrive.PP_DOWN_RIGHT then 
        local offsetX = (pf.vectorX.x)/2 + (-pf.vectorZ.x)/4;     
        local offsetZ = (pf.vectorX.z)/2 + (-pf.vectorZ.z)/4;    
        shapeDefinition.x = worldPos.x + offsetX;
        shapeDefinition.z = worldPos.z + offsetZ;
        shapeDefinition.widthX = pf.minTurnRadius/2 + math.abs(offsetX);
        shapeDefinition.widthZ = pf.minTurnRadius/2 + math.abs(offsetZ);
    elseif cell.direction == AutoDrive.PP_DOWN_LEFT then
        local offsetX = (pf.vectorX.x)/2 + (pf.vectorZ.x)/4;     
        local offsetZ = (pf.vectorX.z)/2 + (pf.vectorZ.z)/4;     
        shapeDefinition.x = worldPos.x + offsetX;
        shapeDefinition.z = worldPos.z + offsetZ;
        shapeDefinition.widthX = pf.minTurnRadius/2 + math.abs(offsetX);
        shapeDefinition.widthZ = pf.minTurnRadius/2 + math.abs(offsetZ);
    end;
    
    return shapeDefinition;
end;

function AutoDrivePathFinder:createWayPoints(pf)
    if pf.smoothStep == 0 then
        local currentCell = pf.targetCell;
        pf.chainTargetToStart = {};
        local index = 1;
        pf.chainTargetToStart[index] = currentCell;
        index = index + 1;
        while currentCell.x ~= 0 or currentCell.z ~= 0 do
            pf.chainTargetToStart[index] = currentCell.incoming;
            currentCell = currentCell.incoming;
            if currentCell == nil then
                break;
            end;
            index = index + 1;
        end;
        index = index - 1;

        pf.chainStartToTarget = {};
        for reversedIndex=0,index,1 do
            pf.chainStartToTarget[reversedIndex+1] = pf.chainTargetToStart[index-reversedIndex];
        end;

        --Now build actual world coordinates as waypoints and include pre and append points
        pf.wayPoints = {};  
        for chainIndex, cell in pairs(pf.chainStartToTarget) do
            pf.wayPoints[chainIndex] = AutoDrivePathFinder:gridLocationToWorldLocation(pf, cell);
            pf.wayPoints[chainIndex].y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pf.wayPoints[chainIndex].x, 1, pf.wayPoints[chainIndex].z);
            pf.wayPoints[chainIndex].lastDirection = cell.direction;
        end;

        AutoDrivePathFinder:smoothResultingPPPath(pf);
    end;
        
    
    if AutoDrive:getSetting("smoothField") == true then
        AutoDrivePathFinder:smoothResultingPPPath_Refined(pf);
    else
        pf.smoothStep = 2;
        pf.smoothDone = true;
    end;

    if pf.smoothStep == 2 then
        if pf.appendWayPointCount ~= nil then
            for i=1, pf.appendWayPointCount, 1 do
                pf.wayPoints[ADTableLength(pf.wayPoints)+1] = pf.appendWayPoints[i];
            end;
            pf.smoothStep = 3;
        end;
    end;
end;

function AutoDrivePathFinder:smoothResultingPPPath(pf)
    local index = 1;
	local filteredIndex = 1;
	local filteredWPs = {};

	while index < ADTableLength(pf.wayPoints) - 2 do
		local node = pf.wayPoints[index];
		local nodeAhead = pf.wayPoints[index+1];
		local nodeTwoAhead = pf.wayPoints[index+2];

		filteredWPs[filteredIndex] = node;
		filteredIndex = filteredIndex + 1;

		if node.lastDirection ~= nil and nodeAhead.lastDirection ~= nil and nodeTwoAhead.lastDirection ~= nil then
			if node.lastDirection == nodeTwoAhead.lastDirection and node.lastDirection ~= nodeAhead.lastDirection then
				index = index + 1; --skip next point because it is a zig zag line. Cut right through instead
			end;
		end;
		
		index = index + 1;
	end;
	
	while index <= ADTableLength(pf.wayPoints) do
		local node = pf.wayPoints[index];
		filteredWPs[filteredIndex] = node;
		filteredIndex = filteredIndex + 1;
		index = index + 1;
	end;

	pf.wayPoints = filteredWPs;
end;

function AutoDrivePathFinder:smoothResultingPPPath_Refined(pf)
    if pf.smoothStep == 0 then
        pf.smoothIndex = 1;
        pf.filteredIndex = 1;
        pf.filteredWPs = {};
    
        --add first few without filtering
        while pf.smoothIndex < ADTableLength(pf.wayPoints) and pf.smoothIndex < 5 do
            pf.filteredWPs[pf.filteredIndex] = pf.wayPoints[pf.smoothIndex];
            pf.filteredIndex = pf.filteredIndex + 1;
            pf.smoothIndex = pf.smoothIndex + 1;
        end;

        pf.smoothStep = 1;
    end;
    
    if pf.smoothStep == 1 then
        local stepsThisFrame = 0;
        while pf.smoothIndex < ADTableLength(pf.wayPoints) - 6 and stepsThisFrame < 1 do
            stepsThisFrame = stepsThisFrame + 1;

            local node = pf.wayPoints[pf.smoothIndex];
            local previousNode = nil;            
            local worldPos = pf.wayPoints[pf.smoothIndex];

            if pf.totalEagerSteps == nil or pf.totalEagerSteps == 0 then
                pf.filteredWPs[pf.filteredIndex] = node;
                if pf.filteredIndex > 1 then
                    previousNode = pf.filteredWPs[pf.filteredIndex-1]
                end;
                pf.filteredIndex = pf.filteredIndex + 1;

                local foundCollision = false;
                pf.lookAheadIndex = 1;
                pf.eagerLookAhead = 0;
                pf.totalEagerSteps = 0;
            end;

            local widthOfColBox = math.sqrt(math.pow(pf.minTurnRadius, 2) + math.pow(pf.minTurnRadius, 2));
            local sideLength = widthOfColBox/2;
            local y = worldPos.y;

            local stepsOfLookAheadThisFrame = 0;
            while (foundCollision == false or pf.totalEagerSteps < 30) and ((pf.smoothIndex+pf.totalEagerSteps) < (ADTableLength(pf.wayPoints) - 6)) and stepsOfLookAheadThisFrame < 3 do
                stepsOfLookAheadThisFrame = stepsOfLookAheadThisFrame + 1;
                local nodeAhead = pf.wayPoints[pf.smoothIndex+pf.totalEagerSteps+1];
                local nodeTwoAhead = pf.wayPoints[pf.smoothIndex+pf.totalEagerSteps+2];

                local angle = AutoDrive:angleBetween( 	{x=	nodeAhead.x	-	node.x, z = nodeAhead.z - node.z },
                                                    {x=	nodeTwoAhead.x-	nodeAhead.x, z = nodeTwoAhead.z - nodeAhead.z } )
                angle = math.abs(angle);

                local hasCollision = false;
                if angle > 60 then
                    hasCollision = true;
                end;        
                if previousNode ~= nil then
                    angle = AutoDrive:angleBetween( 	{x=	node.x	-	previousNode.x, z = node.z - previousNode.z },
                                                    {x=	nodeTwoAhead.x-	node.x, z = nodeTwoAhead.z - node.z } )
                    angle = math.abs(angle);                    
                    if angle > 60 then
                        hasCollision = true;
                    end; 
                    angle = AutoDrive:angleBetween( 	{x=	node.x	-	previousNode.x, z = node.z - previousNode.z },
                                                    {x=	nodeAhead.x-	node.x, z = nodeAhead.z - node.z } )
                    angle = math.abs(angle);
                    if angle > 60 then
                        hasCollision = true;
                    end; 
                end;
                
                local terrain1 = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, worldPos.x, 0, worldPos.z)
                local terrain2 = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, nodeAhead.x, 0, nodeAhead.z)
                local length = MathUtil.vector3Length(worldPos.x-nodeAhead.x, terrain1-terrain2, worldPos.z-nodeAhead.z)
                local angleBetween = math.atan(math.abs(terrain1-terrain2)/length)

                if (angleBetween*2) > AITurnStrategy.SLOPE_DETECTION_THRESHOLD then --be a bit more careful, since slopes will be less steep when combining path sections
                    hasCollision = true;
                end

                local vectorX = nodeAhead.x - node.x;
                local vectorZ = nodeAhead.z - node.z;
                local angleRad = math.atan2(-vectorZ, vectorX);
                angleRad = normalizeAngle(angleRad);
                local length = math.sqrt(math.pow(vectorX, 2) + math.pow(vectorZ, 2)) + widthOfColBox;
                
                local leftAngle = normalizeAngle(angleRad + math.rad(-90));
                local rightAngle = normalizeAngle(angleRad + math.rad(90));

                local cornerX = node.x - math.cos(leftAngle) * sideLength;
                local cornerZ = node.z + math.sin(leftAngle) * sideLength;

                local corner2X = nodeAhead.x - math.cos(leftAngle) * sideLength;
                local corner2Z = nodeAhead.z + math.sin(leftAngle) * sideLength;
                
                local corner3X = nodeAhead.x - math.cos(rightAngle) * sideLength;
                local corner3Z = nodeAhead.z + math.sin(rightAngle) * sideLength;

                local corner4X = node.x - math.cos(rightAngle) * sideLength;
                local corner4Z = node.z + math.sin(rightAngle) * sideLength;

                local shapes = overlapBox(worldPos.x + vectorX/2,y+3,worldPos.z + vectorZ/2, 0,angleRad,0, length/2,2.85,widthOfColBox/2, "collisionTestCallbackIgnore", nil, AIVehicleUtil.COLLISION_MASK, true, true, true)
                hasCollision = hasCollision or (shapes > 0);
                --shapes = overlapBox(worldPos.x + vectorX/2,y+3,worldPos.z + vectorZ/2, 0,angleRad,0, widthOfColBox/4,2.85,length/2, "collisionTestCallbackIgnore", nil, Player.COLLISIONMASK_TRIGGER, true, true, true)
                --hasCollision = hasCollision or (shapes > 0);
                
                if (pf.smoothIndex > 1) then
                    local worldPosPrevious = pf.wayPoints[pf.smoothIndex-1]    
                    local length = MathUtil.vector3Length(worldPos.x-worldPosPrevious.x, worldPos.y-worldPosPrevious.y, worldPos.z-worldPosPrevious.z)
                    local angleBetween = math.atan(math.abs(worldPos.y-worldPosPrevious.y)/length)
            
                    if angleBetween > AITurnStrategy.SLOPE_DETECTION_THRESHOLD then
                        hasCollision = true;                    
                    end
                end;

                if pf.fruitToCheck ~= nil then                    
                    local fruitValue, _, _, _ = FSDensityMapUtil.getFruitArea(pf.fruitToCheck, cornerX, cornerZ, corner2X, corner2Z, corner4X, corner4Z, nil, false);
                    if pf.fruitToCheck == 9 or pf.fruitToCheck == 22 then
                        fruitValue, _, _, _ = FSDensityMapUtil.getFruitArea(pf.fruitToCheck, cornerX, cornerZ, corner2X, corner2Z, corner4X, corner4Z, true, true);
                    end;

                    hasCollision = hasCollision or (fruitValue > 50);                    
                end;

                hasCollision = hasCollision or AutoDrivePathFinder:checkForCombineCollision(pf, cornerX, cornerZ, corner2X, corner2Z, corner3X, corner3Z, corner4X, corner4Z);                
                hasCollision = hasCollision or AutoDrivePathFinder:checkVehicleCollision(pf, cornerX, cornerZ, corner2X, corner2Z, corner3X, corner3Z, corner4X, corner4Z);            
                
                foundCollision = hasCollision;

                if foundCollision then
                    pf.eagerLookAhead = pf.eagerLookAhead + 1;
                else
                    pf.lookAheadIndex = pf.totalEagerSteps+1;--lookAheadIndex + 1 + eagerLookAhead;
                    pf.eagerLookAhead = 0;
                end;

                pf.totalEagerSteps = pf.totalEagerSteps + 1;
            end;

            if pf.totalEagerSteps >= 30 or ((pf.smoothIndex+pf.totalEagerSteps) >= (ADTableLength(pf.wayPoints) - 6)) then
                pf.smoothIndex = pf.smoothIndex + math.max(1,(pf.lookAheadIndex)); --(pf.lookAheadIndex-2)
                pf.totalEagerSteps = 0;
            end;
        end;  
        
        if pf.smoothIndex >= ADTableLength(pf.wayPoints) - 6 then
            pf.smoothStep = 2;
        end;
    end;
   
    if pf.smoothStep == 2 then
        --add remaining points without filtering
        while pf.smoothIndex <= ADTableLength(pf.wayPoints) do
            local node = pf.wayPoints[pf.smoothIndex];
            pf.filteredWPs[pf.filteredIndex] = node;
            pf.filteredIndex = pf.filteredIndex + 1;
            pf.smoothIndex = pf.smoothIndex + 1;
        end;

        pf.wayPoints = pf.filteredWPs;

        pf.smoothDone = true;
    end;
end;

function AutoDrivePathFinder:checkForCombineCollision(pf, cornerX, cornerZ, corner2X, corner2Z, corner3X, corner3Z, corner4X, corner4Z)
    local boundingBox = {};
    boundingBox[1] ={ 	x = cornerX,
                        y = 0,
                        z = cornerZ; };
    boundingBox[2] ={ 	x = corner2X,
                        y = 0,
                        z = corner2Z; };
    boundingBox[3] ={ 	x = corner3X,
                        y = 0,
                        z = corner3Z; };
    boundingBox[4] ={ 	x = corner4X,
                        y = 0,
                        z = corner4Z; };
    
    local objectsToCheck = {};
    table.insert(objectsToCheck, pf.combine);
    if pf.combine ~= nil and pf.combine.getAttachedImplements ~= nil then
        for i, implement in pairs(pf.combine:getAttachedImplements()) do
		    if implement.object ~= nil then
                table.insert(objectsToCheck, implement.object);
            end;
		end;
    end;
    
    for _,object in pairs(objectsToCheck) do
        if object ~= nil and object.components ~= nil and object.sizeWidth ~= nil and object.sizeLength ~= nil and object.rootNode ~= nil then     
            local otherWidth = object.sizeWidth;
            local otherLength = object.sizeLength;
            local otherPos = {};
            otherPos.x,otherPos.y,otherPos.z = getWorldTranslation( object.components[1].node ); 

            local rx,ry,rz = localDirectionToWorld(object.components[1].node, 0, 0, 1);

            local otherVectorToWp = {};
            otherVectorToWp.x = rx;
            otherVectorToWp.z = rz;

            local otherPos2 = {};
            otherPos2.x = otherPos.x + (otherLength/2) * (otherVectorToWp.x/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z)));
            otherPos2.y = 0;
            otherPos2.z = otherPos.z + (otherLength/2) * (otherVectorToWp.z/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z)));
            local otherOrtho = { x=-otherVectorToWp.z, z=otherVectorToWp.x };

            local otherBoundingBox = {};
            otherBoundingBox[1] ={ 	x = otherPos.x + (otherWidth/2) * ( otherOrtho.x / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) + (otherLength/2) * (otherVectorToWp.x/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z))),
                                    y = 0,
                                    z = otherPos.z + (otherWidth/2) * ( otherOrtho.z / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) + (otherLength/2) * (otherVectorToWp.z/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z)))};

            otherBoundingBox[2] ={ 	x = otherPos.x - (otherWidth/2) * ( otherOrtho.x / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) + (otherLength/2) * (otherVectorToWp.x/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z))),
                                    y = 0,
                                    z = otherPos.z - (otherWidth/2) * ( otherOrtho.z / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) + (otherLength/2) * (otherVectorToWp.z/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z)))};
            otherBoundingBox[3] ={ 	x = otherPos.x - (otherWidth/2) * ( otherOrtho.x / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) - (otherLength/2) * (otherVectorToWp.x/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z))),
                                    y = 0,
                                    z = otherPos.z - (otherWidth/2) * ( otherOrtho.z / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) - (otherLength/2) * (otherVectorToWp.z/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z)))};

            otherBoundingBox[4] ={ 	x = otherPos.x + (otherWidth/2) * ( otherOrtho.x / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) - (otherLength/2) * (otherVectorToWp.x/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z))),
                                    y = 0,
                                    z = otherPos.z + (otherWidth/2) * ( otherOrtho.z / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) - (otherLength/2) * (otherVectorToWp.z/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z)))};
            
            if AutoDrive:BoxesIntersect(boundingBox, otherBoundingBox) == true then
                return true;
            end;
        end;
    end;

    return false;
end;

function AutoDrivePathFinder:checkVehicleCollision(pf, cornerX, cornerZ, corner2X, corner2Z, corner3X, corner3Z, corner4X, corner4Z)
    local boundingBox = {};
    boundingBox[1] ={ 	x = cornerX,
                        y = 0,
                        z = cornerZ; };
    boundingBox[2] ={ 	x = corner2X,
                        y = 0,
                        z = corner2Z; };
    boundingBox[3] ={ 	x = corner3X,
                        y = 0,
                        z = corner3Z; };
    boundingBox[4] ={ 	x = corner4X,
                        y = 0,
                        z = corner4Z; };

    for _,other in pairs(g_currentMission.vehicles) do
		if other ~= pf.driver then -- and other ~= pf.driver.ad.currentCombine
			local isAttachedToMe = AutoDrive:checkIsConnected(pf.driver, other);				
            
			if isAttachedToMe == false and other.components ~= nil then
				if other.sizeWidth == nil then
					--print("vehicle " .. other.configFileName .. " has no width");
				else
					if other.sizeLength == nil then
						--print("vehicle " .. other.configFileName .. " has no length");
					else
						if other.rootNode == nil then
							--print("vehicle " .. other.configFileName .. " has no root node");
						else
							local otherWidth = other.sizeWidth;
							local otherLength = other.sizeLength;
							local otherPos = {};
							otherPos.x,otherPos.y,otherPos.z = getWorldTranslation( other.components[1].node ); 

							local distance = AutoDrive:getDistance(cornerX,cornerZ,otherPos.x,otherPos.z);
							if distance < 100 then
								local rx,ry,rz = localDirectionToWorld(other.components[1].node, 0, 0, 1);

								local otherVectorToWp = {};
								otherVectorToWp.x = rx;
								otherVectorToWp.z = rz;

								local otherPos2 = {};
								otherPos2.x = otherPos.x + (otherLength/2) * (otherVectorToWp.x/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z)));
								otherPos2.y = y;
								otherPos2.z = otherPos.z + (otherLength/2) * (otherVectorToWp.z/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z)));
								local otherOrtho = { x=-otherVectorToWp.z, z=otherVectorToWp.x };

								local otherBoundingBox = {};
								otherBoundingBox[1] ={ 	x = otherPos.x + (otherWidth/2) * ( otherOrtho.x / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) + (otherLength/2) * (otherVectorToWp.x/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z))),
														y = y,
														z = otherPos.z + (otherWidth/2) * ( otherOrtho.z / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) + (otherLength/2) * (otherVectorToWp.z/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z)))};

								otherBoundingBox[2] ={ 	x = otherPos.x - (otherWidth/2) * ( otherOrtho.x / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) + (otherLength/2) * (otherVectorToWp.x/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z))),
														y = y,
														z = otherPos.z - (otherWidth/2) * ( otherOrtho.z / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) + (otherLength/2) * (otherVectorToWp.z/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z)))};
								otherBoundingBox[3] ={ 	x = otherPos.x - (otherWidth/2) * ( otherOrtho.x / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) - (otherLength/2) * (otherVectorToWp.x/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z))),
														y = y,
														z = otherPos.z - (otherWidth/2) * ( otherOrtho.z / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) - (otherLength/2) * (otherVectorToWp.z/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z)))};

								otherBoundingBox[4] ={ 	x = otherPos.x + (otherWidth/2) * ( otherOrtho.x / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) - (otherLength/2) * (otherVectorToWp.x/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z))),
														y = y,
														z = otherPos.z + (otherWidth/2) * ( otherOrtho.z / (math.abs(otherOrtho.x)+math.abs(otherOrtho.z))) - (otherLength/2) * (otherVectorToWp.z/(math.abs(otherVectorToWp.x)+math.abs(otherVectorToWp.z)))};

								if AutoDrive:BoxesIntersect(boundingBox, otherBoundingBox) == true then
									return true;
								end;
							end;
						end;
					end;
				end;
			end;
		end;
    end;
    return false;
end;

function AutoDrivePathFinder:gridLocationToWorldLocation(pf, cell)
	local result = {x= 0, z=0};

	result.x = pf.startX + cell.x * pf.vectorX.x + cell.z * pf.vectorZ.x;
	result.z = pf.startZ + cell.x * pf.vectorX.z + cell.z * pf.vectorZ.z;

	return result;
end;

function AutoDrivePathFinder:worldLocationToGridLocation(pf, worldX, worldZ)
	local result = {x= 0, z=0};

	result.z = (((worldX - pf.startX) / pf.vectorX.x) * pf.vectorX.z -worldZ + pf.startZ) / (((pf.vectorZ.x / pf.vectorX.x) * pf.vectorX.z) - pf.vectorZ.z);
	result.x = (worldZ - pf.startZ - result.z * pf.vectorZ.z) / pf.vectorX.z;

	result.x = AutoDrive:round(result.x);
	result.z = AutoDrive:round(result.z);

	return result;
end;

function AutoDrivePathFinder:worldDirectionToGridDirection(pf, vector)
	local vecUp = {x = pf.vectorX.x + pf.vectorZ.x, z = pf.vectorX.z + pf.vectorZ.z};

	local angleWorldDirection = math.atan2(vector.z, vector.x);
	angleWorldDirection = normalizeAngle2(angleWorldDirection);

    --local angleRad = math.atan2(vecUp.z, vecUp.x);
    local angleRad = math.atan2(pf.vectorX.z, pf.vectorX.x);
	angleRad = normalizeAngle2(angleRad);

	local upRightAngle = normalizeAngle2(angleRad + math.rad(45));
	local rightAngle = normalizeAngle2(angleRad + math.rad(90));
	local downRightAngle = normalizeAngle2(angleRad + math.rad(135));
	local downAngle = normalizeAngle2(angleRad + math.rad(180));
	local downLeftAngle = normalizeAngle2(angleRad + math.rad(225));
	local leftAngle = normalizeAngle2(angleRad + math.rad(270));
	local upLeftAngle = normalizeAngle2(angleRad + math.rad(315));

    local direction = AutoDrive.PP_UP;
    --print("vectorUp: " .. math.deg(angleRad) ..  " angle target: " .. math.deg(angleWorldDirection));

	if math.abs( math.deg( normalizeAngle2( angleWorldDirection - upRightAngle ) )) <= 22.5 or math.abs( math.deg( normalizeAngle2( angleWorldDirection - upRightAngle ) )) >= 337.5 then
		direction = AutoDrive.PP_UP_RIGHT;
	elseif math.abs( math.deg( normalizeAngle2( angleWorldDirection - rightAngle ) )) <= 22.5 or math.abs( math.deg( normalizeAngle2( angleWorldDirection - rightAngle ) )) >= 337.5 then
		direction = AutoDrive.PP_RIGHT;
	elseif math.abs( math.deg( normalizeAngle2( angleWorldDirection - downRightAngle ) )) <= 22.5 or math.abs( math.deg( normalizeAngle2( angleWorldDirection - downRightAngle ) )) >= 337.5 then
		direction = AutoDrive.PP_DOWN_RIGHT;
	elseif math.abs( math.deg( normalizeAngle2( angleWorldDirection - downAngle ) )) <= 22.5 or math.abs( math.deg( normalizeAngle2( angleWorldDirection - downAngle ) )) >= 337.5 then
		direction = AutoDrive.PP_DOWN;
	elseif math.abs( math.deg( normalizeAngle2( angleWorldDirection - downLeftAngle ) )) <= 22.5 or math.abs( math.deg( normalizeAngle2( angleWorldDirection - downLeftAngle ) )) >= 337.5 then
		direction = AutoDrive.PP_DOWN_LEFT;
	elseif math.abs( math.deg( normalizeAngle2( angleWorldDirection - leftAngle ) )) <= 22.5 or math.abs( math.deg( normalizeAngle2( angleWorldDirection - leftAngle ) )) >= 337.5 then
		direction = AutoDrive.PP_LEFT;
	elseif math.abs( math.deg( normalizeAngle2( angleWorldDirection - upLeftAngle ) )) <= 22.5 or math.abs( math.deg( normalizeAngle2( angleWorldDirection - upLeftAngle ) )) >= 337.5 then
		direction = AutoDrive.PP_UP_LEFT;
	end;

	return direction;
end;

function AutoDrivePathFinder:determineBlockedCells(pf, endDirection, cell)
    local x = cell.x;
    local z = cell.z;

    if (math.abs(cell.x)<2 and math.abs(cell.z)<2) then
        return;
    end;

	--block cells which would result in bad angles to the end/start point
	-- \|/  x|/  xx/  xxx  xxx  xxx  \xx  \|x
	-- x|x  x/-  x>-  x\-  x|x  -/x  -<x  -\x
	-- xxx  xxx  xx\  x|\  /|\  /|x  /xx  xxx
    if endDirection == AutoDrive.PP_DOWN then
        table.insert(pf.grid, {x=x-1,   z=z,      direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x-1,   z=z-1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x-1,   z=z+1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x+0,   z=z-1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x+0,   z=z+1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
	elseif endDirection == AutoDrive.PP_DOWN_LEFT then
        table.insert(pf.grid, {x=x-1,   z=z,      direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x-1,   z=z-1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x,     z=z-1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x-1,   z=z+1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x+1,   z=z-1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
	elseif endDirection == AutoDrive.PP_LEFT then
        table.insert(pf.grid, {x=x-1,   z=z-1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x-1,   z=z+0,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x+0,   z=z-1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x+1,   z=z+0,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x+1,   z=z-1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
	elseif endDirection == AutoDrive.PP_UP_LEFT then
        table.insert(pf.grid, {x=x+1,   z=z+0,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x+1,   z=z-1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x+0,   z=z-1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x+1,   z=z+1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x-1,   z=z-1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
	elseif endDirection == AutoDrive.PP_UP then
        table.insert(pf.grid, {x=x+1,   z=z+0,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x+1,   z=z-1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x+0,   z=z+1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x+1,   z=z+1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x+0,   z=z-1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
	elseif endDirection == AutoDrive.PP_UP_RIGHT then
        table.insert(pf.grid, {x=x+1,   z=z+0,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x+1,   z=z+1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x+0,   z=z+1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x+1,   z=z-1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x-1,   z=z+1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
	elseif endDirection == AutoDrive.PP_RIGHT then
        table.insert(pf.grid, {x=x-1,   z=z+1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x+1,   z=z+1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x+0,   z=z+1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x+1,   z=z+0,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x-1,   z=z+0,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
	elseif endDirection == AutoDrive.PP_DOWN_RIGHT then
        table.insert(pf.grid, {x=x-1,   z=z+1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x+1,   z=z+1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x+0,   z=z+1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x-1,   z=z+0,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
        table.insert(pf.grid, {x=x-0,   z=z-1,    direction=-1, hasInfo=true, isRestricted=true, hasCollision=true, steps=1000})
    end;    
end;

function cellDistance(pf, cell)
    return math.sqrt(math.pow(pf.targetCell.x - cell.x, 2) + math.pow(pf.targetCell.z - cell.z,2));
end;

function checkForFruitTypeInArea(pf, cell, fruitType, cornerX, cornerZ, corner2X, corner2Z, corner3X, corner3Z)
    local fruitValue = 0;
    if fruitType == 9 or fruitType == 22 then
        fruitValue, _, _, _ = FSDensityMapUtil.getFruitArea(fruitType, cornerX, cornerZ, corner2X, corner2Z, corner3X, corner3Z, true, true);
    else
        fruitValue , _, _, _ = FSDensityMapUtil.getFruitArea(fruitType, cornerX, cornerZ, corner2X, corner2Z, corner3X, corner3Z, nil, false);
    end;
    
    if (pf.fruitToCheck == nil or pf.fruitToCheck < 1) and (fruitValue > 50) then
        pf.fruitToCheck = fruitType;
        pf.driver.ad.combineFruitToCheck = fruitType;
    end;
    local wasRestricted = cell.isRestricted;
    cell.isRestricted = cell.isRestricted or (fruitValue > 50);
    
    cell.hasFruit = (fruitValue > 50);

    --Allow fruit in the first few grid cells
    if (((math.abs(cell.x) <= 3) and (math.abs(cell.z) <= 3)) and pf.driver.ad.combineUnloadInFruit) or cellDistance(pf, cell) <= 3 then
        cell.isRestricted = false or wasRestricted;
    end;
end;

function AutoDrivePathFinder:drawDebugForPF(pf)	
	--if AutoDrive.drawCounter == nil then
		--AutoDrive.drawCounter = 120;
	--else
		--if AutoDrive.drawCounter <= 0 then
            --AutoDrive.drawCounter = 120;
            local pointTarget = AutoDrivePathFinder:gridLocationToWorldLocation(pf, pf.targetCell);
            local pointTargetUp = AutoDrivePathFinder:gridLocationToWorldLocation(pf, pf.targetCell);
            pointTarget.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointTarget.x, 1, pointTarget.z) + 3;
            pointTargetUp.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointTargetUp.x, 1, pointTargetUp.z) + 6;
            AutoDrive:drawLine(pointTarget, pointTargetUp, 0, 0, 1, 1);
            local pointStart = AutoDrivePathFinder:gridLocationToWorldLocation(pf, pf.startCell);
            local pointStartUp = AutoDrivePathFinder:gridLocationToWorldLocation(pf, pf.startCell);
            pointStart.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointStart.x, 1, pointStart.z) + 3;
            pointStartUp.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointStartUp.x, 1, pointStartUp.z) + 6;
            AutoDrive:drawLine(pointStart, pointStartUp, 0, 0, 1, 1);

            for _, cell in pairs(pf.grid) do
                local size = 0.3;
                local pointA = AutoDrivePathFinder:gridLocationToWorldLocation(pf, cell);
                pointA.x = pointA.x + pf.vectorX.x * size + pf.vectorZ.x * size;
                pointA.z = pointA.z + pf.vectorX.z * size + pf.vectorZ.z * size;
                pointA.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointA.x, 1, pointA.z) + 3;
                local pointB = AutoDrivePathFinder:gridLocationToWorldLocation(pf, cell);
                pointB.x = pointB.x - pf.vectorX.x * size - pf.vectorZ.x * size;
                pointB.z = pointB.z - pf.vectorX.z * size - pf.vectorZ.z * size;
                pointB.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointB.x, 1, pointB.z) + 3;
                local pointC = AutoDrivePathFinder:gridLocationToWorldLocation(pf, cell);
                pointC.x = pointC.x + pf.vectorX.x * size - pf.vectorZ.x * size;
                pointC.z = pointC.z + pf.vectorX.z * size - pf.vectorZ.z * size;
                pointC.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointC.x, 1, pointC.z) + 3;
                local pointD = AutoDrivePathFinder:gridLocationToWorldLocation(pf, cell);
                pointD.x = pointD.x - pf.vectorX.x * size + pf.vectorZ.x * size;
                pointD.z = pointD.z - pf.vectorX.z * size + pf.vectorZ.z * size;
                pointD.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointD.x, 1, pointD.z) + 3;
                
                if cell.hasInfo == true then
                    if cell.isRestricted == true then
                        AutoDrive:drawLine(pointA, pointB, 1, 0, 0, 1);
                        if cell.hasCollision == true then
                            AutoDrive:drawLine(pointC, pointD, 1, 1, 0, 1);
                        else
                            AutoDrive:drawLine(pointC, pointD, 1, 0, 1, 1);
                        end;
                    else
                        AutoDrive:drawLine(pointA, pointB, 0, 1, 0, 1);
                        if cell.hasCollision == true then
                            AutoDrive:drawLine(pointC, pointD, 1, 1, 0, 1);
                        else
                            AutoDrive:drawLine(pointC, pointD, 1, 0, 1, 1);
                        end;
                    end;
                else
                    AutoDrive:drawLine(pointA, pointB, 0, 0, 1, 1);
                    AutoDrive:drawLine(pointC, pointD, 0, 0, 1, 1);
                end;
            end;
            
            local size = 0.3;
            local pointA = AutoDrivePathFinder:gridLocationToWorldLocation(pf, pf.targetCell);
            pointA.x = pointA.x + pf.vectorX.x * size + pf.vectorZ.x * size;
            pointA.z = pointA.z + pf.vectorX.z * size + pf.vectorZ.z * size;
            pointA.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointA.x, 1, pointA.z) + 3;
            local pointB = AutoDrivePathFinder:gridLocationToWorldLocation(pf, pf.targetCell);
            pointB.x = pointB.x - pf.vectorX.x * size - pf.vectorZ.x * size;
            pointB.z = pointB.z - pf.vectorX.z * size - pf.vectorZ.z * size;
            pointB.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointB.x, 1, pointB.z) + 3;
            local pointC = AutoDrivePathFinder:gridLocationToWorldLocation(pf, pf.targetCell);
            pointC.x = pointC.x + pf.vectorX.x * size - pf.vectorZ.x * size;
            pointC.z = pointC.z + pf.vectorX.z * size - pf.vectorZ.z * size;
            pointC.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointC.x, 1, pointC.z) + 3;
            local pointD = AutoDrivePathFinder:gridLocationToWorldLocation(pf, pf.targetCell);
            pointD.x = pointD.x - pf.vectorX.x * size + pf.vectorZ.x * size;
            pointD.z = pointD.z - pf.vectorX.z * size + pf.vectorZ.z * size;
            pointD.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointD.x, 1, pointD.z) + 3;

            AutoDrive:drawLine(pointA, pointB, 1, 1, 1, 1);
            AutoDrive:drawLine(pointC, pointD, 1, 1, 1, 1);


            local pointAB = AutoDrivePathFinder:gridLocationToWorldLocation(pf, pf.targetCell);
            pointAB.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointAB.x, 1, pointAB.z) + 3;

            local pointTargetVector = AutoDrivePathFinder:gridLocationToWorldLocation(pf, pf.targetCell);
            pointTargetVector.x = pointTargetVector.x + pf.targetVector.x * 10;
            pointTargetVector.z = pointTargetVector.z + pf.targetVector.z * 10;
            pointTargetVector.y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, pointTargetVector.x, 1, pointTargetVector.z) + 3;
            AutoDrive:drawLine(pointAB, pointTargetVector, 1, 1, 1, 1);

		--else
			--AutoDrive.drawCounter = AutoDrive.drawCounter - 1;
		--end;
	--end;
end;

function drawDebugForCreatedRoute(pf)
    if pf.chainStartToTarget ~= nil then
        for chainIndex, cell in pairs(pf.chainStartToTarget) do 
            local shape = getShapeDefByDirectionType(pf, cell);
            if shape.x ~= nil then
                local pointA = { x=shape.x + shape.widthX*math.cos(shape.angleRad) + shape.widthZ*math.sin(shape.angleRad), y=shape.y,
                z=shape.z + shape.widthZ*math.cos(shape.angleRad) + shape.widthX*math.sin(shape.angleRad) }
                local pointB = { x=shape.x - shape.widthX*math.cos(shape.angleRad) - shape.widthZ*math.sin(shape.angleRad), y=shape.y,
                z=shape.z + shape.widthZ*math.cos(shape.angleRad) + shape.widthX*math.sin(shape.angleRad) }
                local pointC = { x=shape.x - shape.widthX*math.cos(shape.angleRad) - shape.widthZ*math.sin(shape.angleRad), y=shape.y, z=shape.z
                - shape.widthZ*math.cos(shape.angleRad) - shape.widthX*math.sin(shape.angleRad) }
                local pointD = { x=shape.x + shape.widthX*math.cos(shape.angleRad) + shape.widthZ*math.sin(shape.angleRad), y=shape.y, z=shape.z
                - shape.widthZ*math.cos(shape.angleRad) - shape.widthX*math.sin(shape.angleRad) }
                
                AutoDrive:drawLine(pointA, pointC, 1, 1, 1, 1);
                AutoDrive:drawLine(pointB, pointD, 1, 1, 1, 1);


                if cell.incoming ~= nil then

                    local worldPos_cell = AutoDrivePathFinder:gridLocationToWorldLocation(pf, cell);
                    local worldPos_incoming = AutoDrivePathFinder:gridLocationToWorldLocation(pf, cell.incoming);

                    local vectorX = worldPos_cell.x - worldPos_incoming.x;
                    local vectorZ = worldPos_cell.z - worldPos_incoming.z;
                    local angleRad = math.atan2(-vectorZ, vectorX);
                    angleRad = normalizeAngle(angleRad);
                    local widthOfColBox = math.sqrt(math.pow(pf.minTurnRadius, 2) + math.pow(pf.minTurnRadius, 2));
                    local sideLength = widthOfColBox/2;
                    local length = math.sqrt(math.pow(vectorX, 2) + math.pow(vectorZ, 2)) + widthOfColBox;
                    
                    local leftAngle = normalizeAngle(angleRad + math.rad(-90));
                    local rightAngle = normalizeAngle(angleRad + math.rad(90));

                    local cornerX = worldPos_incoming.x - math.cos(leftAngle) * sideLength;
                    local cornerZ = worldPos_incoming.z + math.sin(leftAngle) * sideLength;

                    local corner2X = worldPos_cell.x - math.cos(leftAngle) * sideLength;
                    local corner2Z = worldPos_cell.z + math.sin(leftAngle) * sideLength;
                    
                    local corner3X = worldPos_cell.x - math.cos(rightAngle) * sideLength;
                    local corner3Z = worldPos_cell.z + math.sin(rightAngle) * sideLength;

                    local corner4X = worldPos_incoming.x - math.cos(rightAngle) * sideLength;
                    local corner4Z = worldPos_incoming.z + math.sin(rightAngle) * sideLength;

                    local inY =  getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, worldPos_incoming.x, 1, worldPos_incoming.z) + 1;
                    local currentY =  getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, worldPos_cell.x, 1, worldPos_cell.z) + 1;
                    
                    AutoDrive:drawLine({x = cornerX, y= inY, z=cornerZ}, {x = corner2X, y= currentY, z=corner2Z}, 1, 0, 0, 1);
                    AutoDrive:drawLine({x = corner2X, y= currentY, z=corner2Z}, {x = corner3X, y= currentY, z=corner3Z}, 1, 0, 0, 1);
                    AutoDrive:drawLine({x = corner3X, y= currentY, z=corner3Z}, {x = corner4X, y= inY, z=corner4Z}, 1, 0, 0, 1);
                    AutoDrive:drawLine({x = corner4X, y= inY, z=corner4Z}, {x = cornerX, y= inY, z=cornerZ}, 1, 0, 0, 1);
                end;
            end;
        end;
    end;

    for i, waypoint in pairs(pf.wayPoints) do
        local node = createTransformGroup("Node " .. i);
		setTranslation(node, waypoint.x, waypoint.y + 4 , waypoint.z  );
		DebugUtil.drawDebugNode(node, "Node " .. i);

        if i>1 then
            AutoDrive:drawLine(waypoint, pf.wayPoints[i-1], 0, 1, 1, 1);
        end;
    end;
end;