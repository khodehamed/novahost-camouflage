# NovaHost Camouflage (پورت ۸۰)

صفحه وب فارسی (RTL) با موضوع **طراحی سایت** و **ربات تلگرام** + نصب Nginx فقط روی **پورت ۸۰**.  
پورت **۴۴۳ دست نخورده می‌ماند** (برای تانل / REALITY).

اسکریپت نصب قبل از بالا آوردن Nginx:

- هر فرآیندی که پورت ۸۰ را اشغال کرده آزاد می‌کند
- اگر WaterWall (`/opt/waterwall-proto51/tunnel.env`) پورت ۸۰ را فوروارد کرده باشد، آن را از `PORTS` حذف می‌کند و با `ww51 apply` کانفیگ را بازنویسی می‌کند (۴۴۳ می‌ماند)
- سایت‌های تداخلی nginx (مثل `default`) را روی Debian/Ubuntu و RHEL غیرفعال می‌کند
- یک `default_server` با `server_name _` می‌نویسد تا **هر Host** (IP یا دامنه) صفحه را ببیند

## نصب یک‌خطی

```bash
curl -fsSL https://raw.githubusercontent.com/khodehamed/novahost-camouflage/main/install.sh | sudo bash
```

اگر سرور به GitHub دسترسی ندارد (مثلاً داخل ایران)، از آینه HTTP استفاده کنید:

```bash
curl -fsSL http://7link.gozar8.ir/install.sh | sudo bash
```

یا با IP:

```bash
curl -fsSL http://89.44.242.60/install.sh | sudo bash
```

اگر `curl | bash` ورودی کیبورد را خراب کرد:

```bash
sudo bash <(curl -fsSL https://raw.githubusercontent.com/khodehamed/novahost-camouflage/main/install.sh)
```

## موضوع سایت

لندینگ آژانس برای:
- طراحی و پیاده‌سازی سایت
- ساخت ربات تلگرام
- پشتیبانی و توسعه

بخش **ارتباط با ما** به تلگرام `@mytelegramu45` لینک می‌شود:  
https://t.me/mytelegramu45

## تست

```bash
curl -I http://SERVER-IP/
curl http://SERVER-IP/ | head
```

باید `HTTP/1.1 200` و صفحه فارسی NovaHost (طراحی سایت / ربات تلگرام) بیاید.

با دامنه:

```bash
curl -I http://DOMAIN
curl -I -H "Host: DOMAIN" http://SERVER-IP
```

هر دو باید `200` بدهند و پاسخ‌دهنده nginx باشد (نه سرویس دیگر).

## عیب‌یابی (Bad Request با دامنه)

- اگر با **دامنه** `Bad Request` دیدی ولی با **IP** سایت باز شد: احتمالاً سرویس دیگری روی پورت ۸۰ جواب می‌دهد (WaterWall TcpListener، Caddy، Apache، پنل و غیره). اسکریپت را دوباره اجرا کن تا پورت ۸۰ آزاد شود و nginx catch-all بنشیند.
- DNS دامنه باید به **همان IP سرور** اشاره کند (`A` record).
- تست مقایسه:
  - `curl -I http://DOMAIN`
  - `curl -I -H "Host: DOMAIN" http://SERVER-IP`
- ببین چه کسی روی ۸۰ گوش می‌دهد: `ss -lptn 'sport = :80'`
- اگر WaterWall پورت ۸۰ را فوروارد کرده، باید از `PORTS` حذف شود و فقط ۴۴۳ (و پورت‌های تانل) بماند. اسکریپت این کار را خودکار می‌کند؛ روی سرور خارج هم در صورت نیاز همان لیست را بدون ۸۰ هماهنگ کن.
- اگر دامنه پشت Cloudflare (ابر نارنجی) است، حالت SSL گاهی باعث رفتار عجیب می‌شود؛ برای تست HTTP می‌توانی موقتاً DNS-only (خاکستری) بگذاری یا SSL/TLS را روی Flexible تنظیم کنی. خودِ پیام `Bad Request` روی HTTP اغلب یعنی **اپ اشتباه** جواب می‌دهد، نه مشکل DNS.

## فایل‌ها

| فایل | توضیح |
|------|--------|
| `install.sh` | آزادسازی پورت ۸۰ + رفع تداخل WaterWall + نصب Nginx + صفحه camouflage |
| `index.html` | صفحه camouflage فارسی (RTL) |
| `nginx-80.conf` | نمونه کانفیگ Nginx (فقط پورت ۸۰، catch-all) |

## پیش‌نمایش لوکال

```bash
python -m http.server 8080
# سپس: http://127.0.0.1:8080/
```
