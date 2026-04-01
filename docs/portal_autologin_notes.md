# 教务系统自动登录链路说明

## 目的

这份文档用于固化当前项目里“教务系统自动登录并抓课表”这条链路的关键网页信息、代码入口和维护约定，避免后续页面微调后又要重新排查一轮。

当前自动登录的目标流程是：

1. 打开教务系统登录页。
2. 如果默认落在二维码登录页，自动切换到账号密码登录页。
3. 自动填充已保存的账号和密码。
4. 自动勾选“7天免登录”。
5. 自动点击登录。
6. 如果进入多因子认证页，则停止自动化并等待用户手动完成验证码验证。
7. 登录成功后继续抓取课表数据。

## 相关代码入口

- `lib/services/schedule_login_fetch_service.dart`
  - 登录页自动化脚本的核心实现。
  - `buildFillCredentialScript(...)` 是统一入口。
  - `_buildStableFillCredentialScript(...)` 是当前实际启用的稳定版逻辑。
- `lib/screens/login_screen.dart`
  - Windows 登录页。
  - 负责自动填充重试节奏、状态提示、WebView 桥接消息处理。
- `lib/screens/login_screen_android.dart`
  - Android 登录页。
  - 行为与 Windows 保持一致，调用同一套脚本。
- `lib/services/auth_credentials_service.dart`
  - 保存和读取账号密码。

## 当前已确认可用的网页元素

下面这些 DOM 都已经在自动登录流程里使用，属于当前站点的“已验证锚点”。

### 1. 二维码登录页识别

```html
<img id="qr_img" src="/authserver/qrCode/getCode?uuid=...">
```

用途：

- 判断当前是否仍处于扫码登录页。

当前脚本优先选择器：

```css
img#qr_img[src*="/authserver/qrCode/getCode"]
img#qr_img
```

### 2. 从二维码页切换到账密页

```html
<img class="login-type-btn" src="/authserver/newhainanuaz/static/web/images/pc.png" alt="">
```

用途：

- 在二维码登录页点击它，切换到账号密码登录。

当前脚本优先选择器：

```css
img.login-type-btn[src*="/authserver/newhainanuaz/static/web/images/pc.png"]
img.login-type-btn[src*="pc.png"]
.login-type-btn
```

### 3. 账号输入框

```html
<input id="username" name="username" type="text" placeholder="请输入学号/工号" title="请输入学号/工号" value="">
```

用途：

- 识别“账号密码登录页是否已经出现”。
- 自动填写账号。

当前脚本优先选择器：

```css
input#username[name="username"]
input#username
input[name="username"]
```

### 4. 密码输入框

```html
<input id="password" name="passwordText" type="password" placeholder="请输入密码" title="请输入密码" maxlength="32">
```

用途：

- 自动填写密码。
- 配合账号输入框一起确认账密表单已就绪。

当前脚本优先选择器：

```css
input#password[name="passwordText"]
#password[name="passwordText"]
#password
input#password
input[name="passwordText"]
input[type="password"]
```

### 5. 七天免登录勾选框

```html
<input type="checkbox" name="rememberMe" id="rememberMe" value="true" style="width:15px;margin-right:5px;">
```

用途：

- 自动勾选“7天免登录”。

当前脚本优先选择器：

```css
input#rememberMe[name="rememberMe"]
input#rememberMe
input[name="rememberMe"]
```

实现细节：

- 先尝试真实点击。
- 如果点击后仍未选中，会补一次原生 `checked = true` 并主动触发 `input` / `change` 事件。

### 6. 登录按钮

```html
<a id="login_submit" href="javascript:void(0);" class="login-btn lang_text_ellipsis" title="登录">登录</a>
```

用途：

- 账号密码已填完并勾选免登录后，自动提交登录。

当前脚本优先选择器：

```css
a#login_submit.login-btn
#login_submit
```

### 7. 多因子认证标题

```html
<span class="right-header-title">多因子认证</span>
```

用途：

- 识别当前是否已经进入多因子认证页面。
- 一旦识别到，脚本停止自动点击，交给用户手动处理。

当前脚本优先选择器：

```css
span.right-header-title
```

并配合标题文案：

```text
多因子认证
```

### 8. 多因子认证验证码输入框

```html
<input id="dynamicCode" type="text" class="input-box" name="dynamicCode" placeholder="请输入" maxlength="20">
```

用途：

- 识别多因子认证页。

