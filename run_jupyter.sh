#!/bin/bash
# 自分の OpenCap のデータで OpenSimAD（筋駆動）を解くノートブックを，Docker のコンテナの中の Jupyter で開く（x86_64 の Linux）．
# 使い方：  ./run_jupyter.sh <データのフォルダ> [<結果のフォルダ>]
#   <データのフォルダ>：OpenCap の zip（か，それを展開したフォルダ）を置いたフォルダ．コンテナの中では /data（読み取りだけ）
#   <結果のフォルダ>  ：結果を書くフォルダ（既定はこのフォルダの results/）．コンテナの中では /results
# このフォルダはコンテナの中では /work（ノートブックを開く場所）．
# イメージ（既定の名前 opensimad-local）がなければ，このフォルダの Dockerfile から作る（初回だけ．約 3.6 GB．
# 講師の PC では約 2 分だったが，ダウンロードの量が多いので回線しだいで長くなる）．
# 表示された http://127.0.0.1:8888/lab?token=… をブラウザで開く．止めるときは，この端末で Ctrl+C．
# 環境変数：OSAD_IMAGE（イメージの名前），OSAD_PORT（手元のポート．既定 8888）
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
if [ $# -lt 1 ]; then
  sed -n '2,10p' "$0"
  exit 1
fi
DATA=$(realpath "$1")
OUT=$(realpath -m "${2:-$HERE/results}")
IMAGE=${OSAD_IMAGE:-opensimad-local}
PORT=${OSAD_PORT:-8888}
[ -d "$DATA" ] || { echo "データのフォルダがありません：$DATA"; exit 1; }
mkdir -p "$OUT"
if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "イメージ $IMAGE を作ります（初回だけ．回線しだいで数分〜）"
  docker build -t "$IMAGE" "$HERE"
fi
# 手元のユーザーの権限で動かす（結果のファイルが root のものにならないように）．CPU の数は絞らない
# （--cpus で使える時間だけを絞ると，中からはすべてのコアが見えて，数値計算のライブラリがスレッドを立てすぎ，とても遅くなる）
exec docker run --rm -it -p "127.0.0.1:$PORT:8888" -u "$(id -u):$(id -g)" \
  -v "$HERE":/work -v "$DATA":/data:ro -v "$OUT":/results "$IMAGE"
