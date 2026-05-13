// MainAbility/pages/PrivateWrite.ets
// 私密花园 - 写下心事，种一朵花

import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import dataPreferences from '@ohos.data.preferences';
import { AIResponseGenerator } from '../utils/AIResponseGenerator';

interface LeafPosition {
  x: number;
  y: number;
  angle: number;
  scale: number;
}

interface PrivateLeafData {
  id: string;
  content: string;
  timestamp: number;
  tags: string[];
  isImportant: boolean;
  aiResponse: string;
  position: LeafPosition;
}

const STORE_NAME: string = 'private_garden_store';
const LEAVES_KEY: string = 'private_leaves';
const CUSTOM_TAGS_KEY: string = 'custom_tags';

const PRESET_TAGS: string[] = ['学业', '情感', '生活', '压力', '开心', '迷茫', '目标', '感恩'];

const TAG_COLORS: Record<string, string> = {
  '学业': '#6C9BD2', '情感': '#D4849A', '生活': '#7BB88A', '压力': '#D4A06A',
  '开心': '#D4C76A', '迷茫': '#A688C0', '目标': '#6ABCBC', '感恩': '#D48A6A'
};

@Entry
@Component
struct PrivateWrite {
  @State inputContent: string = '';
  @State selectedTags: string[] = [];
  @State customTags: string[] = [];
  @State allTags: string[] = PRESET_TAGS;
  @State newTagInput: string = '';
  @State showAddTag: boolean = false;
  @State aiResponse: string = '';
  @State showAIResponse: boolean = false;
  @State isSubmitting: boolean = false;

  private store: dataPreferences.Preferences | null = null;

  aboutToAppear(): void {
    this.loadCustomTags();
  }

  private async getStore(): Promise<dataPreferences.Preferences> {
    if (this.store === null) {
      const ctx = getContext(this);
      this.store = await dataPreferences.getPreferences(ctx, STORE_NAME);
    }
    return this.store;
  }

  private getTagColor(tagName: string): string {
    const color: string | undefined = TAG_COLORS[tagName];
    if (color) return color;
    let hash: number = 0;
    for (let i = 0; i < tagName.length; i++) {
      hash = tagName.charCodeAt(i) + ((hash << 5) - hash);
    }
    return `hsl(${Math.abs(hash % 360)}, 45%, 60%)`;
  }

