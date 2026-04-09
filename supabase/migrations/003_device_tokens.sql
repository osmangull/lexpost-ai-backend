-- Device tokens for push notifications
CREATE TABLE IF NOT EXISTS device_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT,
    fcm_token TEXT NOT NULL UNIQUE,
    notification_hour INTEGER NOT NULL DEFAULT 8 CHECK (notification_hour >= 0 AND notification_hour <= 23),
    notifications_enabled BOOLEAN NOT NULL DEFAULT true,
    last_notified_date DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_device_tokens_notification_hour ON device_tokens(notification_hour);
CREATE INDEX IF NOT EXISTS idx_device_tokens_enabled ON device_tokens(notifications_enabled);
