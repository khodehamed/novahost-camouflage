# NovaHost Camouflage (Port 80)

یک صفحه وب ساده + نصب Nginx فقط روی **پورت 80**.  
پورت **443 دست نخورده می‌ماند** (برای تانل / REALITY).

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

باید `HTTP/1.1 200` و صفحه **NovaHost** بیاید.

## فایل‌ها

| فایل | توضیح |
|------|--------|
| `install.sh` | نصب Nginx + صفحه روی پورت 80 |
| `index.html` | صفحه camouflage |
| `nginx-80.conf` | نمونه کانفیگ Nginx (پورت 80) |

## پیش‌نمایش لوکال

```bash
python -m http.server 8080
# سپس: http://127.0.0.1:8080/
```
