import router from '@ohos.router';
import http from '@ohos.net.http';
import promptAction from '@ohos.promptAction';
import { ChatHistoryManager, ChatSession, ChatMsg } from '../service/ChatHistoryManager';
import common from '@ohos.app.ability.common';
import { AppConfig } from '../common/AppConfig';

interface RouterParams {
  interpretation?: string;
  theme?: string;
  sessionId?: string;
}

// ====== SiliconFlow API ======
interface SiliconFlowMessage {
  role: string;
  content: string;
}
interface SiliconFlowReqBody {
  model: string;
  messages: SiliconFlowMessage[];
  temperature: number;
  max_tokens: number;
  userId?: string;
  accountKey?: string;
  nickname?: string;
  bio?: string;
}
interface SiliconFlowChoiceMessage {
  content: string;
}
interface SiliconFlowChoice {
  message: SiliconFlowChoiceMessage;
}
interface SiliconFlowResponse {
  choices: SiliconFlowChoice[];
}

interface ChatMessage {
  id: number;
  role: 'user' | 'assistant';
  content: string;
}

// ====== 全局色彩常量 ======
const BG_PAGE = '#FFFDF9';
const ACCENT = '#F18F01';
const TEXT_MAIN = '#5A3A00';
const TEXT_SUB = '#8D6B32';

@Entry
@Component
struct AIDialogPage {
  @State messages: ChatMessage[] = [];
  @State userInput: string = '';
  @State isLoading: boolean = false;
  @State titleScale: number = 1;
  @State dotCount: number = 0;
  @StorageProp('currentAccountKey') currentAccountKey: string = '';
  @StorageProp('userNickname') userNickname: string = '';
  @StorageProp('userBio') userBio: string = '';
  private nextId: number = 1;
  private dotTimer: number = -1;
  private systemPrompt: string = '';
  // 会话持久化
  private sessionId: string = '';
  private sessionTheme: string = '';
  private memoryContext: string = '';

  aboutToAppear() {
    const params = router.getParams() as RouterParams;
    const interpretation = params.interpretation ?? '';
    const theme = params.theme ?? '你当前最关心的人生议题';
    const existingSessionId = params.sessionId ?? '';

    this.sessionTheme = theme;

    // 初始化 ChatHistoryManager
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const mgr = ChatHistoryManager.getInstance();
      mgr.initialize(context).then(() => {
        // 获取 AI 记忆上下文
        mgr.getMemoryContext((ctx: string) => {
          this.memoryContext = ctx;
          this.buildSystemPrompt(interpretation, theme);
        });

        // 如果有 sessionId，说明是从历史页跳入
        if (existingSessionId.length > 0) {
          this.sessionId = existingSessionId;
          mgr.getSession(existingSessionId).then((session: ChatSession | null) => {
            if (session !== null) {
              this.sessionTheme = session.theme;
              this.systemPrompt = session.systemPrompt;
              let restored: ChatMessage[] = [];
              for (let i = 0; i < session.messages.length; i++) {
                let m = session.messages[i];
                let cm: ChatMessage = {
                  id: m.id,
                  role: m.role === 'user' ? 'user' : 'assistant',
                  content: m.content
                };
                restored.push(cm);
                if (m.id >= this.nextId) {
                  this.nextId = m.id + 1;
                }
              }
              this.messages = restored;
            }
          });
        } else {
          // 新会话
          this.sessionId = ChatHistoryManager.generateId();
          if (interpretation.length > 0) {
            this.messages = [{
              id: this.nextId++,
              role: 'assistant',
              content: interpretation
            }];
          }
        }
      });
    } catch (e) {
      // fallback: 不使用历史
      this.sessionId = `s_${Date.now()}`;
      this.buildSystemPrompt(interpretation, theme);
      if (interpretation.length > 0) {
        this.messages = [{
          id: this.nextId++,
          role: 'assistant',
          content: interpretation
        }];
      }
    }

