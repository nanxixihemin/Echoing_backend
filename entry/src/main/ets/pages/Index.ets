import { ColorConstants } from '../utils/ColorConstants';
import { DatabaseService } from '../utils/DatabaseService';
import { EchoTask } from '../models/EchoTask';
import { Seed } from '../models/Seed';
import { TreeHoleWidget } from '../components/TreeHoleWidget';
import { EchoDrawer } from '../components/EchoDrawer';
import { SpinnerWidget } from '../components/SpinnerWidget';
import { SoulSelectionWidget } from '../components/SoulSelectionWidget';
import { TarotWidget } from '../components/TarotWidget';
import { IntrospectionWidget } from '../components/IntrospectionWidget';
import common from '@ohos.app.ability.common';
import router from '@ohos.router';

@Entry
@Component
struct Index {
  @State pendingTasks: EchoTask[] = [];
  @State showDrawer: boolean = false;
  @State activeTool: string = 'none'; // 'none', 'spinner', 'tarot', etc.
  // 全局登录状态（只读订阅，由 LoginPage 写入）
  @StorageProp('isLoggedIn') isLoggedIn: boolean = false;
  @StorageProp('userNickname') userNickname: string = '';
  private dbService: DatabaseService | null = null;

  async aboutToAppear() {
    this.dbService = new DatabaseService(getContext(this) as common.UIAbilityContext);
    await this.dbService.init();
    await this.loadTasks();
  }

  async loadTasks() {
    if (this.dbService) {
      this.pendingTasks = await this.dbService.getPendingTasks();
    }
  }

  async handleNewSeed(content: string) {
    let seed: Seed = {
      content: content,
      source: 'TREE_HOLE',
      state: 1, 
      created_at: new Date().getTime()
    };
    if (!this.dbService) return;
    let seedId = await this.dbService.insertSeed(seed);

    let task: EchoTask = {
      seed_id: seedId,
      action: '处理杂念: ' + content,
      is_completed: false,
      created_at: new Date().getTime()
    };
    await this.dbService.insertTask(task);
    
    await this.loadTasks();
    this.showDrawer = true;
  }

  async handleSpinnerResult(result: string) {
    this.activeTool = 'none';
    
    // 轮盘没有原始文字输入，直接生成一条特殊来源的待办
    let seed: Seed = {
      content: '求助于指尖轮盘',
      source: 'SPINNER',
      state: 1, 
      created_at: new Date().getTime()
    };
    if (!this.dbService) return;
    let seedId = await this.dbService.insertSeed(seed);

    let task: EchoTask = {
      seed_id: seedId,
      action: result, // 结果比如 "点外卖"
      is_completed: false,
      created_at: new Date().getTime()
    };
    await this.dbService.insertTask(task);
    
    await this.loadTasks();
    this.showDrawer = true;
  }

  async handleSoulResult(result: string) {
    this.activeTool = 'none';
    let seed: Seed = {
      content: '灵魂天平的权衡抉择',
      source: 'CHOICE',
      state: 1, 
      created_at: new Date().getTime()
    };
    if (!this.dbService) return;
    let seedId = await this.dbService.insertSeed(seed);

    let task: EchoTask = {
      seed_id: seedId,
      action: '执行抉择: ' + result,
      is_completed: false,
      created_at: new Date().getTime()
    };
    await this.dbService.insertTask(task);
    
    await this.loadTasks();
    this.showDrawer = true;
  }

  async handleTarotResult(result: string) {
    this.activeTool = 'none';
    let seed: Seed = {
      content: '嵩月塔罗的神秘启示',
      source: 'TAROT',
      state: 1, 
      created_at: new Date().getTime()
    };
    if (!this.dbService) return;
    let seedId = await this.dbService.insertSeed(seed);

    let task: EchoTask = {
      seed_id: seedId,
      action: '塔罗指引: ' + result,
      is_completed: false,
      created_at: new Date().getTime()
    };
    await this.dbService.insertTask(task);
    
    await this.loadTasks();
    this.showDrawer = true;
  }

  async handleIntroResult(result: string) {
    this.activeTool = 'none';
    let seed: Seed = {
      content: '问心对谈的自我剖析',
      source: 'INTROSPECTION',
      state: 1, 
      created_at: new Date().getTime()
    };
    if (!this.dbService) return;
    let seedId = await this.dbService.insertSeed(seed);

    let task: EchoTask = {
      seed_id: seedId,
      action: '微光行动: ' + result,
      is_completed: false,
      created_at: new Date().getTime()
    };
    await this.dbService.insertTask(task);
    
    await this.loadTasks();
    this.showDrawer = true;
  }

