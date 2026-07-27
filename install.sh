#!/usr/bin/env bash
set -euo pipefail

# NovaHost camouflage فقط روی پورت 80 (443 دست نخورده)
# استفاده:
#   curl -fsSL https://raw.githubusercontent.com/khodehamed/novahost-camouflage/main/install.sh | sudo bash
#   یا: sudo bash install.sh

WEB_ROOT="${WEB_ROOT:-/var/www/html}"
NGINX_AVAIL="${NGINX_AVAIL:-/etc/nginx/sites-available/camouflage-80}"
NGINX_ENABLED="${NGINX_ENABLED:-/etc/nginx/sites-enabled/camouflage-80}"
WW_ENV="${WW_ENV:-/opt/waterwall-proto51/tunnel.env}"
WW_SERVICE="${WW_SERVICE:-waterwall-proto51}"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "با دسترسی root اجرا کنید: sudo bash $0"
  exit 1
fi

# اگر WaterWall پورت 80 را فوروارد می‌کند، آن را از PORTS حذف کن (443 بماند)
# سپس کانفیگ را با ww51 apply بازنویسی کن تا دوباره 80 را نگیرد.
drop_waterwall_port_80() {
  if [[ ! -f "$WW_ENV" ]]; then
    return 0
  fi

  # shellcheck disable=SC1090
  set +u
  # shellcheck disable=SC1090
  source "$WW_ENV"
  set -u

  local ports="${PORTS:-}"
  if [[ -z "$ports" ]]; then
    return 0
  fi

  # آیا 80 در لیست PUBLIC هست؟
  local has80=0
  local p new_ports=""
  for p in $(echo "$ports" | tr ',;' ' '); do
    p="$(echo "$p" | tr -d '[:space:]')"
    [[ -z "$p" ]] && continue
    if [[ "$p" == "80" ]]; then
      has80=1
      continue
    fi
    new_ports="${new_ports:+$new_ports }$p"
  done

  if [[ "$has80" -ne 1 ]]; then
    # ممکن است JSON قدیمی هنوز 80 را داشته باشد
    if command -v ss >/dev/null 2>&1 \
      && ss -lptn 'sport = :80' 2>/dev/null | grep -qiE 'waterwall|Waterwall'; then
      echo "هشدار: WaterWall هنوز روی 80 گوش می‌دهد ولی PORTS شامل 80 نیست — apply مجدد..."
      systemctl stop "$WW_SERVICE" 2>/dev/null || true
      if command -v ww51 >/dev/null 2>&1; then
        ww51 apply || true
      elif [[ -f /opt/waterwall-proto51/install.sh ]]; then
        bash /opt/waterwall-proto51/install.sh apply || true
      else
        systemctl start "$WW_SERVICE" 2>/dev/null || true
      fi
      sleep 1
    fi
    return 0
  fi

  echo "WaterWall: پورت 80 از PUBLIC حذف می‌شود (443 و بقیه حفظ می‌شوند)..."
  echo "  PORTS قبلی: $ports"
  echo "  PORTS جدید: ${new_ports:-"(خالی)"}"

  local tmp
  tmp="$(mktemp)"
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" =~ ^PORTS= ]]; then
      echo "PORTS=\"${new_ports}\""
    else
      printf '%s\n' "$line"
    fi
  done < "$WW_ENV" > "$tmp"
  mv -f "$tmp" "$WW_ENV"
  chmod 600 "$WW_ENV"

  systemctl stop "$WW_SERVICE" 2>/dev/null || true
  sleep 1

  if command -v ww51 >/dev/null 2>&1; then
    ww51 apply || true
  elif [[ -f /opt/waterwall-proto51/install.sh ]]; then
    bash /opt/waterwall-proto51/install.sh apply || true
  else
    systemctl start "$WW_SERVICE" 2>/dev/null || true
    echo "هشدار: ww51 پیدا نشد — WaterWall را دستی بدون پورت 80 تنظیم کنید:"
    echo "  sudo ww51 ports   # یا Edit و 80 را از لیست حذف کنید"
  fi

  sleep 1
  echo "توجه: WaterWall نباید روی 80 گوش دهد؛ پورت 443 برای تانل دست نخورده است."
  echo "اگر سرور خارج (Kharej) هم PORTS شامل 80 دارد، آنجا هم 80 را حذف کنید."
}

