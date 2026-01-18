---
name: ""
overview: ""
todos: []
---

# XiaoMusic Flutter 应用开发计划

根据提供的 `openapi.json` 和《后端 API 文档》，以下是 XiaoMusic 移动应用的功能路线图。---

## 1. 项目架构与初始化

- **状态管理**：Riverpod（推荐用于全局认证/播放器状态管理）。
- **网络请求**：Dio（用于 HTTP 请求）+ Retrofit（可选，用于类型安全的 API 调用）。
- **本地持久化**：SharedPreferences 或 Hive（用于保存服务器地址、凭证等）。
- **音频播放**：本应用主要作为小米音箱的**远程控制器**；如需本地试听音乐，可使用 `just_audio` 实现。

---

## 2. 功能模块

### 第一阶段：核心连接与控制（MVP 最小可行产品）

目标是连接到服务器并实现基础播放控制。

- [ ] **登录/连接页面**：
    - 输入服务器地址（例如：`http://192.168.1.x:8090`）。
    - 输入用户名和密码（支持 Basic Auth 认证）。
    - 连接测试按钮（调用 `/getversion` 接口验证连通性）。
- [ ] **首页仪表盘（远程控制）**：
    - **设备选择器**：下拉菜单切换不同设备（通过 `/getsetting` 获取 `devices` 列表）。
    - **当前播放卡片**：
        - 显示当前歌曲名称、艺术家（通过 `/playingmusic` 获取）。
        - **播放控制**：播放/停止（调用 `/cmd` 或 `/playmusic`）、上一首/下一首（调用 `/cmd`）、音量滑块（通过 `/getvolume` 和 `/setvolume` 控制）。
    - **快捷操作**：
        - 文字转语音输入（调用 `/playtts`）。
        - 自定义命令输入（调用 `/cmd`）。

---

### 第二阶段：音乐库与搜索功能

浏览并播放服务器上的音乐。

- [ ] **音乐列表视图**：
    - 展示所有歌曲（调用 `/musiclist`）。
    - 按“全部”、“最新”、“收藏”分组。
    - 搜索栏（调用 `/searchmusic`）。
- [ ] **歌曲详情页**：
    - 查看元数据（歌词、封面）（调用 `/musicinfo`）。
    - 编辑元数据标签（调用 `/setmusictag`）。
    - **播放操作**：发送指定歌曲的播放指令（调用 `/playmusic`）。

---

### 第三阶段：歌单管理

管理音乐合集。

- [ ] **歌单标签页**：
    - 列出所有歌单（通过 `/playlistnames` 或从 `/musiclist` 中提取）。
    - 创建新歌单（调用 `/playlistadd`）。
    - 重命名/删除歌单（调用 `/playlistupdatename`、`/playlistdel`）。
- [ ] **歌单详情页**：
    - 列出歌单中的歌曲（调用 `/playlistmusics`）。
    - 添加/移除歌曲（调用 `/playlistaddmusic`、`/playlistdelmusic`）。
    - 播放整个歌单（调用 `/playmusiclist`）。

---

### 第四阶段：下载器与系统设置

面向服务器管理的高级功能。

- [ ] **下载管理器**：
    - 输入 URL 下载单曲或歌单（调用 `/downloadjson`、`/downloadplaylist`）。
    - 上传 `yt-dlp` 的 Cookie 文件（调用 `/uploadytdlpcookie`）。
- [ ] **系统设置**：
    - 配置小米账号/DID（调用 `/savesetting`）。
    - 管理定时任务（Cron Jobs）。
    - 检查/更新服务器版本（调用 `/getversion`、`/updateversion`）。

---

## 技术数据流

1. **初始化流程**：  

应用启动 → 加载已保存的服务器地址和认证信息 → 调用 `/getsetting` 获取设备列表。

2. **状态同步机制**：  

通过定期轮询 `/playingmusic`（每几秒一次），或使用 WebSocket（通过 `/generate_ws_token` 建立连接），保持 UI 与音箱播放状态实时同步。