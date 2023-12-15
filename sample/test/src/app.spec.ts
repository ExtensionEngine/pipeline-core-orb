import { FastifyInstance, LightMyRequestResponse } from 'fastify';
import { createApp } from '../../src/app';

describe('src/app', () => {
  const app: FastifyInstance = createApp();

  test('Check /ping route', async () => {
    const res: LightMyRequestResponse = await app.inject({
      url: '/ping'
    });

    expect(res.payload).toBe('pong\n');
  });

  test('Check /status route', async () => {
    const res: LightMyRequestResponse = await app.inject({
      url: '/status'
    });

    expect(JSON.parse(res.payload)).toEqual({
      message: 'OK'
    });
  });
});
