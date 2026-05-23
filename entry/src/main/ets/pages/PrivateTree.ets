// MainAbility/pages/PrivateTree.ets
// 私密花园 — 用花朵代替树叶，展示个人心事

import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import dataPreferences from '@ohos.data.preferences';

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
const GUEST_ACCOUNT_KEY: string = 'guest';

const TAG_COLORS: Record<string, string> = {
  '学业': '#6C9BD2', '情感': '#D4849A', '生活': '#7BB88A', '压力': '#D4A06A',
  '开心': '#D4C76A', '迷茫': '#A688C0', '目标': '#6ABCBC', '感恩': '#D48A6A'
};

// 花朵配色方案 - 根据标签
const FLOWER_COLORS: Record<string, string[]> = {
  '学业': ['#89B4E8', '#B8D4F0'],
  '情感': ['#E8A0B4', '#F0C8D4'],
  '生活': ['#8CCB9A', '#B8E0C4'],
  '压力': ['#E8B87A', '#F0D4A8'],
  '开心': ['#E8D87A', '#F0E8B0'],
  '迷茫': ['#B89CD4', '#D4C0E8'],
  '目标': ['#7AD4D4', '#A8E8E8'],
  '感恩': ['#E89A7A', '#F0C0A8']
};

const DEFAULT_FLOWER: string[] = ['#C4B0D4', '#DCD0E8'];

@Entry
@Component
struct PrivateTree {
  @State leaves: PrivateLeafData[] = [];
  @State selectedLeaf: PrivateLeafData | null = null;
  @State showDetail: boolean = false;
  @State showEditMode: boolean = false;
  @State editContent: string = '';
  @State editTags: string[] = [];
  @State isLoading: boolean = true;
  @State gardenScale: number = 1;
  @State todayCount: number = 0;
  @State allTags: string[] = ['学业', '情感', '生活', '压力', '开心', '迷茫', '目标', '感恩'];
  @State viewMode: string = 'garden'; // 'garden' | 'list'
  @StorageProp('currentAccountKey') currentAccountKey: string = '';

  private store: dataPreferences.Preferences | null = null;

  aboutToAppear(): void {
    this.loadLeaves();
  }

  private async getStore(): Promise<dataPreferences.Preferences> {
    if (this.store === null) {
      const ctx = getContext(this);
      this.store = await dataPreferences.getPreferences(ctx, STORE_NAME);
    }
    return this.store;
  }

  private getAccountKey(): string {
    return this.currentAccountKey.length > 0 ? this.currentAccountKey : GUEST_ACCOUNT_KEY;
  }

  private getScopedKey(baseKey: string): string {
    return `${baseKey}.${this.getAccountKey()}`;
  }

  private async getScopedValue(store: dataPreferences.Preferences, baseKey: string, defaultValue: string): Promise<string> {
    const scopedKey = this.getScopedKey(baseKey);
    const scopedData: dataPreferences.ValueType = await store.get(scopedKey, '');
    if (typeof scopedData === 'string' && scopedData.length > 0) {
      return scopedData;
    }

    const legacyData: dataPreferences.ValueType = await store.get(baseKey, '');
    if (typeof legacyData === 'string' && legacyData.length > 0) {
      await store.put(scopedKey, legacyData);
      await store.put(baseKey, '');
      await store.flush();
      return legacyData;
    }

    return defaultValue;
  }

  private getTagColor(tagName: string): string {
    return TAG_COLORS[tagName] || '#9E9E9E';
  }

  private getFlowerColors(leaf: PrivateLeafData): string[] {
    if (leaf.tags.length > 0) {
      return FLOWER_COLORS[leaf.tags[0]] || DEFAULT_FLOWER;
    }
    return DEFAULT_FLOWER;
  }

