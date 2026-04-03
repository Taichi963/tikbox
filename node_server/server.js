'use strict';

const { WebcastPushConnection } = require('tiktok-live-connector');
const { WebSocketServer, WebSocket } = require('ws');

const PORT = Number(process.env.PORT || 3000);
const MAX_RECONNECT_ATTEMPTS = Number(process.env.MAX_RECONNECT_ATTEMPTS || 10);
const INITIAL_BACKOFF_MS = 1000;
const MAX_BACKOFF_MS = 30000;
const TIKTOK_CONNECT_TIMEOUT_MS = Number(process.env.TIKTOK_CONNECT_TIMEOUT_MS || 15000);

const wss = new WebSocketServer({ port: PORT });

log('info', 'server.started', { port: PORT });

wss.on('error', (error) => {
  log('error', 'server.error', {
    port: PORT,
    error: toErrorPayload(error),
  });
});

wss.on('connection', (ws, request) => {
  const session = new TikTokSession(ws, request);
  log('info', 'ws.connected', {
    remoteAddress: request.socket.remoteAddress,
  });

  ws.on('message', async (raw) => {
    try {
      let message;
      try {
        message = JSON.parse(raw.toString());
      } catch (error) {
        session.sendError('不正なJSONを受信しました');
        log('warn', 'ws.invalid_json', { error: error.message });
        return;
      }

      await session.handleMessage(message);
    } catch (error) {
      log('error', 'ws.message_handler_failed', {
        error: toErrorPayload(error),
      });
      session.sendError('メッセージ処理に失敗しました');
    }
  });

  ws.on('close', async () => {
    log('info', 'ws.closed', { username: session.username });
    await session.dispose();
  });

  ws.on('error', async (error) => {
    log('error', 'ws.error', {
      username: session.username,
      error: toErrorPayload(error),
    });
    await session.dispose();
  });
});

class TikTokSession {
  constructor(ws, request) {
    this.ws = ws;
    this.request = request;
    this.connection = null;
    this.username = null;
    this.isDisposed = false;
    this.isManualDisconnect = false;
    this.isConnecting = false;
    this.reconnectAttempts = 0;
    this.reconnectTimer = null;
    this.connectionGeneration = 0;
  }

  async handleMessage(message) {
    if (this.isDisposed || !message || typeof message !== 'object') {
      return;
    }

    switch (message.type) {
      case 'connect':
        await this.start(message.username);
        break;
      case 'disconnect':
        await this.disconnect({ notifyClient: true });
        break;
      default:
        this.sendError(`未対応のメッセージです: ${String(message.type)}`);
        break;
    }
  }

  async start(rawUsername) {
    const username = normalizeUsername(rawUsername);
    if (!username) {
      this.sendError('ユーザー名を入力してください');
      return;
    }

    if (this.isConnecting) {
      this.sendError('現在接続中です');
      return;
    }

    this.username = username;
    this.isManualDisconnect = false;
    this.reconnectAttempts = 0;
    this.clearReconnectTimer();
    await this.disconnect({ notifyClient: false, clearUsername: false });
    await this.connectWithRetry(true);
  }

  async connectWithRetry(resetAttempts = false) {
    if (this.isDisposed || this.isManualDisconnect || !this.username) {
      return;
    }

    if (resetAttempts) {
      this.reconnectAttempts = 0;
    }

    if (this.reconnectAttempts >= MAX_RECONNECT_ATTEMPTS) {
      this.sendError('再接続上限に達しました');
      log('error', 'tiktok.reconnect_exhausted', {
        username: this.username,
        attempts: this.reconnectAttempts,
      });
      return;
    }

    this.isConnecting = true;
    const generation = ++this.connectionGeneration;
    this.sendStatus('connecting', this.reconnectAttempts);

    try {
      await this.openConnection(generation);
      this.isConnecting = false;
      this.reconnectAttempts = 0;
      this.sendStatus('connected', 0);
      log('info', 'tiktok.connected', { username: this.username });
    } catch (error) {
      this.isConnecting = false;
      this.reconnectAttempts += 1;

      log('warn', 'tiktok.connect_failed', {
        username: this.username,
        attempt: this.reconnectAttempts,
        maxAttempts: MAX_RECONNECT_ATTEMPTS,
        error: toErrorPayload(error),
      });

      if (this.reconnectAttempts >= MAX_RECONNECT_ATTEMPTS) {
        this.sendError(`接続失敗: ${error.message}`);
        return;
      }

      const delayMs = backoffMs(this.reconnectAttempts);
      this.sendStatus('connecting', this.reconnectAttempts);
      this.scheduleReconnect(delayMs);
    }
  }

  async openConnection(generation) {
    const connection = new WebcastPushConnection(this.username, {
      processInitialData: false,
      enableExtendedGiftInfo: true,
      requestPollingIntervalMs: 1000,
    });

    this.bindEvents(connection, generation);
    this.connection = connection;

    await withTimeout(
      connection.connect(),
      TIKTOK_CONNECT_TIMEOUT_MS,
      'TikTok接続がタイムアウトしました',
    );
  }

