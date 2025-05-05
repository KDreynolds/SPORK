# SPORK: Structured Process Operating Relational Kernel

SPORK is a fake operating system kernel fully implemented in SQL, using SQLite as its runtime environment. It simulates the basic structure of an OS (programs, processes, filesystem, users, a screen buffer) using only SQL tables, functions, and queries.

## What is SPORK?

SPORK is a relational simulation of an operating system kernel. It's not a real kernel, but rather a thought experiment that demonstrates how many OS concepts can be represented using relational databases. In SPORK:

- Programs are rows in a `programs` table, containing SQL as strings
- The system "runs" programs by `SELECT`ing their code and executing it
- A `screen` table represents the shell's output
- Files are rows in a `files` table with `path`, `content`, and metadata
- Users, processes, logs, and events are all relational abstractions

## Installation

1. Clone this repository
2. Make sure you have Python 3.6+ installed
3. Make the CLI wrapper executable:
   ```bash
   chmod +x spork.py
   ```

## Usage

### Booting SPORK

```bash
./spork.py boot
```

### Running Programs

SPORK comes with a few built-in programs:

```bash
# Echo program
./spork.py run echo "Hello, SPORK!"

# List files
./spork.py run ls

# Display file contents
./spork.py run cat /path/to/file
```

### Viewing the Screen Buffer

```bash
./spork.py screen
```

## Architecture

### Core Tables

- `programs`: Stores program definitions (name, SQL code, metadata)
- `users`: User accounts and sessions
- `screen`: Terminal output buffer
- `files`: Filesystem
- `processes`: Running program instances
- `events`: System events and logging

### How It Works

1. When you run a program, SPORK:
   - Creates a process record
   - Fetches the program's SQL code
   - Executes the code with the provided arguments
   - Updates the screen buffer with the results
   - Logs the event

2. The screen buffer acts as a terminal, storing the output of each program execution

3. The filesystem is implemented as a table with paths, content, and metadata

## Creating Your Own Programs

To create a new program, insert a row into the `programs` table:

```sql
INSERT INTO programs (name, code, description)
VALUES (
    'my_program',
    'SELECT ? AS output;',  -- Your SQL code here
    'Description of what the program does'
);
```

The program's code should be valid SQL that can be executed with parameters.

## Contributing

Feel free to contribute to SPORK! Some ideas:

- Add more built-in programs
- Implement a more sophisticated filesystem
- Add user management features
- Create a web interface
- Add more OS-like features (process scheduling, memory management, etc.)

## License

MIT License - feel free to use SPORK for whatever purpose you'd like! 