  async handleComplete(task: EchoTask) {
    if (!this.dbService || task.id === undefined) {
      return;
    }
    const isUpdated = await this.dbService.markTaskCompleted(task.id, new Date().getTime());
    if (isUpdated) {
      await this.loadTasks();
    }
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      
      if (this.activeTool === 'none') {
        // 主体背景
        Column() {
          // 留出给顶部 Header 避让的空间
          Blank().height(100)

          // 环绕的星轨组件
          Row({ space: 16 }) {
            this.MagicButton('问心', '#FF6B6B', (): void => {
              this.activeTool = 'intro';
            })
            this.MagicButton('抉择', '#FFD93D', (): void => {
              this.activeTool = 'soul';
            })
            this.MagicButton('灵选', '#B89CD4', (): void => {
              router.pushUrl({ url: 'pages/FunChoiceView' });
            })
            this.MagicButton('塔罗', '#6BCB77', (): void => {
              router.pushUrl({ url: 'pages/TarotView' });
            })
            this.MagicButton('轮盘', '#4D96FF', (): void => {
              this.activeTool = 'spinner';
            })
          }
          .margin({ bottom: 40 })

          // 中心树洞区域（入口卡片）
          Column() {
            Row() {
              Column() {
                Text('树隐回声')
                  .fontSize(22)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(ColorConstants.TEXT_PRIMARY)
                  .margin({ bottom: 4 })
                Text('前往你的专属树洞与私密花园')
                  .fontSize(12)
                  .fontColor(ColorConstants.MINT_CYAN)
              }.alignItems(HorizontalAlign.Start)
              
              Blank()
              
              Text('→')
                .fontSize(24)
                .fontColor(ColorConstants.MINT_CYAN)
            }
            .width('100%')
            .padding(24)
            .backgroundColor(ColorConstants.SURFACE_GLASS)
            .borderRadius(20)
            .border({ width: 1, color: 'rgba(0, 240, 255, 0.2)' })
            .onClick((): void => {
              router.pushUrl({ url: 'pages/ZzuMindfulTree' })
            })
          }
          .width('90%')
          .margin({ top: 10 })
        }
        .width('100%')
        .height('100%')
        .backgroundColor(ColorConstants.BACKGROUND_DARK)
        .alignItems(HorizontalAlign.Center)
        .onClick((): void => {
          if (this.showDrawer) this.showDrawer = false;
        })

        // 全局顶部 Header 区
        Row() {
          Image($r('app.media.echoing_icon'))
            .width(44)
            .height(44)
            .borderRadius(22)
            .border({ width: 2, color: ColorConstants.MINT_CYAN })
            .shadow({ radius: 10, color: 'rgba(0, 240, 255, 0.2)' })
          
          Column() {
            Text('Echoing')
              .fontColor(ColorConstants.TEXT_PRIMARY)
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .letterSpacing(2)
            Text('在微光中倾听回声')
              .fontColor(ColorConstants.TEXT_SECONDARY)
              .fontSize(11)
          }
          .alignItems(HorizontalAlign.Start)
          .margin({ left: 12 })
          
          Blank()

          if (this.isLoggedIn && this.userNickname.length > 0) {
            // 已登录：显示昵称首字母头像
            Text(this.userNickname.charAt(0).toUpperCase())
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
              .width(32)
              .height(32)
              .textAlign(TextAlign.Center)
              .borderRadius(16)
              .backgroundColor(ColorConstants.MINT_CYAN)
              .border({ width: 1.5, color: 'rgba(0, 240, 255, 0.4)' })
              .onClick(() => {
                router.pushUrl({ url: 'pages/LoginPage' });
              })
          } else {
            // 未登录：显示默认图标
            Text('👤').fontSize(20)
              .onClick(() => {
                router.pushUrl({ url: 'pages/LoginPage' });
              })
          }
          
          Text('⚙️').fontSize(20)
            .margin({ left: 16 })
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 40 })
        .position({ x: 0, y: 0 })
        .zIndex(10)
      }

      // 底部抽屉
      Column() {
        if (!this.showDrawer) {
          Row()
            .width('30%')
            .height(6)
            .backgroundColor(ColorConstants.MINT_CYAN_DIM)
            .borderRadius(3)
            .margin({ bottom: 20 })
            .onClick((): void => {
              this.showDrawer = true;
            })
        } else {
          EchoDrawer({ 
            tasks: $pendingTasks,
            onCompleteTask: (task: EchoTask): void => { this.handleComplete(task); }
          })
          .height('60%')
          .transition({ type: TransitionType.Insert, translate: { y: 200 } })
          .transition({ type: TransitionType.Delete, translate: { y: 500 } })
        }
      }
      .width('100%')
      .animation({ duration: 400, curve: Curve.FastOutSlowIn })

      // 全屏工具渲染层
      if (this.activeTool === 'spinner') {
        SpinnerWidget({
          onResult: (result: string): void => { this.handleSpinnerResult(result); },
          onClose: (): void => { this.activeTool = 'none'; }
        })
        .transition({ type: TransitionType.Insert, opacity: 1 })
        .transition({ type: TransitionType.Delete, opacity: 0 })
      }

      if (this.activeTool === 'soul') {
        SoulSelectionWidget({
          onResult: (result: string): void => { this.handleSoulResult(result); },
          onClose: (): void => { this.activeTool = 'none'; }
        })
        .transition({ type: TransitionType.Insert, opacity: 1 })
        .transition({ type: TransitionType.Delete, opacity: 0 })
      }

      if (this.activeTool === 'tarot') {
        TarotWidget({
          onResult: (result: string): void => { this.handleTarotResult(result); },
          onClose: (): void => { this.activeTool = 'none'; }
        })
        .transition({ type: TransitionType.Insert, opacity: 1 })
        .transition({ type: TransitionType.Delete, opacity: 0 })
      }

      if (this.activeTool === 'intro') {
        IntrospectionWidget({
          onResult: (result: string): void => { this.handleIntroResult(result); },
          onClose: (): void => { this.activeTool = 'none'; }
        })
        .transition({ type: TransitionType.Insert, opacity: 1 })
        .transition({ type: TransitionType.Delete, opacity: 0 })
      }

    }
    .width('100%')
    .height('100%')
  }

  @Builder MagicButton(title: string, color: string, onClickAction: () => void) {
    Column() {
      Circle({ width: 48, height: 48 })
        .fill(ColorConstants.SURFACE_CARD)
        .stroke(color)
        .strokeWidth(2)
      Text(title)
        .fontSize(12)
        .fontColor(ColorConstants.TEXT_PRIMARY)
        .margin({ top: 8 })
    }
    .onClick(onClickAction)
  }
}
