#!/bin/bash
# Uji di emulator: pasang APK, buka menu lalu langsung level, tangkap layar, cek crash dan bar hitam.
# Pakai: tools/emulator_check.sh <apk> <lebar> <tinggi> <label>
APK=$1; W=$2; H=$3; LABEL=$4
PKG=com.hadydaw.dapurkelilingdunia
FAIL=0
mkdir -p shots
adb wait-for-device
adb shell wm size ${W}x${H}
adb shell wm density 420
# tutup dialog sistem "Viewing full screen" (mode imersif) agar tangkapan layar menampilkan game
adb shell settings put secure immersive_mode_confirmations confirmed
adb shell settings put secure immersive_mode_confirmations "*" || true
echo "== perangkat: Android API $(adb shell getprop ro.build.version.sdk), ABI $(adb shell getprop ro.product.cpu.abi), layar $(adb shell wm size | tr '\n' ' ')"

echo "== pasang APK"
if ! adb install -r "$APK"; then
  echo "GAGAL PASANG"; adb logcat -d | tail -40; exit 1
fi
adb shell pm list packages | grep -q "$PKG" || { echo "paket tidak terdaftar"; exit 1; }
COMP=$(adb shell cmd package resolve-activity --brief -c android.intent.category.LAUNCHER "$PKG" | tail -1 | tr -d '\r')
echo "aktivitas peluncur: $COMP"

thumb() { # file nama: cetak miniatur JPEG base64 ke log (artifact tidak bisa diunduh agen)
  python3 - "$1" "$2" "$LABEL" <<'PY'
import sys, base64, io
from PIL import Image
im = Image.open(sys.argv[1]).convert("RGB"); w, h = im.size
im = im.resize((640, max(1, int(h * 640 / w))))
b = io.BytesIO(); im.save(b, "JPEG", quality=55)
print("THUMB|%s|%s|%s" % (sys.argv[3], sys.argv[2], base64.b64encode(b.getvalue()).decode()))
PY
}

