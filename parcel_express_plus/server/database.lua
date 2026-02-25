ParcelDB = ParcelDB or {}

local function levelFromDeliveries(total)
    local lvl, title = 1, 'مبتدئ'
    for _, item in ipairs(Shared.Levels) do
        if total >= item.minDeliveries then
            lvl = item.level
            title = item.title
        end
    end
    return lvl, title
end

function ParcelDB.ensurePlayer(citizenid)
    local row = MySQL.single.await('SELECT citizenid FROM parcel_express_stats WHERE citizenid = ?', { citizenid })
    if row then return end

    MySQL.insert.await('INSERT INTO parcel_express_stats (citizenid, total_delivered, total_earnings, rating, level, level_title) VALUES (?, 0, 0, 5.0, 1, ?)', {
        citizenid,
        Shared.Levels[1].title
    })
end

function ParcelDB.getStats(citizenid)
    ParcelDB.ensurePlayer(citizenid)
    return MySQL.single.await('SELECT * FROM parcel_express_stats WHERE citizenid = ?', { citizenid })
end

function ParcelDB.updateStats(citizenid, delivered, earning, newRating)
    local current = ParcelDB.getStats(citizenid)
    local totalDelivered = current.total_delivered + delivered
    local totalEarnings = current.total_earnings + earning
    local rating = tonumber(('%0.2f'):format(((current.rating * current.total_delivered) + newRating) / math.max(1, totalDelivered)))
    local level, title = levelFromDeliveries(totalDelivered)

    MySQL.update.await([[
        UPDATE parcel_express_stats
        SET total_delivered = ?, total_earnings = ?, rating = ?, level = ?, level_title = ?, updated_at = CURRENT_TIMESTAMP
        WHERE citizenid = ?
    ]], {
        totalDelivered,
        totalEarnings,
        rating,
        level,
        title,
        citizenid
    })

    return {
        delivered = totalDelivered,
        earnings = totalEarnings,
        rating = rating,
        level = level,
        levelTitle = title
    }
end

function ParcelDB.getTodayProfit()
    local row = MySQL.single.await('SELECT COALESCE(SUM(payout), 0) AS total FROM parcel_express_logs WHERE DATE(created_at) = CURRENT_DATE', {})
    return row and row.total or 0
end

function ParcelDB.logPayout(citizenid, routeId, payout, details)
    MySQL.insert.await('INSERT INTO parcel_express_logs (citizenid, route_id, payout, details) VALUES (?, ?, ?, ?)', {
        citizenid,
        routeId,
        payout,
        json.encode(details)
    })
end

function ParcelDB.resetStats(citizenid)
    MySQL.update.await('UPDATE parcel_express_stats SET total_delivered = 0, total_earnings = 0, rating = 5.0, level = 1, level_title = ? WHERE citizenid = ?', {
        Shared.Levels[1].title,
        citizenid
    })
end
