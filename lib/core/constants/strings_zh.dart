/// 中文字符串常量
class S {
  S._();

  // 应用名称
  static const String appName = '风花雪乐';

  // 导航栏
  static const String navLibrary = '音乐库';
  static const String navSearch = '搜索';
  static const String navFunctions = '功能';

  // 音乐库 Tab
  static const String tabPlaylists = '歌单';
  static const String tabAllSongs = '全部';
  static const String tabFavorites = '收藏';

  // 播放控制
  static const String play = '播放';
  static const String pause = '暂停';
  static const String previous = '上一首';
  static const String next = '下一首';
  static const String stop = '停止';
  static const String volume = '音量';
  static const String nowPlaying = '正在播放';
  static const String notPlaying = '未在播放';
  static const String playlist = '歌单';
  static const String playQueue = '播放队列';

  // 搜索页
  static const String searchHint = '搜索歌曲...';
  static const String searchMusic = '搜索音乐';
  static const String downloadMusic = '下载音乐';
  static const String downloadPlaylist = '下载歌单';
  static const String noResults = '暂无搜索结果';
  static const String enterKeyword = '请输入关键词搜索';

  // 功能页
  static const String deviceSelector = '设备选择';
  static const String selectDevice = '选择设备';
  static const String noDevices = '未找到设备';
  static const String playerControl = '播放控制';
  static const String quickActions = '快捷操作';
  static const String tts = '文字转语音';
  static const String ttsHint = '输入要朗读的文字';
  static const String customCommand = '自定义指令';
  static const String customCommandHint = '例如：关机、播放周杰伦';
  static const String refreshMusicTagCache = '刷新音乐信息缓存';
  static const String deviceInfo = '设备信息';
  static const String versionInfo = '版本信息';
  static const String backendVersion = '后端版本';
  static const String settings = '设置';
  static const String goToSettings = '服务设置';
  static const String connectionConfig = '连接配置';

  // 歌单
  static const String playlists = '歌单';
  static const String createPlaylist = '新建歌单';
  static const String deletePlaylist = '删除歌单';
  static const String renamePlaylist = '重命名歌单';
  static const String playlistName = '歌单名称';
  static const String emptyPlaylist = '暂无歌单';
  static const String emptySongs = '暂无歌曲';
  static const String confirmDelete = '确定删除吗？';
  static const String deleteConfirmMessage = '确定要删除这个歌单吗？';

  // 设置页
  static const String serverUrl = '服务器地址';
  static const String serverUrlHint = 'http://192.168.1.x:8090';
  static const String username = '用户名';
  static const String usernameOptional = '用户名（可选）';
  static const String password = '密码';
  static const String passwordOptional = '密码（可选）';
  static const String connect = '连接';
  static const String connecting = '连接中...';
  static const String connected = '连接成功！';
  static const String connectionFailed = '连接失败';
  static const String themeSettings = '外观设置';
  static const String themeMode = '主题模式';
  static const String themeSystem = '跟随系统';
  static const String themeLight = '浅色模式';
  static const String themeDark = '深色模式';

  // 设置分类
  static const String accountSettings = '账号设置';
  static const String directorySettings = '目录配置';
  static const String serviceSettings = '服务配置';
  static const String playSettings = '播放配置';
  static const String voiceSettings = '语音控制配置';
  static const String dialogSettings = '对话提示音配置';
  static const String appearanceSettings = '外观设置';
  static const String clientSettings = '客户端设置';
  static const String about = '关于';
  static const String testConnection = '测试连接';
  static const String logout = '退出登录';
  static const String logoutConfirm = '确定要退出登录吗？';
  static const String appVersion = 'App 版本';
  static const String openSourceLicense = '开源许可';
  static const String projectLink = '项目主页';

  // 下载
  static const String download = '下载';
  static const String downloading = '下载中...';
  static const String downloadSuccess = '下载成功';
  static const String downloadFailed = '下载失败';
  static const String musicUrl = '音乐链接';
  static const String musicUrlHint = '输入音乐或视频链接';
  static const String playlistUrl = '歌单链接';
  static const String playlistUrlHint = '输入歌单链接';
  static const String folderName = '文件夹名称';
  static const String folderNameHint = '保存到的文件夹名';

  // 通用
  static const String confirm = '确定';
  static const String cancel = '取消';
  static const String save = '保存';
  static const String delete = '删除';
  static const String edit = '编辑';
  static const String add = '添加';
  static const String refresh = '刷新';
  static const String loading = '加载中...';
  static const String error = '错误';
  static const String success = '成功';
  static const String failed = '失败';
  static const String retry = '重试';
  static const String send = '发送';
  static const String speak = '朗读';

  // 错误信息
  static const String errorLoading = '加载失败';
  static const String errorNetwork = '网络错误';
  static const String errorServer = '服务器错误';
  static const String errorUnknown = '未知错误';
  static const String pleaseEnterUrl = '请输入服务器地址';
  static const String urlMustStartWithHttp = '地址必须以 http:// 或 https:// 开头';

  // 提示信息
  static const String playing = '正在播放';
  static const String commandSent = '指令已发送';

  // 账号设置字段
  static const String xiaomiAccount = '小米账号';
  static const String xiaomiAccountDid = '小米账号DID';
  static const String saveChanges = '保存更改';

