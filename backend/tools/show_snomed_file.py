# display the snomed file

import pandas as pd

df = pd.read_csv('01.standardization/data/SNOMED-CT/SNOMED_valid_with_desc_comma.csv')

# 显示数据的基本信息
print("数据形状:", df.shape)
print("列名:", df.columns.tolist())

# 随机展示5行数据的完整内容
print("\n随机5行数据:")
pd.set_option('display.max_columns', None)  # 显示所有列
pd.set_option('display.width', None)  # 显示所有内容不截断
pd.set_option('display.max_colwidth', None)  # 显示每列的完整内容
print(df.sample(5))  # 使用sample方法随机抽取5行

# 显示每列的数据类型和非空值数量
print("\n数据类型和非空值统计:")
print(df.info())

# 显示数值列的统计摘要
print("\n数值列统计摘要:")
print(df.describe())


# 检索包含"Dyspnea"的概念名称
print("\n包含'Dyspnea'的概念:")
dyspnea_concepts = df[df['concept_name'].str.contains('Dyspnea', case=False, na=False)]
print(f"找到 {len(dyspnea_concepts)} 条包含'Dyspnea'的记录")
print(dyspnea_concepts[['concept_code', 'concept_name', 'Full Name', 'Synonyms']])

# domain_id 和 concept_class_id - 展示一下列表
print("\ndomain_id 和 concept_class_id 的列表:")
print(df['domain_id'].unique())
print(df['concept_class_id'].unique())


# # 检查特定概念代码
# concept_code = '267036007'
# print(f"\n检查概念代码 {concept_code}:")
# print(f"是否存在该概念代码: {concept_code in df['concept_code'].values}")

# # 显示所有包含该概念代码的行
# matching_rows = df[df['concept_code'] == concept_code]
# print(f"\n匹配的行数: {len(matching_rows)}")
# if len(matching_rows) > 0:
#     print("\n匹配行的详细信息:")
#     print(matching_rows[['concept_code', 'concept_name', 'Full Name', 'Synonyms']])

# # 检查concept_code列的唯一值数量
# print(f"\nconcept_code列的唯一值数量: {df['concept_code'].nunique()}")

# # 显示concept_code列的一些示例值
# print("\nconcept_code列的一些示例值:")
# print(df['concept_code'].head())

# # 检查数据中的特殊字符
# print("\n检查数据中的特殊字符:")
# # 显示包含目标代码的行
# target_row = df[df['concept_code'].str.contains('267036007', na=False)]
# if len(target_row) > 0:
#     print("\n找到包含目标代码的行:")
#     print(target_row[['concept_code', 'concept_name']])
#     # 显示concept_code的字符编码
#     print("\nconcept_code的字符编码:")
#     print([ord(c) for c in target_row['concept_code'].iloc[0]])

# # 清理数据并重试
# df['concept_code'] = df['concept_code'].str.strip()
# matching_rows_cleaned = df[df['concept_code'] == concept_code]
# print(f"\n清理数据后的匹配行数: {len(matching_rows_cleaned)}")
# if len(matching_rows_cleaned) > 0:
#     print("\n清理数据后的匹配行详细信息:")
#     print(matching_rows_cleaned[['concept_code', 'concept_name', 'Full Name', 'Synonyms']])

# 进一步检查数据
print("\n进一步检查数据:")
# 检查concept_code列的数据类型
print(f"concept_code列的数据类型: {df['concept_code'].dtype}")

# 检查是否有空值
print(f"concept_code列的空值数量: {df['concept_code'].isna().sum()}")

# 检查concept_code列的值长度分布
print("\nconcept_code列的值长度分布:")
print(df['concept_code'].str.len().value_counts().sort_index())

# 尝试使用模糊匹配
print("\n尝试模糊匹配:")
fuzzy_matches = df[df['concept_code'].str.contains('703600', na=False)]
if len(fuzzy_matches) > 0:
    print("找到的模糊匹配:")
    print(fuzzy_matches[['concept_code', 'concept_name']])

# 检查Dyspnea相关的行
print("\n检查Dyspnea相关的行:")
dyspnea_rows = df[df['concept_name'].str.contains('Dyspnea', case=False, na=False)]
print(dyspnea_rows[['concept_code', 'concept_name']])


# 唉，就找concept_name = Dyspnea的吧
print("\n检索concept_name = Dyspnea的行:")
dyspnea_rows = df[df['concept_name'].str.contains('Dyspnea', case=False, na=False)]
print(dyspnea_rows[['concept_code', 'concept_name']])


# 321341 - 拿这个索引号， 第321341行
print("\n检索第321341行的数据:")
print(df.iloc[321341])

