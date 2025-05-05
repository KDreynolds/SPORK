PRAGMA foreign_keys = ON;

-- Core system tables
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY,
    username TEXT NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS programs (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    sql_code TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS screen (
    id INTEGER PRIMARY KEY,
    user_id INTEGER NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE IF NOT EXISTS processes (
    id INTEGER PRIMARY KEY,
    program_name TEXT NOT NULL,
    user_id INTEGER NOT NULL,
    args TEXT,
    status TEXT DEFAULT 'pending',
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ended_at TIMESTAMP,
    output TEXT,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Add files table for filesystem
CREATE TABLE IF NOT EXISTS files (
    id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    parent_id INTEGER,
    owner_id INTEGER NOT NULL,
    content TEXT,
    is_directory INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (parent_id) REFERENCES files(id),
    FOREIGN KEY (owner_id) REFERENCES users(id),
    UNIQUE(name, parent_id)
);

-- Views for program execution
CREATE VIEW program_execution AS
SELECT 
    p.id as process_id,
    p.program_name,
    p.args,
    prg.sql_code,
    CASE 
        WHEN prg.id IS NULL THEN 'error'
        ELSE 'ready'
    END as status,
    CASE
        WHEN prg.id IS NULL THEN 'Program not found: ' || p.program_name
        ELSE p.args
    END as output
FROM processes p
LEFT JOIN programs prg ON p.program_name = prg.name
WHERE p.status = 'pending';

-- Trigger to handle program execution
CREATE TRIGGER run_program
AFTER INSERT ON processes
BEGIN
    -- Update process status and output based on program existence
    UPDATE processes 
    SET 
        status = (
            SELECT status 
            FROM program_execution 
            WHERE process_id = NEW.id
        ),
        output = (
            SELECT output
            FROM program_execution
            WHERE process_id = NEW.id
        ),
        ended_at = CURRENT_TIMESTAMP
    WHERE id = NEW.id;
    
    -- Insert output into screen
    INSERT INTO screen (user_id, content)
    SELECT 
        NEW.user_id,
        json_object('output', output)
    FROM processes
    WHERE id = NEW.id;
END;

-- Initialize system
INSERT INTO users (id, username) VALUES (1, 'root');

-- Insert boot message
INSERT INTO screen (user_id, content) 
VALUES (1, json_object('output', 'SPORK booted successfully'));

-- Initialize root directory
INSERT INTO files (id, name, parent_id, owner_id, is_directory) 
VALUES (1, '/', NULL, 1, 1);

-- Create some example files
INSERT INTO files (name, parent_id, owner_id, is_directory, content) 
VALUES 
    ('home', 1, 1, 1, NULL),
    ('readme.txt', 1, 1, 0, 'Welcome to SPORK - SQL Powered Operating System Kernel');

-- Example programs
INSERT INTO programs (name, description, sql_code) 
VALUES 
    ('echo', 'Echoes its arguments', 'SELECT ? as output'),
    
    ('ls', 'Lists files in the current directory', 
    "SELECT coalesce(
        group_concat(
            CASE 
                WHEN is_directory = 1 THEN 'dir:  ' || name
                ELSE 'file: ' || name
            END,
            char(10)
        ),
        'No files found'
    ) as output
    FROM files 
    WHERE parent_id = 1 
    ORDER BY is_directory DESC, name"),
    
    ('cat', 'Display file contents', 
    "SELECT 
        CASE 
            WHEN EXISTS (SELECT 1 FROM files WHERE name = ? AND is_directory = 0) THEN
                (SELECT content FROM files WHERE name = ? AND is_directory = 0)
            ELSE 
                'File not found: ' || ?
        END as output"),
        
    ('pwd', 'Print working directory', 
    "SELECT '/' as output"),

    ('mkdir', 'Create a directory',
    "SELECT
        CASE
            WHEN ? = '' THEN 'Usage: mkdir <dirname>'
            WHEN EXISTS (SELECT 1 FROM files WHERE name = ? AND parent_id = 1) THEN
                'Directory already exists: ' || ?
            ELSE (
                SELECT 'Created directory: ' || ? 
                WHERE EXISTS (
                    SELECT 1 FROM files WHERE id = 1
                )
            )
        END as output
    "),
    
    ('write', 'Write to a file',
    "SELECT 
        CASE
            WHEN ? = '' THEN 'Usage: write <filename> <content>'
            WHEN instr(?, ' ') = 0 THEN 'Usage: write <filename> <content>'
            ELSE (
                SELECT 'Wrote to file: ' || substr(?, 1, instr(?, ' ')-1)
                WHERE EXISTS (
                    SELECT 1 FROM files WHERE id = 1
                )
            )
        END as output
    "),
    
    ('ps', 'List processes', 
    "SELECT coalesce(
        group_concat(
            'PID ' || id || ': ' || program_name || 
            ' (' || status || ') ' || 
            CASE WHEN ended_at IS NULL THEN 'running' ELSE 'completed' END,
            char(10)
        ),
        'No processes found'
    ) as output
    FROM processes
    ORDER BY id DESC
    LIMIT 10"); 