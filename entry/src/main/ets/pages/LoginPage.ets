import { router } from '@kit.ArkUI';
import { authentication } from '@kit.AccountKit';
import { BusinessError } from '@kit.BasicServicesKit';
import cloud, { VerifyCodeAction } from '@hw-agconnect/cloud';
import dataPreferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';

// 登录模式
type LoginTab = 'huawei' | 'email';
type EmailMode = 'signin' | 'signup';

// ---- Echoing 深色霓虹色板 ----
const M_MINT = '#63F5DC';
const M_PEACH = '#5CC8FF';
const M_BG = '#050810';
const M_CARD = 'rgba(10, 22, 34, 0.78)';
const M_CARD_SOFT = 'rgba(20, 39, 55, 0.64)';
const M_INPUT = 'rgba(255, 255, 255, 0.08)';
const M_TEXT = '#EAFBFF';
const M_TEXT_SUB = '#8EA7B8';
const M_BORDER = 'rgba(99, 245, 220, 0.28)';
const M_BORDER_SOFT = 'rgba(255, 255, 255, 0.10)';

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
  @StorageLink('currentAccountKey') currentAccountKey: string = '';

  private showStatus(msg: string, isErr: boolean = false): void {
    this.statusMsg = msg;
    this.isError = isErr;
  }

  private clearStatus(): void {
    this.statusMsg = '';
    this.isError = false;
  }

  private buildAccountKey(provider: string, rawId: string, lowerCase: boolean = false): string {
    const normalizedId: string = lowerCase ? rawId.trim().toLowerCase() : rawId.trim();
    if (normalizedId.length <= 0) {
      return '';
    }
    return provider + '_' + normalizedId.replace(/[^A-Za-z0-9@._-]/g, '_');
  }

  private profileKey(accountKey: string, field: string): string {
    return 'profile.' + accountKey + '.' + field;
  }

  private async restoreProfileForAccount(accountKey: string): Promise<boolean> {
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      const prefs = await dataPreferences.getPreferences(ctx, 'echoing_user');
      const nick: dataPreferences.ValueType = await prefs.get(this.profileKey(accountKey, 'nickname'), '');
      const bio: dataPreferences.ValueType = await prefs.get(this.profileKey(accountKey, 'bio'), '');
      this.nickname = typeof nick === 'string' ? nick : String(nick);
      this.bio = typeof bio === 'string' ? bio : String(bio);
      return this.nickname.trim().length > 0;
    } catch (err) {
      console.error('testTag', 'Restore account profile failed: ' + JSON.stringify(err));
      this.nickname = '';
      this.bio = '';
      return false;
    }
  }

  // ---- 持久化登录状态到 Preferences ----
  private async persistLoginState(): Promise<void> {
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      const prefs = await dataPreferences.getPreferences(ctx, 'echoing_user');
      await prefs.put('isLoggedIn', true);
      await prefs.put('accountKey', this.currentAccountKey);
      await prefs.put('nickname', this.nickname);
      await prefs.put('bio', this.bio);
      if (this.currentAccountKey.length > 0) {
        await prefs.put(this.profileKey(this.currentAccountKey, 'nickname'), this.nickname);
        await prefs.put(this.profileKey(this.currentAccountKey, 'bio'), this.bio);
      }
      await prefs.flush();
      console.info('testTag', '登录状态已持久化');
    } catch (err) {
      console.error('testTag', `持久化登录状态失败: ${JSON.stringify(err)}`);
    }
  }

  private async persistLogoutState(): Promise<void> {
    try {
      const ctx = getContext(this) as common.UIAbilityContext;
      const prefs = await dataPreferences.getPreferences(ctx, 'echoing_user');
      await prefs.put('isLoggedIn', false);
      await prefs.flush();
      console.info('testTag', 'App user logout state persisted');
    } catch (err) {
      console.error('testTag', 'Persist logout state failed: ' + JSON.stringify(err));
    }
  }

  private goHome(): void {
    router.replaceUrl({ url: 'pages/Index' });
  }

  private logout(): void {
    this.isLoggedIn = false;
    this.persistLogoutState().then(() => {
      this.showStatus('\u5df2\u9000\u51fa\u767b\u5f55');
    });
  }

  private completeSignIn(accountKey: string): void {
    if (accountKey.length <= 0) {
      this.showStatus('登录失败：缺少账号标识', true);
      return;
    }
    this.currentAccountKey = accountKey;
    this.restoreProfileForAccount(accountKey).then((profileReady: boolean) => {
      this.isLoggedIn = true;
      if (!profileReady) {
        this.showStatus('登录成功，请设置你的资料');
        return;
      }
      this.persistLoginState().then(() => {
        this.showStatus('登录成功');
        setTimeout(() => { this.goHome(); }, 300);
      });
    });
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
      this.completeSignIn(this.buildAccountKey('huawei', data.openID ?? ''));
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
      this.completeSignIn(this.buildAccountKey('email', this.email, true));
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
    const trimmedNickname: string = this.nickname.trim();
    const trimmedBio: string = this.bio.trim();
    if (!trimmedNickname) { this.showStatus('\u8bf7\u8f93\u5165\u6635\u79f0', true); return; }
    if (this.currentAccountKey.length <= 0) { this.showStatus('缺少账号标识，请重新登录', true); return; }
    this.nickname = trimmedNickname;
    this.bio = trimmedBio;
    this.persistLoginState().then(() => {
      this.showStatus('\u8d44\u6599\u5df2\u4fdd\u5b58');
      setTimeout(() => { this.goHome(); }, 500);
    });
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
          .borderRadius(18)
          .backgroundColor(M_INPUT)
          .border({ width: 1, color: M_BORDER })
          .shadow({ radius: 14, color: 'rgba(99, 245, 220, 0.12)' })
          .onClick(() => { router.back(); })
      }
      .width('100%')
      .padding({ left: 24, top: 56 })

      // ---- 标题 ----
      Column({ space: 10 }) {
        Row({ space: 12 }) {
          Column() {
            Image($r('app.media.echoing_icon'))
              .width(44)
              .height(44)
              .borderRadius(22)
          }
          .width(56)
          .height(56)
          .borderRadius(28)
          .backgroundColor('rgba(99, 245, 220, 0.12)')
          .border({ width: 1.5, color: M_BORDER })
          .shadow({ radius: 24, color: 'rgba(99, 245, 220, 0.32)' })
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)

          Column({ space: 3 }) {
            Text('Echoing')
              .fontSize(30)
              .fontWeight(800)
              .fontColor(M_TEXT)
            Text(this.isLoggedIn ? '完善你的个人资料' : '登录以同步你的回声')
              .fontSize(13)
              .fontColor(M_TEXT_SUB)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(HorizontalAlign.Start)
        }
        .justifyContent(FlexAlign.Center)

      }
      .alignItems(HorizontalAlign.Center)
      .margin({ top: 22, bottom: 24 })

      Column({ space: 16 }) {
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
            .fontColor(this.isError ? '#FF9CAA' : M_MINT)
            .textAlign(TextAlign.Center)
            .width('100%')
            .padding({ top: 10, bottom: 10, left: 12, right: 12 })
            .backgroundColor(this.isError ? 'rgba(255, 122, 154, 0.12)' : 'rgba(99, 245, 220, 0.10)')
            .borderRadius(14)
            .border({ width: 1, color: this.isError ? 'rgba(255, 122, 154, 0.30)' : M_BORDER })
        }
      }
      .width('88%')
      .padding({ left: 18, right: 18, top: 22, bottom: 22 })
      .borderRadius(28)
      .backgroundColor(M_CARD)
      .border({ width: 1, color: M_BORDER })
      .shadow({ radius: 30, color: 'rgba(0, 240, 255, 0.16)' })

      Blank()

      Text('登录即代表同意服务协议与隐私政策')
        .fontSize(11)
        .fontColor(M_TEXT_SUB)
        .opacity(0.72)
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
    Column({ space: 16 }) {
      // Tab 切换
      Row() {
        Text('华为账号')
          .layoutWeight(1)
          .height(42)
          .textAlign(TextAlign.Center)
          .fontSize(14)
          .fontWeight(600)
          .fontColor(this.activeTab === 'huawei' ? M_BG : M_TEXT_SUB)
          .backgroundColor(this.activeTab === 'huawei' ? M_MINT : 'transparent')
          .borderRadius(16)
          .onClick(() => { this.activeTab = 'huawei'; this.clearStatus(); })

        Text('邮箱登录')
          .layoutWeight(1)
          .height(42)
          .textAlign(TextAlign.Center)
          .fontSize(14)
          .fontWeight(600)
          .fontColor(this.activeTab === 'email' ? M_BG : M_TEXT_SUB)
          .backgroundColor(this.activeTab === 'email' ? M_MINT : 'transparent')
          .borderRadius(16)
          .onClick(() => { this.activeTab = 'email'; this.clearStatus(); })
      }
      .width('100%')
      .padding(4)
      .backgroundColor(M_INPUT)
      .borderRadius(20)
      .border({ width: 1, color: M_BORDER_SOFT })

      if (this.activeTab === 'huawei') {
        // 华为登录 - 简洁一个按钮
        Button(this.isLoading ? '请稍候…' : '使用华为账号登录')
          .width('100%')
          .height(50)
          .fontSize(16)
          .fontWeight(700)
          .fontColor(M_BG)
          .backgroundColor(M_MINT)
          .borderRadius(18)
          .shadow({ radius: 16, color: 'rgba(99, 245, 220, 0.24)' })
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
    Column({ space: 12 }) {
      // 登录/注册切换
      Row() {
        Text('登录')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .fontSize(13)
          .fontWeight(600)
          .fontColor(this.emailMode === 'signin' ? M_BG : M_TEXT_SUB)
          .backgroundColor(this.emailMode === 'signin' ? M_PEACH : 'transparent')
          .borderRadius(14)
          .height(32)
          .onClick(() => { this.emailMode = 'signin'; this.clearStatus(); })

        Text('注册')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .fontSize(13)
          .fontWeight(600)
          .fontColor(this.emailMode === 'signup' ? M_BG : M_TEXT_SUB)
          .backgroundColor(this.emailMode === 'signup' ? M_PEACH : 'transparent')
          .borderRadius(14)
          .height(32)
          .onClick(() => { this.emailMode = 'signup'; this.clearStatus(); })
      }
      .width('100%')
      .padding(3)
      .backgroundColor(M_INPUT)
      .borderRadius(17)
      .border({ width: 1, color: M_BORDER_SOFT })

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
            .borderRadius(16)
            .backgroundColor(M_INPUT)
            .fontColor(M_TEXT)
            .placeholderColor(M_TEXT_SUB)
            .border({ width: 1, color: M_BORDER_SOFT })
            .onChange((v: string) => { this.verifyCode = v; })

          Button(this.canSendCode ? '发送' : `${this.countdown}s`)
            .width(68)
            .height(46)
            .fontSize(13)
            .fontWeight(600)
            .borderRadius(16)
            .enabled(this.canSendCode)
            .backgroundColor(this.canSendCode ? M_PEACH : M_CARD_SOFT)
            .fontColor(this.canSendCode ? M_BG : M_TEXT_SUB)
            .border({ width: 1, color: M_BORDER_SOFT })
            .onClick(() => { this.sendRegisterCode(); })
        }
        .width('100%')
      }

      Button(this.isLoading ? '请稍候…' : (this.emailMode === 'signin' ? '登  录' : '注  册'))
        .width('100%')
        .height(50)
        .fontSize(16)
        .fontWeight(700)
        .fontColor(M_BG)
        .backgroundColor(M_MINT)
        .borderRadius(18)
        .shadow({ radius: 16, color: 'rgba(99, 245, 220, 0.24)' })
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
    Column({ space: 16 }) {
      Column({ space: 4 }) {
        Text(this.nickname.trim().length > 0 ? this.nickname : '个人资料')
          .fontSize(20)
          .fontWeight(700)
          .fontColor(M_TEXT)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text('昵称和签名会保存在本机')
          .fontSize(12)
          .fontColor(M_TEXT_SUB)
      }
      .width('100%')
      .padding({ top: 2, bottom: 4 })
      .alignItems(HorizontalAlign.Center)

      // 昵称
      Column({ space: 4 }) {
        Text('昵称')
          .fontSize(12)
          .fontColor(M_TEXT_SUB)
          .fontWeight(500)
          .width('100%')
          .padding({ left: 4 })
        TextInput({ placeholder: '给自己取个名字吧', text: this.nickname })
          .width('100%')
          .height(46)
          .borderRadius(16)
          .backgroundColor(M_INPUT)
          .fontColor(M_TEXT)
          .fontWeight(600)
          .placeholderColor(M_TEXT_SUB)
          .border({ width: 1, color: M_BORDER_SOFT })
          .onChange((v: string) => { this.nickname = v; })
      }
      .width('100%')

      // 个性签名
      Column({ space: 4 }) {
        Text('一句话签名')
          .fontSize(12)
          .fontColor(M_TEXT_SUB)
          .fontWeight(500)
          .width('100%')
          .padding({ left: 4 })
        TextInput({ placeholder: '说点什么…（选填）', text: this.bio })
          .width('100%')
          .height(46)
          .borderRadius(16)
          .backgroundColor(M_INPUT)
          .fontColor(M_TEXT)
          .fontWeight(600)
          .placeholderColor(M_TEXT_SUB)
          .border({ width: 1, color: M_BORDER_SOFT })
          .onChange((v: string) => { this.bio = v; })
      }
      .width('100%')

      // Profile actions
      Button('\u4fdd\u5b58\u5e76\u8fdb\u5165')
        .width('100%')
        .height(50)
        .fontSize(16)
        .fontWeight(700)
        .fontColor(M_BG)
        .backgroundColor(M_MINT)
        .borderRadius(18)
        .shadow({ radius: 16, color: 'rgba(99, 245, 220, 0.24)' })
        .margin({ top: 6 })
        .onClick(() => { this.saveProfile(); })

      Text('\u9000\u51fa\u767b\u5f55')
        .fontSize(13)
        .fontWeight(500)
        .fontColor('#FF9CAA')
        .padding({ top: 8, bottom: 4 })
        .onClick(() => { this.logout(); })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  // ---- 输入框 ----
  @Builder
  SoftInput(placeholder: string, type: InputType, onChange: (v: string) => void) {
    TextInput({ placeholder: placeholder })
      .type(type)
      .width('100%')
      .height(46)
      .borderRadius(16)
      .backgroundColor(M_INPUT)
      .fontColor(M_TEXT)
      .fontWeight(600)
      .placeholderColor(M_TEXT_SUB)
      .border({ width: 1, color: M_BORDER_SOFT })
      .onChange(onChange)
  }
}
