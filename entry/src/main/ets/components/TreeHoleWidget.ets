import { ColorConstants } from '../utils/ColorConstants';
import { ZzuNetwork } from '../utils/ZzuNetwork';

@Component
export struct TreeHoleWidget {
  @State inputText: string = '';
  @State isZzuMode: boolean = false;
  onConfirm: (text: string) => void = (text: string): void => {};

  async aboutToAppear() {
    // 接入环境探针
    let result = await ZzuNetwork.verifyCampusNetwork();
    this.isZzuMode = result.isZzu;
  }

  build() {
    Column() {
      if (this.isZzuMode) {
        Row() {
          Text('🏫 ZZUer 的专属树洞')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFD93D') 
        }
        .width('90%')
        .margin({ bottom: 8 })
      }

      TextArea({ 
        placeholder: this.isZzuMode 
          ? '眉湖的微风吹散了疲惫，今天在郑大有什么想倾诉的吗...' 
          : '深夜了，写下你的杂念...', 
        text: this.inputText 
      })
        .width('90%')
        .height(180)
        .backgroundColor(ColorConstants.SURFACE_GLASS)
        .fontColor(ColorConstants.TEXT_PRIMARY)
        .placeholderColor(ColorConstants.PLACEHOLDER)
        .borderRadius(24)
        .padding(20)
        .onChange((value: string): void => {
          this.inputText = value;
        })
      
      if (this.inputText.length > 0) {
        Button(this.isZzuMode ? '种下一颗 ZZUer 的种子' : '凝结为一颗种子')
          .backgroundColor(ColorConstants.MINT_CYAN)
          .fontColor(ColorConstants.BACKGROUND_DARK)
          .fontWeight(FontWeight.Bold)
          .height(44)
          .borderRadius(22)
          .shadow({ radius: 10, color: 'rgba(0, 240, 255, 0.2)' })
          .margin({ top: 16 })
          .onClick((): void => {
            if (this.inputText.trim().length > 0) {
              this.onConfirm(this.inputText);
              this.inputText = ''; 
            }
          })
          .animation({ duration: 300, curve: Curve.EaseOut })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }
}
