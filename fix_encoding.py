import os
import sys

files_to_check = [
    r"d:\REPOSITORIO 2026\gravity\lib\features\admin\products\product_form_screen.dart",
    r"d:\REPOSITORIO 2026\gravity\lib\viewmodels\product_import_viewmodel.dart",
    r"d:\REPOSITORIO 2026\gravity\lib\core\importer\parse_utils.dart",
    r"d:\REPOSITORIO 2026\gravity\lib\core\importer\nuvemshop_category_mapper.dart"
]

for file_path in files_to_check:
    if not os.path.exists(file_path):
        print(f"File not found: {file_path}")
        continue
        
    try:
        # Try reading as UTF-8
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        print(f"File {file_path} is valid UTF-8.")
        
        # Rewrite it just to be sure (BOM removal etc)
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
            
    except UnicodeDecodeError:
        print(f"File {file_path} is NOT UTF-8. Attempting convert...")
        try:
            # Try UTF-16 (common for Powershell)
            with open(file_path, 'r', encoding='utf-16') as f:
                content = f.read()
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(content)
            print("Converted from UTF-16 to UTF-8.")
        except Exception as e:
            try:
                # Try latin-1 as fallback
                with open(file_path, 'r', encoding='latin-1') as f:
                    content = f.read()
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(content)
                print("Converted from Latin-1 to UTF-8.")
            except Exception as e2:
                print(f"Failed to convert: {e2}")
    except Exception as e:
        print(f"Error processing {file_path}: {e}")