# آزادسازی پورت 80 — پورت 443 هرگز دست نخورده می‌ماند
free_port_80() {
  echo "در حال آزادسازی پورت 80 ..."

  # اول WaterWall را از 80 جدا کن (systemd با Restart=always دوباره می‌آید اگر JSON هنوز 80 داشته باشد)
  drop_waterwall_port_80

  # توقف سرویس‌های رایج وب روی پورت 80 (در صورت وجود)
  local svc
  for svc in apache2 httpd apache caddy lighttpd x-ui 3x-ui; do
    if command -v systemctl >/dev/null 2>&1; then
      if systemctl list-unit-files "${svc}.service" >/dev/null 2>&1 \
        || systemctl status "${svc}.service" >/dev/null 2>&1; then
        # فقط اگر واقعاً روی 80 گوش می‌دهند متوقف نکن پنل را بی‌دلیل؛
        # برای apache/caddy معمولاً stop امن است
        case "$svc" in
          x-ui|3x-ui)
            if command -v ss >/dev/null 2>&1 && ss -lptn 'sport = :80' 2>/dev/null | grep -qiE 'x-ui|xray|sing'; then
              echo "هشدار: به نظر می‌رسد $svc روی 80 باشد — فقط شنونده 80 کیل می‌شود (سرویس پنل خاموش نمی‌شود)."
            fi
            ;;
          *)
            systemctl stop "${svc}.service" 2>/dev/null || true
            ;;
        esac
      fi
    fi
    if command -v service >/dev/null 2>&1; then
      case "$svc" in
        x-ui|3x-ui) ;;
        *) service "$svc" stop 2>/dev/null || true ;;
      esac
    fi
  done

  # nginx را موقتاً stop کن تا بتوانیم کانفیگ را عوض کنیم (بعداً دوباره استارت می‌شود)
  if command -v systemctl >/dev/null 2>&1; then
    systemctl stop nginx 2>/dev/null || true
  fi
  if command -v service >/dev/null 2>&1; then
    service nginx stop 2>/dev/null || true
  fi

  # نمایش فرآیندهای روی پورت 80 (برای لاگ)
  if command -v ss >/dev/null 2>&1; then
    echo "شنونده‌های فعلی :80 :"
    ss -lptn 'sport = :80' 2>/dev/null || true
  elif command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP:80 -sTCP:LISTEN 2>/dev/null || true
  fi

  # کشتن هر فرآیندی که هنوز به 80/tcp چسبیده (شامل waterwall و غیره)
  if command -v fuser >/dev/null 2>&1; then
    fuser -k 80/tcp 2>/dev/null || true
  elif command -v lsof >/dev/null 2>&1; then
    # shellcheck disable=SC2046
    kill -9 $(lsof -t -iTCP:80 -sTCP:LISTEN 2>/dev/null) 2>/dev/null || true
  elif command -v ss >/dev/null 2>&1; then
    local pids
    pids="$(ss -lptn 'sport = :80' 2>/dev/null | sed -n 's/.*pid=\([0-9]\+\).*/\1/p' | sort -u || true)"
    if [[ -n "${pids}" ]]; then
      # shellcheck disable=SC2086
      kill -9 ${pids} 2>/dev/null || true
    fi
  fi

  sleep 1

  if command -v ss >/dev/null 2>&1 && ss -lptn 'sport = :80' 2>/dev/null | grep -q ':80'; then
    echo "هشدار: هنوز چیزی روی پورت 80 گوش می‌دهد؛ تلاش مجدد با fuser..."
    fuser -k 80/tcp 2>/dev/null || true
    sleep 1
    if ss -lptn 'sport = :80' 2>/dev/null | grep -qiE 'waterwall|Waterwall'; then
      echo "هشدار: WaterWall دوباره 80 را گرفته — سرویس را stop و apply می‌کنیم."
      drop_waterwall_port_80
      fuser -k 80/tcp 2>/dev/null || true
      sleep 1
    fi
  fi

  echo "پورت 80 آماده است (443 دست نخورده)."
}

