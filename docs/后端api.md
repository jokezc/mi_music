[1 tool called]

这里是根据项目代码分析整理的 API 接口文档，适用于 Flutter 复刻开发。

定制的时候，"全部"和”所有歌曲"的区别，帮助有需要的朋友：
歌单中 "全部" 指的是 所有歌单中歌曲，但不包括“歌单内容”配置（http://127.0.0.1:8090/static/setting.html）中的电台 "type": "radio",的
”所有歌曲" 指的是下载的歌曲，在 download 文件夹里

### 接口通用说明

- **基础路径 (Base URL)**: 根据用户配置的 `domain`（域名）或 `ip` 地址拼接。
- **鉴权 (Authentication)**: 支持 Basic Auth。
  - Header: `Authorization: Basic base64(username:password)`
- **请求封装**:
  - 这里的请求大多为 JSON 格式。
  - 成功响应通常状态码为 200。
  - 若使用云开发或其他代理，可能需要在 Header 中携带额外字段。

---

### 1. 系统配置 (System)

#### 获取系统设置

获取服务端的所有配置项、设备列表及定时任务。

- **URL**: `/getsetting`
- **Method**: `GET`
- **Query Params**:
  - `need_device_list`: `true` | `false` (可选，是否返回设备列表)
- **Response**:
  ```json
  {
    "account": "3728190",
    "password": "******",
    "mi_did": "4367284",
    "cookie": "",
    "verbose": false,
    "music_path": "music",
    "temp_path": "music/tmp",
    "download_path": "music/download",
    "conf_path": "conf",
    "cache_dir": "cache",
    "hostname": "192.168.0.11",
    "port": 8090,
    "public_port": 58090,
    "proxy": "",
    "loudnorm": "",
    "search_prefix": "bilisearch:",
    "ffmpeg_location": "./ffmpeg/bin",
    "get_duration_type": "ffprobe",
    "active_cmd": "play,search_play,set_play_type_rnd,playlocal,search_playlocal,play_music_list,play_music_list_index,stop_after_minute,stop",
    "exclude_dirs": "@eaDir,tmp",
    "ignore_tag_dirs": "",
    "music_path_depth": 10,
    "disable_httpauth": false,
    "httpauth_username": "joke",
    "httpauth_password": "******",
    "music_list_url": "",
    "music_list_json": "",
    "custom_play_list_json": "",
    "disable_download": false,
    "key_word_dict": {
      "下一首": "play_next",
      "上一首": "play_prev",
      "单曲循环": "set_play_type_one",
      "全部循环": "set_play_type_all",
      "随机播放": "set_play_type_rnd",
      "单曲播放": "set_play_type_sin",
      "顺序播放": "set_play_type_seq",
      "分钟后关机": "stop_after_minute",
      "刷新列表": "gen_music_list",
      "加入收藏": "add_to_favorites",
      "收藏歌曲": "add_to_favorites",
      "取消收藏": "del_from_favorites",
      "播放列表第": "play_music_list_index",
      "删除歌曲": "cmd_del_music",
      "播放本地歌曲": "playlocal",
      "本地播放歌曲": "playlocal",
      "本地搜索播放": "search_playlocal",
      "播放歌曲": "play",
      "放歌曲": "play",
      "播放音乐": "play",
      "搜索播放": "search_play",
      "关机": "stop",
      "暂停": "stop",
      "停止": "stop",
      "停止播放": "stop",
      "播放列表": "play_music_list",
      "播放歌单": "play_music_list",
      "测试自定义口令": "exec#code1(\"hello\")",
      "测试链接": "exec#httpget(\"https://github.com/hanxi/xiaomusic\")"
    },
    "key_match_order": [
      "分钟后关机",
      "下一首",
      "上一首",
      "单曲循环",
      "全部循环",
      "随机播放",
      "单曲播放",
      "顺序播放",
      "关机",
      "刷新列表",
      "播放列表第",
      "播放列表",
      "加入收藏",
      "收藏歌曲",
      "取消收藏",
      "删除歌曲",
      "播放本地歌曲",
      "本地播放歌曲",
      "本地搜索播放",
      "播放歌曲",
      "放歌曲",
      "播放音乐",
      "搜索播放",
      "暂停",
      "停止",
      "停止播放",
      "播放歌单",
      "测试自定义口令",
      "测试链接"
    ],
    "use_music_api": false,
    "use_music_audio_id": "2321",
    "use_music_id": "321321",
    "log_file": "xiaomusic.log.txt",
    "fuzzy_match_cutoff": 0.6,
    "enable_fuzzy_match": true,
    "stop_tts_msg": "好运",
    "enable_config_example": false,
    "keywords_playlocal": "播放本地歌曲,本地播放歌曲",
    "keywords_search_playlocal": "本地搜索播放",
    "keywords_play": "播放歌曲,放歌曲,播放音乐",
    "keywords_search_play": "搜索播放",
    "keywords_stop": "关机,暂停,停止,停止播放",
    "keywords_playlist": "播放列表,播放歌单",
    "user_key_word_dict": {
      "测试自定义口令": "exec#code1(\"hello\")",
      "测试链接": "exec#httpget(\"https://github.com/hanxi/xiaomusic\")"
    },
    "enable_force_stop": false,
    "devices": {
      "4367284": {
        "did": "4367284",
        "device_id": "cb212121289ee2bdb",
        "hardware": "S12A",
        "name": "小米AI音箱",
        "play_type": 4,
        "cur_music": "薛之谦-暧昧",
        "cur_playlist": "所有歌曲"
      }
    },
    "group_list": "",
    "remove_id3tag": false,
    "convert_to_mp3": false,
    "delay_sec": 3,
    "continue_play": false,
    "enable_file_watch": false,
    "file_watch_debounce": 10,
    "pull_ask_sec": 1,
    "enable_pull_ask": true,
    "crontab_json": "",
    "enable_yt_dlp_cookies": false,
    "enable_save_tag": false,
    "enable_analytics": true,
    "get_ask_by_mina": false,
    "play_type_one_tts_msg": "已经设置为单曲循环",
    "play_type_all_tts_msg": "已经设置为全部循环",
    "play_type_rnd_tts_msg": "已经设置为随机播放",
    "play_type_sin_tts_msg": "已经设置为单曲播放",
    "play_type_seq_tts_msg": "已经设置为顺序播放",
    "recently_added_playlist_len": 50,
    "enable_cmd_del_music": true,
    "search_music_count": 100,
    "web_music_proxy": false,
    "device_list": [
      {
        "deviceID": "cbfffb23-5483-2121",
        "serialNumber": "18090/2121",
        "name": "小米AI音箱",
        "alias": "小米AI音箱",
        "current": false,
        "presence": "online",
        "address": "212.88.64.2",
        "miotDID": "2121",
        "hardware": "S12A",
        "romVersion": "1.76.54",
        "romChannel": "release",
        "capabilities": {
          "content_blacklist": 1,
          "lan_tv_control": 1,
          "night_mode_v2": 1,
          "school_timetable": 1,
          "night_mode": 1,
          "user_nick_name": 1,
          "player_pause_timer": 1,
          "dialog_h5": 1,
          "child_mode_2": 1,
          "dlna": 1,
          "report_times": 1,
          "voice_print": 1,
          "ai_instruction": 1,
          "alarm_volume": 1,
          "classified_alarm": 1,
          "loadmore_v2": 1,
          "mesh": 1,
          "ai_protocol_3_0": 1,
          "voice_print_multidevice": 1,
          "night_mode_detail": 1,
          "child_mode": 1,
          "baby_schedule": 1,
          "tone_setting": 1,
          "earthquake": 1,
          "alarm_repeat_option_v2": 1,
          "xiaomi_voip": 1,
          "nearby_wakeup_cloud": 1,
          "family_voice": 1,
          "bluetooth_option_v2": 1,
          "skill_try": 0,
          "yueyu": 1,
          "yunduantts": 1,
          "mico_current": 1,
          "cp_level": 1,
          "voip_used_time": 1
        },
        "remoteCtrlType": "",
        "deviceSNProfile": "2222=",
        "deviceProfile": "3333=",
        "brokerEndpoint": "c3-xq-mt003.bj:1884",
        "brokerIndex": 114,
        "mac": "E4:321321:AD",
        "ssid": ""
      }
    ]
  }
  ```

