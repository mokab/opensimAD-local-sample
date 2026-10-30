# 自分の OpenCap のデータの歩行周期を，筋駆動の OpenSimAD で解くノートブック（opensimad_muscle_local.ipynb）を動かす環境（x86_64 の Linux）．
# 作り方（このフォルダで）：docker build -t opensimad-local .   （run_jupyter.sh は，イメージがなければ作る）
#
# OpenSim の環境（/opt/osad）は，Colab の版のノートブックと同じ setup_env.sh で作る：micromamba 2.10.0，Python 3.10，OpenSim 4.5，
# numpy 1.21，CasADi 3.7.2，opencap-processing 72b5416（OpenCap のサーバーに接続しないように書き換える），OpenSimAD のライブラリ
# （SourceForge から 113 MB を取る）．ノートブックのカーネル（Jupyter）は，それとは別の Ubuntu の Python 3.10 で，OpenSim を使わない
# 処理と図を受け持つ（Colab の版と同じ分け方）．
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8 LC_ALL=C.UTF-8

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl git bzip2 make g++ libopenblas0 python3 python3-pip \
 && rm -rf /var/lib/apt/lists/*

# OpenSim の環境（重いので先に作る．setup_env.sh を変えたときだけ作り直す）．ログは /opt/osad/setup.log
COPY setup_env.sh /opt/osad/setup_env.sh
RUN OSAD_ROOT=/opt/osad bash /opt/osad/setup_env.sh || { tail -n 40 /opt/osad/setup.log; exit 1; } \
 && rm -rf /opt/osad/mamba/pkgs /root/.cache \
 && chmod a+rwx /opt/osad && chmod -R a+rwX /opt/osad/ocp

# ノートブックのカーネル（Jupyter）の Python のパッケージ（版を固定．2026-10-30 に Ubuntu 22.04 の Python 3.10 で入った版）
RUN pip3 install --no-cache-dir numpy==2.2.6 pandas==2.3.3 scipy==1.15.3 matplotlib==3.10.9 pyyaml==6.0.3 \
    jupyterlab==4.6.5 ipykernel==7.3.0 nbconvert==7.17.2

# 作業のフォルダは /opt/osad（コンテナを止めると消える）．手元のユーザーの権限で動かすので，HOME は書ける /tmp にする
ENV OSAD_ROOT=/opt/osad HOME=/tmp
WORKDIR /work
EXPOSE 8888
CMD ["jupyter", "lab", "--ip=0.0.0.0", "--port=8888", "--no-browser", "--ServerApp.root_dir=/work"]
