# 作业提醒

学习通作业提醒本地版 Flutter App。用户使用学习通账号密码登录后，App 在本机同步未完成作业、提醒截止时间，并支持手动标记完成。

## 项目信息

- 版权归 HY 所有
- 微信：HY676-
- GitHub：https://github.com/mshzy/study_assistant
- 开源协议：MIT License，详见 [LICENSE](LICENSE)

## 当前开源内容

本仓库只提交本地版 App：`local_app`。

服务器版资料保留在本机 `server_version` 目录中，用于后续开发“后端 + 连接服务器的 App”，但该目录已加入 `.gitignore`，不会上传到 GitHub。

## 开源协议

本项目采用 MIT License 开源，版权归 HY 所有。你可以在遵守 MIT License 的前提下使用、复制、修改、合并、发布、分发、再授权或销售本项目副本，但必须在软件副本或主要部分中保留原始版权声明和许可声明。

软件按“原样”提供，不提供任何明示或暗示担保。完整协议文本见 [LICENSE](LICENSE)。

## 本地版运行

```powershell
cd D:\code\study_assistant\local_app
flutter pub get
flutter run
```

构建 APK：

```powershell
cd D:\code\study_assistant\local_app
flutter build apk --release
```

## 已实现能力

- 学习通账号密码登录，凭证仅保存在本机安全存储。
- 作业同步、去重更新、完成标记、同步状态。
- 未完成互评作业保留，已完成互评作业过滤。
- 本地提醒规则和 24 小时内作业通知预览。
- iOS WidgetKit 与 Android AppWidget 读取同一份 `assignment_snapshot`。
- “关于应用”展示版权、微信、开源协议和 GitHub 源码入口。

## 隐私说明

- 学习通账号密码和作业数据只保存在本机，不会上传到任何服务器。
- 不绕过学习通验证码、风控或加密保护。
- 小组件不直接访问学习通或后端，只显示 App 写入的本地共享快照。
