-- CareApp Database Initialization Script
-- This script creates the initial schema and inserts sample data

-- Create messages table
CREATE TABLE IF NOT EXISTS messages (
    id SERIAL PRIMARY KEY,
    message TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample message
INSERT INTO messages (message) VALUES ('Hello ECS Service')
ON CONFLICT DO NOTHING;

-- Create index
CREATE INDEX IF NOT EXISTS idx_messages_created_at ON messages(created_at);

-- Grant permissions (if needed)
-- GRANT ALL PRIVILEGES ON TABLE messages TO your_app_user;
-- GRANT USAGE, SELECT ON SEQUENCE messages_id_seq TO your_app_user;

-- Display success message
SELECT 'Database initialized successfully!' AS status;
SELECT * FROM messages;
