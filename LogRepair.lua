local _, DP = ...

-- Exact, user-confirmed repair; reload also repairs the running client's copy.
function DP.RepairConfirmedEncounter(store)
    if not store or not store.encounters then return false end
    local changed = false
    for index = #store.encounters, 1, -1 do
        local record = store.encounters[index]
        if record.repairedFromEncounterId == 142 and record.playerGUID == "Player-5066-01722C84" and
                record.correctionSource and record.enemies and #record.enemies == 1 and
                record.enemies[1].guid == "Player-5066-02E07E49" then
            table.remove(store.encounters, index)
            changed = true
        end
    end
    for _, record in ipairs(store.encounters) do
        if record.id == 142 and record.timestamp == 1791171493 and
                record.playerGUID == "Player-5066-01722C84" and not record.confirmedSweepRepair then
            if not record.playerDied or record.enemyDeaths ~= 3 then return false end
            local latest, returning = 0, nil
            for _, enemy in ipairs(record.enemies or {}) do
                if not enemy.died or not enemy.killingBlow or not enemy.killedAt then return false end
                latest = math.max(latest, enemy.killedAt)
                if enemy.guid == "Player-5066-02E07E49" then returning = enemy end
            end
            if not returning or not record.playerDiedAt or record.playerDiedAt <= latest + 6 then return false end
            local boundary = latest + 6
            record.confirmedSweepRepair = {originalDuration = record.duration, originalEndedAt = record.endedAt,
                originalPlayerDiedAt = record.playerDiedAt, originalResultKey = record.resultKey}
            record.playerDied, record.playerDiedAt = false, nil
            record.duration, record.endedAt = boundary, record.timestamp + boundary
            record.endReason, record.completedSoloSweep = "all-enemies-dead", 3
            record.resultLabel, record.resultKey = "1v3 VICTORY", "outnumbered_victory"
            return true
        end
    end
    return changed
end

-- User-confirmed latest fall death, repaired in memory on reload.
function DP.RepairColdbullyFall(store)
    if not store or store.confirmedColdbullyFallRepair then return end
    local latest
    for _,record in ipairs(store.encounters or {}) do
        if record.playerDied and (not latest or (record.timestamp or 0)>(latest.timestamp or 0)) then latest=record end
    end
    local enemy=latest and latest.enemies and latest.enemies[1]
    if latest and latest.playerGUID=="Player-5066-01722C84" and #latest.enemies==1 and
            enemy and tostring(enemy.name):lower():match("^[^-]+")=="coldbully" then
        latest.playerDeathCause="FALLING"
        latest.resultLabel,latest.resultKey="FALL DAMAGE","fall_damage"
        latest.correctionSource="user-confirmed-fall-damage"
        store.confirmedColdbullyFallRepair={id=latest.id,timestamp=latest.timestamp}
    end
end
