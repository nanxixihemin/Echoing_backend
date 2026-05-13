import connection from '@ohos.net.connection';

export interface NetworkCheckResult {
  isZzu: boolean;
  ipOrStatus: string;
}

export class ZzuNetwork {
  /**
   * 核心逻辑：通过探测当前连接的 IP 属性来判定是否处于郑州大学校园网 (ZZU-WLAN / 郑大内网基站)
   */
  static async verifyCampusNetwork(): Promise<NetworkCheckResult> {
    try {
      let netHandle = await connection.getDefaultNet();
      if (!netHandle || netHandle.netId === 0) {
        let res: NetworkCheckResult = { isZzu: false, ipOrStatus: '未连接网络' };
        return res;
      }

      let netProperties = await connection.getConnectionProperties(netHandle);
      if (netProperties && netProperties.linkAddresses && netProperties.linkAddresses.length > 0) {
        // 读取本机的 IPv4 地址
        let ipAddress = netProperties.linkAddresses[0].address.address;
        
        // 核心判定准则 (ZZU-WLAN 通常基于校园的 10.x.x.x 局域网分发，或专属的 CERNET 外网网段)
        // 此处为规则引擎样例：
        if (ipAddress.startsWith('10.') || ipAddress.startsWith('172.16.') || ipAddress.startsWith('202.197.')) {
           let res: NetworkCheckResult = { isZzu: true, ipOrStatus: `ZZU-WLAN (IP: ${ipAddress})` };
           return res;
        } else {
           let res: NetworkCheckResult = { isZzu: false, ipOrStatus: `外网环境 (IP: ${ipAddress})` };
           return res;
        }
      }
      let finalRes: NetworkCheckResult = { isZzu: false, ipOrStatus: '无法读取网络拓扑' };
      return finalRes;

    } catch (e) {
      // 撤掉伪装面具，直面抛出的真实报错！
      let err = e as Error;
      let errorMsg = err.message ? err.message : '未知异常(无message)';
      let res: NetworkCheckResult = { isZzu: false, ipOrStatus: '底层拦截/失败: ' + errorMsg };
      return res;
    }
  }
}
