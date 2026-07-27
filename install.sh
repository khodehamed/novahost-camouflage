#!/usr/bin/env bash
set -euo pipefail

# NovaHost camouflage on port 80 only (443 untouched)
# Usage:
#   curl -fsSL <URL>/install.sh | sudo bash
#   یا: sudo bash install.sh

WEB_ROOT="${WEB_ROOT:-/var/www/html}"
NGINX_AVAIL="${NGINX_AVAIL:-/etc/nginx/sites-available/camouflage-80}"
NGINX_ENABLED="${NGINX_ENABLED:-/etc/nginx/sites-enabled/camouflage-80}"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root: sudo bash $0"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
if command -v apt-get >/dev/null 2>&1; then
  apt-get update -y
  apt-get install -y nginx
elif command -v dnf >/dev/null 2>&1; then
  dnf install -y nginx
elif command -v yum >/dev/null 2>&1; then
  yum install -y nginx
else
  echo "No supported package manager (apt/dnf/yum)."
  exit 1
fi

mkdir -p "$WEB_ROOT"

# Embedded camouflage page
cat > "$WEB_ROOT/index.html" <<'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <meta name="description" content="NovaHost — reliable cloud hosting, VPS, and managed infrastructure for growing businesses." />
  <title>NovaHost — Cloud Infrastructure</title>
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
  <link href="https://fonts.googleapis.com/css2?family=DM+Sans:wght@400;500;700&family=Fraunces:opsz,wght@9..144,600;9..144,700&display=swap" rel="stylesheet" />
  <style>
    :root {
      --bg: #0f1c17;
      --bg2: #163028;
      --ink: #e8f2ec;
      --muted: #9bb5a8;
      --accent: #3dba7c;
      --accent2: #c9f07a;
      --line: rgba(232, 242, 236, 0.12);
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      min-height: 100vh;
      font-family: "DM Sans", sans-serif;
      color: var(--ink);
      background:
        radial-gradient(900px 500px at 10% -10%, rgba(61, 186, 124, 0.22), transparent 55%),
        radial-gradient(700px 400px at 90% 0%, rgba(201, 240, 122, 0.12), transparent 50%),
        linear-gradient(165deg, var(--bg), var(--bg2) 55%, #0c1612);
      line-height: 1.55;
    }
    .wrap { width: min(1080px, calc(100% - 2.5rem)); margin: 0 auto; }
    header {
      display: flex; align-items: center; justify-content: space-between;
      padding: 1.4rem 0 1rem; border-bottom: 1px solid var(--line);
    }
    .logo { font-family: "Fraunces", serif; font-size: 1.35rem; letter-spacing: -0.02em; }
    .logo span { color: var(--accent); }
    nav { display: flex; gap: 1.25rem; color: var(--muted); font-size: 0.95rem; }
    nav a { color: inherit; text-decoration: none; }
    nav a:hover { color: var(--ink); }
    .hero { padding: 4.5rem 0 3.5rem; max-width: 720px; }
    .eyebrow {
      display: inline-block; margin-bottom: 1rem; color: var(--accent2);
      font-size: 0.85rem; font-weight: 500; letter-spacing: 0.04em; text-transform: uppercase;
    }
    h1 {
      font-family: "Fraunces", serif; font-size: clamp(2.2rem, 5vw, 3.4rem);
      line-height: 1.1; letter-spacing: -0.03em; margin-bottom: 1rem;
    }
    .lead { color: var(--muted); font-size: 1.08rem; max-width: 54ch; margin-bottom: 1.8rem; }
    .actions { display: flex; flex-wrap: wrap; gap: 0.75rem; }
    .btn {
      appearance: none; border: 0; border-radius: 10px; padding: 0.85rem 1.2rem;
      font: inherit; font-weight: 500; cursor: pointer; text-decoration: none;
    }
    .btn-primary { background: linear-gradient(135deg, var(--accent), #2f9a66); color: #042015; }
    .btn-ghost { background: transparent; color: var(--ink); border: 1px solid var(--line); }
    .grid {
      display: grid; grid-template-columns: repeat(3, 1fr); gap: 1rem; padding: 0.5rem 0 3.5rem;
    }
    .card {
      border: 1px solid var(--line); border-radius: 16px; padding: 1.25rem;
      background: rgba(255, 255, 255, 0.03);
    }
    .card h3 { font-size: 1.05rem; margin-bottom: 0.45rem; }
    .card p { color: var(--muted); font-size: 0.95rem; }
    footer {
      border-top: 1px solid var(--line); padding: 1.4rem 0 2rem; color: var(--muted);
      font-size: 0.9rem; display: flex; justify-content: space-between; gap: 1rem; flex-wrap: wrap;
    }
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
        <a href="#products">Products</a>
        <a href="#network">Network</a>
        <a href="#support">Support</a>
      </nav>
    </header>
    <main>
      <section class="hero">
        <p class="eyebrow">Managed Cloud Platform</p>
        <h1>Infrastructure that stays online when traffic peaks.</h1>
        <p class="lead">
          NovaHost provides VPS, object storage, and edge networking for teams that need
          predictable performance and simple operations.
        </p>
        <div class="actions">
          <a class="btn btn-primary" href="#products">View plans</a>
          <a class="btn btn-ghost" href="#support">Contact sales</a>
        </div>
      </section>
      <section class="grid" id="products">
        <article class="card">
          <h3>Cloud VPS</h3>
          <p>SSD-backed instances with hourly billing, snapshots, and private networking.</p>
        </article>
        <article class="card" id="network">
          <h3>Anycast DNS</h3>
          <p>Global DNS with health checks and automatic failover for critical endpoints.</p>
        </article>
        <article class="card" id="support">
          <h3>24/7 Support</h3>
          <p>Human support for deploy issues, migrations, and network troubleshooting.</p>
        </article>
      </section>
    </main>
    <footer>
      <span>© 2026 NovaHost Systems Ltd.</span>
      <span>status.novahost.example · docs.novahost.example</span>
    </footer>
  </div>
</body>
</html>
HTML

# Nginx site: port 80 only
mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled /var/log/nginx

cat > "$NGINX_AVAIL" <<'NGINX'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    root /var/www/html;
    index index.html;
    server_tokens off;

    location / {
        try_files $uri $uri/ =404;
    }

    location ~ /\. {
        deny all;
    }

    access_log /var/log/nginx/camouflage.access.log;
    error_log  /var/log/nginx/camouflage.error.log warn;
}
NGINX

ln -sfn "$NGINX_AVAIL" "$NGINX_ENABLED"
rm -f /etc/nginx/sites-enabled/default

# RHEL-style: ensure sites-enabled is included
if [[ -f /etc/nginx/nginx.conf ]] && ! grep -q 'sites-enabled' /etc/nginx/nginx.conf; then
  if grep -q 'conf.d/\*.conf' /etc/nginx/nginx.conf; then
    cp -f "$NGINX_AVAIL" /etc/nginx/conf.d/camouflage-80.conf
  fi
fi

nginx -t
systemctl enable nginx
systemctl restart nginx

# Free tip: stop anything else binding :80 if needed was already handled by default_server

IP="$(curl -4 -fsS --max-time 5 ifconfig.me 2>/dev/null || curl -4 -fsS --max-time 5 api.ipify.org 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}' || echo 'SERVER-IP')"

echo
echo "OK — camouflage site on port 80"
echo "URL:  http://${IP}/"
echo "443 left untouched for your tunnel."
echo "Test: curl -I http://127.0.0.1/"
