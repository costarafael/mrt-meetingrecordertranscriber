#!/usr/bin/env python3
"""
Script para padronizar logging removendo print() statements e convertendo para LoggingService
"""

import os
import re
import sys
from pathlib import Path

# Patterns para diferentes tipos de print statements
PRINT_PATTERNS = [
    # Pattern: print("🔄 [PREFIX] message")
    (r'print\("🔄 \[([^\]]+)\] (.+)"\)', r'logger.debug("\2", category: .general)'),
    
    # Pattern: print("✅ message")  
    (r'print\("✅ (.+)"\)', r'logger.info("\1", category: .general)'),
    
    # Pattern: print("❌ message")
    (r'print\("❌ (.+)"\)', r'logger.error("\1", category: .general)'),
    
    # Pattern: print("⚠️ message") 
    (r'print\("⚠️ (.+)"\)', r'logger.warning("\1", category: .general)'),
    
    # Pattern: print("🎤 message")
    (r'print\("🎤 (.+)"\)', r'logger.info("\1", category: .audio)'),
    
    # Pattern: print("📊 message")
    (r'print\("📊 (.+)"\)', r'logger.debug("\1", category: .performance)'),
    
    # Pattern: print("🔧 message")
    (r'print\("🔧 (.+)"\)', r'logger.debug("\1", category: .general)'),
    
    # Pattern: generic print with string literal
    (r'print\("([^"]+)"\)', r'logger.debug("\1", category: .general)'),
]

def process_file(file_path):
    """Process a single Swift file to replace print statements"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original_content = content
        changes_made = 0
        
        # Apply each pattern
        for pattern, replacement in PRINT_PATTERNS:
            matches = re.findall(pattern, content)
            if matches:
                content = re.sub(pattern, replacement, content)
                changes_made += len(matches)
        
        # Only write if changes were made
        if content != original_content:
            # Ensure LoggingService import exists
            if 'logger.' in content and 'LoggingService' not in content:
                # Add LoggingService import after other imports
                import_pattern = r'(import [^\n]+\n)(?!import)'
                if re.search(import_pattern, content):
                    content = re.sub(
                        r'(import [^\n]+\n)(?=\n)',
                        r'\1\n// LoggingService for unified logging\nprivate let logger = LoggingService.shared\n',
                        content,
                        count=1
                    )
            
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            
            return changes_made
        
        return 0
        
    except Exception as e:
        print(f"Error processing {file_path}: {e}")
        return 0

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 cleanup_logging.py <source_directory>")
        sys.exit(1)
    
    source_dir = Path(sys.argv[1])
    if not source_dir.exists():
        print(f"Directory {source_dir} does not exist")
        sys.exit(1)
    
    # Find all Swift files
    swift_files = list(source_dir.rglob("*.swift"))
    
    total_changes = 0
    files_modified = 0
    
    print(f"Processing {len(swift_files)} Swift files...")
    
    for swift_file in swift_files:
        changes = process_file(swift_file)
        if changes > 0:
            files_modified += 1
            total_changes += changes
            print(f"✅ {swift_file.name}: {changes} print statements converted")
    
    print(f"\n🎉 Complete!")
    print(f"   Files modified: {files_modified}")
    print(f"   Total print statements converted: {total_changes}")

if __name__ == "__main__":
    main()