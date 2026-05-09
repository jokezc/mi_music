# 播放链路自动化方案

## 目标

把本地播放链路尽量收敛成“真机一键回归”，减少你自己逐项手点。

## 方案结构

1. 启动配置自动化
   - 通过 `--dart-define` 开启测试模式。
   - 可复用设备已有登录态，也可临时注入服务端配置。
   - 默认强制切到本地设备，避免误测远程播放。

2. UI 可测试化
   - 登录页、歌单列表、歌曲列表、迷你播放器、全屏播放器都补了稳定 `Key`。

3. 状态探针
   - 测试模式下挂载隐藏 Probe，直接暴露当前歌曲、播放状态、进度、队列长度等关键信息。

4. 真机执行与日志采集
   - 使用 `integration_test` 真机拉起 App 并自动操作。
   - 同时采集 `flutter test` 输出和 `adb logcat`。

## 当前自动化覆盖

`integration_test/playback_flow_test.dart` 当前覆盖：

1. 自动登录或复用已有登录态
2. 进入音乐库
3. 打开目标歌单
4. 播放目标歌曲
5. 校验是否进入本地播放态
6. 打开全屏播放器
7. 校验暂停/恢复
8. 校验拖动进度
9. 校验上一首/下一首

## 运行方式

### 复用设备已有登录态

```powershell
.\tool\run_playback_integration.ps1
```

### 显式传入服务端配置

```powershell
.\tool\run_playback_integration.ps1 `
  -DeviceId "192.168.1.104:38017" `
  -ServerUrl "http://192.168.1.10:8090" `
  -Username "your_user" `
  -Password "your_password"
```

### 指定歌单和歌曲

```powershell
.\tool\run_playback_integration.ps1 `
  -PlaylistName "全部" `
  -SongName "某一首歌"
```

## 日志产物

脚本会输出到 `test_logs/<timestamp>/`：

- `flutter_test_output.txt`
- `adb_logcat.txt`

## 仍建议保留的少量人工专项

1. 锁屏通知栏控制
2. 后台长时间保活
3. 蓝牙耳机接入/断开
4. 来电或系统音频焦点抢占
5. 厂商 ROM 特有后台限制

## integration_test 是什么

`integration_test` 是 Flutter 官方的集成测试方案。

它会把 App 真跑到手机上，然后自动点页面、切歌、拖进度，再结合日志判断整条播放链路是否正常。
