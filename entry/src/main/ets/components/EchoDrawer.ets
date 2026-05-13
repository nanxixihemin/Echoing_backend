import { ColorConstants } from '../utils/ColorConstants';
import { EchoTask } from '../models/EchoTask';

@Component
export struct EchoDrawer {
  @Link tasks: EchoTask[];
  onCompleteTask: (task: EchoTask) => void = (task: EchoTask): void => {};

  build() {
    Column() {
      // 抽屉把手
      Row()
        .width(40)
        .height(4)
        .backgroundColor(ColorConstants.BORDER_COLOR)
        .borderRadius(2)
        .margin({ top: 12, bottom: 20 })

      Text('🪐 回声墙 (Echoes)')
        .fontColor(ColorConstants.MINT_CYAN)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 16 })

      List({ space: 12 }) {
        ForEach(this.tasks, (task: EchoTask) => {
          ListItem() {
            Row() {
              Checkbox()
                .select(task.is_completed)
                .selectedColor(ColorConstants.MINT_CYAN)
                .onChange((value: boolean): void => {
                  if (value) {
                    this.onCompleteTask(task);
                  }
                })
              
              Column() {
                if (task.seed_id) {
                  Text(`🔗 来源种子 #${task.seed_id}`)
                    .fontSize(10)
                    .fontColor(ColorConstants.MINT_CYAN_DIM)
                    .margin({ bottom: 4 })
                }
                Text(task.action)
                  .fontColor(ColorConstants.TEXT_PRIMARY)
                  .fontSize(14)
              }
              .alignItems(HorizontalAlign.Start)
              .margin({ left: 12 })
            }
            .width('100%')
            .padding(16)
            .backgroundColor(ColorConstants.SURFACE_CARD)
            .borderRadius(12)
          }
        }, (task: EchoTask, index: number) => task.id ? task.id.toString() : index.toString())
      }
      .width('90%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorConstants.BACKGROUND_DARK)
    .borderRadius({ topLeft: 32, topRight: 32 })
    .alignItems(HorizontalAlign.Center)
  }
}
