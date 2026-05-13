export interface EchoTask {
  id?: number;
  seed_id?: number | null; // 可以为空，如果不为空则表示来源于某颗种子
  action: string;
  is_completed: boolean;
  completed_at?: number | null;
  created_at: number;
}
