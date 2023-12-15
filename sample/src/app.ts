import Fastify, { FastifyInstance } from 'fastify';

function registerRoutes(app: FastifyInstance): void {
  app.get('/ping', async (request, reply) => {
    return 'pong\n';
  });

  app.get('/status', async (request, reply) => {
    return {
      message: 'OK'
    };
  });
}

function createApp(options = {}): FastifyInstance {
  const app: FastifyInstance = Fastify(options);

  registerRoutes(app);

  return app;
}

export {
  createApp
};
