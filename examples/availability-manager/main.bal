// Copyright (c) 2025 WSO2 LLC. (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/io;
import ballerinax/zoom.scheduler as zoom;

configurable string clientId = ?;
configurable string clientSecret = ?;
configurable string refreshToken = ?;
configurable string userId = ?;

final zoom:Client zoomClient = check new ({
    auth: {
        clientId,
        clientSecret,
        refreshUrl: "https://zoom.us/oauth/token",
        refreshToken
    }
});

public function main() returns error? {
    zoom:InlineResponse2007 userInfo = check zoomClient->/users/[userId].get();
    io:println("User: ", userInfo.displayName, " | Timezone: ", userInfo.timeZone);
    zoom:InlineResponse200 analytics = check zoomClient->/analytics.get(
        userId = userId,
        'from = "2025-01-01",
        to = "2025-12-31"
    );
    
    if analytics.lastNDays is zoom:InlineResponse200LastNDays {
        zoom:InlineResponse200LastNDays stats = <zoom:InlineResponse200LastNDays>analytics.lastNDays;
        io:println("Analytics - Events Created: ", stats.scheduledEventsCreated ?: 0, 
                  " | Completed: ", stats.scheduledEventsCompleted ?: 0,
                  " | Canceled: ", stats.scheduledEventsCanceled ?: 0);
    }
    
    zoom:InlineResponse2001 availabilityResponse = check zoomClient->/availability.get(
        userId = userId,
        pageSize = 10
    );
    
    if availabilityResponse.items is zoom:InlineResponse2001Items[] {
        zoom:InlineResponse2001Items[] availabilities = <zoom:InlineResponse2001Items[]>availabilityResponse.items;
        io:println("Availability Schedules: ", availabilities.length());
        foreach zoom:InlineResponse2001Items availability in availabilities {
            io:println("- ", availability.name, " (", availability.timeZone, "), ID: ", availability.availabilityId);
            io:println("Owner: ", availability.owner ?: "Unknown");
        }
    }

    boolean shouldCreateNew = true;
    if availabilityResponse.items is zoom:InlineResponse2001Items[] {
        zoom:InlineResponse2001Items[] availabilities = <zoom:InlineResponse2001Items[]>availabilityResponse.items;
        int extendedHoursCount = 0;
        foreach zoom:InlineResponse2001Items availability in availabilities {
            if availability.name == "Extended Office Hours" {
                extendedHoursCount += 1;
            }
        }
        if extendedHoursCount >= 3 {
            shouldCreateNew = false;
            io:println("Skipping creation - already have ", extendedHoursCount, " Extended Office Hours schedules");
        }
    }
    
    if shouldCreateNew {
        zoom:SchedulerAvailabilityBody newAvailability = {
            name: "Extended Office Hours",
            timeZone: "America/New_York",
            segmentsRecurrence: {
                mon: [{
                    'start: "08:00",
                    end: "18:00"
                }],
                tue: [{
                    'start: "08:00", 
                    end: "18:00"
                }],
                wed: [{
                    'start: "08:00",
                    end: "18:00"
                }],
                thu: [{
                    'start: "08:00",
                    end: "18:00"
                }],
                fri: [{
                    'start: "08:00",
                    end: "16:00"
                }]
            }
        };

        zoom:InlineResponse201 createdAvailability = check zoomClient->/availability.post(
            payload = newAvailability
        );
        io:println("Created new availability: ", createdAvailability.name, " (", createdAvailability.availabilityId, ")");
    }
    
    zoom:InlineResponse2005|error allSchedulesResult = zoomClient->/schedules.get(
        userId = userId,
        pageSize = 5,
        showDeleted = false
    );
    
    if allSchedulesResult is zoom:InlineResponse2005 {
        zoom:InlineResponse2005 allSchedules = allSchedulesResult;
        if allSchedules.items is zoom:InlineResponse2005Items[] {
            zoom:InlineResponse2005Items[] schedules = <zoom:InlineResponse2005Items[]>allSchedules.items;
            io:println("Active Schedules: ", schedules.length());
            foreach zoom:InlineResponse2005Items schedule in schedules {
                io:println("- ", schedule.summary, " (", schedule.duration, "min, ", schedule.capacity, " attendees)");
            }
        } else {
            io:println("No schedules found");
        }
    } else {
        io:println("Error fetching schedules: ", allSchedulesResult.message());
    }
}
