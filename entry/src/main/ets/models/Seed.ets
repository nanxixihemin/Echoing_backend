export interface Seed {
  id?: number;
  account_key?: string;
  content: string;
  source: 'TREE_HOLE' | 'TAROT' | 'SPINNER' | 'CHOICE' | 'INTROSPECTION';
  state: number; // 0=未转化(沉睡), 1=已转化为待办
  created_at: number;
}