    setInterval(() => {
      this.titleScale = this.titleScale === 1 ? 1.04 : 1;
    }, 1800);
  }

  aboutToDisappear() {
    if (this.dotTimer !== -1) {
      clearInterval(this.dotTimer);
    }
    // 页面销毁时保存会话
    this.saveCurrentSession();
  }

  private buildSystemPrompt(interpretation: string, theme: string): void {
    let prompt = `你是一位资深塔罗占卜师，擅长以"嵩月塔罗占卜师"的身份为用户提供温暖且深刻的解读。本次占卜主题为：${theme}。请围绕此主题展开。`;
    if (interpretation.length > 0) {
      prompt += `\n以下是你刚才给出的初始解读，请基于此继续对话：\n${interpretation}`;
    }
    if (this.memoryContext.length > 0) {
      prompt += `\n\n${this.memoryContext}`;
      prompt += `\n请结合以上历史记忆，在对话中自然地呼应用户过往的经历。`;
    }
    prompt += `\n注意：回复请保持自然、温暖、有深度，语气坚定而不模糊，不使用 Markdown 格式，不要在末尾标注字数。`;
    this.systemPrompt = prompt;
  }

  private async saveCurrentSession(): Promise<void> {
    if (this.messages.length === 0) return;
    try {
      const mgr = ChatHistoryManager.getInstance();
      const context = getContext(this) as common.UIAbilityContext;
      await mgr.initialize(context);
      // 将 ChatMessage[] 转为 ChatMsg[]
      let msgs: ChatMsg[] = [];
      for (let i = 0; i < this.messages.length; i++) {
        let m = this.messages[i];
        let cm: ChatMsg = {
          id: m.id,
          role: m.role,
          content: m.content
        };
        msgs.push(cm);
      }

      // 自动摘要：取最后一条 AI 回复的前 30 字
      let summary = '';
      for (let i = this.messages.length - 1; i >= 0; i--) {
        if (this.messages[i].role === 'assistant') {
          summary = this.messages[i].content.substring(0, 30);
          break;
        }
      }

      let session: ChatSession = {
        id: this.sessionId,
        theme: this.sessionTheme,
        summary: summary,
        systemPrompt: this.systemPrompt,
        createdAt: Date.now(),
        updatedAt: Date.now(),
        messages: msgs
      };
      await mgr.saveSession(session);
    } catch (e) {
      // ignore save errors
    }
  }

  build() {
    Column() {
      // ========== 顶部导航栏 ==========
      Row() {
        // 返回按钮 或 返回箭头
        Text("←")
          .fontSize(22)
          .fontColor(TEXT_MAIN)
          .fontWeight(FontWeight.Bold)
          .width(36)
          .height(36)
          .textAlign(TextAlign.Center)
          .backgroundColor('#FFF2CC')
          .border({ width: 1.5, color: ACCENT, radius: 18 })
          .onClick(() => {
            router.back();
          })

        Blank()

        // 标题文字
        Text("嵩月塔罗")
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(TEXT_MAIN)
          .letterSpacing(2)

        Blank()

        // 右上角回顾按钮 跳转到历史页
        Text("回顾")
          .fontSize(12)
          .fontColor(TEXT_MAIN)
          .fontWeight(FontWeight.Bold)
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .backgroundColor('#E8DAEF')
          .border({ width: 1.5, color: ACCENT, radius: 12 })
          .onClick(() => {
            this.saveCurrentSession();
            router.pushUrl({
              url: 'pages/ChatHistoryPage'
            });
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 52, bottom: 8 })
      .alignItems(VerticalAlign.Center)

      // ========== 消息列表 ==========
      List({ space: 12 }) {
        ForEach(
          this.messages,
          (item: ChatMessage) => {
            ListItem() {
              Column() {
                if (item.role === 'assistant') {
                  Text("嵩月塔罗占卜师")
                    .fontSize(11)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(TEXT_SUB)
                    .margin({ bottom: 4 })
                    .alignSelf(ItemAlign.Start)
                }

                Row() {
                  if (item.role === 'user') {
                    Blank()
                  }

                  Text(item.content)
                    .fontSize(14)
                    .fontColor(TEXT_MAIN)
                    .lineHeight(21)
                    .wordBreak(WordBreak.BREAK_ALL)
                    .constraintSize({ maxWidth: '78%' })
                    .backgroundColor(item.role === 'user' ? '#FFD8D8' : '#E2F0CB')
                    .border({
                      width: 1.5,
                      color: item.role === 'user' ? ACCENT : '#A8D5A2',
                      radius: 14
                    })
                    .padding({ left: 12, right: 12, top: 10, bottom: 10 })

                  if (item.role === 'assistant') {
                    Blank()
                  }
                }
                .width('100%')
              }
              .width('100%')
            }
            .key(item.id.toString())
          },
          (item: ChatMessage) => item.id.toString()
        )

        if (this.isLoading) {
          ListItem() {
            Column() {
              Text("嵩月塔罗占卜师 正在感应中")
                .fontSize(11)
                .fontWeight(FontWeight.Bold)
                .fontColor(TEXT_SUB)
                .margin({ bottom: 4 })
                .alignSelf(ItemAlign.Start)

              Text(this.getLoadingDots())
                .fontSize(18)
                .fontColor('#A8D5A2')
                .fontWeight(FontWeight.Bold)
                .backgroundColor('#E2F0CB')
                .border({ width: 1.5, color: '#A8D5A2', radius: 14 })
                .padding({ left: 12, right: 12, top: 8, bottom: 8 })
                .alignSelf(ItemAlign.Start)
            }
            .width('100%')
          }
        }
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 16, right: 16 })
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

      // ========== 底部输入区 ==========
      Row({ space: 8 }) {
        TextInput({
          placeholder: "继续提问…",
          text: this.userInput
        })
          .onChange((value: string) => {
            this.userInput = value;
          })
          .layoutWeight(1)
          .height(42)
          .backgroundColor('#FFF2CC')
          .fontColor(TEXT_MAIN)
          .placeholderColor(TEXT_SUB)
          .border({ width: 1.5, color: ACCENT, radius: 21 })
          .padding({ left: 14, right: 14 })

        Button("发送")
          .width(56)
          .height(42)
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.userInput.trim().length > 0 ? TEXT_MAIN : TEXT_SUB)
          .backgroundColor(this.userInput.trim().length > 0 ? '#FFAFCC' : '#EDE4D6')
          .border({ width: 1.5, color: ACCENT, radius: 21 })
          .onClick(() => {
            this.sendMessage();
          })
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 8, bottom: 28 })
      .backgroundColor(BG_PAGE)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(BG_PAGE)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  private getLoadingDots(): string {
    let d = this.dotCount % 4;
    if (d === 0) return '·';
    if (d === 1) return '··';
    if (d === 2) return '···';
    return '····';
  }

  private sendMessage(): void {
    const trimmed = this.userInput.trim();
    if (!trimmed || this.isLoading) return;
    this.userInput = '';

    this.messages.push({
      id: this.nextId++,
      role: 'user',
      content: trimmed
    });
    this.isLoading = true;
    this.dotCount = 0;

    this.dotTimer = setInterval(() => {
      this.dotCount++;
    }, 500);

    let apiMessages: SiliconFlowMessage[] = [];

    if (this.systemPrompt.length > 0) {
      let sysMsg: SiliconFlowMessage = {
        role: 'system',
        content: this.systemPrompt
      };
      apiMessages.push(sysMsg);
    }

    for (let i = 0; i < this.messages.length; i++) {
      let msg = this.messages[i];
      let sfMsg: SiliconFlowMessage = {
        role: msg.role === 'user' ? 'user' : 'assistant',
        content: msg.content
      };
      apiMessages.push(sfMsg);
    }

    let reqBody: SiliconFlowReqBody = {
      model: AppConfig.AI_MODEL,
      messages: apiMessages,
      temperature: 0.7,
      max_tokens: 600,
      userId: this.currentAccountKey,
      accountKey: this.currentAccountKey,
      nickname: this.userNickname,
      bio: this.userBio
    };

    const endpoint = AppConfig.AI_CHAT_COMPLETIONS_PROXY_URL;

    const httpRequest = http.createHttp();
    httpRequest.request(
      endpoint,
      {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json'
        },
        extraData: JSON.stringify(reqBody),
        connectTimeout: 15000,
        readTimeout: 30000
      },
      (err, data) => {
        httpRequest.destroy();
        this.isLoading = false;
        if (this.dotTimer !== -1) {
          clearInterval(this.dotTimer);
          this.dotTimer = -1;
        }

        if (err || data.responseCode !== 200) {
          let errMsg = '网络请求失败，请重试。';
          if (data?.responseCode === 401) errMsg = 'API 密钥无效，请检查。';
          if (data?.responseCode === 403) errMsg = '该接口暂无访问权限。';
          this.messages.push({
            id: this.nextId++,
            role: 'assistant',
            content: errMsg
          });
          return;
        }

        try {
          const resp: SiliconFlowResponse = JSON.parse(data.result as string);

          if (!resp.choices || resp.choices.length === 0) {
            this.messages.push({
              id: this.nextId++,
              role: 'assistant',
              content: '未获取到有效解读数据，请稍后重试。'
            });
            return;
          }

          let aiText = resp.choices[0].message.content.trim();

          aiText = aiText.replace(/<think>[\s\S]*?<\/think>/g, '');
          aiText = aiText
            .replace(/\*\*(.*?)\*\*/g, '$1')
            .replace(/\*(.*?)\*/g, '$1')
            .replace(/`/g, '')
            .replace(/^#{1,6}\s+/gm, '')
            .replace(/^\s*-\s+/gm, '- ')
            .replace(/\n\s*\n/g, '\n\n')
            .trim();

          if (aiText.length === 0) {
            aiText = '暂未获得有效回复，请再试一次。';
          }

          this.messages.push({
            id: this.nextId++,
            role: 'assistant',
            content: aiText
          });
        } catch (e) {
          this.messages.push({
            id: this.nextId++,
            role: 'assistant',
            content: '数据解析失败，请重试。'
          });
        }
      }
    );
  }
}