  private formatTime(timestamp: number): string {
    const diff: number = Date.now() - timestamp;
    if (diff < 60000) return '刚刚';
    if (diff < 3600000) return `${Math.floor(diff / 60000)}分钟前`;
    if (diff < 86400000) return `${Math.floor(diff / 3600000)}小时前`;
    const date: Date = new Date(timestamp);
    return `${date.getMonth() + 1}月${date.getDate()}日`;
  }

  private formatFullDate(timestamp: number): string {
    const d: Date = new Date(timestamp);
    const m: number = d.getMonth() + 1;
    const day: number = d.getDate();
    const h: string = d.getHours().toString().padStart(2, '0');
    const min: string = d.getMinutes().toString().padStart(2, '0');
    return `${m}月${day}日 ${h}:${min}`;
  }

  private async loadLeaves(): Promise<void> {
    this.isLoading = true;
    try {
      const store: dataPreferences.Preferences = await this.getStore();
      const data: string = await this.getScopedValue(store, LEAVES_KEY, '[]');
      this.leaves = JSON.parse(data) as PrivateLeafData[];
      this.calculateTodayCount();
    } catch (e) {
      console.error('PrivateGarden', 'Load failed');
    }
    this.isLoading = false;
  }

  private async saveLeaves(): Promise<void> {
    try {
      const store: dataPreferences.Preferences = await this.getStore();
      await store.put(this.getScopedKey(LEAVES_KEY), JSON.stringify(this.leaves));
      await store.flush();
    } catch (e) {
      console.error('PrivateGarden', 'Save failed');
    }
  }

  private calculateTodayCount(): void {
    const today: Date = new Date();
    today.setHours(0, 0, 0, 0);
    const todayStart: number = today.getTime();
    let count: number = 0;
    for (let i = 0; i < this.leaves.length; i++) {
      if (this.leaves[i].timestamp >= todayStart) {
        count++;
      }
    }
    this.todayCount = count;
  }

  private async toggleImportant(leafId: string): Promise<void> {
    let isNowImportant: boolean = false;
    const updated: PrivateLeafData[] = [];
    for (let i = 0; i < this.leaves.length; i++) {
      const leaf: PrivateLeafData = this.leaves[i];
      if (leaf.id === leafId) {
        const newLeaf: PrivateLeafData = {
          id: leaf.id, content: leaf.content, timestamp: leaf.timestamp,
          tags: leaf.tags, isImportant: !leaf.isImportant,
          aiResponse: leaf.aiResponse, position: leaf.position
        };
        isNowImportant = newLeaf.isImportant;
        updated.push(newLeaf);
      } else {
        updated.push(leaf);
      }
    }
    this.leaves = updated;
    await this.saveLeaves();
    promptAction.showToast({ message: isNowImportant ? '已标记为珍藏' : '取消珍藏' });
  }

  private async deleteLeaf(leafId: string): Promise<void> {
    const newLeaves: PrivateLeafData[] = [];
    for (let i = 0; i < this.leaves.length; i++) {
      if (this.leaves[i].id !== leafId) {
        newLeaves.push(this.leaves[i]);
      }
    }
    this.leaves = newLeaves;
    await this.saveLeaves();
    this.calculateTodayCount();
    this.showDetail = false;
    this.selectedLeaf = null;
    promptAction.showToast({ message: '已删除' });
  }

  private async updateLeaf(): Promise<void> {
    if (this.selectedLeaf === null || this.editContent.trim().length === 0) return;
    const selectedId: string = this.selectedLeaf.id;
    const updated: PrivateLeafData[] = [];
    for (let i = 0; i < this.leaves.length; i++) {
      const leaf: PrivateLeafData = this.leaves[i];
      if (leaf.id === selectedId) {
        const newLeaf: PrivateLeafData = {
          id: leaf.id, content: this.editContent.trim(), timestamp: leaf.timestamp,
          tags: [...this.editTags], isImportant: leaf.isImportant,
          aiResponse: leaf.aiResponse, position: leaf.position
        };
        updated.push(newLeaf);
      } else {
        updated.push(leaf);
      }
    }
    this.leaves = updated;
    await this.saveLeaves();
    this.showEditMode = false;
    this.showDetail = false;
    this.selectedLeaf = null;
    promptAction.showToast({ message: '已更新' });
  }