  // 目录配置字段
  static const String musicDirectory = '音乐目录';
  static const String musicDownloadDirectory = '音乐下载目录';
  static const String tempFileDirectory = '临时文件目录';
  static const String configFileDirectory = '配置文件目录';
  static const String cacheFileDirectory = '缓存文件目录';
  static const String logFile = '日志文件';
  static const String ffmpegPath = 'FFmpeg路径';
  static const String excludeDirs = '忽略目录(逗号分割)';
  static const String ignoreTagDirs = '不扫描标签信息目录(逗号分割)';
  static const String musicPathDepth = '扫描目录深度';

  // 服务配置字段
  static const String hostnameIp = '主机名/IP';
  static const String localPort = '本地端口';
  static const String publicPort = '公共端口';
  static const String proxyAddress = '代理地址';
  static const String proxyAddressHint = '请输入代理地址';
  static const String disableHttpAuth = '禁用HTTP认证';
  static const String httpAuthUsername = 'HTTP认证用户名';
  static const String httpAuthPassword = 'HTTP认证密码';

  // 语音控制配置字段
  static const String allowedWakeupCommands = '允许唤醒的命令';
  static const String playLocalSongCommand = '播放本地歌曲口令';
  static const String playSongCommand = '播放歌曲口令';
  static const String playListCommand = '播放列表口令';
  static const String stopCommand = '停止口令';
  static const String localSearchPlayCommand = '本地搜索播放口令';
  static const String searchPlayCommand = '搜索播放口令';

  // 对话提示音配置字段
  static const String getDialogueRecords = '获取对话记录';
  static const String getDialogueInterval = '获取对话间隔(秒)';
  static const String specialModelGetDialogueRecords = '特殊型号获取对话记录';
  static const String stopPromptTone = '停止提示音';
  static const String singleSongLoopPromptTone = '单曲循环提示音';
  static const String allLoopPromptTone = '全部循环提示音';
  static const String randomPlayPromptTone = '随机播放提示音';
  static const String singleSongPlayPromptTone = '单曲播放提示音';
  static const String sequentialPlayPromptTone = '顺序播放提示音';
  static const String saveSuccess = '保存成功';
  static const String saveFailed = '保存失败';

  // 播放配置字段
  static const String searchPrefix = 'XIAOMUSIC_SEARCH(歌曲下载方式)';
  static const String getDurationType = '获取时长方式';
  static const String loudnorm = '均衡歌曲音量大小(loudnorm滤镜)';
  static const String removeId3tag = '去除MP3 ID3v2和填充';
  static const String convertToMp3 = '转换为MP3';
  static const String delaySec = '下一首歌延迟播放秒数(支持负数)';
  static const String enableFuzzyMatch = '开启模糊搜索';
  static const String fuzzyMatchCutoff = '模糊匹配阈值(0.1~0.9)';
  static const String disableDownload = '关闭下载功能';

  // 客户端设置字段
  static const String pauseCurrentDeviceOnSwitch = '切换设备时暂停当前设备';
  static const String pauseCurrentDeviceOnSwitchDesc = '自动暂停正在播放的远程设备';
  static const String syncPlaybackOnSwitch = '切换设备时同步播放内容';
  static const String syncPlaybackOnSwitchDesc = '同步播放内容到新设备（暂停时不同步）';
  static const String softwareSettings = '软件设置';

  // 定时任务
  static const String scheduledTasks = '定时任务';
  static const String addScheduledTask = '添加定时任务';
  static const String editScheduledTask = '编辑定时任务';
  static const String taskName = '任务名称';
  static const String taskType = '任务类型';
  static const String cronExpression = 'Cron表达式';
  static const String cronExpressionHint = '例如：0 8 * * 0-4 (周一到周五每天8点)';
  static const String deviceName = '设备名称';
  static const String deviceId = '设备ID';
  static const String deviceIdHint = '小爱音箱的设备ID';
  static const String taskParameter = '任务参数';
  static const String taskParameterHint = '根据任务类型填写参数';
  static const String musicList = '音乐列表';
  static const String firstSong = '首播歌曲';
  static const String firstSongHint = '从哪首歌曲开始播放';
  static const String emptyScheduledTasks = '暂无定时任务';
  static const String deleteTaskConfirm = '确定要删除这个定时任务吗？';
  static const String taskSaved = '定时任务已保存';
  static const String taskDeleted = '定时任务已删除';
  static const String taskSaveFailed = '保存定时任务失败';
  static const String taskDeleteFailed = '删除定时任务失败';
  static const String invalidCronExpression = '无效的Cron表达式';
  static const String taskTypeStop = '关机';
  static const String taskTypePlay = '播放歌曲';
  static const String taskTypePlayMusicList = '播放列表';
  static const String taskTypeTts = '文字转语音';
  static const String taskTypeRefreshMusicList = '刷新播放列表';
  static const String taskTypeSetVolume = '设置音量';
  static const String taskTypeSetPlayType = '设置播放类型';
  static const String taskTypeSetPullAsk = '设置拉取对话记录';
  static const String taskTypeReinit = '重新初始化';
  static const String taskTypePlayMusicTmpList = '播放自定义列表';
  static const String playTypeSingleLoop = '单曲循环';
  static const String playTypeAllLoop = '全部循环';
  static const String playTypeRandom = '随机播放';
  static const String playTypeSingle = '单曲播放';
  static const String playTypeSequential = '顺序播放';
  static const String enable = '启用';
  static const String disable = '禁用';
  static const String cronExpressionExample = 'Cron表达式示例';
  static const String cronExpressionHelp = '格式：分 时 日 月 星期';
  static const String quickExpression = '快捷表达式';
  static const String selectQuickExpression = '选择快捷表达式';
  static const String customExpression = '自定义';
}
