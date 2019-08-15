function AutoDrive:handleFillables(vehicle, dt)
    if vehicle.ad.isActive == true and vehicle.ad.mode == AutoDrive.MODE_LOAD then --and vehicle.isServer == true
        local trailers, trailerCount = AutoDrive:getTrailersOf(vehicle, false);  		

        if trailerCount == 0 then
            return
        end;        
        
        local leftCapacity = 0;
        local fillLevel = 0;
        for _,trailer in pairs(trailers) do
            for _,fillUnit in pairs(trailer:getFillUnits()) do
                leftCapacity = leftCapacity + trailer:getFillUnitFreeCapacity(_);
                fillLevel = fillLevel + trailer:getFillUnitFillLevel(_);
            end
        end;

        if fillLevel == 0 then
            vehicle.ad.isUnloading = false;
            vehicle.ad.isUnloadingToBunkerSilo = false;
        end;

        --check distance to unloading destination, do not unload too far from it. You never know where the tractor might already drive over an unloading trigger before that
        local x,y,z = getWorldTranslation(vehicle.components[1].node);
        local destination = AutoDrive.mapWayPoints[vehicle.ad.targetSelected];        

        if destination == nil then
            return;
        end;
        local distance = AutoDrive:getDistance(x,z, destination.x, destination.z);
 
        if vehicle.ad.mode == AutoDrive.MODE_LOAD then
            local x,y,z = getWorldTranslation(vehicle.components[1].node);
            local destination = AutoDrive.mapWayPoints[vehicle.ad.targetSelected_Unload];
            if destination == nil then
                return;
            end;
            local distance = AutoDrive:getDistance(x,z, destination.x, destination.z);        
            if distance < 20 then
                for _,trailer in pairs(trailers) do
                    for _,trigger in pairs(AutoDrive.Triggers.siloTriggers) do
                        local activate = false;
			            if trigger.fillableObjects ~= nil then
                            for __,fillableObject in pairs(trigger.fillableObjects) do
                                if fillableObject.object == trailer then   
                                    activate = true;    
                                end;
                            end;
                        end;

                        local leftCapacityTrailer = 0;
                        local fillLevelTrailer = 0;
                        for _,fillUnit in pairs(trailer:getFillUnits()) do
                            leftCapacityTrailer = leftCapacityTrailer + trailer:getFillUnitFreeCapacity(_);
                            fillLevelTrailer = fillLevelTrailer + trailer:getFillUnitFillLevel(_);
                        end
                        if AutoDrive:getSetting("continueOnEmptySilo") and trigger == vehicle.ad.trigger and vehicle.ad.isLoading and vehicle.ad.isPaused and not trigger.isLoading and vehicle.ad.trailerStartedLoadingAtTrigger then --trigger must be empty by now. Drive on!
                            vehicle.ad.isPaused = false;
                            vehicle.ad.isUnloading = false;
                            vehicle.ad.isLoading = false;
                        elseif activate == true and not trigger.isLoading and leftCapacity > 0 and AutoDrive:fillTypesMatch(vehicle, trigger, trailer) and trigger:getIsActivatable(trailer) and ((not vehicle.ad.trailerStartedLoadingAtTrigger) or trigger ~= vehicle.ad.trigger) then -- and  and vehicle.ad.isLoading == false                      
                            trigger.autoStart = true
                            trigger.selectedFillType = vehicle.ad.unloadFillTypeIndex   
                            trigger:onFillTypeSelection(vehicle.ad.unloadFillTypeIndex);
                            trigger.selectedFillType = vehicle.ad.unloadFillTypeIndex 
                            g_effectManager:setFillType(trigger.effects, trigger.selectedFillType)
                            trigger.autoStart = false

                            vehicle.ad.isPaused = true;
                            vehicle.ad.isLoading = true;
                            vehicle.ad.startedLoadingAtTrigger = true;
                            vehicle.ad.trailerStartedLoadingAtTrigger = true;
                            vehicle.ad.trigger = trigger;
                        elseif activate == true and not trigger.isLoading and leftCapacity > 0 and not AutoDrive:fillTypesMatch(vehicle, trigger, trailer) and trigger:getIsActivatable(trailer) and ((not vehicle.ad.trailerStartedLoadingAtTrigger) or trigger ~= vehicle.ad.trigger) then -- and  and vehicle.ad.isLoading == false                      
                            local storedFillType = vehicle.ad.unloadFillTypeIndex;
                            local matches = false;
                            if storedFillType == 13 or storedFillType == 43 then
                                if storedFillType == 13 then
                                    vehicle.ad.unloadFillTypeIndex = 43;
                                else
                                    vehicle.ad.unloadFillTypeIndex = 13;
                                end;
                                
                                matches = AutoDrive:fillTypesMatch(vehicle, trigger, trailer);
                            end;

                            if matches == true then
                                trigger.autoStart = true
                                trigger.selectedFillType = vehicle.ad.unloadFillTypeIndex   
                                trigger:onFillTypeSelection(vehicle.ad.unloadFillTypeIndex);
                                trigger.selectedFillType = vehicle.ad.unloadFillTypeIndex 
                                g_effectManager:setFillType(trigger.effects, trigger.selectedFillType)
                                trigger.autoStart = false

                                vehicle.ad.isPaused = true;
                                vehicle.ad.isLoading = true;
                                vehicle.ad.startedLoadingAtTrigger = true;
                                vehicle.ad.trailerStartedLoadingAtTrigger = true;
                                vehicle.ad.trigger = trigger;
                            end;

                            vehicle.ad.unloadFillTypeIndex = storedFillType;
                        elseif (leftCapacity == 0 or (leftCapacityTrailer == 0 and activate)) and vehicle.ad.isPaused then
                            vehicle.ad.isPaused = false;
                            vehicle.ad.isUnloading = false;
                            vehicle.ad.isLoading = false;
                            vehicle.ad.trailerStartedLoadingAtTrigger = false;
                        end;
                    end;

                    if trailer.spec_cover ~= nil then
                        if trailer.spec_cover.state == 0 then
                            local newState = 1    
                            if trailer.spec_cover.state ~= newState and trailer:getIsNextCoverStateAllowed(newState) then
                                trailer:setCoverState(newState,true);
                            end
                        end;
                    end;
                end;
            elseif distance > 50 then
				for _,trailer in pairs(trailers) do
					if trailer.spec_cover ~= nil then
                        if trailer.spec_cover.state > 0 then
                            local newState = 0    
                            if trailer.spec_cover.state ~= newState and trailer:getIsNextCoverStateAllowed(newState) then
                                trailer:setCoverState(newState,true);
                            end
                        end;
                    end;
				end;
			end;
        end;
    end;
end;

