// MainAbility/pages/SharedWrite.ets

import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { AIResponseGenerator } from '../utils/AIResponseGenerator';
import { KeywordDetector, CrisisDetectionResult, CRISIS_HELP_INFO } from '../utils/KeywordDetector';
import { SharedForestService } from '../service/SharedForestService';

@Entry
@Component
struct SharedWrite {
  @State inputContent: string = '';
  @State inputNickname: string = '';
  @State aiResponse: string = '';
  @State showAIResponse: boolean = false;
  @State isSubmitting: boolean = false;
  @State isOnline: boolean = true;

  // 危机检测相关状态
  @State showCrisisDialog: boolean = false;
  @State crisisLevel: string = 'none';
  @State showMildWarning: boolean = false;
  @StorageProp('currentAccountKey') currentAccountKey: string = '';
  @StorageProp('userNickname') userNickname: string = '';

  aboutToAppear(): void {
    this.checkConnection();
  }

  private async checkConnection(): Promise<void> {
    this.isOnline = await SharedForestService.checkConnection();
  }

  private generateNickname(): string {
    const prefixes: string[] = ['南核的', '图书馆的', '操场边的', '食堂里的', '眉湖边的', '樱花道的', '钟楼下的', '柳园的'];
    const suffixes: string[] = ['猫', '云', '风', '星星', '蒲公英', '叶子', '萤火虫', '小鸟', '蝴蝶'];
    const pIndex: number = Math.floor(Math.random() * prefixes.length);
    const sIndex: number = Math.floor(Math.random() * suffixes.length);
    return prefixes[pIndex] + suffixes[sIndex];
  }

  // 检测并处理提交
  private handleSubmit(): void {
    if (this.inputContent.trim().length === 0 || this.isSubmitting) {
      return;
    }

    const result: CrisisDetectionResult = KeywordDetector.detect(this.inputContent);

    if (result.isCrisis) {
      this.crisisLevel = result.level;

      if (result.level === 'severe') {
        // 严重：显示关怀弹窗，不允许发布
        this.showCrisisDialog = true;
      } else if (result.level === 'mild') {
        // 轻度：显示关怀弹窗，但允许选择继续发布
        this.showMildWarning = true;
      }
    } else {
      // 无危机关键词，直接发布
      this.submitLeaf();
    }
  }

  private async submitLeaf(): Promise<void> {
    if (this.inputContent.trim().length === 0 || this.isSubmitting) {
      return;
    }

    this.isSubmitting = true;

    const nickname: string = this.inputNickname.trim().length > 0
      ? this.inputNickname.trim()
      : this.generateNickname();

    try {
      const response = await SharedForestService.submitLeaf(
        this.inputContent.trim(),
        nickname,
        this.currentAccountKey,
        this.userNickname
      );

      if (response.responseCode === 200) {
        const aiRes: string = AIResponseGenerator.generate(this.inputContent);
        this.aiResponse = aiRes;
        this.showAIResponse = true;
        this.inputContent = '';
        this.inputNickname = '';

        promptAction.showToast({ message: '叶子已飘向森林 🍃' });
      } else {
        promptAction.showToast({ message: '发送失败，请重试' });
      }
    } catch (e) {
      console.error('SharedWrite', 'Submit failed');
      promptAction.showToast({ message: '网络错误，请检查校园网连接' });
    } finally {
      this.isSubmitting = false;
    }
  }

  build() {
    Stack() {
      // 背景
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [['#F0F8F5', 0], ['#E0F2F1', 0.5], ['#C8E6C9', 1]]
        })

      // 装饰叶子
      this.LeafDecoration()

