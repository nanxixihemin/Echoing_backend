import relationalStore from '@ohos.data.relationalStore';
import common from '@ohos.app.ability.common';
import { Seed } from '../models/Seed';
import { EchoTask } from '../models/EchoTask';

const STORE_CONFIG: relationalStore.StoreConfig = {
  name: 'EchoingCore.db',
  securityLevel: relationalStore.SecurityLevel.S1
};

export class DatabaseService {
  private rdbStore: relationalStore.RdbStore | null = null;
  private context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  // 初始化数据库及建表
  async init(): Promise<void> {
    try {
      this.rdbStore = await relationalStore.getRdbStore(this.context, STORE_CONFIG);

      // 创建心念种子表
      const SQL_CREATE_SEED_TABLE = `
        CREATE TABLE IF NOT EXISTS seed (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          content TEXT NOT NULL,
          source TEXT NOT NULL,
          state INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL
        )
      `;

      // 创建回声待办表
      const SQL_CREATE_TASK_TABLE = `
        CREATE TABLE IF NOT EXISTS echo_task (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          seed_id INTEGER,
          action TEXT NOT NULL,
          is_completed INTEGER NOT NULL DEFAULT 0,
          completed_at INTEGER,
          created_at INTEGER NOT NULL,
          FOREIGN KEY(seed_id) REFERENCES seed(id)
        )
      `;

      await this.rdbStore.executeSql(SQL_CREATE_SEED_TABLE);
      await this.rdbStore.executeSql(SQL_CREATE_TASK_TABLE);
      console.info('[Echoing] Database initialized successfully.');
    } catch (err) {
      console.error(`[Echoing] Database init failed. Code: ${err.code}, message: ${err.message}`);
    }
  }

  // 插入一颗种子
  async insertSeed(seed: Seed): Promise<number> {
    if (!this.rdbStore) return -1;
    const valueBucket: relationalStore.ValuesBucket = {
      'content': seed.content,
      'source': seed.source,
      'state': seed.state,
      'created_at': seed.created_at
    };
    return await this.rdbStore.insert('seed', valueBucket);
  }

  // 插入一个回声待办 (可关联Seed)
  async insertTask(task: EchoTask): Promise<number> {
    if (!this.rdbStore) return -1;
    const valueBucket: relationalStore.ValuesBucket = {
      'seed_id': task.seed_id ? task.seed_id : null,
      'action': task.action,
      'is_completed': task.is_completed ? 1 : 0,
      'completed_at': task.completed_at ? task.completed_at : null,
      'created_at': task.created_at
    };
    return await this.rdbStore.insert('echo_task', valueBucket);
  }

  async markTaskCompleted(taskId: number, completedAt: number): Promise<boolean> {
    if (!this.rdbStore) return false;
    const valueBucket: relationalStore.ValuesBucket = {
      'is_completed': 1,
      'completed_at': completedAt
    };
    let predicates = new relationalStore.RdbPredicates('echo_task');
    predicates.equalTo('id', taskId);
    const updatedRows = await this.rdbStore.update(valueBucket, predicates);
    return updatedRows > 0;
  }

  // 获取所有未完成的任务，以便展示在首页抽屉
  async getPendingTasks(): Promise<EchoTask[]> {
    if (!this.rdbStore) return [];
    let predicates = new relationalStore.RdbPredicates('echo_task');
    predicates.equalTo('is_completed', 0);
    predicates.orderByDesc('created_at'); // 最新的在前面

    let resultSet = await this.rdbStore.query(predicates, ['id', 'seed_id', 'action', 'is_completed', 'completed_at', 'created_at']);
    let tasks: EchoTask[] = [];
    
    while (resultSet.goToNextRow()) {
      tasks.push({
        id: resultSet.getLong(resultSet.getColumnIndex('id')),
        seed_id: resultSet.getLong(resultSet.getColumnIndex('seed_id')),
        action: resultSet.getString(resultSet.getColumnIndex('action')),
        is_completed: resultSet.getLong(resultSet.getColumnIndex('is_completed')) === 1,
        completed_at: resultSet.getLong(resultSet.getColumnIndex('completed_at')),
        created_at: resultSet.getLong(resultSet.getColumnIndex('created_at'))
      });
    }
    resultSet.close();
    return tasks;
  }
}
