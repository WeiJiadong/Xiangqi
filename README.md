# Xiangqi（象棋）

macOS 桌面象棋学习 App，SwiftUI 编写，内置 [Pikafish](https://github.com/Official-pikafish/Pikafish) 引擎支招。

## 功能

- **分析学习模式**：双人均手动走子，引擎只算"支招"（最佳着法 + 箭头指示），从不代走
- **自动走棋**：「帮红走棋 / 帮黑走棋」独立开关，开启后引擎替该方行棋；双方都开可看引擎自对弈
- 前进 / 后退（⌘Z / ⇧⌘Z）
- **棋盘编辑**：自由摆放棋子，研究任意局面
- 反转棋盘视角、手动指定行棋方
- 拟木棋盘（Canvas 手绘木纹 + 书法棋子），支招箭头、将军区高亮

## 下载安装

从 [Releases](../../releases) 下载 `Xiangqi.dmg`，拖入 Applications 即可。

> 安装包为 ad-hoc 签名，首次打开需在 Finder 中**右键 → 打开**以通过 Gatekeeper。要求 macOS 15+，Apple Silicon。

## 本地构建

```bash
swift build            # 编译
./make_app.sh          # 打包 build/Xiangqi.app + Xiangqi.dmg（内嵌引擎与 NNUE）
```

引擎默认读取 `~/pikafish/pikafish`（可执行文件）与 `pikafish.nnue`（模型）；打包时二者会复制进 App 的 Resources。

## 许可

本项目以 **GPL-3.0** 发布（见 [LICENSE](LICENSE)）。

内置引擎 [Pikafish](https://github.com/Official-pikafish/Pikafish) 为 GPL-3.0 开源软件，版权归 Pikafish developers 所有；随包分发的 NNUE 网络文件来自 Pikafish 官方发布。
