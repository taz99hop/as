# qb-fbi

Advanced FBI roleplay job for QBCore + qb-target.

## Features
- Secret identity toggle: `/fbi undercover`.
- FBI-only classified case management (NUI).
- Surveillance requests: phone tracing and vehicle bugging with cooldowns.
- Multi-stage cinematic raid flow with command approval stage control.
- Specialized internal roles:
  - Intelligence Analyst
  - Field Agent
  - HRT Operator
  - Regional Lead
- Federal-level NPC threat files for live events.
- Agent count balance cap, operation logs, and restricted access gates.

## Dependencies
- `qb-core`
- `qb-target`
- `oxmysql`

## Installation
1. Put the folder in your resources directory.
2. Ensure dependency order in `server.cfg`:
   ```cfg
   ensure qb-core
   ensure qb-target
   ensure qb-fbi
   ```
3. Add FBI job in your QBCore jobs table with 4 grades (0-3).
4. Restart server.

## Notes
- Cases are persisted to `server/cases.json` in the resource.
- This package is a production-ready foundation and can be expanded with real MDT, camera feeds, and judge integrations.

## توضيح الملاحظات المهمة (What this means)

### 1) "السكربت أساس قوي لكنه ليس MDT كامل"
المقصود أن السكربت الحالي يوفّر نواة ممتازة لوظيفة FBI (قضايا، مداهمات، صلاحيات، تنصّت، لوحة NUI)،
لكن ليس نظام MDT متكامل مثل أنظمة الشرطة المتقدمة التي تحتوي على:
- ربط مباشر مع سجلات المواطنين/المركبات من قاعدة البيانات.
- بحث متقدم مع فلاتر متعددة وسجل أوامر قضائي كامل.
- نظام مرفقات واسع مع صلاحيات تفصيلية جدًا لكل إجراء إداري.

### 2) "موافقات التنصّت currently pending"
في النسخة الحالية، عند طلب `phoneTrace` أو `bugPlant` يتم:
- تسجيل الطلب في لوق القضية كـ "pending lead authorization".
- إرسال تنبيه بأن الموافقة من القائد مطلوبة.

لكن لا يوجد بعد "سير موافقات كامل" (Approve/Reject workflow) داخل الواجهة نفسها،
أي أن الطلب لا يتحول تلقائيًا إلى تنفيذ نهائي بمجرد الضغط من واجهة مخصصة.

### 3) "الوظيفة تعتمد على job = fbi وتطابق أسماء الرتب"
السكربت يقرأ اسم الوظيفة والرتب من الإعدادات. لذلك يجب أن تكون متطابقة حرفيًا:
- اسم الوظيفة: `fbi` (من `Config.JobName`).
- أسماء الرتب الداخلية: `analyst`, `field_agent`, `hrt`, `regional_lead` (من `Config.Grades` + `Config.Permissions`).

إذا غيّرت الأسماء داخل `qb-core/shared/jobs.lua` بدون تحديث `qb-fbi/shared/config.lua`،
فستتعطل الصلاحيات أو تتصرف بشكل خاطئ.

### مثال صحيح للربط
```lua
['fbi'] = {
    label = 'Federal Bureau of Investigation',
    grades = {
        ['0'] = { name = 'analyst' },
        ['1'] = { name = 'field_agent' },
        ['2'] = { name = 'hrt' },
        ['3'] = { name = 'regional_lead', isboss = true },
    },
}
```

## خارطة تطوير احترافية (مميزات أقوى ليصبح النظام "كامل مكمل")

### 1) MDT فدرالي كامل (Tier-1)
- قاعدة بيانات فعلية للقضايا بدل JSON (جداول: cases, evidence, warrants, approvals, raids, chain_of_custody).
- بحث موحّد عن: مواطن / مركبة / لوحة / سلاح / رقم هاتف / حسابات مالية.
- Workflow كامل للقضية: Draft -> Intelligence -> Legal Review -> Approved Action -> Court -> Archived.
- صلاحيات دقيقة جدًا (RBAC) لكل إجراء: عرض/تعديل/اعتماد/إغلاق/حذف.

### 2) نظام الموافقات الذكي (Tier-1)
- شاشة "Pending Approvals" للقائد تتضمن Approve / Reject / Request More Info.
- كل طلب تنصت أو اقتحام يحتاج:
  - سبب قانوني (Probable Cause)
  - رقم قضية
  - مدة صلاحية الإذن