当前脚本优先选择器：

```css
input#dynamicCode[name="dynamicCode"]
input#dynamicCode
```

### 9. 多因子认证获取验证码按钮

```html
<button id="getDynamicCode" title="获取验证码" class="dynamicCode_btn auth_login_btn" onclick="sendDynamicCodeByPhone(this)">获取验证码</button>
```

用途：

- 作为多因子认证页的辅助识别锚点。

当前脚本优先选择器：

```css
button#getDynamicCode
```

### 10. 多因子认证提交按钮

```html
<button id="reAuthSubmitBtn" class="auth_login_btn submit_btn">登录</button>
```

用途：

- 作为多因子认证页的辅助识别锚点。
- 当前逻辑只用于识别，不会自动帮用户提交验证码。

当前脚本优先选择器：

```css
button#reAuthSubmitBtn
```

## 当前状态机

### 阶段 1：识别登录页类型

- 如果命中 `#qr_img`，且还没有可见的 `#username`，认定为二维码登录页。
- 如果命中 `#username` 和密码输入框，认定为账密页已就绪。
- 如果命中“多因子认证”标题、`#dynamicCode`、`#getDynamicCode`、`#reAuthSubmitBtn` 中任意一项，认定为需要人工处理。

### 阶段 2：从二维码页切到账密页

- 仅在二维码页状态下才点击 `login-type-btn`。
- 脚本会记录最近一次切换时间，短时间内不会重复狂点，避免页面闪烁。

### 阶段 3：自动填充

- 给账号框写入保存的用户名。
- 给密码框写入保存的密码。
- 派发 `input`、`change`、`keyup`、`blur` 等事件，尽量兼容页面自己的监听逻辑。

### 阶段 4：勾选 7 天免登录

- 优先操作 `#rememberMe`。
- 如果真实点击未生效，则直接补 `checked=true`。

### 阶段 5：自动提交

- 优先点击 `#login_submit`。
- 若找不到，再退回到表单提交或回车提交。

### 阶段 6：多因子认证拦截

- 一旦识别到多因子认证页，立即发送 `VERIFICATION_REQUIRED` 状态。
- Flutter 侧会停止自动化重试，并提示用户手动完成验证。

## Flutter 侧重试策略

Windows 和 Android 当前保持同样的节奏：

- 会开启一个短时自动填充重试循环。
- 前几次更偏向于“等待页面切换到账密页”和“稳定识别表单”。
- 第 3 次起才更积极地自动提交登录。
- 当前最大尝试次数是 5 次。

这样做的原因是：

- 避免刚从二维码页切换出来就立刻点登录。
- 降低页面闪烁和重复点击。

## 当前用户可见状态文案

自动登录过程中会出现这些关键状态：

- 检测到二维码登录页，正在寻找账号密码登录入口
- 已识别二维码登录，正在切换到账号密码登录
- 已点击切换按钮，正在等待账号密码表单出现
- 登录表单还在加载，继续尝试识别
- 已识别到账密表单，正在自动填充
- 已勾选记住/信任选项，准备提交登录
- 已自动填充账号密码，准备自动登录
- 登录请求已发出，正在等待页面响应
- 检测到多因子或设备验证码验证，需要你手动完成后再继续

## 维护建议

如果后续自动登录再次失效，优先按下面顺序排查：

1. 先看网页 DOM 是否变了。
2. 先核对这几个精确锚点是否还存在：
   - `#qr_img`
   - `.login-type-btn[src*="pc.png"]`
   - `#username`
   - `#password`
   - `#rememberMe`
   - `#login_submit`
   - `.right-header-title`
   - `#dynamicCode`
3. 如果只是 class、name、id 小改动，先改精确选择器，不要先放大模糊匹配范围。
4. 如果流程变化了，再调整状态机判断顺序。
5. Windows 和 Android 共用同一套注入脚本，改这块时必须一起考虑两端。

## 建议的回归测试

每次改动自动登录后，至少测下面 4 个场景：

1. 默认进入二维码页，是否能稳定切到账密页。
2. 是否能自动填入账号密码。
3. 是否能自动勾选“7天免登录”并自动点击登录。
4. 首次登录或陌生设备时，是否能在多因子认证页正确停下，不再误操作。

## 备注

本说明基于当前海南大学教务系统登录页的已确认页面结构整理。如果学校后续改版，优先更新本文件，再同步更新脚本实现。