# حذف/غیرفعال‌سازی سایت‌های nginx که روی 80 تداخل دارند (Debian + RHEL)
disable_conflicting_nginx_sites() {
  echo "در حال پاک‌سازی کانفیگ‌های تداخلی nginx روی پورت 80 ..."

  rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true

  # RHEL/CentOS/Alma پیش‌فرض
  if [[ -f /etc/nginx/conf.d/default.conf ]]; then
    if grep -Eq 'listen\s+\[?::\]?:?80|listen\s+80' /etc/nginx/conf.d/default.conf 2>/dev/null; then
      mv -f /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.bak-camouflage 2>/dev/null || true
    fi
  fi

  local f base
  for f in /etc/nginx/sites-enabled/* /etc/nginx/conf.d/*.conf; do
    [[ -e "$f" ]] || continue
    base="$(basename "$f")"
    case "$base" in
      camouflage-80|camouflage-80.conf) continue ;;
    esac
    if grep -Eq 'listen[[:space:]]+\[?::\]?:?80|listen[[:space:]]+80' "$f" 2>/dev/null; then
      echo "  غیرفعال: $f"
      if [[ -L "$f" ]]; then
        rm -f "$f"
      else
        mv -f "$f" "${f}.bak-camouflage" 2>/dev/null || rm -f "$f"
      fi
    fi
  done

  # اگر داخل nginx.conf یک server بلاک default روی 80 باشد که Host ناشناس را 400 می‌کند،
  # آن را دست نمی‌زنیم مگر اینکه فقط sites/conf.d را include کند (حالت رایج).
}

write_nginx_camouflage_conf() {
  local dest="$1"
  cat > "$dest" <<'NGINX'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    root /var/www/html;
    index index.html;
    server_tokens off;
    absolute_redirect off;
    underscores_in_headers on;

    if ($request_method !~ ^(GET|HEAD|POST)$) {
        return 405;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }

    location ~ /\. {
        deny all;
    }

    access_log /var/log/nginx/camouflage.access.log;
    error_log  /var/log/nginx/camouflage.error.log warn;
}
NGINX
}

free_port_80

export DEBIAN_FRONTEND=noninteractive
if command -v apt-get >/dev/null 2>&1; then
  apt-get update -y
  apt-get install -y nginx psmisc
elif command -v dnf >/dev/null 2>&1; then
  dnf install -y nginx psmisc
elif command -v yum >/dev/null 2>&1; then
  yum install -y nginx psmisc
else
  echo "مدیر بسته پشتیبانی‌شده پیدا نشد (apt/dnf/yum)."
  exit 1
fi

# بعد از نصب پکیج‌ها دوباره پورت 80 را آزاد کن (بعضی پکیج‌ها nginx را بالا می‌آورند)
free_port_80

mkdir -p "$WEB_ROOT"

# صفحه camouflage فارسی (RTL) — طراحی سایت و ربات تلگرام
cat > "$WEB_ROOT/index.html" <<'HTML'
<!DOCTYPE html>
<html lang="fa" dir="rtl">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <meta name="description" content="نواهاست — طراحی سایت حرفه‌ای و ساخت ربات تلگرام برای کسب‌وکارها." />
  <title>NovaHost — طراحی سایت و ربات تلگرام</title>
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
  <link href="https://fonts.googleapis.com/css2?family=Vazirmatn:wght@400;500;700&display=swap" rel="stylesheet" />
  <style>
    :root {
      --bg: #101820;
      --bg2: #1a2a35;
      --ink: #eef4f7;
      --muted: #9db0bc;
      --accent: #2eb8a0;
      --accent2: #7fd4c3;
      --line: rgba(238, 244, 247, 0.12);
      --soft: rgba(255, 255, 255, 0.04);
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      min-height: 100vh;
      font-family: "Vazirmatn", Tahoma, sans-serif;
      color: var(--ink);
      background:
        radial-gradient(900px 520px at 85% -15%, rgba(46, 184, 160, 0.22), transparent 55%),
        radial-gradient(700px 420px at 5% 5%, rgba(127, 212, 195, 0.1), transparent 50%),
        linear-gradient(165deg, var(--bg), var(--bg2) 55%, #0c141a);
      line-height: 1.75;
    }
    .wrap { width: min(1080px, calc(100% - 2.5rem)); margin: 0 auto; }
    header {
      display: flex; align-items: center; justify-content: space-between;
      padding: 1.4rem 0 1rem; border-bottom: 1px solid var(--line);
    }
    .logo { font-size: 1.35rem; font-weight: 700; letter-spacing: -0.02em; }
    .logo span { color: var(--accent); }
    nav { display: flex; gap: 1.25rem; color: var(--muted); font-size: 0.95rem; }
    nav a { color: inherit; text-decoration: none; }
    nav a:hover { color: var(--ink); }
    .hero { padding: 4.5rem 0 3.5rem; max-width: 740px; }
    .eyebrow {
      display: inline-block; margin-bottom: 1rem; color: var(--accent2);
      font-size: 0.85rem; font-weight: 500;
    }
    h1 {
      font-size: clamp(1.9rem, 4.5vw, 2.8rem); line-height: 1.35;
      font-weight: 700; margin-bottom: 1rem;
    }
    .lead { color: var(--muted); font-size: 1.05rem; max-width: 54ch; margin-bottom: 1.8rem; }
    .actions { display: flex; flex-wrap: wrap; gap: 0.75rem; }
    .btn {
      appearance: none; border: 0; border-radius: 10px; padding: 0.85rem 1.2rem;
      font: inherit; font-weight: 500; cursor: pointer; text-decoration: none;
    }
    .btn-primary { background: linear-gradient(135deg, var(--accent), #1f9a86); color: #042018; }
    .btn-ghost { background: transparent; color: var(--ink); border: 1px solid var(--line); }
    .section-title { font-size: 1.35rem; margin-bottom: 1rem; }
    .grid {
      display: grid; grid-template-columns: repeat(3, 1fr); gap: 1rem; padding: 0.5rem 0 3rem;
    }
    .card {
      border: 1px solid var(--line); border-radius: 16px; padding: 1.25rem;
      background: var(--soft);
    }
    .card h3 { font-size: 1.05rem; margin-bottom: 0.45rem; }
    .card p { color: var(--muted); font-size: 0.95rem; }
    .contact {
      border: 1px solid var(--line); border-radius: 18px; padding: 1.6rem 1.4rem;
      margin-bottom: 3rem;
      background:
        linear-gradient(135deg, rgba(46, 184, 160, 0.1), transparent 55%),
        var(--soft);
    }
    .contact p { color: var(--muted); margin: 0.6rem 0 1.2rem; max-width: 55ch; }
    .contact .tg {
      display: inline-flex; align-items: center; gap: 0.45rem;
      color: var(--accent2); text-decoration: none; font-weight: 500; font-size: 1.05rem;
    }
    .contact .tg:hover { color: var(--ink); }
    footer {
      border-top: 1px solid var(--line); padding: 1.4rem 0 2rem; color: var(--muted);
      font-size: 0.9rem; display: flex; justify-content: space-between; gap: 1rem; flex-wrap: wrap;
    }
    footer a { color: var(--accent2); text-decoration: none; }
    @media (max-width: 800px) {
      nav { display: none; }
      .grid { grid-template-columns: 1fr; }
      .hero { padding-top: 3rem; }
    }
  </style>
</head>
<body>
  <div class="wrap">
    <header>
      <div class="logo">Nova<span>Host</span></div>
      <nav>
        <a href="#services">خدمات</a>
        <a href="#bots">ربات تلگرام</a>
        <a href="#contact">ارتباط با ما</a>
      </nav>
    </header>
    <main>
      <section class="hero">
        <p class="eyebrow">آژانس طراحی وب و اتوماسیون تلگرام</p>
        <h1>طراحی سایت و ربات تلگرام، دقیق و آماده رشد کسب‌وکار شما.</h1>
        <p class="lead">
          نواهاست وب‌سایت‌های سریع و مدرن می‌سازد و ربات‌های تلگرام را برای فروش،
          پشتیبانی و اتوماسیون فرآیندها پیاده‌سازی می‌کند.
        </p>
        <div class="actions">
          <a class="btn btn-primary" href="#services">مشاهده خدمات</a>
          <a class="btn btn-ghost" href="#contact">ارتباط با ما</a>
        </div>
      </section>
      <h2 class="section-title" id="services">خدمات ما</h2>
      <section class="grid">
        <article class="card">
          <h3>طراحی سایت</h3>
          <p>طراحی و پیاده‌سازی سایت شرکتی، فروشگاهی و لندینگ با ظاهر حرفه‌ای و تجربه کاربری روان.</p>
        </article>
        <article class="card" id="bots">
          <h3>ربات تلگرام</h3>
          <p>ساخت ربات فروش، پشتیبانی، اطلاع‌رسانی و اتصال به درگاه پرداخت یا سیستم داخلی شما.</p>
        </article>
        <article class="card">
          <h3>پشتیبانی و توسعه</h3>
          <p>به‌روزرسانی، بهینه‌سازی سرعت، افزودن امکانات جدید و نگهداری مداوم پروژه.</p>
        </article>
      </section>
      <section class="contact" id="contact">
        <h2 class="section-title">ارتباط با ما</h2>
        <p>
          برای سفارش طراحی سایت، ساخت ربات تلگرام یا مشاوره رایگان، از طریق تلگرام پیام دهید.
        </p>
        <a class="tg" href="https://t.me/mytelegramu45" target="_blank" rel="noopener noreferrer">
          تلگرام: @mytelegramu45
        </a>
      </section>
    </main>
    <footer>
      <span>© ۱۴۰۵ نواهاست — طراحی سایت و ربات تلگرام</span>
      <span><a href="https://t.me/mytelegramu45">@mytelegramu45</a></span>
    </footer>
  </div>
</body>
</html>
HTML

mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled /etc/nginx/conf.d /var/log/nginx

disable_conflicting_nginx_sites

write_nginx_camouflage_conf "$NGINX_AVAIL"
ln -sfn "$NGINX_AVAIL" "$NGINX_ENABLED"

# مسیر RHEL / وقتی sites-enabled در nginx.conf نیست
if [[ -f /etc/nginx/nginx.conf ]]; then
  if ! grep -q 'sites-enabled' /etc/nginx/nginx.conf; then
    write_nginx_camouflage_conf /etc/nginx/conf.d/camouflage-80.conf
  else
    # حتی روی Debian هم یک کپی در conf.d نگذار مگر لازم باشد؛ فقط ensure enabled
    :
  fi
  # همیشه یک کپی قابل‌اتکا در conf.d برای توزیع‌هایی که هر دو را include می‌کنند
  if grep -q 'conf.d/\*\.conf' /etc/nginx/nginx.conf || grep -q 'conf.d/*.conf' /etc/nginx/nginx.conf; then
    # اگر sites-enabled استفاده می‌شود، از دوبل default_server جلوگیری کن
    if grep -q 'sites-enabled' /etc/nginx/nginx.conf; then
      rm -f /etc/nginx/conf.d/camouflage-80.conf 2>/dev/null || true
    else
      write_nginx_camouflage_conf /etc/nginx/conf.d/camouflage-80.conf
    fi
  fi
fi

# قبل از استارت نهایی، دوباره هر اشغال‌کننده پورت 80 را پاک کن
free_port_80

nginx -t
systemctl enable nginx
systemctl restart nginx

# اگر WaterWall بعد از استارت nginx دوباره 80 را دزدید، یک‌بار دیگر اصلاح کن
if command -v ss >/dev/null 2>&1; then
  if ss -lptn 'sport = :80' 2>/dev/null | grep -qiE 'waterwall|Waterwall'; then
    echo "هشدار: بعد از استارت، WaterWall دوباره روی 80 آمد — اصلاح مجدد..."
    drop_waterwall_port_80
    fuser -k 80/tcp 2>/dev/null || true
    sleep 1
    systemctl restart nginx
  fi
fi

IP="$(curl -4 -fsS --max-time 5 ifconfig.me 2>/dev/null || curl -4 -fsS --max-time 5 api.ipify.org 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}' || echo 'SERVER-IP')"

echo
echo "تمام — سایت camouflage روی پورت 80 (catch-all برای هر Host)"
echo "آدرس IP:     http://${IP}/"
echo "با دامنه:    http://YOUR-DOMAIN/   (DNS باید به همین IP اشاره کند)"
echo "پورت 443 برای تانل دست نخورده ماند."
echo
echo "تست:"
echo "  curl -I http://127.0.0.1/"
echo "  curl -I -H \"Host: YOUR-DOMAIN\" http://${IP}/"
echo "  curl -I http://YOUR-DOMAIN/"
echo
echo "اگر هنوز Bad Request دیدی: معمولاً سرویس دیگری (WaterWall/Caddy/…) روی 80 جواب می‌دهد."
echo "  ss -lptn 'sport = :80'"
echo "  و اسکریپت را دوباره اجرا کن. اگر دامنه پشت Cloudflare (ابر نارنجی) است،"
echo "  SSL/TLS Mode را روی Flexible یا DNS-only (خاکستری) برای تست HTTP امتحان کن."