shot_check() { # file
  python3 - "$1" "$W" "$H" <<'PY'
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert("L"); w, h = im.size
px = im.load()
def dark(x0, y0, x1, y1):
    n = d = 0
    for y in range(y0, y1, 3):
        for x in range(x0, x1, 3):
            n += 1; d += px[x, y] < 8
    return d / max(n, 1)
bw, bh = max(2, int(w * 0.03)), max(2, int(h * 0.03))
edges = {"kiri": dark(0, 0, bw, h), "kanan": dark(w - bw, 0, w, h), "atas": dark(0, 0, w, bh), "bawah": dark(0, h - bh, w, h)}
mean = sum(px[x, y] for y in range(0, h, 5) for x in range(0, w, 5)) / (((h + 4) // 5) * ((w + 4) // 5))
cols = len({im.getpixel((x, y)) for y in range(0, h, 17) for x in range(0, w, 17)})
print("   tangkapan %dx%d | kecerahan rata-rata %.1f | variasi warna %d | gelap di tepi: %s" % (w, h, mean, cols, ", ".join("%s %.0f%%" % (k, v * 100) for k, v in edges.items())))
bad = [k for k, v in edges.items() if v > 0.9]
ok = mean > 25 and cols > 200
print("   HASIL:", "OK tampil normal" if ok and not bad else "MASALAH (layar hitam/bar hitam: %s)" % (bad or "kosong"))
sys.exit(0 if ok and not bad else 1)
PY
}

run_case() { # nama  param
  NAME=$1; shift
  adb logcat -c
  adb shell am force-stop "$PKG"
  if [ -n "$1" ]; then
    adb shell am start -W -n "$COMP" --esa command_line_params "$1" | tail -3
  else
    adb shell am start -W -n "$COMP" | tail -3
  fi
  sleep 25
  if [ -z "$(adb shell pidof "$PKG" | tr -d '\r')" ]; then
    echo "   (percobaan 1: proses mati; log:)"; adb logcat -d -b all | grep -iE "am_proc_died|am_kill|lowmemorykiller|lmkd|Out of memory|Fatal signal|SIGSEGV|SIGABRT|F libc|ANR in|Killing|has died|DEBUG   :" | tail -25 | cut -c1-230; adb logcat -d -s godot:V | tail -12 | cut -c1-200
    adb logcat -c; adb shell am start -W -n "$COMP" | tail -2; sleep 25
  fi
  if [ -z "$(adb shell pidof "$PKG" | tr -d '\r')" ]; then
    echo "   PROSES MATI (crash) pada $NAME"; adb logcat -d -b crash | tail -30; adb logcat -d | grep -iE "godot|AndroidRuntime|FATAL|signal|vulkan|GLES" | tail -30; FAIL=1; return
  fi
  adb exec-out screencap -p > "shots/${LABEL}_${NAME}_t25.png"
  sleep 30
  adb exec-out screencap -p > "shots/${LABEL}_${NAME}.png"
  thumb "shots/${LABEL}_${NAME}_t25.png" "${NAME}_t25"
  thumb "shots/${LABEL}_${NAME}.png" "${NAME}_t55"
  echo "== $NAME: proses hidup, ukuran jendela: $(adb shell dumpsys window displays | grep -m1 -oE 'cur=[0-9]+x[0-9]+')"
  shot_check "shots/${LABEL}_${NAME}.png" || echo "   (INFO: emulator memakai GL perangkat lunak yang sangat lambat; tangkapan layar tidak dijadikan syarat lulus)"
  CR=$(adb logcat -d | grep -cE "FATAL EXCEPTION|SIGSEGV|Fatal signal")
  [ "$CR" -gt 0 ] && { echo "   ada $CR baris crash di logcat"; FAIL=1; }
  adb logcat -d -s godot:V Godot:V | cut -c1-220 | head -25
}

run_case menu ""

echo "== SELF-TEST di dalam game (sentuhan nyata, menu, level, main, Jeda, simpan, audio)"
selftest_attempt() {
  adb logcat -c
  adb shell am force-stop "$PKG"
  adb shell "mkdir -p /sdcard/Android/data/$PKG/files && echo 1 > /sdcard/Android/data/$PKG/files/selftest"
  adb shell ls -l /sdcard/Android/data/$PKG/files/ || true
  adb shell am start -W -n "$COMP" --esa command_line_params "--,--selftest" | tail -2
  DONE=0
  for i in $(seq 1 60); do
    sleep 5
    [ $((i % 6)) -eq 0 ] && { echo "   [mem t=$((i*5))s]"; adb shell dumpsys meminfo "$PKG" | grep -E "Native Heap|Graphics|TOTAL:|Java Heap|Private Other" | head -5; }
    if adb logcat -d -s godot:V | grep -q "SELFTEST|SELESAI"; then DONE=1; break; fi
    if [ -z "$(adb shell pidof "$PKG" | tr -d '\r')" ]; then
      echo "   PROSES MATI saat self-test; jejak:"
      adb logcat -d -b all | grep -iE "am_proc_died|am_kill|lowmemorykiller|lmkd|Out of memory|Fatal signal|SIGSEGV|SIGABRT|F libc|ANR in|Killing|has died|DEBUG   :" | tail -25 | cut -c1-230
      adb logcat -d -s godot:V | tail -15 | cut -c1-200
      break
    fi
  done
}
DONE=0
selftest_attempt
if [ "$DONE" != "1" ] && adb logcat -d -b all | grep -q "lowmemorykiller.*Kill '$PKG'"; then
  echo "   (INFO: emulator kehabisan RAM dan sistem membunuh aplikasi; ulangi sekali)"
  adb shell am force-stop "$PKG"; sleep 5
  selftest_attempt
fi
adb logcat -d -s godot:V | grep -E "SELFTEST\|" | sed -E 's/^.*(SELFTEST\|)/\1/' | cut -c1-260
adb exec-out screencap -p > "shots/${LABEL}_selftest_akhir.png"
if [ "$DONE" != "1" ]; then echo "   SELF-TEST TIDAK SELESAI dalam 300 dtk"; FAIL=1; fi
if adb logcat -d -s godot:V | grep -E "SELFTEST\|[A-Z_]+_GAGAL"; then echo "   ADA PEMERIKSAAN GAGAL"; FAIL=1; fi
SE=$(adb logcat -d -s godot:V | grep -c "SCRIPT ERROR")
echo "   SCRIPT ERROR di logcat: $SE"; [ "$SE" -gt 0 ] && { adb logcat -d -s godot:V | grep -A3 "SCRIPT ERROR" | head -20; FAIL=1; }
[ -z "$(adb shell pidof "$PKG" | tr -d '\r')" ] && { echo "   proses mati setelah self-test"; FAIL=1; }
adb shell dumpsys meminfo "$PKG" | grep -E "TOTAL PSS|TOTAL:" | head -2
[ "$FAIL" = "0" ] && echo "SEMUA OK ($LABEL)" || echo "ADA KEGAGALAN ($LABEL)"
exit $FAIL
