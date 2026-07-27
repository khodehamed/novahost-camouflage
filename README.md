# NovaHost Camouflage (پورت ۸۰)

یک صفحه وب فارسی (RTL) + نصب Nginx فقط روی **پورت ۸۰**.  
پورت **۴۴۳ دست نخورده می‌ماند** (برای تانل / REALITY).

## نصب یک‌خطی

```bash
curl -fsSL https://raw.githubusercontent.com/khodehamed/novahost-camouflage/main/install.sh | sudo bash
```

اگر `curl | bash` ورودی کیبورد را خراب کرد:

```bash
sudo bash <(curl -fsSL https://raw.githubusercontent.com/khodehamed/novahost-camouflage/main/install.sh)
```

## تست

```bash
curl -I http://SERVER-IP/
curl http://SERVER-IP/ | head
```

باید `HTTP/1.1 200` و صفحه **NovaHost** (فارسی) بیاید.

## فایل‌ها

| فایل | توضیح |
|------|--------|
| `install.sh` | نصب Nginx + صفحه روی پورت ۸۰ |
| `index.html` | صفحه camouflage فارسی |
| `nginx-80.conf` | نمونه کانفیگ Nginx (پورت ۸۰) |

## پیش‌نمایش لوکال

```bash
python -m http.server 8080
# سپس: http://127.0.0.1:8080/
```
