// utils/KeywordDetector.ets

export interface CrisisDetectionResult {
  isCrisis: boolean
  level: string  // 'none' | 'mild' | 'severe'
  matchedKeywords: string[]
}

export class KeywordDetector {
  // 严重危机关键词
  private static readonly SEVERE_KEYWORDS: string[] = [
    '自杀', '自残', '不想活', '结束生命', '跳楼', '割腕',
    '安眠药', '去死', '活着没意思', '世界没有我'
  ]

  // 轻度关注关键词
  private static readonly MILD_KEYWORDS: string[] = [
    '绝望', '崩溃', '撑不下去', '好累', '没有希望',
    '讨厌自己', '失眠', '焦虑', '抑郁'
  ]

  static detect(content: string): CrisisDetectionResult {
    const matchedSevere: string[] = []
    const matchedMild: string[] = []

    KeywordDetector.SEVERE_KEYWORDS.forEach((keyword: string) => {
      if (content.includes(keyword)) {
        matchedSevere.push(keyword)
      }
    })

    if (matchedSevere.length > 0) {
      const result: CrisisDetectionResult = {
        isCrisis: true,
        level: 'severe',
        matchedKeywords: matchedSevere
      }
      return result
    }

    KeywordDetector.MILD_KEYWORDS.forEach((keyword: string) => {
      if (content.includes(keyword)) {
        matchedMild.push(keyword)
      }
    })

    if (matchedMild.length >= 2) {
      const result: CrisisDetectionResult = {
        isCrisis: true,
        level: 'mild',
        matchedKeywords: matchedMild
      }
      return result
    }

    const result: CrisisDetectionResult = {
      isCrisis: false,
      level: 'none',
      matchedKeywords: []
    }
    return result
  }
}

// 心理援助信息
export interface CrisisHelpInfo {
  hotline: string
  name: string
  available: string
  message: string
}

export const CRISIS_HELP_INFO: CrisisHelpInfo = {
  hotline: '0371-67783291',
  name: '郑州大学心理健康教育中心',
  available: '24小时',
  message: '你很重要，你的感受值得被倾听。专业的帮助就在身边。'
}
