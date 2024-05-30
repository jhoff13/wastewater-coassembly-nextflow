#!/usr/bin/env python3

#Output Sub_DF to dir for concat_read_runner.py

import pandas as pd
import ast
import argparse

def parse_args():
    """
    Parse command-line arguments.
    """
    parser = argparse.ArgumentParser(description='Process library DataFrame and generate cat commands')
    parser.add_argument('-l','--library', type=str, required=True, help='Path to library DF with the read path & coassembly group properly formatted.')
    parser.add_argument('-s','--sample_suffix', type=str, default='parsed', required=False, help='Name of Sample Suffix.')
    parser.add_argument('-o','--out_dir', type=str, required=False, help='Path to Output directory')
    args = parser.parse_args()
    return args

def process_DF(library_DF_path):
    """
    Process the DataFrame: Load, validate, and prepare for cohort extraction.
    """
    library_DF = pd.read_csv(library_DF_path)

    # DF processing:
    assert 'coassembly' in library_DF.columns and 'library' in library_DF.columns and len(library_DF.columns) == 2, \
        'Column names need to be "library" & "coassembly"'

    if type(library_DF.coassembly.iloc[0]) == str:
        library_DF.coassembly = library_DF.coassembly.apply(lambda x: ast.literal_eval(x))

    # Make each cohort a column:
    library_DF = library_DF.merge(library_DF.coassembly.apply(pd.Series).notna(), right_index=True, left_index=True)
    return library_DF



def main():
    args = parse_args()
    clean_library_DF = process_DF(args.library)
    list_of_cohort_names = list(clean_library_DF.columns[2:])
    for cohort in list_of_cohort_names:
        out_DF = clean_library_DF[clean_library_DF[cohort]==True]
        out_DF.to_csv(f'{args.out_dir}cohort_{cohort}_{args.sample_suffix}.csv')
    print(f'Complete! {len(list_of_cohort_names)} sub-dataframes created!')
    #return [str(i) for i in list_of_cohort_names]

if __name__ == "__main__":
    main()
