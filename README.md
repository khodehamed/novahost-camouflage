# NovaHost Camouflage (پورت ۸۰)

صفحه وب فارسی (RTL) با موضوع **طراحی سایت** و **ربات تلگرام** + نصب Nginx فقط روی **پورت ۸۰**.  
پورت **۴۴۳ دست نخورده می‌ماند** (برای تانل / REALITY).

اسکریپت نصب قبل از بالا آوردن Nginx، هر فرآیندی که پورت ۸۰ را اشغال کرده (apache، nginx قبلی، caddy، waterwall و غیره) را متوقف/کیل می‌کند.

## نصب یک‌خطی

```bash
curl -fsSL https://raw.githubusercontent.com/khodehamed/novahost-camouflage/main/install.sh | sudo bash
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

## فایل‌ها

| فایل | توضیح |
|------|--------|
| `install.sh` | آزادسازی پورت ۸۰ + نصب Nginx + صفحه camouflage |
| `index.html` | صفحه camouflage فارسی (RTL) |
| `nginx-80.conf` | نمونه کانفیگ Nginx (فقط پورت ۸۰) |

## پیش‌نمایش لوکال

```bash
python -m http.server 8080
# سپس: http://127.0.0.1:8080/
```
