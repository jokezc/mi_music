# 小米音乐 App P0 核心体验开发计划

## 当前状态分析

现有代码结构：

- 3Tab 导航：Remote(首页) / Library(音乐库) / Playlists(歌单)
- 路由：`go_router` 的 `StatefulShellRoute` 实现
- 状态管理：`riverpod` + 代码生成
- API 层已完备，包含播放控制、歌单管理、音乐搜索等

## P0 开发内容

### 1. 布局重构

将当前 3Tab 调整为新结构：**音乐库（主页）** / **搜索** / **功能修改文件：**

- [`lib/router.dart`](lib/router.dart) - 更新路由分支
- [`lib/presentation/pages/scaffold_with_nav.dart`](lib/presentation/pages/scaffold_with_nav.dart) - 3个新导航项 + 迷你播放条容器

**新建文件：**

- `lib/presentation/pages/search/search_page.dart` - 搜索页（搜索 + 下载功能）
- `lib/presentation/pages/functions/functions_page.dart` - 功能页（设备控制 + 设置入口）
- `lib/presentation/widgets/mini_player.dart` - 底部迷你播放条

**删除/重构：**

- 删除 [`lib/presentation/pages/dashboard/`](lib/presentation/pages/dashboard/) - Dashboard 功能并入 Functions
- 重构 [`lib/presentation/pages/library/library_page.dart`](lib/presentation/pages/library/library_page.dart) - 添加顶部 TabBar（歌单/所有歌曲/收藏）

### 2. 主题系统

**新建文件：**

- `lib/core/theme/app_theme.dart` - 浅色/深色主题定义
- `lib/core/theme/app_colors.dart` - 颜色常量（渐变紫蓝主色 + 玫瑰粉强调色）
- `lib/data/providers/theme_provider.dart` - 主题状态管理（持久化到 SharedPreferences）

**修改文件：**

- [`lib/main.dart`](lib/main.dart) - 集成主题切换

### 3. 界面中文化

**新建文件：**

- `lib/core/constants/strings_zh.dart` - 中文字符串常量

**修改所有 UI 文件：**

- 将所有英文文案替换为中文

## 依赖更新

````yaml
# pubspec.yaml 无需新增依赖，现有依赖足够完成 P0
```



## 文件结构预览

```javascript
lib/
├── core/
│   ├── theme/
│   │   ├── app_theme.dart
│   │   └── app_colors.dart
│   └── constants/
│       └── strings_zh.dart
├── data/providers/
│   └── theme_provider.dart (新增)
├── presentation/
│   ├── pages/
│   │   ├── library/
│   │   │   └── library_page.dart (重构：TabBar)
│   │   ├── search/
│   │   │   └── search_page.dart (新增)
│   │   ├── functions/
│   │   │   └── functions_page.dart (新增)
│   │   └── scaffold_with_nav.dart (重构)
│   └── widgets/
│       └── mini_player.dart (新增)
└── router.dart (重构)





````