  private generateId(): string {
    return `leaf_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
  }

  private generatePosition(): LeafPosition {
    return {
      x: 0.1 + Math.random() * 0.8,
      y: 0.1 + Math.random() * 0.6,
      angle: -30 + Math.random() * 60,
      scale: 0.7 + Math.random() * 0.4
    };
  }

  private async loadCustomTags(): Promise<void> {
    try {
      const store: dataPreferences.Preferences = await this.getStore();
      const data: dataPreferences.ValueType = await store.get(CUSTOM_TAGS_KEY, '[]');
      if (typeof data === 'string') {
        this.customTags = JSON.parse(data) as string[];
        this.allTags = [...PRESET_TAGS, ...this.customTags];
      }
    } catch (e) {
      console.error('PrivateWrite', 'Load tags failed');
    }
  }

  private async saveCustomTags(): Promise<void> {
    try {
      const store: dataPreferences.Preferences = await this.getStore();
      await store.put(CUSTOM_TAGS_KEY, JSON.stringify(this.customTags));
      await store.flush();
    } catch (e) {
      console.error('PrivateWrite', 'Save tags failed');
    }
  }

  private addCustomTag(): void {
    const tag: string = this.newTagInput.trim();
    if (tag.length === 0) {
      promptAction.showToast({ message: '标签不能为空' });
      return;
    }
    if (tag.length > 6) {
      promptAction.showToast({ message: '标签最多6个字' });
      return;
    }
    if (this.allTags.includes(tag)) {
      promptAction.showToast({ message: '标签已存在' });
      return;
    }

    this.customTags = [...this.customTags, tag];
    this.allTags = [...PRESET_TAGS, ...this.customTags];
    this.saveCustomTags();
    this.newTagInput = '';
    this.showAddTag = false;
  }

  private toggleTag(tagName: string): void {
    const index: number = this.selectedTags.indexOf(tagName);
    if (index >= 0) {
      const newTags: string[] = [];
      for (let i = 0; i < this.selectedTags.length; i++) {
        if (this.selectedTags[i] !== tagName) {
          newTags.push(this.selectedTags[i]);
        }
      }
      this.selectedTags = newTags;
    } else if (this.selectedTags.length < 3) {
      this.selectedTags = [...this.selectedTags, tagName];
    } else {
      promptAction.showToast({ message: '最多选择3个标签' });
    }
  }

  private async submitLeaf(): Promise<void> {
    if (this.inputContent.trim().length === 0 || this.isSubmitting) {
      return;
    }

    this.isSubmitting = true;
    const aiRes: string = AIResponseGenerator.generate(this.inputContent);

    const newLeaf: PrivateLeafData = {
      id: this.generateId(),
      content: this.inputContent.trim(),
      timestamp: Date.now(),
      tags: [...this.selectedTags],
      isImportant: false,
      aiResponse: aiRes,
      position: this.generatePosition()
    };

    try {
      const store: dataPreferences.Preferences = await this.getStore();
      const data: dataPreferences.ValueType = await store.get(LEAVES_KEY, '[]');
      let leaves: PrivateLeafData[] = [];
      if (typeof data === 'string') {
        leaves = JSON.parse(data) as PrivateLeafData[];
      }
      leaves = [newLeaf, ...leaves];
      await store.put(LEAVES_KEY, JSON.stringify(leaves));
      await store.flush();

      this.aiResponse = aiRes;
      this.showAIResponse = true;
      this.inputContent = '';
      this.selectedTags = [];

      promptAction.showToast({ message: '花朵已种下' });
    } catch (e) {
      promptAction.showToast({ message: '保存失败' });
    }

    this.isSubmitting = false;
  }

  build() {
    Stack() {
      // 花园背景图片
      Image($rawfile('garden_bg.jpg'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)

      // 半透明遮罩
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(246,243,238,0.35)')

      Column() {
        // 顶部
        this.TopBar()

        // AI回复
        if (this.showAIResponse) {
          this.AIResponseCard()
        }

        // 内容区
        Scroll() {
          Column({ space: 16 }) {
            // 引导语
            Column({ space: 6 }) {
              Text('写下你的心事')
                .fontSize(22)
                .fontWeight(600)
                .fontColor('#3D3832')

              Text('这里只属于你，每一朵花都是你的故事')
                .fontSize(13)
                .fontColor('#B0AAA2')
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .margin({ top: 12 })

            // 输入区
            Column() {
              TextArea({ placeholder: '今天有什么想说的吗？', text: this.inputContent })
                .fontSize(15)
                .fontColor('#3D3832')
                .placeholderColor('#C4BFBA')
                .backgroundColor(Color.Transparent)
                .height(180)
                .maxLength(500)
                .onChange((value: string) => {
                  this.inputContent = value;
                })

              Text(`${this.inputContent.length}/500`)
                .fontSize(11)
                .fontColor('#C4BFBA')
                .alignSelf(ItemAlign.End)
                .margin({ right: 14, bottom: 10 })
            }
            .width('100%')
            .backgroundColor('rgba(255,255,255,0.85)')
            .backdropBlur(16)
            .borderRadius(16)
            .shadow({
              radius: 12,
              color: 'rgba(0,0,0,0.06)',
              offsetY: 3
            })

            // 标签选择
            Column({ space: 12 }) {
              Row() {
                Text('选择标签')
                  .fontSize(13)
                  .fontColor('#8A8480')

                Text('（可选，最多3个）')
                  .fontSize(11)
                  .fontColor('#C4BFBA')

                Blank()

                Text('+ 自定义')
                  .fontSize(12)
                  .fontColor('#C4A882')
                  .onClick(() => {
                    this.showAddTag = !this.showAddTag;
                  })
              }
              .width('100%')

              if (this.showAddTag) {
                Row({ space: 10 }) {
                  TextInput({ placeholder: '标签名', text: this.newTagInput })
                    .fontSize(14)
                    .maxLength(6)
                    .backgroundColor('#FFFFFF')
                    .fontColor('#3D3832')
                    .borderRadius(12)
                    .height(40)
                    .layoutWeight(1)
                    .onChange((value: string) => {
                      this.newTagInput = value;
                    })

                  Button('添加')
                    .fontSize(13)
                    .height(40)
                    .backgroundColor('#C4A882')
                    .fontColor('#FFFFFF')
                    .borderRadius(12)
                    .onClick(() => {
                      this.addCustomTag();
                    })
                }
                .width('100%')
              }

              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.allTags, (tagName: string) => {
                  Text(tagName)
                    .fontSize(13)
                    .fontColor(this.selectedTags.includes(tagName) ? '#FFFFFF' : this.getTagColor(tagName))
                    .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                    .backgroundColor(this.selectedTags.includes(tagName)
                      ? this.getTagColor(tagName)
                      : this.getTagColor(tagName) + '18')
                    .borderRadius(16)
                    .margin({ right: 10, bottom: 10 })
                    .onClick(() => {
                      this.toggleTag(tagName);
                    })
                }, (tagName: string) => tagName)
              }
              .width('100%')
            }
            .width('100%')
            .padding(16)
            .backgroundColor('rgba(255,255,255,0.85)')
            .backdropBlur(16)
            .borderRadius(16)
            .shadow({
              radius: 12,
              color: 'rgba(0,0,0,0.06)',
              offsetY: 3
            })
          }
          .width('100%')
          .padding({ left: 24, right: 24, bottom: 120 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')

      // 提交按钮
      Row() {
        Text('种下这朵花')
          .fontSize(16)
          .fontWeight(500)
          .fontColor('#FFFFFF')
      }
      .width('80%')
      .height(50)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(this.inputContent.trim().length > 0 ? '#C4A882' : '#D8D0C6')
      .borderRadius(25)
      .shadow({
        radius: 16,
        color: this.inputContent.trim().length > 0 ? 'rgba(196,168,130,0.3)' : 'transparent',
        offsetY: 4
      })
      .position({ x: '10%', y: '88%' })
      .onClick(() => {
        if (this.inputContent.trim().length > 0 && !this.isSubmitting) {
          this.submitLeaf();
        }
      })
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  @Builder
  TopBar() {
    Row() {
      Column()
        .width(40)
        .height(40)
        .borderRadius(20)
        .backgroundColor('rgba(255,255,255,0.7)')
        .backdropBlur(12)
        .onClick(() => { router.back(); })

      Text('<')
        .fontSize(18)
        .fontColor('#5A5550')
        .position({ x: 38, y: 58 })

      Blank()

      Text('写下心事')
        .fontSize(17)
        .fontWeight(600)
        .fontColor('#3D3832')

      Blank()

      Column()
        .width(40)
        .height(40)
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 52, bottom: 8 })
  }

  @Builder
  AIResponseCard() {
    Column({ space: 10 }) {
      Text('花园的回应')
        .fontSize(13)
        .fontWeight(500)
        .fontColor('#C4A882')

      Text(this.aiResponse)
        .fontSize(14)
        .fontColor('#6B6560')
        .lineHeight(24)

      Text('点击关闭')
        .fontSize(11)
        .fontColor('#C4BFBA')
    }
    .width('88%')
    .padding(18)
    .margin({ top: 12 })
    .backgroundColor('rgba(255,255,255,0.88)')
    .backdropBlur(16)
    .borderRadius(16)
    .shadow({
      radius: 12,
      color: 'rgba(0,0,0,0.06)',
      offsetY: 3
    })
    .alignSelf(ItemAlign.Center)
    .onClick(() => {
      this.showAIResponse = false;
    })
  }
}
