---
alwaysApply: true
---

## 运行说明

我本地已经运行`dart run build_runner watch --delete-conflicting-outputs`命令会实时监测改动并重新生成代码,你不需要在执行生成代码的命令.

## 依赖控制

使用最新的依赖版本且需要和 flutter3.38.2 版本保持兼容

## ui 要求

所有界面需要支持深色浅色模式.
颜色搭配要使用按照 lib\core\theme\app_colors.dart 和 lib\core\theme\app_theme.dart 的文件的规范.
界面元素文字统一存放和使用 lib\core\constants\strings_zh.dart 文件内容.
Icons全部使用_rounded规格的,比如Icons.timer要使用Icons.timer_rounded

## 编码规范

### 日志打印

项目不允许使用 print,必须使用 package:logger/logger.dart 实现日志打印

### dart INFO,这种一般都是简单的语法告警

1.使用最新语法 api 2.明确参数类型
比如

```
SharedPreferences sharedPreferences(ref) {
  throw UnimplementedError();
}
```

应该改成

```
SharedPreferences sharedPreferences(Ref ref) {
  throw UnimplementedError();
}
```

### 部分代码如果后期还有可能使用请添加

// ignore: unused_element
忽略未使用告警
