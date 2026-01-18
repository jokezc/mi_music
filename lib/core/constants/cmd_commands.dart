/// 播放器控制指令常量
class PlayerCommands {
  PlayerCommands._();

  // 播放控制
  static const String play = '播放';
  static const String pause = '暂停';
  static const String stop = '停止';
  static const String next = '下一首';
  static const String previous = '上一首';

  // 播放模式
  static const String singleLoop = '单曲循环';
  static const String allLoop = '全部循环';
  static const String shuffle = '随机播放';
  static const String sequential = '顺序播放';

  // 定时关机（格式：X分钟后关机）
  static String shutdownAfterMinutes(int minutes) => '$minutes分钟后关机';
}

/// 设备命令常量
class DeviceCommands {
  DeviceCommands._();

  // 刷新歌单列表缓存
  static const String refreshList = '刷新列表';
}