  private toggleEditTag(tagName: string): void {
    const index: number = this.editTags.indexOf(tagName);
    if (index >= 0) {
      const newTags: string[] = [];
      for (let i = 0; i < this.editTags.length; i++) {
        if (this.editTags[i] !== tagName) newTags.push(this.editTags[i]);
      }
      this.editTags = newTags;
    } else if (this.editTags.length < 3) {
      this.editTags = [...this.editTags, tagName];
    }
  }

  build() {
    Stack() {
      // 花园背景图片
      Image($rawfile('garden_bg.jpg'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)

      // 半透明遮罩层，让内容可读
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(246,243,238,0.3)')

      Column() {
        this.TopBar()
        this.StatsBar()

        if (this.isLoading) {
          this.LoadingView()
        } else if (this.leaves.length === 0) {
          this.EmptyView()
        } else {
          if (this.viewMode === 'garden') {
            this.GardenView()
          } else {
            this.ListView()
          }
        }
      }
      .width('100%')
      .height('100%')

      // 详情弹窗
      if (this.showDetail && this.selectedLeaf !== null) {
        if (this.showEditMode) {
          this.EditPanel()
        } else {
          this.DetailPanel()
        }
      }
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
        .position({ x: 14, y: 58 })

      Blank()

      Column({ space: 2 }) {
        Text('私密花园')
          .fontSize(18)
          .fontWeight(600)
          .fontColor('#3D3832')

        Text('长按花朵珍藏')
          .fontSize(10)
          .fontColor('#8A8480')
      }
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .borderRadius(12)
      .backgroundColor('rgba(255,255,255,0.5)')
      .backdropBlur(8)

      Blank()

      // 切换视图
      Column()
        .width(40)
        .height(40)
        .borderRadius(20)
        .backgroundColor('rgba(255,255,255,0.7)')
        .backdropBlur(12)
        .onClick(() => {
          this.viewMode = this.viewMode === 'garden' ? 'list' : 'garden';
        })

      Text(this.viewMode === 'garden' ? '=' : '#')
        .fontSize(16)
        .fontColor('#5A5550')
        .position({ x: '87%', y: 58 })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 52, bottom: 8 })
  }

