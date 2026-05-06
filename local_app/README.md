# 学习通作业提醒本地版 App

这是当前 GitHub 仓库实际开源的版本，位于 `local_app`。它是一个本地优先的 Flutter App，不依赖自建后端。

当前版本：1.0.3

## 功能

- 使用学习通账号密码登录并同步作业。
- 只显示未完成作业；已完成/已互评作业会被过滤，未完成互评作业会保留。
- 支持作业详情、返回主页、手动标记完成。
- 手动标记完成的作业会本地隐藏，后续刷新不会重新出现。
- 提供本地同步状态页和友好刷新提示。
- 支持自定义提醒时间，可添加、删除并保存多个提醒规则。
- 支持本地系统通知和开机后恢复已安排提醒。
- 支持 Android 桌面小组件，显示近期待完成作业、课程名和剩余时间。
- 小组件点击可通过 deep link 直接进入对应作业详情。
- “关于应用”包含版权、微信、MIT License 和 GitHub 源码入口。

## 预览

| 作业列表 | 桌面小组件 |
| --- | --- |
| ![作业列表](../docs/images/app-homework-list.jpg) | ![桌面小组件](../docs/images/home-widget.jpg) |

## 隐私与边界

- 账号密码和作业数据只保存在本机，不会上传到任何服务器。
- 凭证通过 Flutter 安全存储保存到 iOS Keychain / Android Keystore。
- 不实现验证码绕过、风控绕过或逆向破解加密保护。

## 开发运行

```powershell
cd D:\code\study_assistant\local_app
flutter pub get
flutter test
flutter analyze
flutter run
```

## 构建 APK

```powershell
cd D:\code\study_assistant\local_app
flutter build apk --release
```

如需使用本机 release keystore 签名，请在本地保管 `.jks` 文件，不要提交到 Git。

## 目录

- `lib`：Flutter 业务代码。
- `android`：Android Runner、小组件、原生打开外部链接 MethodChannel。
- `ios`：iOS Runner 和 WidgetKit 扩展骨架。
- `test`：解析、过滤、同步合并、提醒规则和 deep link 测试。
