# natega-elshenawy

بوابة بحث في نتيجة الثانوية العامة بالاسم أو رقم الجلوس.

## طريقة العمل

- المتصفح لا يحمّل ملف Excel أو قاعدة البيانات.
- الواجهة ترسل عبارة البحث فقط إلى `/api/search`.
- Vercel Function تبحث داخل قاعدتي SQLite مفهرستين وتعيد النتائج المطابقة فقط.

## النشر

```powershell
Set-Location "$HOME\Downloads\natega"
git add -A
git commit -m "Use server-side indexed result search"
git push origin main
vercel deploy --prod --yes
```

احذف ملف Excel القديم من مجلد المشروع قبل الرفع؛ لم يعد مطلوبًا.
