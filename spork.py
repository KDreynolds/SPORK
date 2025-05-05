#!/usr/bin/env python3
import sqlite3
import sys
import os
import json
from typing import Dict, Any, Optional

class SPORK:
    def __init__(self, db_path: str = "spork.db"):
        """Initialize SPORK with SQLite database."""
        print(f"Initializing SPORK with database: {db_path}")
        
        # Create new database and schema if it doesn't exist
        db_exists = os.path.exists(db_path)
        self.conn = sqlite3.connect(db_path)
        self.conn.row_factory = sqlite3.Row
        self.conn.execute("PRAGMA foreign_keys = ON")
        
        if not db_exists:
            print("Creating schema...")
            with open("schema.sql", "r") as f:
                schema = f.read()
                print("Executing schema...")
                self.conn.executescript(schema)
                print("Schema executed successfully")
            self.conn.commit()
        else:
            print("Using existing database")

    def boot(self) -> None:
        """Boot the SPORK system."""
        print("Booting SPORK...")
        # Boot message is handled by schema.sql
        pass

    def run_program(self, program_name: str, args: str = "") -> Dict[str, Any]:
        """Execute a program through SQL."""
        try:
            print(f"Running program: {program_name} with args: {args}")
            # Start transaction
            self.conn.execute("BEGIN")
            
            # Create process record to trigger execution
            print("Creating process record...")
            self.conn.execute(
                "INSERT INTO processes (program_name, user_id, args) VALUES (?, 1, ?)",
                (program_name, args)
            )
            process_id = self.conn.execute("SELECT last_insert_rowid()").fetchone()[0]
            
            # Get program code
            program = self.conn.execute(
                "SELECT sql_code FROM programs WHERE name = ?",
                (program_name,)
            ).fetchone()
            
            if not program:
                raise Exception(f"Program not found: {program_name}")
            
            # Execute program SQL
            sql_code = program["sql_code"]
            params = tuple([args] * sql_code.count('?'))
            cursor = self.conn.execute(sql_code, params)
            result = cursor.fetchone()
            output = result["output"] if result else None
            
            # Handle file operations in SQL
            if program_name == "mkdir":
                if args:
                    self.conn.execute(
                        "INSERT INTO files (name, parent_id, owner_id, is_directory) VALUES (?, 1, 1, 1)",
                        (args,)
                    )
            elif program_name == "write":
                if " " in args:
                    filename, content = args.split(" ", 1)
                    self.conn.execute(
                        """INSERT OR REPLACE INTO files 
                           (name, parent_id, owner_id, content, is_directory) 
                           VALUES (?, 1, 1, ?, 0)""",
                        (filename, content)
                    )
            elif program_name == "set":
                if " " in args:
                    name, value = args.split(" ", 1)
                    self.conn.execute(
                        """INSERT OR REPLACE INTO variables 
                           (user_id, name, value, updated_at) 
                           VALUES (1, ?, ?, CURRENT_TIMESTAMP)""",
                        (name, value)
                    )
            
            # Update process status
            self.conn.execute(
                """UPDATE processes 
                   SET status = 'completed', output = ?, ended_at = CURRENT_TIMESTAMP
                   WHERE id = ?""",
                (output, process_id)
            )
            
            # Insert output into screen
            self.conn.execute(
                "INSERT INTO screen (user_id, content) VALUES (1, json_object('output', ?))",
                (output,)
            )
            
            # Commit transaction
            print("Committing transaction...")
            self.conn.commit()
            
            return {"output": output} if output else {"success": True, "results": [{"output": "Command executed"}]}
            
        except Exception as e:
            print(f"Error: {str(e)}")
            self.conn.rollback()
            return {"success": False, "error": str(e)}

    def get_screen(self) -> Dict[str, Any]:
        """Get current screen buffer."""
        cursor = self.conn.execute(
            "SELECT content FROM screen WHERE user_id = 1 ORDER BY id DESC LIMIT 10"
        )
        results = cursor.fetchall()
        return {
            "success": True,
            "results": [json.loads(row["content"]) for row in results]
        }

    def close(self) -> None:
        """Close database connection."""
        self.conn.close()

def main():
    if len(sys.argv) < 2:
        print("Usage: ./spork.py [boot|run|screen] [program] [args...]")
        sys.exit(1)

    command = sys.argv[1]
    spork = SPORK()

    try:
        if command == "boot":
            spork.boot()
            print("SPORK booted successfully")
        elif command == "run":
            if len(sys.argv) < 3:
                print("Usage: ./spork.py run <program> [args...]")
                sys.exit(1)
            program = sys.argv[2]
            args = " ".join(sys.argv[3:])
            result = spork.run_program(program, args)
            print(json.dumps(result, indent=2))
        elif command == "screen":
            result = spork.get_screen()
            print(json.dumps(result, indent=2))
        else:
            print(f"Unknown command: {command}")
            sys.exit(1)
    finally:
        spork.close()

if __name__ == "__main__":
    main() 