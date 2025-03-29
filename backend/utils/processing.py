import re
import pandas as pd
import os
import json

# function to search for headers and extract corresponding text
def extract_fields(text, headers):
    extracted_fields = {}

    for header in headers:
        # searches for field, extracts text until empty line is reached
        base_pattern = r'{}:\s*(.*?)(?:\n\s*\n|$)'
        pattern = base_pattern.format(re.escape(header))
        regex = re.compile(pattern, re.DOTALL)
        
        match = regex.search(text)
        value = match.group(1).strip() if match else ''

        # if field is found & not empty, append it to extracted_fields
        if value != '':
            # remove newline chars
            value_without_newlines = value.replace('\n', '')

            extracted_fields[header] = value_without_newlines
        else:
            print(f"Could not find header: \"{header}\" ", header)

    return extracted_fields


# split section into sentences
def split_on_fullstops(text):
    # Use a regex to match periods that are not part of a decimal number
    parts = re.split(r'(?<!\d)\.(?!\d)', text)
    return parts


# removes quotes
def process_sentences(text):
    words = text.replace('"', '').strip().split()
    normalized_text = ' '.join(words)

    return normalized_text


# returns true if word has:
    # a '/' AND is longer than 4 chars OR
    # 2 or more uppercase chars
def has_slash_or_two_or_more_uppercase(word):
    pattern = re.compile(r'\b\w{5,}/\w{5,}\b|\b(?:\w*[A-Z]){2,}\w*\b')
    return bool(pattern.match(word))


# ensure there are abbreviations in each data point
def has_abbreviations(text):
    words = text.split()

    for word in words:
        if has_slash_or_two_or_more_uppercase(word):
            return True

    return False


# extract sentences from discharge notes
def extract_sentences(dataset_path, headers, samples):
    df = pd.read_csv(dataset_path)
    
    data = []

    for row in df['text']:
        extracted_fields = extract_fields(row, headers)

        for field in extracted_fields:
            split_sentences = split_on_fullstops(extracted_fields[field])
            
            for sent in split_sentences:
                sent = process_sentences(sent)
                
                # append sentences longer than 100 chars
                if len(sent) > 100 and has_abbreviations(sent):
                    data_entry = {
                        "input": sent
                    }
                    data.append(data_entry)

                # stop at 100 sentences
                if len(data) >= samples:
                    return data


# either saves output (as list of json objects), OR appends it to an existing list of json objects
def save_model_output(output, save_path, save_file):
    file_full_path = os.path.join(save_path, save_file)
    existing_data = []

    # Read existing data if the file exists
    if os.path.exists(file_full_path):
        try:
            with open(file_full_path, 'r') as f:
                existing_data = json.load(f)
        except (json.JSONDecodeError, IOError) as e:
            # Handle the case where the file is empty or contains invalid JSON
            print(f"Error reading existing data from file: {e}")
            existing_data = {}

    # Update the existing data with sample result
    try:
        existing_data.append(output)
    except Exception as e:
        print(f"Error updating dictionary: {e}")
        return

    # Write the updated data back to the file
    try:
        with open(file_full_path, 'w') as f:
            json.dump(existing_data, f, indent=4)
    except (IOError, OSError) as e:
        print(f"Error writing updated data to file: {e}")
        return


# read json file
def read_json_file(path):
    with open(path, 'r') as file:
        json_object = json.load(file)
    
    return json_object


# save json file
def save_json_file(save_file, json_object):
    with open(save_file, 'w') as file:
        json.dump(json_object, file, indent=4)