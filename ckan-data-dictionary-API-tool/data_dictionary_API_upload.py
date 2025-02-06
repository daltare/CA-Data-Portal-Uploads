
import pandas as pd
import polars as pl


df_data_dict = pl.read_excel('CEDEN_Chemistry_Data_Dictionary.xlsx')

df_data_dict = df_data_dict.select(["column", "type", "label", "description"])

l = []
for row in df_data_dict.head().rows():
    print(row)
    # l.append({
        
    # })


# df_data_dict = df_data_dict.with_columns(
#     z = pl.concat
#     info = pl.concat_list("type", "label", "description"),
#     info2 = pl.DataFrame({
#         'ty': type, 
#         'b': label, 
#         'cd': description})
# )

# print(df_data_dict.head())

# df.with_columns(
#   b_plus_c = pl.sum_horizontal(pl.col('b'), pl.col('c')) 
# )


# df.with_columns(list_col = pl.struct( cs.integer() ))