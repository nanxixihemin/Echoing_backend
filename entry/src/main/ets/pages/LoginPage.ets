import { router } from '@kit.ArkUI';
import { authentication } from '@kit.AccountKit';
import { BusinessError } from '@kit.BasicServicesKit';
import cloud, { VerifyCodeAction } from '@hw-agconnect/cloud';
import dataPreferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';

// 登录模式
type LoginTab = 'huawei' | 'email';
type EmailMode = 'signin' | 'signup';

// ---- 马卡龙色板 ----
const M_PINK = '#F8C8DC';
const M_MINT = '#B5EAD7';
const M_LAVENDER = '#C9B8E8';
const M_PEACH = '#FFD6B0';
const M_BG = '#FFF9F3';
const M_CARD = '#FFFFFF';
const M_TEXT = '#3D3D50';
const M_TEXT_SUB = '#9090A0';
const M_BORDER = '#E0D8E8';

// AGC 接口声明
interface EmailSignInCredential { kind: 'email'; email: string; password: string; }
interface EmailSignInParams { credentialInfo: EmailSignInCredential; }
interface EmailCreateUserParams { kind: 'email'; email: string; password: string; verifyCode: string; }
interface EmailVerifyCodeType { email: string; kind: 'email'; }
interface RequestEmailVerifyCodeParams {
  action: VerifyCodeAction; lang: string; sendInterval: number; verifyCodeType: EmailVerifyCodeType;
}

@Entry
@Component
struct LoginPage {
  @State activeTab: LoginTab = 'huawei';
  @State statusMsg: string = '';
  @State isError: boolean = false;
  @State isLoading: boolean = false;
  @State emailMode: EmailMode = 'signin';
  @State email: string = '';
  @State password: string = '';
  @State confirmPassword: string = '';
  @State verifyCode: string = '';
  @State canSendCode: boolean = true;
  @State countdown: number = 60;

  // ---- 全局登录状态：通过 AppStorage 与其他页面共享 ----
  @StorageLink('isLoggedIn') isLoggedIn: boolean = false;
  @StorageLink('userNickname') nickname: string = '';
  @StorageLink('userBio') bio: string = '';

  private showStatus(msg: string, isErr: boolean = false): void {
    this.statusMsg = msg;
    this.isError = isErr;
  }

  private clearStatus(): void {
    this.statusMsg = '';
    this.isError = false;
  }