  @Builder
  StatsBar() {
    Row() {
      // 今日
      Row({ space: 6 }) {
        Column()
          .width(8)
          .height(8)
          .borderRadius(4)
          .backgroundColor('#D4849A')

        Text(`今日 ${this.todayCount}`)
          .fontSize(12)
          .fontColor('#6B6560')
      }

      // 全部
      Row({ space: 6 }) {
        Column()
          .width(8)
          .height(8)
          .borderRadius(4)
          .backgroundColor('#7BB88A')

        Text(`共 ${this.leaves.length} 朵`)
          .fontSize(12)
          .fontColor('#6B6560')
      }
      .margin({ left: 20 })

      Blank()

      // 珍藏数
      Text(`珍藏 ${this.leaves.filter((l: PrivateLeafData) => l.isImportant).length}`)
        .fontSize(12)
        .fontColor('#8A8480')
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 10, bottom: 10 })
    .backgroundColor('rgba(255,255,255,0.45)')
    .backdropBlur(8)
    .borderRadius(12)
    .margin({ left: 12, right: 12 })
  }

  @Builder
  LoadingView() {
    Column({ space: 16 }) {
      LoadingProgress()
        .width(40)
        .height(40)
        .color('#C4B0A0')

      Text('花园正在苏醒...')
        .fontSize(14)
        .fontColor('#B0AAA2')
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  EmptyView() {
    Column({ space: 16 }) {
      Text('🪴')
        .fontSize(72)

      Text('你的花园还空空的')
        .fontSize(17)
        .fontWeight(500)
        .fontColor('#6B6560')
        .margin({ top: 12 })

      Text('写下第一个心事，种下一朵花')
        .fontSize(13)
        .fontColor('#A09A92')

      Row() {
        Text('写下心事')
          .fontSize(14)
          .fontColor('#FFFFFF')
      }
      .height(44)
      .padding({ left: 28, right: 28 })
      .backgroundColor('#4CAF50')
      .borderRadius(22)
      .justifyContent(FlexAlign.Center)
      .margin({ top: 16 })
      .onClick(() => {
        router.pushUrl({ url: 'pages/PrivateWrite' });
      })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  GardenView() {
    Scroll() {
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
        ForEach(this.leaves, (leaf: PrivateLeafData) => {
          this.FlowerItem(leaf)
        }, (leaf: PrivateLeafData) => leaf.id)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 20, bottom: 40 })
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  FlowerItem(leaf: PrivateLeafData) {
    Stack({ alignContent: Alignment.Center }) {
      // 五瓣花瓣
      ForEach([0, 72, 144, 216, 288], (angle: number) => {
        Circle()
          .width(leaf.isImportant ? 32 : 24)
          .height(leaf.isImportant ? 32 : 24)
          .fill(this.getFlowerColors(leaf)[0])
          .opacity(0.35)
          .offset({
            x: Math.cos(angle * Math.PI / 180) * (leaf.isImportant ? 20 : 15),
            y: Math.sin(angle * Math.PI / 180) * (leaf.isImportant ? 20 : 15)
          })
      }, (angle: number) => angle.toString())

      // 花蕊
      Circle()
        .width(leaf.isImportant ? 24 : 18)
        .height(leaf.isImportant ? 24 : 18)
        .fill(this.getFlowerColors(leaf)[1])
        .shadow({ radius: 6, color: 'rgba(0,0,0,0.08)', offsetY: 1 })

      if (leaf.isImportant) {
        Circle()
          .width(10)
          .height(10)
          .fill('#FFF9D0')
          .opacity(0.9)
      }
    }
    .width(leaf.isImportant ? 90 : 70)
    .height(leaf.isImportant ? 90 : 70)
    .margin(6)
    .onClick(() => {
      this.selectedLeaf = leaf;
      this.showDetail = true;
      this.showEditMode = false;
    })
    .gesture(
      LongPressGesture()
        .onAction(() => {
          this.toggleImportant(leaf.id);
        })
    )
  }

  @Builder
  ListView() {
    Scroll() {
      Column({ space: 8 }) {
        ForEach(this.leaves, (leaf: PrivateLeafData) => {
          this.FlowerCard(leaf)
        }, (leaf: PrivateLeafData) => leaf.id)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 8, bottom: 20 })
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Off)
  }

  @Builder
  FlowerCard(leaf: PrivateLeafData) {
    Row() {
      // 记录小图标
      Row() {
        Stack({ alignContent: Alignment.Center }) {
          // 小花瓣图标
          ForEach([0, 120, 240], (angle: number) => {
            Circle()
              .width(14)
              .height(14)
              .fill(this.getFlowerColors(leaf)[0])
              .opacity(0.4)
              .offset({
                x: Math.cos(angle * Math.PI / 180) * 8,
                y: Math.sin(angle * Math.PI / 180) * 8
              })
          }, (angle: number) => angle.toString())
          
          Circle()
            .width(10)
            .height(10)
            .fill(this.getFlowerColors(leaf)[1])
        }
      }
      .width(38)
      .height(38)
      .justifyContent(FlexAlign.Center)

      Column({ space: 4 }) {
        Text(leaf.content)
          .fontSize(14)
          .fontColor('#3D3832')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .lineHeight(20)

        Row({ space: 6 }) {
          if (leaf.tags.length > 0) {
            ForEach(leaf.tags.slice(0, 2), (tag: string) => {
              Text(tag)
                .fontSize(10)
                .fontColor(this.getTagColor(tag))
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .backgroundColor(this.getTagColor(tag) + '18')
                .borderRadius(6)
            }, (tag: string) => tag)
          }

          Text(this.formatTime(leaf.timestamp))
            .fontSize(10)
            .fontColor('#B0AAA2')
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })

      if (leaf.isImportant) {
        Column()
          .width(6)
          .height(6)
          .borderRadius(3)
          .backgroundColor('#E8C864')
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor('rgba(255,255,255,0.85)')
    .backdropBlur(12)
    .borderRadius(16)
    .shadow({
      radius: 12,
      color: 'rgba(0,0,0,0.06)',
      offsetY: 3
    })
    .onClick(() => {
      this.selectedLeaf = leaf;
      this.showDetail = true;
      this.showEditMode = false;
    })
    .gesture(
      LongPressGesture()
        .onAction(() => {
          this.toggleImportant(leaf.id);
        })
    )
  }

  @Builder
  DetailPanel() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.3)')
        .onClick(() => {
          this.showDetail = false;
          this.selectedLeaf = null;
        })

      Column({ space: 16 }) {
        if (this.selectedLeaf !== null) {
          // 顶部花朵 + 时间
          Row() {
            Stack() {
              Circle()
                .width(36)
                .height(36)
                .fill(this.getFlowerColors(this.selectedLeaf)[0])
                .opacity(0.5)
              Circle()
                .width(22)
                .height(22)
                .fill(this.getFlowerColors(this.selectedLeaf)[1])
                .opacity(0.8)
              Circle()
                .width(10)
                .height(10)
                .fill(this.selectedLeaf.isImportant ? '#F0E6A0' : '#F0E8D8')
            }
            .width(40)
            .height(40)

            Column({ space: 2 }) {
              Row({ space: 6 }) {
                if (this.selectedLeaf.tags.length > 0) {
                  ForEach(this.selectedLeaf.tags, (tag: string) => {
                    Text(tag)
                      .fontSize(11)
                      .fontColor(this.getTagColor(tag))
                      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                      .backgroundColor(this.getTagColor(tag) + '18')
                      .borderRadius(8)
                  }, (tag: string) => tag)
                } else {
                  Text('私密心事')
                    .fontSize(12)
                    .fontColor('#C4A882')
                }
              }

              Text(this.formatFullDate(this.selectedLeaf.timestamp))
                .fontSize(11)
                .fontColor('#B0AAA2')
            }
            .alignItems(HorizontalAlign.Start)
            .margin({ left: 10 })

            Blank()

            if (this.selectedLeaf.isImportant) {
              Text('珍藏')
                .fontSize(11)
                .fontColor('#C4A060')
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .backgroundColor('#F8F0D8')
                .borderRadius(8)
            }
          }
          .width('100%')

          // 内容
          Scroll() {
            Text(this.selectedLeaf.content)
              .fontSize(15)
              .fontColor('#3D3832')
              .lineHeight(26)
              .width('100%')
          }
          .width('100%')
          .constraintSize({ maxHeight: 160 })
          .scrollBar(BarState.Off)

          // AI 回复
          if (this.selectedLeaf.aiResponse.length > 0) {
            Column({ space: 6 }) {
              Text('花园的回应')
                .fontSize(11)
                .fontColor('#C4A882')

              Text(this.selectedLeaf.aiResponse)
                .fontSize(13)
                .fontColor('#6B6560')
                .lineHeight(22)
            }
            .width('100%')
            .padding(14)
            .backgroundColor('#FAF6F0')
            .borderRadius(12)
            .alignItems(HorizontalAlign.Start)
          }

          // 操作按钮
          Row({ space: 10 }) {
            Button(this.selectedLeaf.isImportant ? '取消珍藏' : '珍藏')
              .layoutWeight(1)
              .height(42)
              .fontSize(13)
              .backgroundColor(this.selectedLeaf.isImportant ? '#F0ECE6' : '#FAF0E0')
              .fontColor(this.selectedLeaf.isImportant ? '#8A8480' : '#C4A060')
              .borderRadius(21)
              .onClick(() => {
                if (this.selectedLeaf !== null) {
                  this.toggleImportant(this.selectedLeaf.id);
                  this.showDetail = false;
                  this.selectedLeaf = null;
                }
              })

            Button('编辑')
              .width(60)
              .height(42)
              .fontSize(13)
              .backgroundColor('#EDE8E0')
              .fontColor('#6B6560')
              .borderRadius(21)
              .onClick(() => {
                if (this.selectedLeaf !== null) {
                  this.editContent = this.selectedLeaf.content;
                  this.editTags = [...this.selectedLeaf.tags];
                  this.showEditMode = true;
                }
              })

            Button('删除')
              .width(60)
              .height(42)
              .fontSize(13)
              .backgroundColor('#F8ECEC')
              .fontColor('#C88080')
              .borderRadius(21)
              .onClick(() => {
                if (this.selectedLeaf !== null) {
                  const leafId: string = this.selectedLeaf.id;
                  promptAction.showDialog({
                    title: '删除',
                    message: '确定要移除这朵花吗？',
                    buttons: [
                      { text: '取消', color: '#8A8480' },
                      { text: '删除', color: '#C88080' }
                    ]
                  }).then((result: promptAction.ShowDialogSuccessResponse) => {
                    if (result.index === 1) {
                      this.deleteLeaf(leafId);
                    }
                  });
                }
              })
          }
          .width('100%')
        }
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 24, bottom: 32 })
      .backgroundColor('#FFFFFF')
      .borderRadius({ topLeft: 24, topRight: 24 })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  EditPanel() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.3)')
        .onClick(() => {
          this.showEditMode = false;
          this.showDetail = false;
        })

      Column({ space: 14 }) {
        Text('编辑')
          .fontSize(16)
          .fontWeight(600)
          .fontColor('#3D3832')
          .alignSelf(ItemAlign.Start)

        TextArea({ text: this.editContent })
          .fontSize(14)
          .fontColor('#3D3832')
          .backgroundColor('#F6F3EE')
          .borderRadius(14)
          .height(100)
          .maxLength(500)
          .onChange((value: string) => {
            this.editContent = value;
          })

        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(this.allTags, (tag: string) => {
            Text(tag)
              .fontSize(12)
              .fontColor(this.editTags.includes(tag) ? '#FFFFFF' : this.getTagColor(tag))
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .backgroundColor(this.editTags.includes(tag) ? this.getTagColor(tag) : this.getTagColor(tag) + '18')
              .borderRadius(14)
              .margin({ right: 8, bottom: 8 })
              .onClick(() => {
                this.toggleEditTag(tag);
              })
          }, (tag: string) => tag)
        }
        .width('100%')

        Row({ space: 12 }) {
          Button('取消')
            .layoutWeight(1)
            .height(44)
            .fontSize(14)
            .backgroundColor('#F0ECE6')
            .fontColor('#6B6560')
            .borderRadius(22)
            .onClick(() => {
              this.showEditMode = false;
            })

          Button('保存')
            .layoutWeight(1)
            .height(44)
            .fontSize(14)
            .backgroundColor('#C4A882')
            .fontColor('#FFFFFF')
            .borderRadius(22)
            .onClick(() => {
              this.updateLeaf();
            })
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 24, bottom: 32 })
      .backgroundColor('#FFFFFF')
      .borderRadius({ topLeft: 24, topRight: 24 })
    }
    .width('100%')
    .height('100%')
  }
}
