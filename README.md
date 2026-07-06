# Soto Player-Community Nix Package

水芸音乐播放器（Soto Player-Community）的 Nix 打包。

## 快速使用

```bash
# 直接运行（不安装）
nix run github:yigexuanmu/soto-player-flake

# 临时运行
nix shell github:yigexuanmu/soto-player-flake -c soto-player

# 安装到系统（NixOS）
{
  inputs = {
    soto-player.url = "github:yigexuanmu/soto-player-flake";
  };
  outputs = { soto-player, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        { environment.systemPackages = [ soto-player.packages.${system}.default ]; }
      ];
    };
  };
}

# Home Manager 方式
{
  home.packages = [ inputs.soto-player.packages.${system}.default ];
}
```

## 排错记录

| 问题 | 原因 | 修复 |
|------|------|------|
| `@electron-toolkit/utils` 找不到 | `out/` 目录结构不对 | `cp -r out` 保持目录 |
| `better-sqlite3` 数据库模块缺失 | pnpm 跳过 postinstall | `node-gyp rebuild --nodedir=\${electron.headers}` |
| `ffmpeg_audio_sys` 编译失败 | build.rs 试图从源码构建 FFmpeg | patch 改用系统 FFmpeg（pkg-config + bindgen） |
| cargo git 依赖无法下载 | Nix 沙盒无网络 | `importCargoLock` + `outputHashes` |
| pnpm node_modules symlink 损坏 | `cp -rL` 破坏 pnpm 结构 | `tar` 保留 symlink |
| `node.h` 找不到 | node-gyp 用了 Node.js 头文件而非 Electron | `--nodedir=\${electron.headers}` |

## 构建流程

```
pnpm install（离线缓存）
  → cargo vendor dir 设置
  → node-gyp rebuild better-sqlite3（Electron headers）
  → napi build audio-engine + media-ctrl（系统 FFmpeg）
  → electron-vite build（Vue + Electron 主进程）
```

## 依赖

- Node.js 22
- pnpm 11+
- Electron 41+
- Rust（cargo + rustc）
- FFmpeg（用于音频分析）
- alsa-lib
- libclang（bindgen 需要）

## 致谢

- [Fantasy-XY808 / Soto-Player-Community](https://github.com/Fantasy-XY808/Soto-Player-Community) — 上游项目
- [opencode](https://github.com/anomalyco/opencode) — AI 编程助手
