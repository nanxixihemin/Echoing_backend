// MainAbility/pages/FunChoiceView.ets

import router from '@ohos.router';
import { promptAction } from '@kit.ArkUI';
import preferences from '@ohos.data.preferences';
import vibrator from '@ohos.vibrator';
import common from '@ohos.app.ability.common';

interface Question {
  id: number;
  title: string;
  description: string;
  answers: string[];
  category: string;
  isCustom: boolean;
  isFavorite: boolean;
}

interface HistoryRecord {
  questionTitle: string;
  answer: string;
  timestamp: number;
  category?: string;
}

@Entry
@Component
struct FunChoiceView {
  @State selectedQuestion: Question | null = null;
  @State showAnswer: boolean = false;
  @State currentAnswer: string = '';
  @State showCustomDialog: boolean = false;
  @State showEditDialog: boolean = false;
  @State customQuestion: string = '';
  @State customAnswers: string = '';
  @State customCategory: string = '自定义';
  @State editingQuestion: Question | null = null;
  @State selectedCategory: string = '全部';
  @State showHistory: boolean = false;
  @State historyRecords: HistoryRecord[] = [];
  @State isAnimating: boolean = false;
  @State questions: Question[] = [];

  private categories: string[] = ['全部', '学业篇', '生活篇', '社交篇', '情感篇', '成长篇', '娱乐篇', '自定义'];

