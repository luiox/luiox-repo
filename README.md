# luiox-repo

luiox 自研私有库的 xmake **包定义仓**（package definitions only）。库源码不在本仓——
各库来自它自己的 git 仓库；本仓只回答「有哪些版本、怎么构建安装」。

## 消费方接线

项目级（写进消费项目的 `xmake.lua`，xmake 首次配置时自动克隆本仓）：

```lua
add_repositories("luiox-repo https://github.com/luiox/luiox-repo.git")
add_requires("libca 0.0.1")
```

开发机全局（对本机所有项目生效，`xrepo` 命令行场景适用）：

```sh
xrepo add-repo luiox-repo https://github.com/luiox/luiox-repo.git
```

私有仓认证：xmake 对 git URL 直接调用系统 git，SSH key / Windows 凭据管理器 /
credential helper 自动生效，CI 用 deploy key，与 submodule 时代同源，无额外配置。
若全局 `.gitconfig` 配置了失效代理，可 `GIT_CONFIG_GLOBAL=/dev/null xmake ...` 绕过。

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
| libca | 0.0.1 | [luiox/libca](https://github.com/luiox/libca) @ `1ab29dea` |

新增包：`packages/<包名首字母>/<包名>/xmake.lua`，参考 libca 现有定义。
