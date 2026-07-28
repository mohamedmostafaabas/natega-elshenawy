# natega-elshenawy

بوابة ثابتة للبحث في نتيجة الثانوية العامة بالاسم أو رقم الجلوس.

## الملفات الأساسية

- `index.html`: واجهة الموقع ومحرك البحث.
- `نتيجة ثانوية عامة نظام حديث.xlsx`: قاعدة بيانات النتيجة.
- `favicon.svg`: أيقونة الموقع.
- `vercel.json`: إعدادات النشر والترويسات.
- `deploy.ps1`: رفع المشروع إلى GitHub ونشره على Vercel.

## التشغيل المحلي

افتح `index.html` في Chrome أو Edge ثم اختر ملف Excel يدويًا. عند النشر على Vercel، يحمّل الموقع ملف Excel تلقائيًا من المجلد نفسه.

## النشر

شغّل PowerShell، ثم نفّذ:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
& "$HOME\Downloads\natega\deploy.ps1"
```

> تنبيه: نشر المشروع يجعل ملف Excel متاحًا للعامة من خلال رابط الموقع؛ لذلك لا تنشر بيانات غير مصرح بعرضها.

---

Developed by **Mohamed Mostafa** · Powered = true