  private defaultQuestions: Question[] = [
    { id: 1, title: "今天要不要逃课？", description: "看着窗外的阳光，再看看课表上的高数课...", category: "学业篇", isCustom: false, isFavorite: false,
      answers: ["去吧！生活不止眼前的苟且，还有诗和远方", "别去！老师今天可能点名，而且期末要考", "看心情！如果昨天熬夜了就去休息一下", "问室友！看看大家都怎么选择的", "翻硬币！正面去逃课，反面乖乖上课"] },
    { id: 2, title: "要不要考研？", description: "室友都在刷题，我却在刷抖音...", category: "学业篇", isCustom: false, isFavorite: false,
      answers: ["考！提升学历，为未来投资", "不考！直接工作，积累社会经验", "再想想！先实习看看工作是什么样的", "问家人！听听长辈的建议", "跟风走！室友考我也考，抱团取暖"] },
    { id: 3, title: "今晚要不要熬夜写作业？", description: "作业还没写完，但是已经很困了...", category: "生活篇", isCustom: false, isFavorite: false,
      answers: ["熬夜！今日事今日毕，不拖到明天", "睡觉！身体是革命的本钱，明早再写", "写一半！完成最重要的部分就睡", "找帮助！问问同学能不能参考一下", "设闹钟！最晚12点必须睡觉"] },
    { id: 4, title: "要不要参加社团活动？", description: "社团群里又在组织活动，但我想躺平...", category: "社交篇", isCustom: false, isFavorite: false,
      answers: ["参加！扩展人脉，锻炼社交能力", "不去！好好休息，给自己充电", "看活动！有趣的就去，无聊的就算了", "带朋友！和室友一起去会更有趣", "下次吧！这次休息，下次一定参加"] },
    { id: 5, title: "要不要向喜欢的人表白？", description: "心动了很久，但是害怕被拒绝...", category: "情感篇", isCustom: false, isFavorite: false,
      answers: ["表白！青春就要勇敢，不留遗憾", "再等等！先成为朋友，慢慢了解", "暗示！发个朋友圈，看看对方反应", "问朋友！让共同朋友帮忙打探一下", "提升自己！先让自己变得更优秀"] },
    { id: 6, title: "周末要不要回家？", description: "想家了，但是路费有点贵，而且作业还没写完...", category: "生活篇", isCustom: false, isFavorite: false,
      answers: ["回家！家人的怀抱是最好的充电站", "不回！省钱省时间，专心学习", "视频通话！和家人聊天解解思乡之苦", "下周回！这周忙完下周一定回家", "约朋友！和同学一起出去玩放松一下"] },
    { id: 7, title: "要不要换专业？", description: "发现自己对现在的专业没有兴趣...", category: "学业篇", isCustom: false, isFavorite: false,
      answers: ["换！趁早换到自己喜欢的专业", "不换！每个专业都有它的价值", "了解清楚！先搞明白转专业的要求", "问老师！听听专业老师的建议", "培养兴趣！试着找到专业的有趣之处"] },
    { id: 8, title: "要不要买那个心仪已久的东西？", description: "购物车里躺了很久，但是钱包有点紧张...", category: "生活篇", isCustom: false, isFavorite: false,
      answers: ["买！人生苦短，及时行乐", "不买！理性消费，存钱更重要", "等打折！双十一或者其他活动再买", "买便宜的！找个平替产品", "再想一周！如果还想要就买"] },
    { id: 9, title: "要不要去兼职？", description: "想要经济独立，但是担心影响学习...", category: "成长篇", isCustom: false, isFavorite: false,
      answers: ["去！积累社会经验，锻炼自己", "不去！专心学习，学业为重", "找轻松的！选择时间灵活的兼职", "先试试！做一段时间看看效果", "问学长！听听过来人的经验"] },
    { id: 10, title: "要不要熬夜刷剧？", description: "新剧更新了，但是明天还有早课...", category: "娱乐篇", isCustom: false, isFavorite: false,
      answers: ["刷！青春就是要任性一点", "不刷！早睡早起身体好", "看一集！满足一下就睡觉", "周末补！平时好好休息，周末再看", "和室友一起！大家一起看更有趣"] },
    { id: 11, title: "室友关系有矛盾，要不要直接说？", description: "室友的一些习惯让我很困扰，但不知道怎么开口...", category: "社交篇", isCustom: false, isFavorite: false,
      answers: ["直接说！坦诚沟通解决问题", "委婉提醒！用温和的方式表达", "忍一忍！小事情就算了", "找中介！让其他室友帮忙调解", "换宿舍！实在不行就申请换宿舍"] },
    { id: 12, title: "要不要参加学生会？", description: "学生会在招新，听说很锻炼人但也很累...", category: "成长篇", isCustom: false, isFavorite: false,
      answers: ["参加！锻炼组织能力和领导力", "不参加！专心学习和社团活动", "先了解！问问学长学姐的真实感受", "试试看！不合适可以退出", "看部门！选择自己感兴趣的部门"] },
    { id: 13, title: "食堂吃什么？", description: "又到了饭点，看着各个窗口陷入选择困难...", category: "生活篇", isCustom: false, isFavorite: false,
      answers: ["荷园！胡辣汤配油条，河南人的最爱", "柳园！川菜麻辣香锅，刺激味蕾", "松园！清淡小炒，健康第一", "菊园！面食专区，各种面条任你选", "出去吃！偶尔改善一下伙食"] },
    { id: 14, title: "要不要早起占座？", description: "图书馆座位紧张，但是7点起床真的好困...", category: "学业篇", isCustom: false, isFavorite: false,
      answers: ["早起！好座位值得早起的痛苦", "算了！睡眠更重要，随便找个位置", "去其他地方！宿舍或者教学楼也能学习", "网上预约！用图书馆预约系统", "找研友！让早起的朋友帮忙占座"] },
    { id: 15, title: "要不要谈恋爱？", description: "单身久了有点寂寞，但又怕影响学习...", category: "情感篇", isCustom: false, isFavorite: false,
      answers: ["谈！爱情让生活更美好", "不谈！专心学业，毕业后再说", "随缘！遇到合适的就谈", "先交朋友！从朋友开始慢慢发展", "问室友！听听大家的恋爱经验"] }
  ];

  private context: common.UIAbilityContext | null = null;
  private preferencesName: string = 'fun_choice_data';

  aboutToAppear(): void {
    this.loadData();
  }

