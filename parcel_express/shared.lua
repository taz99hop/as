Shared = Shared or {}

Shared.ResourceName = GetCurrentResourceName()
Shared.JobName = 'parcel_express'
Shared.TabletItem = 'tablet'

Shared.Ranks = {
    [0] = { label = 'سائق', manager = false },
    [1] = { label = 'مدير', manager = true }
}

Shared.Animations = {
    carry = {
        dict = 'anim@heists@box_carry@',
        clip = 'idle',
        flag = 49
    },
    place = {
        dict = 'anim@heists@money_grab@briefcase',
        clip = 'put_down_case',
        flag = 48,
        duration = 1700
    }
}

Shared.WeatherImpact = {
    CLEAR = 1.0,
    EXTRASUNNY = 1.0,
    CLOUDS = 0.98,
    OVERCAST = 0.95,
    RAIN = 0.82,
    THUNDER = 0.75,
    CLEARING = 0.88,
    SMOG = 0.92,
    FOGGY = 0.9,
    XMAS = 0.86,
    SNOWLIGHT = 0.84,
    BLIZZARD = 0.7
}

Shared.Levels = {
    { level = 1, minDeliveries = 0, title = 'مبتدئ' },
    { level = 2, minDeliveries = 25, title = 'موصل ناشئ' },
    { level = 3, minDeliveries = 75, title = 'موصل محترف' },
    { level = 4, minDeliveries = 160, title = 'قائد ميداني' },
    { level = 5, minDeliveries = 300, title = 'أسطورة التوصيل' }
}

Shared.NUIActions = {
    OPEN = 'openTablet',
    CLOSE = 'closeTablet',
    UPDATE = 'updateTablet',
    MANAGER = 'updateManager'
}
