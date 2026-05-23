import http from '@ohos.net.http';
import { AppConfig } from '../common/AppConfig';

export class SharedForestService {
  static async fetchLeaves(): Promise<http.HttpResponse> {
    const httpRequest = http.createHttp();
    try {
      return await httpRequest.request(
        `${AppConfig.SHARED_FOREST_API_BASE}/api/leaves`,
        {
          method: http.RequestMethod.GET,
          header: { 'Content-Type': 'application/json' },
          connectTimeout: 10000,
          readTimeout: 10000
        }
      );
    } finally {
      httpRequest.destroy();
    }
  }

  static async checkConnection(): Promise<boolean> {
    try {
      const response = await SharedForestService.fetchLeaves();
      return response.responseCode === 200;
    } catch (e) {
      return false;
    }
  }

  static async likeLeaf(leafId: string): Promise<http.HttpResponse> {
    const httpRequest = http.createHttp();
    try {
      return await httpRequest.request(
        `${AppConfig.SHARED_FOREST_API_BASE}/api/leaves/${leafId}/like`,
        {
          method: http.RequestMethod.POST,
          header: { 'Content-Type': 'application/json' },
          connectTimeout: 10000,
          readTimeout: 10000
        }
      );
    } finally {
      httpRequest.destroy();
    }
  }

  static async submitLeaf(content: string, nickname: string, accountKey: string = '', ownerNickname: string = ''): Promise<http.HttpResponse> {
    const httpRequest = http.createHttp();
    try {
      const requestBody: string = JSON.stringify({
        content: content,
        nickname: nickname,
        accountKey: accountKey,
        ownerNickname: ownerNickname
      });

      return await httpRequest.request(
        `${AppConfig.SHARED_FOREST_API_BASE}/api/leaves`,
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json',
            'X-Account-Key': accountKey
          },
          extraData: requestBody,
          connectTimeout: 10000,
          readTimeout: 10000
        }
      );
    } finally {
      httpRequest.destroy();
    }
  }
}
