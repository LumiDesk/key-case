# R8 规则：Flutter 引擎与插件通过反射/平台通道访问的类必须保留。
# 新增使用反射的依赖时同步这里，并用 CI 的 release APK 在设备上验证。

# Flutter 引擎
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# 本项目原生桥与 Keystore 辅助类
-keep class top.talyra42.keycase.** { *; }

# Android Keystore / 生物识别
-keep class androidx.biometric.** { *; }
-dontwarn androidx.biometric.**