  bindEvents(connection, generation) {
    connection.on('chat', (data) => {
      if (!this.isActive(generation)) {
        return;
      }

      this.safeSend({
        type: 'comment',
        userName: normalizeUsername(data.uniqueId),
        text: String(data.comment || ''),
      });
    });

    connection.on('gift', (data) => {
      if (!this.isActive(generation)) {
        return;
      }

      if (data.giftType === 1 && !data.repeatEnd) {
        return;
      }

      this.safeSend({
        type: 'gift',
        userName: normalizeUsername(data.uniqueId),
        giftName: String(data.giftName || 'Gift'),
        giftCount: Number(data.repeatCount || 1),
      });
    });

    connection.on('member', (data) => {
      if (!this.isActive(generation)) {
        return;
      }

      this.safeSend({
        type: 'member',
        userName: normalizeUsername(data.uniqueId),
      });
    });

    connection.on('disconnected', async () => {
      if (!this.isActive(generation) || this.isManualDisconnect) {
        return;
      }

      log('warn', 'tiktok.disconnected', { username: this.username });
      await this.cleanupConnection();
      await this.connectWithRetry(false);
    });

    connection.on('error', async (error) => {
      if (!this.isActive(generation) || this.isManualDisconnect) {
        return;
      }

      log('error', 'tiktok.runtime_error', {
        username: this.username,
        error: toErrorPayload(error),
      });
      await this.cleanupConnection();
      await this.connectWithRetry(false);
    });
  }

  scheduleReconnect(delayMs) {
    if (this.isDisposed || this.isManualDisconnect) {
      return;
    }

    this.clearReconnectTimer();

    log('info', 'tiktok.reconnect_scheduled', {
      username: this.username,
      delayMs,
      attempt: this.reconnectAttempts,
    });

    this.reconnectTimer = setTimeout(async () => {
      try {
        await this.connectWithRetry(false);
      } catch (error) {
        log('error', 'tiktok.reconnect_failed', {
          username: this.username,
          error: toErrorPayload(error),
        });
      }
    }, delayMs);
  }

  async disconnect({
    notifyClient = true,
    clearUsername = false,
  } = {}) {
    this.isManualDisconnect = true;
    this.isConnecting = false;
    this.clearReconnectTimer();
    this.connectionGeneration += 1;

    await this.cleanupConnection();

    if (notifyClient) {
      this.sendStatus('disconnected', 0);
    }

    if (clearUsername) {
      this.username = null;
    }
  }

  async cleanupConnection() {
    const currentConnection = this.connection;
    this.connection = null;

    if (!currentConnection) {
      return;
    }

    try {
      await currentConnection.disconnect();
    } catch (error) {
      log('warn', 'tiktok.disconnect_cleanup_failed', {
        username: this.username,
        error: toErrorPayload(error),
      });
    }
  }

  clearReconnectTimer() {
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }
  }

  isActive(generation) {
    return !this.isDisposed && generation === this.connectionGeneration;
  }

  sendStatus(status, reconnectAttempts = 0) {
    this.safeSend({
      type: 'status',
      status,
      username: this.username || '',
      reconnectAttempts,
    });
  }

  sendError(message) {
    this.safeSend({
      type: 'error',
      message,
    });
  }

  safeSend(payload) {
    try {
      if (!this.isDisposed && this.ws.readyState === WebSocket.OPEN) {
        this.ws.send(JSON.stringify(payload));
      }
    } catch (error) {
      log('error', 'ws.send_failed', {
        username: this.username,
        error: toErrorPayload(error),
      });
    }
  }

  async dispose() {
    if (this.isDisposed) {
      return;
    }

    this.isDisposed = true;
    this.isManualDisconnect = true;
    this.isConnecting = false;
    this.clearReconnectTimer();
    this.connectionGeneration += 1;
    await this.cleanupConnection();
  }
}

function normalizeUsername(value) {
  return String(value || '')
    .trim()
    .replace(/^@+/, '')
    .replace(/^https?:\/\/(www\.)?tiktok\.com\/@?/i, '')
    .replace(/\?.*$/, '')
    .replace(/\/+$/, '');
}

function backoffMs(attempt) {
  const value = INITIAL_BACKOFF_MS * (2 ** Math.max(attempt - 1, 0));
  return Math.min(value, MAX_BACKOFF_MS);
}

function withTimeout(promise, timeoutMs, message) {
  return Promise.race([
    promise,
    new Promise((_, reject) => {
      setTimeout(() => reject(new Error(message)), timeoutMs);
    }),
  ]);
}

function log(level, event, payload = {}) {
  const entry = {
    timestamp: new Date().toISOString(),
    level,
    event,
    ...payload,
  };
  process.stdout.write(`${JSON.stringify(entry)}\n`);
}

function toErrorPayload(error) {
  if (error instanceof Error) {
    return {
      message: error.message,
      stack: error.stack,
    };
  }

  return {
    message: String(error),
  };
}
