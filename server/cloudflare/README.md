# خادم Cloudflare Workers + D1

نسخة cloudflare من خادم Khold تعمل على شبكة Cloudflare العالمية دون تشغيل جهازك.
تستخدم نفس مسارات `server/server.py`، لذا يكفي تغيير **عنوان الخادم** في اللعبة.

## المتطلبات

- حساب Cloudflare مجاني.
- Node.js 20 أو أحدث (يأتي معه `npx`).

## النشر لأول مرة

من مجلد `server/cloudflare`:

```powershell
npx wrangler login
npx wrangler d1 create khold-levels
```

سينسخ الأمر الأخير معرّفًا مثل `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`.
ضعه في `wrangler.toml` بدل `REPLACE_WITH_YOUR_D1_DATABASE_ID`.

ثم أنشئ الجداول وانشر:

```powershell
npx wrangler d1 migrations apply khold-levels --remote
npx wrangler deploy
```

سيطبع `wrangler` رابطًا مثل:

```text
https://khold-levels.<account>.workers.dev
```

افتح اللعبة → «مراحل الإنترنت» → ضع الرابط في حقل **عنوان الخادم** واضغط **اتصال**.
هذا الرابط عام ويمكن مشاركته مع اللاعبين.

## التطوير المحلي

```powershell
npx wrangler d1 migrations apply khold-levels --local
npx wrangler dev --local --port 8788
```

قاعدة البيانات المحلية تُحفظ في `.wrangler/` وهي مستثناة من Git.

## النشر التلقائي من GitHub

أضف في إعدادات المستودع (`Settings → Secrets and variables → Actions`):

| الاسم | النوع | القيمة |
|---|---|---|
| `CLOUDFLARE_API_TOKEN` | Secret | توكن بصلاحيات **Workers Scripts:Edit** و **D1:Edit** |
| `CLOUDFLARE_ACCOUNT_ID` | Secret | معرّف الحساب من لوحة Cloudflare |
| `CLOUDFLARE_DEPLOY` | Variable | `true` |

بعد إضافة المتغير يعمل `.github/workflows/deploy-worker.yml` عند كل تعديل في
`server/cloudflare/`، ويطبّق الترحيلات ثم ينشر Worker.

لإنشاء التوكن: `My Profile → API Tokens → Create Token → Custom Token`،
وأضف الصلاحيات أعلاه وحدّد حسابك.

## الفروق عن خادم Python

- لا حاجة لخادم دائم أو نسخ احتياطي يدوي؛ D1 مُدار من Cloudflare.
- حد الطلبات والحماية متوفران في لوحة Cloudflare (WAF/Rate Limiting).
- التقييمات والبلاغات مرتبطة بمعرّف الجهاز، وإذا غاب يُستخدم عنوان IP.
- سياسة الإخفاء: ثلاثة بلاغات من أجهزة مختلفة تخفي المرحلة.

## حدود الخطة المجانية

- Workers: 100,000 طلب/يوم.
- D1: 5 ملايين صف مقروء/يوم و100,000 صف مكتوب/يوم تقريبًا.
- هذا أكثر من كافٍ للبداية، ويمكن ترقية الخطة عند النمو.
