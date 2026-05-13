import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { util } from '@kit.ArkTS';
import { initialize } from '@hw-agconnect/hmcore';
import dataPreferences from '@ohos.data.preferences';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    // 初始化 AppStorage 中的全局登录状态（默认值）
    AppStorage.setOrCreate<boolean>('isLoggedIn', false);
    AppStorage.setOrCreate<string>('userNickname', '');
    AppStorage.setOrCreate<string>('userBio', '');
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    // 初始化 AGC SDK：必须手动读取 agconnect-services.json 传入
    try {
      let resMgr = this.context.resourceManager;
      hilog.info(DOMAIN, 'testTag', 'Step1: got resourceManager');
      let jsonUint8 = resMgr.getRawFileContentSync('agconnect-services.json');
      hilog.info(DOMAIN, 'testTag', 'Step2: rawfile read, length=%{public}d', jsonUint8.byteLength);
      let decoder = new util.TextDecoder('utf-8');
      let jsonStr = decoder.decode(jsonUint8);
      hilog.info(DOMAIN, 'testTag', 'Step3: decoded, length=%{public}d', jsonStr.length);
      let jsonObj: ESObject = JSON.parse(jsonStr) as ESObject;
      hilog.info(DOMAIN, 'testTag', 'Step4: parsed JSON, calling initialize...');
      initialize(this.context, jsonObj);
      hilog.info(DOMAIN, 'testTag', 'Step5: AGC SDK initialized successfully!');
    } catch (err) {
      let errMsg = (err instanceof Error) ? err.message : JSON.stringify(err);
      hilog.error(DOMAIN, 'testTag', 'AGC init FAILED: %{public}s', errMsg);
    }

    // 从 Preferences 恢复登录状态到 AppStorage
    this.restoreLoginState();

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }

  private async restoreLoginState(): Promise<void> {
    try {
      const prefs = await dataPreferences.getPreferences(this.context, 'echoing_user');
      const logged: dataPreferences.ValueType = await prefs.get('isLoggedIn', false);
      const nick: dataPreferences.ValueType = await prefs.get('nickname', '');
      const bio: dataPreferences.ValueType = await prefs.get('bio', '');
      AppStorage.setOrCreate<boolean>('isLoggedIn', logged as boolean);
      AppStorage.setOrCreate<string>('userNickname', nick as string);
      AppStorage.setOrCreate<string>('userBio', bio as string);
      hilog.info(DOMAIN, 'testTag', 'Restored login state: isLoggedIn=%{public}s, nick=%{public}s',
        String(logged), String(nick));
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to restore login state: %{public}s', JSON.stringify(err));
    }
  }
}