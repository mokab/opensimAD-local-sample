# 自分の OpenCap のデータで，歩行周期を筋駆動の OpenSimAD で解く

OpenCapで撮った歩行（TUG を含む）から歩行周期を1つ切り出し，筋駆動の OpenSimAD で解いて，床反力・関節モーメント・筋活動を求め，OpenSim（GUI）で読み込める形で書き出します．
OpenSimAD は，OpenSim のモデルで自動微分を使い，CasADi と組み合わせて軌道最適化を速く解く道具です．

## 要るもの

- x86_64 の Linux と Docker Engine（`docker run hello-world` が sudo なしで動くこと．Windows・Mac は扱いません）
- ディスク：イメージに約 3.6 GB
- メモリ：求解の途中で約 5 GB．最初の数分は，筋の走行の近似式を並列に作るプロセス（コアの数 − 2 個）の分が加わります．コアの多い PC では，16 GB 以上あると安心です
- 初回だけインターネット（イメージを作るときに micromamba，conda-forge・opensim-org のパッケージ，GitHub の opencap-processing，
  SourceForge の OpenSimAD のライブラリを取ります）
- OpenCap のデータ：Web の「Download data」で取った zip（`OpenCapData_<ID>.zip`）か，それを展開したフォルダ

## 使い方

1. このフォルダを好きな場所に配置します．
2. OpenCap の zip を1つのフォルダに置きます（例：`~/opencap/OpenCapData_abc.zip`）．
3. 端末でこのフォルダに移り，起動します．2つ目のフォルダは結果を書く場所です（省くと，このフォルダの `results/`）．

   ```bash
   ./run_jupyter.sh ~/opencap ~/opencap_results
   ```

   初回だけ，Docker のイメージ `opensimad-local` を作ります（10〜20 分）．
4. 端末に出た `http://127.0.0.1:8888/lab?token=…` をブラウザで開きます．
5. `opensimad_muscle_local.ipynb` を開き，1 節のセルの `SESSION`（例 `'/data/OpenCapData_abc.zip'`）と `TRIAL`（試行の名前）を書き換えて，
   「Run」→「Run All Cells」．`TRIAL` を空のまま実行すると，3 節で試行の一覧を出して止まります．
6. 結果は `~/opencap_results/<試行>_<区間の名前>/` と，同じ中身の zip に書かれます．
7. 終わったら，端末で Ctrl+C を押してコンテナを止めます．

コンテナの中から見えるのは，データのフォルダ（`/data`，読み取りだけ），結果のフォルダ（`/results`），このフォルダ（`/work`）だけです．
ノートブックの中のパスは，コンテナの中のもので書きます．ノートブックを保存すると，このフォルダのファイルが書き換わるので，
試行ごとに写して使うと便利です（例：`cp opensimad_muscle_local.ipynb walk01.ipynb`）．

### 1 節で選べること

| 名前 | 既定 | 中身 |
|---|---|---|
| `SESSION` | | zip か，展開したフォルダ（コンテナの中のパス） |
| `TRIAL` | 空 | 試行の名前 |
| `CYCLE` | `'auto'` | 自動で選ぶ．TUG（立ち上がりと方向転換が見つかる試行）なら往路の歩行周期，ほかの歩行なら，いちばん長い直進の区間の真ん中の歩行周期．数を書くと，4 節の表の番号の周期 |
| `WINDOW` | `None` | `(開始の秒, 終了の秒)` を書くと，その区間を解く（`CYCLE` より優先） |
| `MASS_KG`・`HEIGHT_M` | `None` | 体重・身長．`None` なら `sessionMetadata.yaml` の値（OpenCap の1台版の zip にはないので書く） |
| `MESH` | 50 | 1 秒あたりの区間の数 |
| `LEVEL_FLOOR` | `True` | 傾いて再構成された床を，解く前に水平にする |
| `TIME_LIMIT_MIN` | 300 | 求解の打ち切り（分） |
| `OUT_DIR` | `'/results'` | 結果を書くフォルダ |

## 結果と OpenSim での開き方

- `README.md`：区間，設定，確認の値，所要時間，ファイルの説明
- `LaiUhlrich2022_scaled_adjusted_contacts_disabled.osim`：File → Open Model で開くモデル（足の接触球の力を切ってある）
- `…_motion_activations.mot`：File → Load Motion（関節角度と筋活動）
- `…_GRF.mot`：動きを読み込んだあと，Navigator の動きを右クリック → Associate Motion Data（床反力）
- `…_GRF_ExternalLoads.xml`，`…_ID_setup.xml`：逆動力学などのツール用（接触球の力を切ったモデルで，筋を除いて使う．
  接触球の力が有効なモデルで ExternalLoads を使うと，床反力が二重に入ります）
- `…_kinetics.mot`：OpenSimAD の関節モーメント
- `figures/`：ノートブックが描いた図
- `opensimad_original/`：OpenSimAD が書いたファイルとモデルそのまま


## このフォルダのファイル

| ファイル | 中身 |
|---|---|
| `opensimad_muscle_local.ipynb` | ノートブック（関数も中に含まれている） |
| `Dockerfile` | イメージの作り方．Ubuntu 22.04．OpenSim の環境（`/opt/osad`）は `setup_env.sh` で作り，Jupyter はそれとは別の Python 3.10 |
| `setup_env.sh` | OpenSim の環境を作るスクリプト（micromamba 2.10.0，OpenSim 4.5，CasADi 3.7.2，opencap-processing 72b5416，OpenSimAD のライブラリ）．Colab の版と同じもの |
| `run_jupyter.sh` | イメージがなければ作り，コンテナを起動して Jupyter を開く |
| `.dockerignore` | イメージを作るときに `setup_env.sh` だけを渡す |


## 参考文献

- Uhlrich SD, Falisse A, Kidziński Ł, Muccini J, Ko M, Chaudhari AS, Hicks JL, Delp SL (2023) OpenCap: Human movement dynamics from smartphone videos. *PLOS Comput Biol* 19(10):e1011462. doi:10.1371/journal.pcbi.1011462
- Falisse A, Serrancolí G, Dembia CL, Gillis J, De Groote F (2019) Algorithmic differentiation improves the computational efficiency of OpenSim-based trajectory optimization of human movement. *PLOS ONE* 14(10):e0217730. doi:10.1371/journal.pone.0217730
- Zeni JA, Richards JG, Higginson JS (2008) Two simple methods for determining gait events during treadmill and overground walking using kinematic data. *Gait Posture* 27(4):710–714. doi:10.1016/j.gaitpost.2007.07.007
