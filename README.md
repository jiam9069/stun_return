# 【Lucky STUN 反向回源一键脚本】

- 一个基于 STUN 协议的双向流量回源工具，支持 CentOS、Debian、Ubuntu、 Alpine 和 OpenWRT 系统。

* * *

## 目录

- [1. 教程](README.md#1教程)
- [2. 特点](README.md#2特点)
- [3. 支持的操作系统和架构](README.md#3支持的操作系统和架构)
- [4. 安装方法](README.md#4安装方法)
- [5. 卸载方法](README.md#5卸载方法)
- [6. 命令行参数](README.md#6命令行参数)
- [7. 使用示例](README.md#7使用示例)

* * *
## 1. 教程
- 博客教程: https://www.fscarmen.com/2025/01/gost-stun.html
- 视频教程: https://youtu.be/nqxA7kFVJi0

## 2. 特点
- 双栈支持：同时支持 IPv4 和 IPv6 回源，可以根据需要选择使用单栈或双栈模式。
- 无需公网 IP：通过 STUN 协议实现 NAT 穿透，让内网设备也能提供服务，工作十分高效。
- 高效转发：使用高性能的 GOST v3 作为转发工具，保证稳定的连接和较低的延迟。
- 轻量运行：工具依赖少，配置简单，适合在各种环境下部署。
- 灵活配置：支持自定义端口、路径等参数，方便与其他服务集成。

## 3. 支持的操作系统和架构
   | | 系统 | 架构 |
   | -- | -- | -- |
   | 服务端 | CentOS, Debian, Ubuntu, OpenWRT | amd64 (x86_64), arm64 |
   | 客户端 | CentOS, Debian, Ubuntu, Alpine | amd64 (x86_64), arm64 |

## 4. 安装方法

### 4.1 服务端安装

#### 4.1.1 交互式安装：

```bash
bash <(wget -qO- https://raw.githubusercontent.com/fscarmen/stun_return/main/stun_return.sh)
```

#### 4.1.2 快捷参数安装：

```
bash <(wget -qO- https://raw.githubusercontent.com/fscarmen/stun_return/main/stun_return.sh) \
  -s \
  -p server-origin-port \
  -w your-ws-path \
  -4 your-IPv4-domain.com \
  -6 your-IPv6-domain.com
```

### 4.2 客户端安装

#### 4.2.1 交互式安装：

```
bash <(wget -qO- https://raw.githubusercontent.com/fscarmen/stun_return/main/stun_return.sh)
```

#### 4.2.2 快捷参数安装：

```
bash <(wget -qO- https://raw.githubusercontent.com/fscarmen/stun_return/main/stun_return.sh) \
  -c \
  -w your-ws-path \
  -4 your-IPv4-domain.com \
  -r your-IPv4-return-port \
  -6 your-IPv6-domain.com \
  -e your-IPv6-return-port
```

## 5. 卸载方法

```
bash <(wget -qO- https://raw.githubusercontent.com/fscarmen/stun_return/main/stun_return.sh) -u
```

## 6. 命令行参数

| 参数 | 说明 | 使用场景 |
| ---- | ---- | -------- |
| -h | 显示帮助信息 | 服务端和客户端 |
| -u | 卸载服务端和客户端 | 服务端和客户端 |
| -w | WebSocket 路径 | 服务端和客户端 |
| -s | 安装服务端 | 服务端 |
| -p | 服务端端口 | 服务端 |
| -n | 显示客户端安装命令 | 服务端 |
| -c | 安装客户端 | 客户端 |
| -4 | IPv4 回源域名 | 客户端 |
| -r | IPv4 远程端口 | 客户端 |
| -6 | IPv6 回源域名 | 客户端 |
| -e | IPv6 远程端口 | 客户端 |

## 7. 使用示例

### 7.1 服务端完整安装示例：

```
bash <(wget -qO- https://raw.githubusercontent.com/fscarmen/stun_return/main/stun_return.sh) \
  -s \
  -p 20000 \
  -w 3b451552-e776-45c5-9b98-bde3ab99bf75 \
  -4 v4.stun.com \
  -6 v6.stun.com
```

### 7.2 客户端完整安装示例：

```
bash <(wget -qO- https://raw.githubusercontent.com/fscarmen/stun_return/main/stun_return.sh) \
  -c \
  -w 3b451552-e776-45c5-9b98-bde3ab99bf75 \
  -4 v4.stun.com \
  -r 30000 \
  -6 v6.stun.com \
  -e 30001
```

### 7.3 查看客户端安装命令：

```
bash <(wget -qO- https://raw.githubusercontent.com/fscarmen/stun_return/main/stun_return.sh) -n
```

### 7.4 卸载所有组件：

```
bash <(wget -qO- https://raw.githubusercontent.com/fscarmen/stun_return/main/stun_return.sh) -u
```