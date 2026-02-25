# just_audio currentIndex=-1 导致 RangeError 的说明

## 现象

- 控制台：`RangeError (length): Not in inclusive range 0..N: -1`
- 堆栈：`AudioPlayer._setPlatformActive.subscribeToEvents.<anonymous> (just_audio.dart:1559)`
- 常出现在：**切换歌单**、**App 从后台恢复** 时
- 可能伴随：`MPV: [error] media_kit: property not found _setProperty(osc, 1)`（osc = 屏幕控制相关，与 media_kit/MPV 有关）

## 根因链（为什么会出现 -1）

1. **我们这边的调用**
   - 切换歌单时：`loadPlaylist()` 里会先 `await _player.stop()` 再 `await _player.setAudioSources(sources, initialIndex: 0)`。
   - `stop()` 会清空当前播放列表，此时底层（media_kit/MPV）可能处于「无当前曲目」状态。

2. **底层上报 -1**
   - Windows 使用 **just_audio_media_kit**，底层是 **media_kit / libmpv**。
   - 在「清空列表 → 设置新列表」的过渡瞬间，或 MPV 报错（如 osc 属性不存在）时，底层可能向 just_audio 上报 **currentIndex = -1**（表示暂无当前项）。
   - 文档上 currentIndex 在「无源/空列表」时本应是 `null`，但平台实现可能先发出 -1。

3. **just_audio 未做防护**
   - just_audio 在 `subscribeToEvents` 的回调里用「平台给的 index」直接做 `sequence[index]`，没有对 -1 或越界做校验，于是 `list[-1]` 抛出 RangeError。

所以：**-1 来自底层/平台，just_audio 未校验就用了，所以会走到报错这一步。**

## 我们能做的

### 1. 兜底（当前做法）——必须保留

- 在 `main.dart` 用 `runZonedGuarded` 包住 `runApp`，对「Not in inclusive range ... -1」的 RangeError 只打日志、不抛出。
- 这样应用不会崩溃，播放会继续；不兜底的话一旦出现就会未处理异常退出。

### 2. 根因修复——只能在上游做

- **just_audio**：在收到平台 index 时做校验（例如 -1 或越界时当 null/无效处理，不执行 `sequence[index]`）。需在 [just_audio](https://github.com/ryanheise/just_audio) 提 issue 或 PR。
- **just_audio_media_kit**：在向 just_audio 上报 currentIndex 时，若有列表且 index&lt;0，改为上报 0 或不下发。需在对应仓库提 issue/PR。

我们无法在本项目里改这两个包的源码，所以**只能兜底 + 推动上游修**。

### 3. 调用侧缓解（可选）

- 当前逻辑：切换歌单时先 `stop()` 再 `setAudioSources(...)`，会有一小段「空列表」时间，容易让底层发出 -1。
- 可尝试：在**仅切换歌单**（不是从「无列表」到「有列表」）时，不先 `stop()`，直接 `setAudioSources(newSources, initialIndex: 0)`，看是否减少 -1 出现频率。若试下来有效，可保留；若带来别的问题（如资源未释放、卡顿），再恢复先 stop 再 set。

## 总结

- **为什么会报错**：底层在过渡或异常时上报 currentIndex=-1，just_audio 直接用 -1 访问列表导致 RangeError。
- **是否只能兜底**：在我们应用内只能兜底；真正修掉需要在 just_audio 或 just_audio_media_kit 里对 index 做校验或修正。
- **当前**：保留 runZonedGuarded 兜底；可选地尝试「切换歌单时不先 stop」以减轻触发。
