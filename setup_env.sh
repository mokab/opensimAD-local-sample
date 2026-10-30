#!/bin/bash
# OpenSimAD を動かす環境を OSAD_ROOT（既定 /content/osad）に作る．Colab の Python とは別の環境なので，ランタイムの再起動は要らない．
# ノートブックの 1 節のセルが裏で実行する．ログは $ROOT/setup.log，終わると $ROOT/READY，失敗すると $ROOT/FAILED．
# 版：micromamba 2.10.0，Python 3.10，OpenSim 4.5，numpy 1.21，scipy 1.10，pandas 1.5，CasADi 3.7.2，
#     opencap-processing 72b5416（論文の実行例と同じ），OpenSimAD のライブラリ（SourceForge の linux.tar.gz）
set -uo pipefail
ROOT=${OSAD_ROOT:-/content/osad}
mkdir -p "$ROOT" && cd "$ROOT" || exit 1
rm -f READY FAILED sdk.ok linux.tar.gz
exec >> setup.log 2>&1
T0=$(date +%s)
say() { echo "[setup] $(( $(date +%s) - T0 )) 秒：$*"; }
# 失敗したら，裏のライブラリの取得も止める（やり直したときに，前の取得と重ならないように）
fail() { echo "[setup] 失敗：$*"; [ -n "${SDK_PID:-}" ] && kill "$SDK_PID" 2>/dev/null; touch FAILED; exit 1; }
# grep -q は見つけた時点で終わり，pipefail のもとでは ldconfig の SIGPIPE で「ない」と判定されるので，-q を使わない
have_lib() { ldconfig -p | grep "$1" >/dev/null; }
OCP=$ROOT/ocp
SDK=$OCP/UtilsDynamicSimulations/OpenSimAD/opensimAD-install

NEED=""
for c in curl git bzip2 make g++; do command -v "$c" >/dev/null || NEED="$NEED $c"; done
have_lib libopenblas.so.0 || NEED="$NEED libopenblas0"
if [ -n "$NEED" ]; then
  say "足りない OS のパッケージを入れます：$NEED"
  apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $NEED >/dev/null || fail "apt-get install$NEED"
fi

say "OpenSimAD のライブラリ（113 MB）の取得を裏で始めます"
if [ -n "${OSAD_SDK_TARBALL:-}" ] && [ -f "$OSAD_SDK_TARBALL" ]; then
  cp "$OSAD_SDK_TARBALL" linux.tar.gz &           # 確かめるとき用（取得の時間を省く）
else
  curl -fsSL --retry 5 --retry-delay 5 -o linux.tar.gz https://sourceforge.net/projects/opensimad/files/linux.tar.gz &
fi
SDK_PID=$!

say "OpenSim の環境（約 1.2 GB）を作ります"
curl -fsSL https://micro.mamba.pm/api/micromamba/linux-64/2.10.0 | tar -xj bin/micromamba || fail "micromamba の取得"
export MAMBA_ROOT_PREFIX=$ROOT/mamba
rm -rf "$ROOT/env"                                # やり直したときに，作りかけの環境を残さない
./bin/micromamba create -y -q -p "$ROOT/env" -c opensim-org -c conda-forge python=3.10 "opensim=4.5=py310np121" \
  "numpy=1.21.*" "scipy=1.10.*" "pandas=1.5.*" "matplotlib-base=3.7.*" pyyaml joblib requests seaborn-base cmake \
  || fail "conda のパッケージ"
"$ROOT/env/bin/pip" install -q casadi==3.7.2 python-decouple maskpass==0.3.6 || fail "pip のパッケージ"

say "opencap-processing（72b5416）を取得します"
rm -rf "$OCP"
git clone -q https://github.com/stanfordnmbl/opencap-processing.git "$OCP" \
  && git -C "$OCP" checkout -q 72b5416bf6172fe3d9b42b01e1a02252362b20fc || fail "opencap-processing の取得"
echo "API_TOKEN=dummy" > "$OCP/.env"
sed -i "s/API_TOKEN = get_token()/API_TOKEN = os.environ.get('API_TOKEN', 'local_mode')/" "$OCP/utils.py"
grep -q "local_mode" "$OCP/utils.py" || fail "utils.py の書き換え（OpenCap のサーバーに接続しないため）"

say "OpenSimAD のライブラリの取得を待ちます"
wait $SDK_PID || { SDK_PID=; fail "OpenSimAD のライブラリの取得（SourceForge）．1 節の「環境づくりを裏で始める」セルを実行し直してください"; }
SDK_PID=
mkdir -p "$SDK" && tar -xf linux.tar.gz -C "$SDK" && rm -f linux.tar.gz || fail "ライブラリの展開"
"$ROOT/env/bin/python" -c "import opensim, casadi; print('opensim', opensim.GetVersion(), 'casadi', casadi.__version__)" \
  || fail "OpenSim の読み込み"
say "準備ができました"
touch READY
