Config = {}

Config.Debug = false
Config.JobName = Shared.JobName
Config.UseTabletItem = false

Config.Warehouse = {
    duty = vec3(120.72, -3104.89, 5.90),
    vehicleSpawn = vec4(126.35, -3112.61, 5.95, 269.70),
    vehicleReturn = vec3(114.12, -3121.84, 5.90),
    packageLoad = vec3(114.61, -3096.78, 5.90),
    managerDesk = vec3(132.55, -3090.45, 5.89)
}

Config.CompanyVehicle = 'boxville2'
Config.VehiclePlatePrefix = 'PXL'

Config.PackageModel = `prop_cardbordbox_04a`
Config.MinPackages = 5
Config.MaxPackages = 15

Config.RequiredDeliveryDistance = 2.0
Config.PackageDeleteDelay = 3000
Config.UrgentChance = 35
Config.UrgentDuration = 360

Config.Payments = {
    basePerPackage = 95,
    speedBonus = 40,
    ratingBonusPerStar = 15,
    damagePenaltyPercent = 0.35,
    urgentBonus = 70
}

Config.Target = {
    iconVehicle = 'fas fa-truck',
    iconDuty = 'fas fa-id-card',
    iconPackage = 'fas fa-box-open',
    iconDoor = 'fas fa-door-open',
    iconManager = 'fas fa-user-tie'
}

Config.HomeDeliveryPoints = {
    vec4(-153.27, 910.11, 235.65, 318.0),
    vec4(-297.21, 379.85, 112.10, 359.0),
    vec4(-595.62, 393.02, 101.88, 90.0),
    vec4(-763.10, 430.81, 100.18, 30.0),
    vec4(-842.42, 466.88, 87.60, 10.0),
    vec4(-967.08, 510.86, 81.06, 49.0),
    vec4(-997.21, 517.88, 83.63, 45.0),
    vec4(-1097.92, 548.75, 102.63, 26.0),
    vec4(-1223.01, 666.91, 143.10, 312.0),
    vec4(-1337.19, 606.26, 134.38, 281.0),
    vec4(-1452.49, 545.76, 120.80, 36.0),
    vec4(-1502.21, 523.18, 118.27, 287.0),
    vec4(-1607.45, 451.83, 109.02, 357.0),
    vec4(-1667.84, 385.13, 89.35, 4.0),
    vec4(-1804.61, 436.83, 128.83, 184.0),
    vec4(-1932.68, 162.43, 84.65, 115.0),
    vec4(-1899.11, 132.48, 81.98, 117.0),
    vec4(-1976.16, 628.67, 122.68, 251.0),
    vec4(-2014.03, 499.84, 107.17, 70.0),
    vec4(-2285.57, 376.54, 174.47, 178.0),
    vec4(-2304.98, 344.13, 169.08, 102.0),
    vec4(-3037.37, 115.53, 11.61, 304.0),
    vec4(-3093.01, 349.34, 7.54, 174.0),
    vec4(-3205.71, 1155.93, 9.65, 90.0),
    vec4(-171.62, 214.70, 89.83, 177.0),
    vec4(79.12, 486.30, 148.20, 154.0),
    vec4(224.14, 513.53, 140.76, 167.0),
    vec4(315.76, 502.46, 153.18, 196.0),
    vec4(331.42, 465.35, 151.25, 165.0),
    vec4(387.28, 358.91, 102.57, 346.0),
    vec4(84.92, 561.72, 182.76, 343.0),
    vec4(-66.40, 490.27, 144.64, 160.0),
    vec4(-7.79, 468.18, 145.85, 352.0),
    vec4(57.85, 449.95, 146.93, 159.0),
    vec4(119.67, 564.24, 183.96, 3.0),
    vec4(232.11, 672.31, 189.97, 252.0),
    vec4(-400.11, 664.02, 163.83, 74.0),
    vec4(-607.69, 672.20, 151.60, 168.0),
    vec4(-704.97, 589.74, 142.37, 331.0),
    vec4(-852.43, 697.99, 148.95, 97.0)
}

Config.NPCLines = {
    'شكراً! كنت بانتظار الطرد من الصباح.',
    'خدمة ممتازة، بارك الله فيك.',
    'تم الاستلام بنجاح، يومك سعيد.',
    'وصل بسرعة! هذا رائع جداً.'
}

Config.ManagerActions = {
    { key = 'raisePay', label = 'زيادة الراتب الأساسي +10$', value = 10 },
    { key = 'reducePay', label = 'خفض الراتب الأساسي -10$', value = -10 }
}
