import re

def clean_timestamps(input_file, output_file=None):
    """Remove timestamps from each line of the input file and save to output file."""
    if output_file is None:
        output_file = input_file  # Overwrite the input file if no output file specified
    
    with open(input_file, 'r') as f:
        lines = f.readlines()
    
    # Remove timestamps (format: 2025-09-04T22:59:35.792912425Z )
    cleaned_lines = [re.sub(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d+Z\s*', '', line) 
                    for line in lines]
    
    with open(output_file, 'w') as f:
        f.writelines(cleaned_lines)
    
    return len(cleaned_lines)

if __name__ == "__main__":
    input_file = "audit_1_no_ts.log"
    num_lines = clean_timestamps(input_file)
    print(f"Processed {num_lines} lines from {input_file}")
