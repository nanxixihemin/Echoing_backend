// utils/AIResponseGenerator.ets

export class AIResponseGenerator {
  private static empathyMap: Map<string, string[]> = new Map([
    ['批评', [
      '被批评的感觉一定很难受吧。但愿意反思的你，已经比很多人勇敢了。🌱',
      '听到批评会难过是很正常的。给自己一个拥抱，你已经很努力了。💚',
      '批评不代表否定你这个人。休息一下，明天又是新的开始。🌿'
    ]],
    ['失败', [
      '觉得失败的时候最难熬。但每一次跌倒，都是在学习如何站起来。🌱',
      '失败只是暂时的，你的价值不由一次结果定义。相信自己。💪',
      '允许自己难过一会儿。然后记住，这只是人生的一小段路。🛤️'
    ]],
    ['累', [
      '听起来你真的很累了。累了就休息，不必一直逞强。🌙',
      '你已经承受了很多。今晚早点睡，让身体和心都歇一歇。💚',
      '疲惫是身体在提醒你：该对自己好一点了。🌿'
    ]],
    ['孤独', [
      '感到孤独的时候，记得这棵树一直在这里陪着你。🌳',
      '孤独是很多人都有的感受。你不是一个人在经历这些。💚',
      '有时候独处也是一种力量。但如果想说话，随时来这里。🌱'
    ]],
    ['焦虑', [
      '焦虑的感觉很不好受。试着深呼吸，一切都会慢慢好起来的。🍃',
      '未来的事交给未来的自己。现在，先照顾好此刻的你。💚',
      '焦虑说明你在乎。但记得，你已经在努力了，这就够了。🌱'
    ]],
    ['难过', [
      '难过的时候，允许自己哭一哭。眼泪也是一种释放。💧',
      '你的难过是真实的，不需要假装坚强。🌿',
      '难过会过去的，就像云会散开一样。☁️'
    ]],
    ['压力', [
      '压力大的时候，记得给自己喘息的空间。🌬️',
      '你不需要一个人扛下所有。适当求助也是智慧。💚',
      '压力是暂时的，你的能力是持久的。相信自己。🌱'
    ]]
  ]);

  private static defaultResponses: string[] = [
    '谢谢你愿意说出来。把心事挂在树上，让风带走一些重量。🍃',
    '你的感受很重要。这棵树会一直在这里，静静陪着你。🌳',
    '说出来就是勇敢的第一步。希望你今天能对自己温柔一点。💚',
    '每一片叶子都承载着故事。你的故事，值得被温柔对待。🌿',
    '不管发生什么，你都值得被爱和被理解。🌱',
    '今天辛苦了。明天又是新的一天。🌅'
  ];

  static generate(content: string): string {
    // 遍历关键词匹配
    const keys: string[] = ['批评', '失败', '累', '孤独', '焦虑', '难过', '压力'];

    for (let i = 0; i < keys.length; i++) {
      const keyword: string = keys[i];
      if (content.includes(keyword)) {
        const responses: string[] | undefined = AIResponseGenerator.empathyMap.get(keyword);
        if (responses !== undefined && responses.length > 0) {
          const index: number = Math.floor(Math.random() * responses.length);
          return responses[index];
        }
      }
    }

    // 默认回复
    const index: number = Math.floor(Math.random() * AIResponseGenerator.defaultResponses.length);
    return AIResponseGenerator.defaultResponses[index];
  }
}
