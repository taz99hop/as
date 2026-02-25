-- ضع هذا المقتطف داخل: qb-core/shared/jobs.lua
-- أو في أي ملف يتم تحميله قبل تشغيل السيرفر ويعدل QBShared.Jobs

QBShared = QBShared or {}
QBShared.Jobs = QBShared.Jobs or {}

QBShared.Jobs['parcel_express'] = {
    label = 'Parcel Express',
    defaultDuty = true,
    offDutyPay = false,
    grades = {
        ['0'] = {
            name = 'driver',
            label = 'سائق',
            payment = 90,
            isboss = false
        },
        ['1'] = {
            name = 'manager',
            label = 'مدير',
            payment = 130,
            isboss = true
        }
    }
}

-- ملاحظة:
-- السكربت parcel_express يعتبر الرتبة 1 مدير (grade.level >= 1).
-- لذلك تأكد أن المدير فعلاً على grade 1 أو أعلى.
