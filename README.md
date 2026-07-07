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