  // ---- 持久化登录状态到 Preferences ----
  private async persistLoginState(): Promise<void> {
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      const prefs = await dataPreferences.getPreferences(ctx, 'echoing_user');
      await prefs.put('isLoggedIn', true);
      await prefs.put('nickname', this.nickname);
      await prefs.put('bio', this.bio);
      await prefs.flush();
      console.info('testTag', '登录状态已持久化');
    } catch (err) {
      console.error('testTag', `持久化登录状态失败: ${JSON.stringify(err)}`);
    }
  }

  // ---- 华为账号登录 ----
  private doHuaweiSignIn(): void {
    this.isLoading = true;
    this.showStatus('正在拉起华为账号…');
    const request = new authentication.HuaweiIDProvider().createLoginWithHuaweiIDRequest();
    request.forceLogin = false;
    request.state = String(new Date().getTime());
    const authController = new authentication.AuthenticationController();
    authController.executeRequest(request).then((response: authentication.LoginWithHuaweiIDResponse) => {
      const data: authentication.LoginWithHuaweiIDCredential = response.data!;
      console.info('testTag', `华为账号 openID: ${data.openID ?? ''}`);
      // 登录成功 → 更新全局状态（AppStorage 自动同步到所有 @StorageLink 页面）
      this.isLoggedIn = true;
      this.showStatus('登录成功，请设置你的资料');
    }).catch((err: BusinessError) => {
      if (err.code === 1001502001 || (err.message ?? '').indexOf('cancel') >= 0) {
        this.showStatus('已取消');
      } else {
        this.showStatus(`登录失败: ${err.message}`, true);
      }
    }).finally(() => { this.isLoading = false; });
  }

  // ---- 邮箱登录 ----
  private doEmailSignIn(): void {
    if (!this.email || !this.password) { this.showStatus('请填写邮箱和密码', true); return; }
    this.isLoading = true;
    this.showStatus('正在登录…');
    const params: EmailSignInParams = {
      credentialInfo: { kind: 'email', email: this.email, password: this.password }
    };
    cloud.auth().signIn(params).then(() => {
      this.isLoggedIn = true;
      this.showStatus('登录成功，请设置你的资料');
    }).catch((err: BusinessError) => {
      this.showStatus(`登录失败：${err.message}`, true);
    }).finally(() => { this.isLoading = false; });
  }

  private sendRegisterCode(): void {
    if (!this.email) { this.showStatus('请先填写邮箱', true); return; }
    this.canSendCode = false;
    this.showStatus('正在发送…');
    const params: RequestEmailVerifyCodeParams = {
      action: VerifyCodeAction.REGISTER_LOGIN, lang: 'zh_CN', sendInterval: 60,
      verifyCodeType: { email: this.email, kind: 'email' }
    };
    cloud.auth().requestVerifyCode(params).then(() => {
      this.showStatus('验证码已发送');
      this.countdown = 60;
      const interval = setInterval(() => {
        this.countdown--;
        if (this.countdown <= 0) { clearInterval(interval); this.canSendCode = true; this.countdown = 60; }
      }, 1000);
    }).catch((err: BusinessError) => {
      this.showStatus(`发送失败：${err.message}`, true);
      this.canSendCode = true;
    });
  }

  private doEmailSignUp(): void {
    if (!this.email || !this.password || !this.verifyCode) { this.showStatus('请填写完整信息', true); return; }
    if (this.password !== this.confirmPassword) { this.showStatus('两次密码不一致', true); return; }
    this.isLoading = true;
    this.showStatus('正在注册…');
    const params: EmailCreateUserParams = {
      kind: 'email', email: this.email, password: this.password, verifyCode: this.verifyCode
    };
    cloud.auth().createUser(params).then(() => {
      this.showStatus('注册成功，正在登录…');
      this.doEmailSignIn();
    }).catch((err: BusinessError) => {
      this.showStatus(`注册失败：${err.message}`, true);
      this.isLoading = false;
    });
  }

  // ---- 保存用户资料并持久化 ----
  private saveProfile(): void {
    if (!this.nickname.trim()) { this.showStatus('请输入昵称', true); return; }
    // nickname 和 bio 已通过 @StorageLink 自动写入 AppStorage
    // 这里再持久化到 Preferences
    this.persistLoginState();
    this.showStatus('资料已保存');
    setTimeout(() => { router.back(); }, 500);
  }

  build() {
    Column() {
      // ---- 返回按钮 ----
      Row() {
        Text('‹')
          .fontSize(28)
          .fontWeight(700)
          .fontColor(M_TEXT)
          .width(36)
          .height(36)
          .textAlign(TextAlign.Center)
          .borderRadius(10)
          .backgroundColor(M_CARD)
          .border({ width: 1.5, color: M_BORDER })
          .onClick(() => { router.back(); })
      }
      .width('100%')
      .padding({ left: 24, top: 56 })

      // ---- 标题 ----
      Column({ space: 4 }) {
        Text('Echoing')
          .fontSize(28)
          .fontWeight(800)
          .fontColor(M_TEXT)
          .letterSpacing(1)
        Text(this.isLoggedIn ? '完善你的个人资料' : '登录以同步你的回声')
          .fontSize(13)
          .fontColor(M_TEXT_SUB)
      }
      .alignItems(HorizontalAlign.Center)
      .margin({ top: 32, bottom: 28 })

      if (this.isLoggedIn) {
        // ---- 登录后：设置资料 ----
        this.ProfileSection()
      } else {
        // ---- 登录前：Tab + 表单 ----
        this.LoginFormSection()
      }

      // ---- 状态提示 ----
      if (this.statusMsg.length > 0) {
        Text(this.statusMsg)
          .fontSize(12)
          .fontWeight(500)
          .fontColor(this.isError ? '#D45050' : M_TEXT)
          .textAlign(TextAlign.Center)
          .width('85%')
          .padding({ top: 10, bottom: 10 })
          .backgroundColor(this.isError ? '#FDEAEA' : M_MINT + '60')
          .borderRadius(10)
          .border({ width: 1, color: this.isError ? '#E8BFBF' : M_BORDER })
          .margin({ top: 14 })
      }

      Blank()

      Text('登录即代表同意服务协议与隐私政策')
        .fontSize(11)
        .fontColor(M_TEXT_SUB)
        .opacity(0.6)
        .margin({ bottom: 32 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(M_BG)
    .alignItems(HorizontalAlign.Center)
  }

  // ---- 登录表单区 ----
  @Builder
  LoginFormSection() {
    Column({ space: 0 }) {
      // Tab 切换
      Row() {
        Text('华为账号')
          .layoutWeight(1)
          .height(42)
          .textAlign(TextAlign.Center)
          .fontSize(14)
          .fontWeight(600)
          .fontColor(this.activeTab === 'huawei' ? M_TEXT : M_TEXT_SUB)
          .backgroundColor(this.activeTab === 'huawei' ? M_PINK + '80' : 'transparent')
          .borderRadius({ topLeft: 12, bottomLeft: 12 })
          .onClick(() => { this.activeTab = 'huawei'; this.clearStatus(); })

        Text('邮箱登录')
          .layoutWeight(1)
          .height(42)
          .textAlign(TextAlign.Center)
          .fontSize(14)
          .fontWeight(600)
          .fontColor(this.activeTab === 'email' ? M_TEXT : M_TEXT_SUB)
          .backgroundColor(this.activeTab === 'email' ? M_MINT + '80' : 'transparent')
          .borderRadius({ topRight: 12, bottomRight: 12 })
          .onClick(() => { this.activeTab = 'email'; this.clearStatus(); })
      }
      .width('85%')
      .backgroundColor(M_CARD)
      .borderRadius(12)
      .border({ width: 1.5, color: M_BORDER })
      .margin({ bottom: 20 })

      if (this.activeTab === 'huawei') {
        // 华为登录 - 简洁一个按钮
        Button(this.isLoading ? '请稍候…' : '使用华为账号登录')
          .width('85%')
          .height(50)
          .fontSize(16)
          .fontWeight(700)
          .fontColor(M_TEXT)
          .backgroundColor(M_PEACH + '90')
          .borderRadius(14)
          .border({ width: 1.5, color: M_BORDER })
          .enabled(!this.isLoading)
          .onClick(() => { this.doHuaweiSignIn(); })
      } else {
        this.EmailSection()
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  // ---- 邮箱区 ----
  @Builder
  EmailSection() {
    Column({ space: 10 }) {
      // 登录/注册切换
      Row() {
        Text('登录')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .fontSize(13)
          .fontWeight(600)
          .fontColor(this.emailMode === 'signin' ? M_TEXT : M_TEXT_SUB)
          .backgroundColor(this.emailMode === 'signin' ? M_LAVENDER + '60' : 'transparent')
          .borderRadius(8)
          .height(32)
          .onClick(() => { this.emailMode = 'signin'; this.clearStatus(); })

        Text('注册')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .fontSize(13)
          .fontWeight(600)
          .fontColor(this.emailMode === 'signup' ? M_TEXT : M_TEXT_SUB)
          .backgroundColor(this.emailMode === 'signup' ? M_LAVENDER + '60' : 'transparent')
          .borderRadius(8)
          .height(32)
          .onClick(() => { this.emailMode = 'signup'; this.clearStatus(); })
      }
      .width('85%')
      .padding(3)
      .backgroundColor(M_CARD)
      .borderRadius(10)
      .border({ width: 1, color: M_BORDER })

      this.SoftInput('邮箱地址', InputType.Email, (v: string) => { this.email = v; })
      this.SoftInput('密码', InputType.Password, (v: string) => { this.password = v; })

      if (this.emailMode === 'signup') {
        this.SoftInput('确认密码', InputType.Password, (v: string) => { this.confirmPassword = v; })
        Row({ space: 8 }) {
          TextInput({ placeholder: '验证码' })
            .type(InputType.Number)
            .maxLength(6)
            .layoutWeight(1)
            .height(46)
            .borderRadius(12)
            .backgroundColor(M_CARD)
            .fontColor(M_TEXT)
            .placeholderColor(M_TEXT_SUB)
            .border({ width: 1, color: M_BORDER })
            .onChange((v: string) => { this.verifyCode = v; })

          Button(this.canSendCode ? '发送' : `${this.countdown}s`)
            .width(68)
            .height(46)
            .fontSize(13)
            .fontWeight(600)
            .borderRadius(12)
            .enabled(this.canSendCode)
            .backgroundColor(this.canSendCode ? M_PEACH + '80' : M_CARD)
            .fontColor(M_TEXT)
            .border({ width: 1, color: M_BORDER })
            .onClick(() => { this.sendRegisterCode(); })
        }
        .width('85%')
      }

      Button(this.isLoading ? '请稍候…' : (this.emailMode === 'signin' ? '登  录' : '注  册'))
        .width('85%')
        .height(50)
        .fontSize(16)
        .fontWeight(700)
        .fontColor(M_TEXT)
        .backgroundColor(this.emailMode === 'signin' ? M_MINT + '90' : M_PINK + '90')
        .borderRadius(14)
        .border({ width: 1.5, color: M_BORDER })
        .enabled(!this.isLoading)
        .margin({ top: 4 })
        .onClick(() => {
          if (this.emailMode === 'signin') { this.doEmailSignIn(); }
          else { this.doEmailSignUp(); }
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  // ---- 登录后：个人资料设置 ----
  @Builder
  ProfileSection() {
    Column({ space: 14 }) {
      // 头像占位
      Column() {
        Text(this.nickname ? this.nickname.charAt(0).toUpperCase() : '?')
          .fontSize(28)
          .fontWeight(800)
          .fontColor(M_TEXT)
      }
      .width(72)
      .height(72)
      .borderRadius(36)
      .backgroundColor(M_LAVENDER + '70')
      .border({ width: 1.5, color: M_BORDER })
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      // 昵称
      Column({ space: 4 }) {
        Text('昵称')
          .fontSize(12)
          .fontColor(M_TEXT_SUB)
          .fontWeight(500)
          .width('85%')
          .padding({ left: 4 })
        TextInput({ placeholder: '给自己取个名字吧', text: this.nickname })
          .width('85%')
          .height(46)
          .borderRadius(12)
          .backgroundColor(M_CARD)
          .fontColor(M_TEXT)
          .fontWeight(600)
          .placeholderColor(M_TEXT_SUB)
          .border({ width: 1, color: M_BORDER })
          .onChange((v: string) => { this.nickname = v; })
      }

      // 个性签名
      Column({ space: 4 }) {
        Text('一句话签名')
          .fontSize(12)
          .fontColor(M_TEXT_SUB)
          .fontWeight(500)
          .width('85%')
          .padding({ left: 4 })
        TextInput({ placeholder: '说点什么…（选填）', text: this.bio })
          .width('85%')
          .height(46)
          .borderRadius(12)
          .backgroundColor(M_CARD)
          .fontColor(M_TEXT)
          .fontWeight(600)
          .placeholderColor(M_TEXT_SUB)
          .border({ width: 1, color: M_BORDER })
          .onChange((v: string) => { this.bio = v; })
      }

      // 保存按钮
      Button('保存并进入')
        .width('85%')
        .height(50)
        .fontSize(16)
        .fontWeight(700)
        .fontColor(M_TEXT)
        .backgroundColor(M_MINT + '90')
        .borderRadius(14)
        .border({ width: 1.5, color: M_BORDER })
        .margin({ top: 6 })
        .onClick(() => { this.saveProfile(); })

      // 跳过
      Text('稍后再说')
        .fontSize(13)
        .fontColor(M_TEXT_SUB)
        .fontWeight(500)
        .margin({ top: 4 })
        .onClick(() => {
          // 即使跳过资料设置，也要持久化登录状态
          this.persistLoginState();
          router.back();
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  // ---- 输入框 ----
  @Builder
  SoftInput(placeholder: string, type: InputType, onChange: (v: string) => void) {
    TextInput({ placeholder: placeholder })
      .type(type)
      .width('85%')
      .height(46)
      .borderRadius(12)
      .backgroundColor(M_CARD)
      .fontColor(M_TEXT)
      .fontWeight(600)
      .placeholderColor(M_TEXT_SUB)
      .border({ width: 1, color: M_BORDER })
      .onChange(onChange)
  }
}