      Column() {
        this.TopBar()

        if (this.showAIResponse) {
          this.AIResponseCard()
        }

        Scroll() {
          Column({ space: 18 }) {
            // 提示区域
            Column({ space: 8 }) {
              Text('🍃 挂一片叶子')
                .fontSize(24)
                .fontWeight(FontWeight.Bold)
                .fontColor('#1B5E20')

              Text('让你的心情随风飘向森林')
                .fontSize(14)
                .fontColor('#4CAF50')

              // 连接状态
              Row({ space: 6 }) {
                Circle()
                  .width(8)
                  .height(8)
                  .fill(this.isOnline ? '#4CAF50' : '#F44336')

                Text(this.isOnline ? '已连接校园网' : '未连接，请检查网络')
                  .fontSize(12)
                  .fontColor(this.isOnline ? '#4CAF50' : '#F44336')
              }
              .margin({ top: 8 })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .margin({ top: 48 })

            // 昵称输入
            Column({ space: 8 }) {
              Text('你的昵称')
                .fontSize(13)
                .fontColor('#666666')

              Row() {

                TextInput({ placeholder: '匿名小树叶', text: this.inputNickname })
                  .fontSize(15)
                  .maxLength(12)
                  .backgroundColor(Color.Transparent)
                  .fontColor('#333333')
                  .placeholderColor('#999999')
                  .layoutWeight(1)
                  .onChange((value: string) => {
                    this.inputNickname = value;
                  })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 14, bottom: 14 })
              .backgroundColor('#FFFFFF')
              .borderRadius(16)
              .shadow({
                radius: 8,
                color: 'rgba(0,0,0,0.08)',
                offsetY: 2
              })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            // 内容输入
            Column({ space: 8 }) {
              Text('想说的话')
                .fontSize(13)
                .fontColor('#666666')

              Column() {
                TextArea({ placeholder: '今天有什么想分享的吗？\n你的心情会化作叶子，飘向校园的心灵森林...', text: this.inputContent })
                  .fontSize(15)
                  .fontColor('#333333')
                  .placeholderColor('#999999')
                  .backgroundColor(Color.Transparent)
                  .height(160)
                  .maxLength(500)
                  .onChange((value: string) => {
                    this.inputContent = value;
                  })

                Row() {
                  Blank()
                  Text(this.inputContent.length.toString() + '/500')
                    .fontSize(11)
                    .fontColor('#999999')
                }
                .width('100%')
                .padding({ right: 12, bottom: 8 })
              }
              .width('100%')
              .backgroundColor('#FFFFFF')
              .borderRadius(16)
              .shadow({
                radius: 8,
                color: 'rgba(0,0,0,0.08)',
                offsetY: 2
              })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            // 提示信息
            Column({ space: 6 }) {
              Row({ space: 8 }) {
                Text('完全匿名，不会显示个人信息')
                  .fontSize(12)
                  .fontColor('#666666')
              }

              Row({ space: 8 }) {
                Text('叶子会在7天后自动消失')
                  .fontSize(12)
                  .fontColor('#666666')
              }

              Row({ space: 8 }) {
                Text('仅限校内网络访问')
                  .fontSize(12)
                  .fontColor('#666666')
              }
            }
            .width('100%')
            .padding(16)
            .backgroundColor('rgba(76,175,80,0.1)')
            .borderRadius(14)
            .alignItems(HorizontalAlign.Start)

            // 心理援助信息卡片（始终显示）
            Column({ space: 10 }) {
              Row({ space: 8 }) {
                Text('心理支持')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#1B5E20')
              }

              Text('如果你正在经历困难，记得你不是一个人')
                .fontSize(13)
                .fontColor('#555555')

              Row({ space: 12 }) {
                Text(CRISIS_HELP_INFO.name)
                  .fontSize(12)
                  .fontColor('#4CAF50')
                Text(CRISIS_HELP_INFO.hotline)
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#1B5E20')
              }
            }
            .width('100%')
            .padding(14)
            .backgroundColor('rgba(76,175,80,0.08)')
            .borderRadius(14)
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .padding({ left: 20, right: 20, bottom: 120 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')

      // 提交按钮
      Button('🍃 飘向森林')
        .width('85%')
        .height(54)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FFFFFF')
        .backgroundColor(this.inputContent.trim().length > 0 && this.isOnline ? '#4CAF50' : '#CCCCCC')
        .borderRadius(27)
        .shadow({
          radius: 16,
          color: 'rgba(76,175,80,0.4)',
          offsetY: 6
        })
        .position({ x: '7.5%', y: '88%' })
        .enabled(this.inputContent.trim().length > 0 && this.isOnline && !this.isSubmitting)
        .onClick(() => {
          this.handleSubmit();
        })

      // 严重危机弹窗（不允许发布）
      if (this.showCrisisDialog) {
        this.SevereCrisisDialog()
      }

      // 轻度关怀弹窗（可以选择继续发布）
      if (this.showMildWarning) {
        this.MildWarningDialog()
      }
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  // ==================== 严重危机弹窗 ====================
  @Builder
  SevereCrisisDialog() {
    // 遮罩层
    Column()
      .width('100%')
      .height('100%')
      .backgroundColor('rgba(0,0,0,0.6)')

    // 弹窗内容
    Column({ space: 18 }) {

      Text('我们很担心你')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1B5E20')

      Text('检测到你可能正在经历非常困难的时刻。\n你的感受很重要，我们希望能帮助你。')
        .fontSize(14)
        .fontColor('#555555')
        .textAlign(TextAlign.Center)
        .lineHeight(24)

      // 援助信息卡片
      Column({ space: 10 }) {
        Text(CRISIS_HELP_INFO.message)
          .fontSize(14)
          .fontColor('#333333')
          .textAlign(TextAlign.Center)
          .lineHeight(22)

        Column({ space: 4 }) {
          Text(CRISIS_HELP_INFO.name)
            .fontSize(14)
            .fontColor('#4CAF50')
            .fontWeight(FontWeight.Medium)

          Text(CRISIS_HELP_INFO.hotline)
            .fontSize(22)
            .fontColor('#1B5E20')
            .fontWeight(FontWeight.Bold)

          Text(CRISIS_HELP_INFO.available + '在线')
            .fontSize(12)
            .fontColor('#888888')
        }
      }
      .width('100%')
      .padding(18)
      .backgroundColor('#E8F5E9')
      .borderRadius(14)

      // 额外资源
      Column({ space: 8 }) {
        Text('其他求助方式')
          .fontSize(13)
          .fontColor('#666666')

        Row({ space: 16 }) {
          Column({ space: 4 }) {
            Text('全国心理援助')
              .fontSize(11)
              .fontColor('#666666')
            Text('400-161-9995')
              .fontSize(12)
              .fontColor('#333333')
              .fontWeight(FontWeight.Medium)
          }
        }
      }
      .width('100%')
      .padding(14)
      .backgroundColor('#FAFAFA')
      .borderRadius(12)

      // 按钮
      Column({ space: 10 }) {
        Button('我想和专业人员聊聊')
          .width('100%')
          .height(48)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .backgroundColor('#4CAF50')
          .borderRadius(24)
          .onClick(() => {
            // 这里可以集成拨打电话功能
            promptAction.showToast({ message: '请拨打: ' + CRISIS_HELP_INFO.hotline });
          })

        Button('我现在感觉好一些了')
          .width('100%')
          .height(44)
          .fontSize(14)
          .backgroundColor('#E8F5E9')
          .fontColor('#4CAF50')
          .borderRadius(22)
          .onClick(() => {
            this.showCrisisDialog = false;
            this.inputContent = '';
          })
      }
      .width('100%')

      Text('为了保护你，这条内容暂时无法发布')
        .fontSize(11)
        .fontColor('#999999')
    }
    .width('90%')
    .padding(26)
    .backgroundColor(Color.White)
    .borderRadius(24)
    .position({ x: '5%', y: '10%' })
  }

  // ==================== 轻度关怀弹窗 ====================
  @Builder
  MildWarningDialog() {
    // 遮罩层
    Column()
      .width('100%')
      .height('100%')
      .backgroundColor('rgba(0,0,0,0.5)')
      .onClick(() => {
        this.showMildWarning = false;
      })

    // 弹窗内容
    Column({ space: 16 }) {

      Text('我们注意到了')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1B5E20')

      Text('看起来你可能正在经历一些压力或困扰。\n无论发生什么，记得有人关心你。')
        .fontSize(14)
        .fontColor('#555555')
        .textAlign(TextAlign.Center)
        .lineHeight(22)

      // 援助信息
      Row({ space: 12 }) {
        Column({ space: 4 }) {
          Text('需要倾诉？')
            .fontSize(12)
            .fontColor('#666666')
        }

        Column({ space: 2 }) {
          Text(CRISIS_HELP_INFO.name)
            .fontSize(13)
            .fontColor('#4CAF50')
          Text(CRISIS_HELP_INFO.hotline)
            .fontSize(15)
            .fontColor('#1B5E20')
            .fontWeight(FontWeight.Medium)
        }
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding(14)
      .backgroundColor('#E8F5E9')
      .borderRadius(12)
      .justifyContent(FlexAlign.Center)

      // 按钮
      Row({ space: 12 }) {
        Button('继续发布')
          .layoutWeight(1)
          .height(46)
          .fontSize(14)
          .backgroundColor('#E8F5E9')
          .fontColor('#4CAF50')
          .borderRadius(23)
          .onClick(() => {
            this.showMildWarning = false;
            this.submitLeaf();
          })

        Button('重新编辑')
          .layoutWeight(1)
          .height(46)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .backgroundColor('#4CAF50')
          .borderRadius(23)
          .onClick(() => {
            this.showMildWarning = false;
          })
      }
      .width('100%')

      Text('你可以随时寻求帮助 💚')
        .fontSize(12)
        .fontColor('#888888')
    }
    .width('88%')
    .padding(24)
    .backgroundColor(Color.White)
    .borderRadius(22)
    .position({ x: '6%', y: '22%' })
  }

  @Builder
  LeafDecoration() {
    Stack() {
      ForEach([1, 2, 3, 4, 5, 6], (i: number) => {
        Text('🍃')
          .fontSize(16 + i * 2)
          .opacity(0.15 + i * 0.05)
          .position({
            x: (10 + i * 15).toString() + '%',
            y: (5 + (i * 8) % 20).toString() + '%'
          })
          .rotate({ angle: -20 + i * 15 })
      }, (i: number) => i.toString())
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  TopBar() {
    Row() {
      Button({ type: ButtonType.Circle }) {
        Text('返回')
          .fontSize(12)
          .fontColor('#1B5E20')
          .fontWeight(500)
      }
      .width(44)
      .height(44)
      .backgroundColor('rgba(255,255,255,0.9)')
      .shadow({
        radius: 4,
        color: 'rgba(0,0,0,0.1)',
        offsetY: 2
      })
      .onClick(() => {
        router.back();
      })

      Blank()

      Text('挂叶子')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1B5E20')

      Blank()

      Column()
        .width(44)
        .height(44)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 8 })
  }

  @Builder
  AIResponseCard() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text('小树苗说')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#4CAF50')
      }

      Text(this.aiResponse)
        .fontSize(14)
        .fontColor('#333333')
        .lineHeight(24)

      Row() {
        Blank()
        Text('点击关闭')
          .fontSize(11)
          .fontColor('#999999')
      }
      .width('100%')
    }
    .width('90%')
    .padding(18)
    .margin({ top: 12 })
    .backgroundColor('#FFFFFF')
    .borderRadius(18)
    .shadow({
      radius: 12,
      color: 'rgba(76,175,80,0.2)',
      offsetY: 4
    })
    .onClick(() => {
      this.showAIResponse = false;
    })
  }
}