#### 保存系统设置

保存修改后的配置。

- **URL**: `/savesetting`
- **Method**: `POST`
- **Body**: 见上述 `/getsetting` 的返回结构，但 `device_list` 字段可选（如果不需要更新它）。

#### 获取版本信息

- **URL**: `/getversion`
- **Method**: `GET`
- **Response**:
  ```json
  {
    "version": "v1.2.3"
  }
  ```

---

### 2. 播放控制 (Player Control)

#### 发送通用指令

向指定设备发送文本指令（如“下一首”、“关机”）。

- **URL**: `/cmd`
- **Method**: `POST`
- **Body**:
  ```json
  {
    "cmd": "上一首", // 或 "关机", "播放xxx"
    "did": "device_id"
  }
  ```

#### 播放指定歌曲

- **URL**: `/playmusic`
- **Method**: `POST`
- **Body**:
  ```json
  {
    "did": "device_id",
    "musicname": "歌曲名",
    "searchkey": "歌曲名" // 通常与 musicname 相同
  }
  ```

#### 播放指定歌单

- **URL**: `/playmusiclist`
- **Method**: `POST`
- **Body**:
  ```json
  {
    "did": "device_id",
    "listname": "歌单名",
    "musicname": "歌曲名" // (可选) 指定从歌单中的哪首歌开始播放
  }
  ```