  private async loadData(): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      this.context = context;
      const store = await preferences.getPreferences(context, this.preferencesName);
      const questionsStr = await store.get('questions', '') as string;
      if (questionsStr && questionsStr.length > 0) {
        this.questions = JSON.parse(questionsStr) as Question[];
      } else {
        this.questions = this.defaultQuestions;
      }
      const historyStr = await store.get('history', '') as string;
      if (historyStr && historyStr.length > 0) {
        this.historyRecords = JSON.parse(historyStr) as HistoryRecord[];
      }
    } catch (error) {
      this.questions = this.defaultQuestions;
    }
  }

  private async saveData(): Promise<void> {
    try {
      if (this.context === null) { return; }
      const store = await preferences.getPreferences(this.context, this.preferencesName);
      await store.put('questions', JSON.stringify(this.questions));
      await store.put('history', JSON.stringify(this.historyRecords));
      await store.flush();
    } catch (error) {
      // ignore
    }
  }

  private getFilteredQuestions(): Question[] {
    if (this.selectedCategory === '全部') { return this.questions; }
    return this.questions.filter((q: Question) => q.category === this.selectedCategory);
  }

  private toggleFavorite(question: Question): void {
    const index = this.questions.findIndex((q: Question) => q.id === question.id);
    if (index >= 0) {
      this.questions[index].isFavorite = !this.questions[index].isFavorite;
      this.questions = [...this.questions];
      this.saveData();
      this.getUIContext().getPromptAction().showToast({ message: this.questions[index].isFavorite ? '已收藏' : '已取消收藏' });
    }
  }

  private deleteQuestion(question: Question): void {
    this.getUIContext().showAlertDialog({
      title: '确认删除', message: `确定要删除"${question.title}"吗？`,
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: { value: '删除', fontColor: '#FF3B30', action: () => {
        this.questions = this.questions.filter((q: Question) => q.id !== question.id);
        this.saveData();
        this.getUIContext().getPromptAction().showToast({ message: '已删除' });
      }}
    });
  }

  private resetToDefault(): void {
    this.getUIContext().showAlertDialog({
      title: '重置确认', message: '确定要重置所有问题为默认设置吗？自定义问题将被删除。',
      primaryButton: { value: '取消', action: () => {} },
      secondaryButton: { value: '重置', fontColor: '#FF3B30', action: () => {
        this.questions = [...this.defaultQuestions];
        this.saveData();
        this.getUIContext().getPromptAction().showToast({ message: '已重置' });
      }}
    });
  }

  private randomSelectQuestion(): void {
    const filtered = this.getFilteredQuestions();
    if (filtered.length === 0) { this.getUIContext().getPromptAction().showToast({ message: '当前分类没有问题' }); return; }
    try { vibrator.startVibration({ type: 'time', duration: 50 }, { id: 0, usage: 'touch' }); } catch (e) {}
    this.isAnimating = true;
    let count = 0;
    const maxCount = 10;
    const interval = setInterval(() => {
      const randomIndex = Math.floor(Math.random() * filtered.length);
      this.selectedQuestion = filtered[randomIndex];
      count++;
      if (count >= maxCount) {
        clearInterval(interval);
        this.isAnimating = false;
        this.generateAnswer(); // 动画结束自动出答案
      }
    }, 100);
  }

  private generateAnswer(): void {
    if (this.selectedQuestion === null) { return; }
    try { vibrator.startVibration({ type: 'time', duration: 100 }, { id: 0, usage: 'touch' }); } catch (e) {}
    const randomIndex = Math.floor(Math.random() * this.selectedQuestion.answers.length);
    this.currentAnswer = this.selectedQuestion.answers[randomIndex];
    this.showAnswer = true;
    const record: HistoryRecord = { 
      questionTitle: this.selectedQuestion.title, 
      answer: this.currentAnswer, 
      timestamp: Date.now(),
      category: this.selectedQuestion.category
    };
    this.historyRecords.unshift(record);
    if (this.historyRecords.length > 20) { this.historyRecords = this.historyRecords.slice(0, 20); }
    this.saveData();
  }

  private formatTime(timestamp: number): string {
    const date = new Date(timestamp);
    const month = date.getMonth() + 1;
    const day = date.getDate();
    const hour = date.getHours();
    const minute = date.getMinutes();
    return `${month}/${day} ${hour}:${minute < 10 ? '0' + minute : minute}`;
  }

  private getRecordCategory(record: HistoryRecord): string {
    if (record.category) {
      return record.category;
    }
    const q = this.questions.find(q => q.title === record.questionTitle);
    return q ? q.category : '其他';
  }

  // ==================== UI ====================

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#F0F5FA')

      Column() {
        this.TopBar()
        if (this.showHistory) {
          this.HistoryPage()
        } else if (this.selectedQuestion === null) {
          this.QuestionListPage()
        } else {
          this.QuestionDetailPage()
        }
      }
      .width('100%')
      .height('100%')

      if (this.showCustomDialog) { this.CustomDialog() }
      if (this.showEditDialog && this.editingQuestion !== null) { this.EditDialog() }
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  @Builder
  TopBar() {
    Row() {
      Text(this.showHistory ? '‹ 返回' : (this.selectedQuestion ? '‹ 返回' : '‹'))
        .fontSize(15)
        .fontColor('#8B7355')
        .fontWeight(FontWeight.Medium)
        .onClick(() => {
          if (this.showHistory) { this.showHistory = false; }
          else if (this.selectedQuestion !== null) { this.selectedQuestion = null; this.showAnswer = false; }
          else { router.back(); }
        })

      Blank()

      Text(this.showHistory ? '选择历史' : (this.selectedQuestion ? '做选择' : '灵魂选择'))
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor('#3D3225')

      Blank()

      if (!this.showHistory && this.selectedQuestion === null) {
        Row({ space: 16 }) {
          Text('记录')
            .fontSize(13)
            .fontColor('#8B7355')
            .onClick(() => { this.showHistory = true; })

          Text('+')
            .fontSize(18)
            .fontColor('#C8956C')
            .fontWeight(FontWeight.Bold)
            .onClick(() => {
              this.customQuestion = '';
              this.customAnswers = '';
              this.customCategory = '自定义';
              this.showCustomDialog = true;
            })
        }
      } else {
        Column().width(40)
      }
    }
    .width('100%')
    .height(88)
    .padding({ left: 20, right: 20, top: 40 })
    .backgroundColor('#F0F5FA')
  }

  @Builder
  QuestionListPage() {
    Column() {
      // 分类标签
      Scroll() {
        Row({ space: 6 }) {
          ForEach(this.categories, (category: string) => {
            Text(category)
              .fontSize(12)
              .fontColor(this.selectedCategory === category ? '#FFFFFF' : '#8B7355')
              .backgroundColor(this.selectedCategory === category ? '#C8956C' : '#E0E8F0')
              .padding({ left: 14, right: 14, top: 7, bottom: 7 })
              .borderRadius(4)
              .onClick(() => { this.selectedCategory = category; })
          })
        }
        .padding({ left: 20, right: 20 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .margin({ top: 4, bottom: 8 })

      // 功能行
      Row() {
        Button() {
          Row({ space: 4 }) {
            Text('🎲').fontSize(14)
            Text('随机选题')
              .fontSize(13)
              .fontColor('#C8956C')
          }
        }
          .backgroundColor('#F0EBE2')
          .borderRadius(4)
          .height(32)
          .padding({ left: 16, right: 16 })
          .onClick(() => { this.randomSelectQuestion(); })

        Blank()

        Text('重置')
          .fontSize(12)
          .fontColor('#B5A48B')
          .onClick(() => { this.resetToDefault(); })
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 8 })

      // 问题列表
      List({ space: 1 }) {
        ForEach(this.getFilteredQuestions(), (question: Question) => {
          ListItem() {
            this.QuestionCard(question)
          }
        }, (question: Question) => question.id.toString())
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 20, right: 20, bottom: 20 })
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  QuestionCard(question: Question) {
    Row() {
      Column()
        .width(4)
        .height(44)
        .backgroundColor(question.category === '学业篇' ? '#7EB5A6' :
          (question.category === '生活篇' ? '#C8956C' :
            (question.category === '社交篇' ? '#9B8EC4' :
              (question.category === '情感篇' ? '#D4868A' :
                (question.category === '成长篇' ? '#6B99C9' :
                  (question.category === '娱乐篇' ? '#D4A74E' : '#B5A48B'))))))

      Text(question.title)
        .fontSize(14)
        .fontColor('#3D3225')
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ left: 12 })

      if (question.isFavorite) {
        Text('★')
          .fontSize(10)
          .fontColor('#E8A87C')
          .margin({ right: 4 })
      }

      Text('›')
        .fontSize(16)
        .fontColor('#C4BDB0')
        .margin({ right: 12 })
    }
    .width('100%')
    .height(44)
    .backgroundColor(question.category === '学业篇' ? '#F2FAF7' :
      (question.category === '生活篇' ? '#FBF6F0' :
        (question.category === '社交篇' ? '#F5F2FA' :
          (question.category === '情感篇' ? '#FBF0F1' :
            (question.category === '成长篇' ? '#EFF4FA' :
              (question.category === '娱乐篇' ? '#FAF6EC' : '#F6F4F0'))))))
    .onClick(() => {
      this.selectedQuestion = question;
      this.showAnswer = false;
      // 点击卡片直接出答案
      setTimeout(() => {
        this.generateAnswer();
      }, 300); // 稍微延迟一下，配合转场
    })
    .gesture(
      LongPressGesture()
        .onAction(() => {
          this.getUIContext().showAlertDialog({
            title: question.title,
            message: '请选择操作',
            primaryButton: {
              value: question.isFavorite ? '取消收藏' : '收藏',
              action: () => { this.toggleFavorite(question); }
            },
            secondaryButton: {
              value: question.isCustom ? '删除' : '编辑',
              fontColor: question.isCustom ? '#D4868A' : '#C8956C',
              action: () => {
                if (question.isCustom) {
                  this.deleteQuestion(question);
                } else {
                  this.editingQuestion = question;
                  this.customQuestion = question.title;
                  this.customAnswers = question.answers.join('\n');
                  this.customCategory = question.category;
                  this.showEditDialog = true;
                }
              }
            }
          });
        })
    )
  }

  @Builder
  QuestionDetailPage() {
    Column() {
      Scroll() {
        Column() {
          // 问题卡片
          Column() {
            Row() {
              Text(this.selectedQuestion!.category)
                .fontSize(11)
                .fontColor('#8B7355')
                .backgroundColor('#F0EBE2')
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .borderRadius(3)
              Blank()
              Text(this.selectedQuestion!.isFavorite ? '★ 已收藏' : '☆ 收藏')
                .fontSize(12)
                .fontColor(this.selectedQuestion!.isFavorite ? '#E8A87C' : '#B5A48B')
                .onClick(() => { this.toggleFavorite(this.selectedQuestion!); })
            }
            .width('100%')

            // 装饰色条
            Column()
              .width(40)
              .height(3)
              .backgroundColor('#C8956C')
              .borderRadius(2)
              .margin({ top: 20, bottom: 16 })

            Text(this.selectedQuestion!.title)
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor('#3D3225')
              .textAlign(TextAlign.Center)
              .lineHeight(32)
              .margin({ bottom: 10 })

            Text(this.selectedQuestion!.description)
              .fontSize(14)
              .fontColor('#A0917C')
              .textAlign(TextAlign.Center)
              .lineHeight(20)
          }
          .width('100%')
          .padding(24)
          .backgroundColor('#FFFFFF')
          .borderRadius(8)
          .margin({ top: 12 })

          // 答案揭晓
          if (this.showAnswer) {
            Column() {
              Text('命运的选择')
                .fontSize(13)
                .fontColor('#C8956C')
                .fontWeight(FontWeight.Medium)
                .margin({ bottom: 4 })

              Column()
                .width(24)
                .height(2)
                .backgroundColor('#C8956C')
                .borderRadius(1)
                .margin({ bottom: 14 })

              Text(this.currentAnswer)
                .fontSize(16)
                .fontColor('#3D3225')
                .textAlign(TextAlign.Center)
                .lineHeight(26)
                .padding({ left: 16, right: 16, top: 14, bottom: 14 })
                .width('100%')
                .backgroundColor('#E6EEF7')
                .borderRadius(6)
                .border({ width: { left: 3 }, color: '#C8956C' })
            }
            .width('100%')
            .padding(20)
            .backgroundColor('#FFFFFF')
            .borderRadius(8)
            .margin({ top: 12 })
          }

          // 选项列表
          Column() {
            Text('所有选项')
              .fontSize(12)
              .fontColor('#B5A48B')
              .margin({ bottom: 10 })
              .alignSelf(ItemAlign.Start)

            ForEach(this.selectedQuestion!.answers, (answer: string, index: number) => {
              Row() {
                Text(`${index + 1}`)
                  .fontSize(11)
                  .fontColor('#FFFFFF')
                  .width(20)
                  .height(20)
                  .textAlign(TextAlign.Center)
                  .backgroundColor(this.showAnswer && this.currentAnswer === answer ? '#C8956C' : '#C4BDB0')
                  .borderRadius(3)

                Text(answer)
                  .fontSize(13)
                  .fontColor(this.showAnswer && this.currentAnswer === answer ? '#3D3225' : '#6B6155')
                  .fontWeight(this.showAnswer && this.currentAnswer === answer ? FontWeight.Medium : FontWeight.Normal)
                  .margin({ left: 10 })
                  .layoutWeight(1)
              }
              .width('100%')
              .padding({ left: 10, right: 10, top: 10, bottom: 10 })
              .backgroundColor(this.showAnswer && this.currentAnswer === answer ? '#E6EEF7' : '#FAFAF7')
              .borderRadius(4)
              .border(this.showAnswer && this.currentAnswer === answer
                ? { width: { left: 3 }, color: '#C8956C' }
                : { width: { left: 3 }, color: '#E8E4DC' })
              .margin({ bottom: 6 })
            })
          }
          .width('100%')
          .padding(20)
          .backgroundColor('#FFFFFF')
          .borderRadius(8)
          .margin({ top: 12 })
        }
        .padding({ left: 20, right: 20, bottom: 110 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      // 底部按钮
      Column() {
        Button() {
          Row({ space: 8 }) {
            Text('🎲').fontSize(20)
            Text(this.showAnswer ? '再来一次' : '帮我选择')
              .fontSize(16)
              .fontColor('#FFFFFF')
              .fontWeight(FontWeight.Medium)
          }
        }
          .width('100%')
          .height(48)
          .backgroundColor('#C8956C')
          .borderRadius(6)
          .onClick(() => { this.generateAnswer(); })
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 30, top: 10 })
      .backgroundColor('#F0F5FA')
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  HistoryPage() {
    Column() {
      if (this.historyRecords.length === 0) {
        Column({ space: 12 }) {
          Column()
            .width(48)
            .height(48)
            .borderRadius(8)
            .backgroundColor('#E8E4DC')

          Text('暂无选择记录')
            .fontSize(14)
            .fontColor('#B5A48B')

          Text('快去做一些选择吧')
            .fontSize(12)
            .fontColor('#C4BDB0')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 1 }) {
          ForEach(this.historyRecords, (record: HistoryRecord, index: number) => {
            ListItem() {
              Row() {
                Column()
                  .width(4)
                  .height(44)
                  .backgroundColor(
                    this.getRecordCategory(record) === '学业篇' ? '#7EB5A6' :
                      (this.getRecordCategory(record) === '生活篇' ? '#C8956C' :
                        (this.getRecordCategory(record) === '社交篇' ? '#9B8EC4' :
                          (this.getRecordCategory(record) === '情感篇' ? '#D4868A' :
                            (this.getRecordCategory(record) === '成长篇' ? '#6B99C9' :
                              (this.getRecordCategory(record) === '娱乐篇' ? '#D4A74E' : '#B5A48B')))))
                  )

                Text(record.questionTitle)
                  .fontSize(14)
                  .fontColor('#3D3225')
                  .layoutWeight(0.4) // 限制问题占宽度比例
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .margin({ left: 12 })

                Text('→')
                  .fontSize(12)
                  .fontColor('#C4BDB0')
                  .margin({ left: 4, right: 4 })

                Text(record.answer)
                  .fontSize(13)
                  .fontColor('#C8956C')
                  .fontWeight(FontWeight.Medium)
                  .layoutWeight(0.6)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })

                Text(this.formatTime(record.timestamp))
                  .fontSize(10)
                  .fontColor('#B5A48B')
                  .margin({ right: 12 })
              }
              .width('100%')
              .height(44)
              .backgroundColor(
                this.getRecordCategory(record) === '学业篇' ? '#F2FAF7' :
                  (this.getRecordCategory(record) === '生活篇' ? '#FBF6F0' :
                    (this.getRecordCategory(record) === '社交篇' ? '#F5F2FA' :
                      (this.getRecordCategory(record) === '情感篇' ? '#FBF0F1' :
                        (this.getRecordCategory(record) === '成长篇' ? '#EFF4FA' :
                          (this.getRecordCategory(record) === '娱乐篇' ? '#FAF6EC' : '#F6F4F0')))))
              )
              .borderRadius(0)
              .margin({ bottom: 0 })
              // 底部分隔线
              .border({ width: { bottom: 1 }, color: '#E0E8F0' })
            }
          }, (record: HistoryRecord, index: number) => index.toString())
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 20, right: 20, top: 8 })
        .scrollBar(BarState.Off)

        Button('清空历史记录')
          .width('90%')
          .height(40)
          .backgroundColor('#E0E8F0')
          .fontColor('#B5A48B')
          .fontSize(13)
          .borderRadius(4)
          .margin({ bottom: 30 })
          .onClick(() => {
            this.getUIContext().showAlertDialog({
              title: '确认清空', message: '确定要清空所有历史记录吗？',
              primaryButton: { value: '取消', action: () => {} },
              secondaryButton: { value: '清空', fontColor: '#D4868A', action: () => { this.historyRecords = []; this.saveData(); } }
            });
          })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  CustomDialog() {
    Column() {
      Column().width('100%').height('100%').backgroundColor('rgba(0,0,0,0.4)')
        .onClick(() => { this.showCustomDialog = false; })
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Center).position({ x: 0, y: 0 })

    Column() {
      Text('添加自定义问题')
        .fontSize(18).fontWeight(FontWeight.Bold).fontColor('#3D3225').margin({ bottom: 20 })

      Column({ space: 6 }) {
        Text('问题').fontSize(12).fontColor('#8B7355').alignSelf(ItemAlign.Start)
        TextInput({ placeholder: '例如：今天中午吃什么？', text: this.customQuestion })
          .width('100%').height(42).backgroundColor('#E6EEF7').borderRadius(4)
          .padding({ left: 12, right: 12 }).fontSize(14)
          .onChange((value: string) => { this.customQuestion = value; })
      }.width('100%').margin({ bottom: 14 })

      Column({ space: 6 }) {
        Text('分类').fontSize(12).fontColor('#8B7355').alignSelf(ItemAlign.Start)
        Scroll() {
          Row({ space: 6 }) {
            ForEach(['学业篇', '生活篇', '社交篇', '情感篇', '成长篇', '娱乐篇', '自定义'], (cat: string) => {
              Text(cat).fontSize(11)
                .fontColor(this.customCategory === cat ? '#FFFFFF' : '#8B7355')
                .backgroundColor(this.customCategory === cat ? '#C8956C' : '#E0E8F0')
                .padding({ left: 10, right: 10, top: 5, bottom: 5 }).borderRadius(3)
                .onClick(() => { this.customCategory = cat; })
            })
          }
        }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')
      }.width('100%').margin({ bottom: 14 })

      Column({ space: 6 }) {
        Text('选项（每行一个）').fontSize(12).fontColor('#8B7355').alignSelf(ItemAlign.Start)
        TextArea({ placeholder: '选项A\n选项B\n选项C', text: this.customAnswers })
          .width('100%').height(90).backgroundColor('#E6EEF7').borderRadius(4).padding(12).fontSize(13)
          .onChange((value: string) => { this.customAnswers = value; })
      }.width('100%').margin({ bottom: 20 })

      Row({ space: 10 }) {
        Button('取消').layoutWeight(1).height(40).backgroundColor('#E0E8F0')
          .fontColor('#8B7355').fontSize(14).borderRadius(4)
          .onClick(() => { this.showCustomDialog = false; })

        Button('添加').layoutWeight(1).height(40).backgroundColor('#C8956C')
          .fontColor('#FFFFFF').fontSize(14).borderRadius(4)
          .onClick(() => {
            if (this.customQuestion.trim().length === 0) { this.getUIContext().getPromptAction().showToast({ message: '请输入问题' }); return; }
            const answers = this.customAnswers.split('\n').filter((item: string) => item.trim().length > 0);
            if (answers.length < 2) { this.getUIContext().getPromptAction().showToast({ message: '请至少输入2个选项' }); return; }
            const newQuestion: Question = {
              id: Date.now(), title: this.customQuestion.trim(), description: '自定义问题',
              category: this.customCategory, isCustom: true, isFavorite: false, answers: answers
            };
            this.questions.unshift(newQuestion);
            this.saveData();
            this.showCustomDialog = false;
            this.getUIContext().getPromptAction().showToast({ message: '添加成功' });
          })
      }.width('100%')
    }
    .width('85%').backgroundColor('#FFFFFF').borderRadius(8).padding(24)
    .position({ x: '7.5%', y: '20%' })
  }

  @Builder
  EditDialog() {
    Column() {
      Column().width('100%').height('100%').backgroundColor('rgba(0,0,0,0.4)')
        .onClick(() => { this.showEditDialog = false; this.editingQuestion = null; })
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Center).position({ x: 0, y: 0 })

    Column() {
      Text('编辑问题')
        .fontSize(18).fontWeight(FontWeight.Bold).fontColor('#3D3225').margin({ bottom: 20 })

      Column({ space: 6 }) {
        Text('问题').fontSize(12).fontColor('#8B7355').alignSelf(ItemAlign.Start)
        TextInput({ placeholder: '问题', text: this.customQuestion })
          .width('100%').height(42).backgroundColor('#E6EEF7').borderRadius(4)
          .padding({ left: 12, right: 12 }).fontSize(14)
          .onChange((value: string) => { this.customQuestion = value; })
      }.width('100%').margin({ bottom: 14 })

      Column({ space: 6 }) {
        Text('分类').fontSize(12).fontColor('#8B7355').alignSelf(ItemAlign.Start)
        Scroll() {
          Row({ space: 6 }) {
            ForEach(['学业篇', '生活篇', '社交篇', '情感篇', '成长篇', '娱乐篇', '自定义'], (cat: string) => {
              Text(cat).fontSize(11)
                .fontColor(this.customCategory === cat ? '#FFFFFF' : '#8B7355')
                .backgroundColor(this.customCategory === cat ? '#C8956C' : '#E0E8F0')
                .padding({ left: 10, right: 10, top: 5, bottom: 5 }).borderRadius(3)
                .onClick(() => { this.customCategory = cat; })
            })
          }
        }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')
      }.width('100%').margin({ bottom: 14 })

      Column({ space: 6 }) {
        Text('选项（每行一个）').fontSize(12).fontColor('#8B7355').alignSelf(ItemAlign.Start)
        TextArea({ placeholder: '选项', text: this.customAnswers })
          .width('100%').height(90).backgroundColor('#E6EEF7').borderRadius(4).padding(12).fontSize(13)
          .onChange((value: string) => { this.customAnswers = value; })
      }.width('100%').margin({ bottom: 20 })

      Row({ space: 10 }) {
        Button('取消').layoutWeight(1).height(40).backgroundColor('#E0E8F0')
          .fontColor('#8B7355').fontSize(14).borderRadius(4)
          .onClick(() => { this.showEditDialog = false; this.editingQuestion = null; })

        Button('保存').layoutWeight(1).height(40).backgroundColor('#C8956C')
          .fontColor('#FFFFFF').fontSize(14).borderRadius(4)
          .onClick(() => {
            if (this.customQuestion.trim().length === 0) { this.getUIContext().getPromptAction().showToast({ message: '请输入问题' }); return; }
            const answers = this.customAnswers.split('\n').filter((item: string) => item.trim().length > 0);
            if (answers.length < 2) { this.getUIContext().getPromptAction().showToast({ message: '请至少输入2个选项' }); return; }
            const index = this.questions.findIndex((q: Question) => q.id === this.editingQuestion!.id);
            if (index >= 0) {
              this.questions[index].title = this.customQuestion.trim();
              this.questions[index].category = this.customCategory;
              this.questions[index].answers = answers;
              this.questions = [...this.questions];
              this.saveData();
            }
            this.showEditDialog = false;
            this.editingQuestion = null;
            this.getUIContext().getPromptAction().showToast({ message: '保存成功' });
          })
      }.width('100%')
    }
    .width('85%').backgroundColor('#FFFFFF').borderRadius(8).padding(24)
    .position({ x: '7.5%', y: '20%' })
  }
}
