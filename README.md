# luiox-repo

luiox 自研库的 xmake **包定义仓**（package definitions only）。库源码不在本仓——
各库来自它自己的 git 仓库；本仓只回答「有哪些版本、怎么构建安装」。

## 消费方接线

项目级（写进消费项目的 `xmake.lua`，xmake 首次配置时自动克隆本仓）：

```lua
add_repositories("luiox-repo https://github.com/luiox/luiox-repo.git")
add_requires("libca 0.0.7")
```

开发机全局（对本机所有项目生效，`xrepo` 命令行场景适用）：

```sh
xrepo add-repo luiox-repo https://github.com/luiox/luiox-repo.git
```

非公开源码仓认证：xmake 对 git URL 直接调用系统 git，SSH key / Windows 凭据管理
器 / credential helper 自动生效，CI 用 deploy key，与 submodule 时代同源，无额外配置。
若全局 `.gitconfig` 配置了失效代理：公共库可 `GIT_CONFIG_GLOBAL=/dev/null xmake ...`
绕过；**非公开库会连凭据一起丢**，改用注入方式只覆盖代理、保留凭据 helper：

```sh
GIT_CONFIG_COUNT=2 GIT_CONFIG_KEY_0=http.proxy GIT_CONFIG_VALUE_0= \
GIT_CONFIG_KEY_1=https.proxy GIT_CONFIG_VALUE_1= xmake ...
```

## 可复现纪律

- 消费项目建议启用 `set_policy("package.requires_lock", true)`（xmake >= 2.5.7），
  生成 `xmake-requires.lock` 随项目入库，锁定 `add_requires` 的解析结果。
- **既有版本条目只追加、不修改**：改默认 config、换 commit 一律以新版本号追加，
  已发布版本不可变。
- git URL 的 `add_versions("x.y.z", "<40位commit>")` 第二参数是 commit，不是 sha256；
  写 tag 名亦可但 tag 可移动，默认锁 commit。

## 包清单

| 包 | 版本 | 源码 |
|---|---|---|
| [libca](packages/l/libca/xmake.lua) | 0.0.1 – 0.0.8 | [luiox/libca](https://github.com/luiox/libca) |
| [libmcp](packages/l/libmcp/xmake.lua) | 0.0.1 – 0.0.2 | [luiox/libmcp](https://github.com/luiox/libmcp) |
| [micon](packages/m/micon/xmake.lua) | 0.2.0 | [luiox/micon](https://github.com/luiox/micon) |
| [duilib](packages/d/duilib/xmake.lua) | 0.1.0 | [luiox/DuiLib_DuiEditor](https://github.com/luiox/DuiLib_DuiEditor) |
| [uikit](packages/u/uikit/xmake.lua) | 0.1.0 | [luiox/uikit](https://github.com/luiox/uikit) |

> libca 0.0.7 起包内不再含 em（已拆分至独立仓库）。0.0.2 为嵌入式代快照，勿在桌面消费。
> libmcp 依赖 libca 0.0.7（public 传导）；libmcp 0.0.1 头文件安装布局有缺陷，勿消费。
> libca 按需子库：`add_requires("libca 0.0.7", {configs = {modules = "core,str,json"}})`，
> links 按 MODULE_DEPS 依赖闭包裁剪；`all`（默认）= 除 test 外全部模块；
> test 须显式点名（消费方自带 gtest）；未知名直接报错。
> uikit 整包（默认）依赖 duilib（windows）；linux/macos 消费主题引擎须
> `add_requires("uikit 0.1.0", {configs = {core_only = true}})`。

新增包：`packages/<包名首字母>/<包名>/xmake.lua`，参考 libca 现有定义。