#### 播放 URL 链接

- **URL**: `/playurl`
- **Method**: `GET`
- **Query Params**:
  - `url`: `http://example.com/music.mp3` (需 URL Encode)
  - `did`: `device_id`

#### 文本转语音 (TTS)

- **URL**: `/playtts`
- **Method**: `POST`
- **Body**:
  ```json
  {
    "did": "device_id",
    "text": "需要播放的文本内容"
  }
  ```

#### 获取播放状态

获取设备当前的播放进度、状态等。

- **URL**: `/playingmusic`
- **Method**: `GET`
- **Query Params**:
  - `did`: `device_id`
- **Response**:
  ```json
  {
    "cur_music": "歌曲名",
    "cur_playlist": "歌单名",
    "is_playing": true,
    "offset": 120, // 当前播放秒数
    "duration": 300 // 总时长秒数
  }
  ```

#### 获取/设置音量

- **获取音量**:
  - **URL**: `/getvolume`
  - **Method**: `GET`
  - **Query**: `did=xxx`
  - **Response**: `{ "volume": 30 }`
- **设置音量**:
  - **URL**: `/setvolume`
  - **Method**: `POST`
  - **Body**:
    ```json
    {
      "did": "device_id",
      "volume": 50
    }
    ```

---

### 3. 歌单与音乐管理 (Playlist & Music)

#### 获取所有音乐列表

返回所有歌单及其包含的歌曲。

- **URL**: `/musiclist`
- **Method**: `GET`
- **Response**:
  ```json
  {
    "所有歌曲": ["song1.mp3", "song2.mp3"],
    "最近新增": ["song1.mp3"],
    "收藏": ["song2.mp3"],
    "自定义歌单1": [...]
  }
  ```

#### 获取当前播放列表名称

- **URL**: `/curplaylist`
- **Method**: `GET`
- **Query**: `did=xxx`
- **Response**: `"歌单名称"` (直接返回字符串或简单对象，需根据实际后端确认，前端代码作为字符串处理)

#### 获取歌单名称列表

- **URL**: `/playlistnames`
- **Method**: `GET`
- **Response**:
  ```json
  {
    "names": ["自定义歌单1", "自定义歌单2"]
  }
  ```

#### 歌单操作

以下操作均为 `POST` 请求。

| 接口                  | 用途             | Body 参数                                        |
| :-------------------- | :--------------- | :----------------------------------------------- |
| `/playlistadd`        | 新建歌单         | `{ "name": "歌单名" }`                           |
| `/playlistdel`        | 删除歌单         | `{ "name": "歌单名" }`                           |
| `/playlistupdatename` | 重命名歌单       | `{ "oldname": "旧名", "newname": "新名" }`       |
| `/playlistaddmusic`   | 添加歌曲到歌单   | `{ "name": "歌单名", "music_list": ["歌曲名"] }` |
| `/playlistdelmusic`   | 从歌单移除歌曲   | `{ "name": "歌单名", "music_list": ["歌曲名"] }` |
| `/delmusic`           | **永久删除**文件 | `{ "name": "歌曲名" }`                           |

---

### 4. 元数据与刮削 (Metadata)

#### 获取音乐详情

获取歌曲的元数据（封面、歌词、专辑信息）。

- **URL**: `/musicinfo`
- **Method**: `GET`
- **Query Params**:
  - `name`: `歌曲名`
  - `musictag`: `true`
- **Response**:
  ```json
  {
    "tags": {
      "title": "歌曲标题",
      "artist": "歌手",
      "album": "专辑名",
      "picture": "http://.../cover.jpg",
      "lyrics": "[00:01.00]歌词...",
      "year": "2023"
    }
  }
  ```

#### 写入音乐元数据

将刮削到的信息写入服务端文件。

- **URL**: `/setmusictag`
- **Method**: `POST`
- **Body**:
  ```json
  {
    "musicname": "原文件名",
    "title": "新标题",
    "artist": "歌手",
    "album": "专辑",
    "year": "年份",
    "lyrics": "LRC歌词内容",
    "picture": "Base64字符串"
  }
  ```
