ParcelPay = ParcelPay or {}

function ParcelPay.calculate(data)
    local base = Config.Payments.basePerPackage
    local speedBonus = data.fast and Config.Payments.speedBonus or 0
    local urgentBonus = data.urgent and data.fast and Config.Payments.urgentBonus or 0
    local ratingBonus = math.floor((data.rating or 3) * Config.Payments.ratingBonusPerStar)

    local damageFactor = math.max(0, (1000.0 - (data.vehicleBody or 1000.0)) / 1000.0)
    local damagePenalty = math.floor((base + speedBonus + ratingBonus + urgentBonus) * damageFactor * Config.Payments.damagePenaltyPercent)

    local gross = base + speedBonus + ratingBonus + urgentBonus
    local final = math.max(10, gross - damagePenalty)

    return {
        base = base,
        speedBonus = speedBonus,
        urgentBonus = urgentBonus,
        ratingBonus = ratingBonus,
        damagePenalty = damagePenalty,
        total = final
    }
end
