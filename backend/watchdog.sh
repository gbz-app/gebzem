#!/bin/bash
# Nobetci: API'yi dakikada bir yoklar, cevap vermezse otomatik yeniden baslatir.
# Her mudahale /var/log/gebzem-watchdog.log dosyasina yazilir (Sentry'e de dusurulebilir).
set -u

LOG=/var/log/gebzem-watchdog.log
STACK=/opt/gebzem/repo/backend
FAIL_FILE=/tmp/gebzem-api-fails

fails=$(cat "$FAIL_FILE" 2>/dev/null || echo 0)

if curl -sf --max-time 8 http://localhost:8080/health | grep -q '"ok"'; then
    # saglikli — sayaci sifirla
    [ "$fails" -gt 0 ] && echo "$(date -Is) API tekrar saglikli (onceki hata: $fails)" >> "$LOG"
    echo 0 > "$FAIL_FILE"
    exit 0
fi

fails=$((fails + 1))
echo "$fails" > "$FAIL_FILE"
echo "$(date -Is) API yanit vermiyor (ust uste $fails)" >> "$LOG"

# 2 ust uste basarisizlikta mudahale et
if [ "$fails" -ge 2 ]; then
    echo "$(date -Is) MUDAHALE: api konteyneri yeniden baslatiliyor" >> "$LOG"
    cd "$STACK" && docker compose restart api >> "$LOG" 2>&1
    echo 0 > "$FAIL_FILE"
fi

# Disk %90'i asarsa eski docker artiklarini temizle
disk=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
if [ "$disk" -ge 90 ]; then
    echo "$(date -Is) MUDAHALE: disk %$disk — docker temizligi" >> "$LOG"
    docker system prune -af --volumes >> "$LOG" 2>&1
fi
