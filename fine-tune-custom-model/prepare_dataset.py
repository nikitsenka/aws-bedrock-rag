import os
import random
import jsonlines
from datasets import load_dataset

dataset = load_dataset("knkarthick/samsum")
print(dataset)

system_string = "Below is an intruction that describes a task, paired with an input that provides further context. Write a response that appropriately completes the request."
instruction = """instruction:

Summarize the conversation provided below.

input:
"""

datapoints_train = []
for dp in dataset['train']:
    temp_dict = {}
    temp_dict["system"] = system_string
    temp_dict["messages"] = [
        {"role": "user", "content": instruction + dp['dialogue']},
        {"role": "assistant", "content": dp['summary']}
    ]
    datapoints_train.append(temp_dict)

print(datapoints_train[4])

datapoints_valid = []
for dp in dataset['validation']:
    temp_dict = {}
    temp_dict["system"] = system_string
    temp_dict["messages"] = [
        {"role": "user", "content": instruction + dp['dialogue']},
        {"role": "assistant", "content": dp['summary']}
    ]
    datapoints_valid.append(temp_dict)

datapoints_test = []
for dp in dataset['test']:
    temp_dict = {}
    temp_dict["system"] = system_string
    temp_dict["messages"] = [
        {"role": "user", "content": instruction + dp['dialogue']},
        {"role": "assistant", "content": dp['summary']}
    ]
    datapoints_test.append(temp_dict)


def dp_transform(data_points, num_dps, max_dp_length):
    lines = []
    for dp in data_points:
        if len(dp['system'] + dp['messages'][0]['content'] + dp['messages'][1]['content']) <= max_dp_length:
            lines.append(dp)
    random.shuffle(lines)
    lines = lines[:num_dps]
    return lines


def jsonl_converter(dataset, file_name):
    print(file_name)
    with jsonlines.open(file_name, 'w') as writer:
        for line in dataset:
            writer.write(line)


train = dp_transform(datapoints_train, 1000, 20000)
validation = dp_transform(datapoints_valid, 100, 20000)
test = dp_transform(datapoints_test, 10, 20000)

dataset_folder = "haiku-fine-tuning-datasets-samsum"
train_file_name = "train-samsum-1K.jsonl"
validation_file_name = "validation-samsum-100.jsonl"
test_file_name = "test-samsum-10.jsonl"

os.makedirs(dataset_folder, exist_ok=True)
abs_path = os.path.abspath(dataset_folder)

jsonl_converter(train, f'{abs_path}/{train_file_name}')
jsonl_converter(validation, f'{abs_path}/{validation_file_name}')
jsonl_converter(test, f'{abs_path}/{test_file_name}')

print(f"\nDatasets created successfully:")
print(f"  Training: {len(train)} records")
print(f"  Validation: {len(validation)} records")
print(f"  Test: {len(test)} records")
print(f"\nFiles saved to: {abs_path}")