- Audit Log غير قابل للتلاعب لكل قرار (من وافق، متى، لماذا).

### 3) أوامر قضائية (Warrants) + قاضٍ فدرالي (Tier-1)
- أوامر تفتيش/قبض/تنصت رقمية مرتبطة بالقضية.
- قاضي NPC أو لاعب يوقع إلكترونيًا داخل الواجهة.
- انتهاء تلقائي لصلاحية الإذن + تنبيه قبل الانتهاء.

### 4) Chain of Custody للأدلة (Tier-1)
- كل دليل له بصمة زمنية (Evidence ID) ومسار انتقال كامل.
- منع استخدام أي دليل بالمحكمة إذا انكسر التسلسل.
- دعم مرفقات: صور، فيديو، تسجيلات، ملفات صوت.

### 5) مراقبة متقدمة (Tier-2)
- تنصت هاتف فعلي بحدود زمنية وبتأخير تجهيز.
- زرع أجهزة تتبع GPS في مركبة/هاتف مع بطارية ونطاق إشارة.
- غرفة مراقبة كاميرات مع قنوات متعددة + تسجيل قصير (Replay).

### 6) عمليات ميدانية تكتيكية (Tier-2)
- Planner للمداهمة: نقاط دخول، فرق Alpha/Bravo، قواعد اشتباك ROE.
- تجهيز مسبق للمعدات حسب الدور (Analyst/Field/HRT).
- After Action Report إلزامي مع تقييم نجاح/KPI.

### 7) نظام استخبارات حي (Tier-2)
- شبكات NPC إجرامية ديناميكية تتوسع تلقائيًا حسب نشاط السيرفر.
- مولّد أحداث سرية: تهريب/اختطاف/خلية/تمويل.
- Heat Level لكل منظمة يفتح تحقيقات أعلى مستوى.

### 8) التكامل مع اقتصاد السيرفر (Tier-3)
- تتبع غسل الأموال وربط المعاملات المشبوهة بالقضايا.
- تجميد أصول/مصادرة ممتلكات بأمر قضائي.
- ميزانية قسم FBI وتكاليف العمليات (توازن RP ممتاز).

### 9) التدريب والتقييم الداخلي (Tier-3)
- أكاديمية FBI: اختبارات رماية/تحقيق/تفاوض.
- نظام Certifications (SWAT, Cyber, Financial Crimes).
- إنذارات وعقوبات داخلية عند سوء استخدام الصلاحيات.

### 10) أمن وتشغيل Production-Grade (Tier-3)
- Rate limiting للأحداث الحساسة + صلاحيات Server-side فقط.
- تشفير/توقيع للمرفقات الحساسة داخل قاعدة البيانات.
- Backup/Restore تلقائي + لوحة مراقبة أداء.

### Quick Wins (تنفيذ سريع عالي الأثر)
1. نقل القضايا من `server/cases.json` إلى DB.
2. إضافة جدول approvals + واجهة approve/reject.
3. إضافة warrants مرتبطة بالقضايا.
4. تفعيل chain of custody للأدلة.
5. توسيع واجهة Ops إلى Runbook كامل للمداهمات.

## إضافات جديدة مطبقة الآن
- ✅ تعريب واجهة NUI بالكامل (التبويبات، النماذج، الحالات، الأزرار).
- ✅ إضافة تبويب "الموافقات" داخل اللوحة مع عرض الطلبات المعلقة/المقبولة/المرفوضة.
- ✅ تنفيذ Workflow موافقات كامل لطلبات:
  - `phoneTrace`
  - `bugPlant`
  - `raidStart`
- ✅ القائد يمكنه الآن "موافقة / رفض" الطلب مباشرة من الواجهة مع ملاحظة قرار.
- ✅ حفظ طلبات الموافقة بشكل دائم داخل `server/approvals.json`.
- ✅ إضافة أسماء هوية مستعارة متنوعة للعناصر المتخفية بدل الاسم الحقيقي.

### آلية العمل الجديدة
1. العميل يرسل طلب عملية مع سبب قانوني.
2. إذا يحتاج الطلب موافقة قيادة، ينزل في تبويب "الموافقات" بحالة `pending`.
3. القائد الإقليمي يراجع الطلب ويضغط:
   - موافقة → يتم تنفيذ العملية وتحديث Logs.
   - رفض → يتم توثيق الرفض وسببه في القضية.
4. كل التحديثات تنعكس مباشرة على لوحة كل عناصر FBI.

