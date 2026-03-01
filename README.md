# FiveM Script Starter Tool

أضفت لك أداة ويب بسيطة وجميلة تساعدك تبدأ سكربت FiveM بسرعة:

- تولّد `fxmanifest.lua` تلقائي.
- تولّد ملفات `client/server/shared` الأساسية.
- اختيار Framework (`QBCore` أو `ESX` أو بدون).
- خيارات إضافية مثل `config.lua` و `locales` وواجهة NUI.
- توليد سطر جاهز لـ `server.cfg`.
- عرض حي لكل ملف + تحميل Blueprint بصيغة JSON.

## التشغيل

```bash
cd fivem-script-builder
python3 -m http.server 4173
```

ثم افتح المتصفح على:

`http://localhost:4173`
