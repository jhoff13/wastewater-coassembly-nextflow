#!/usr/bin/env python3

#v2: take in a DF with a pre-filtered cohort, just look at the library column (first)

import pandas as pd
import ast
import argparse
import subprocess

def parse_args():
    """
    Parse command-line arguments.
    """
    parser = argparse.ArgumentParser(description='Process library DataFrame and generate cat commands')
    parser.add_argument('-l','--library', type=str, required=True, help='Path to library DF with the read path & coassembly group properly formatted.')
    parser.add_argument('-s','--sample_suffix', type=str, required=True, help='Name of the sample prefix for concat reads - cat_{coassembly_number}_{sample}_1.fastq')
    parser.add_argument('-r','--read_path', type=str, required=True, help='Path for reads for raw reads, end with /')
    args = parser.parse_args()
    return args

def select_DF(library_DF_path,cohort):
    """
    Process the DataFrame: Load, validate, and subselect based on input cohort.
    """
    library_DF = pd.read_csv(library_DF_path)

    # DF processing:
    assert 'coassembly' in library_DF.columns and 'library' in library_DF.columns and len(library_DF.columns) == 2, \
        'Column names need to be "library" & "coassembly"'

    if type(library_DF.coassembly.iloc[0]) == str:
        library_DF.coassembly = library_DF.coassembly.apply(lambda x: ast.literal_eval(x))

    # Make each cohort a column:
    library_DF = library_DF.merge(library_DF.coassembly.apply(pd.Series)\
                            .notna(), right_index=True, left_index=True)

    #Subselect DF
    assert cohort in library_DF.columns, \
        f'Input Cohort Label: {cohort} not found {library_DF.columns}'
    sub_library_DF = library_DF[library_DF[cohort]==True]

    return sub_library_DF

def run_cmd(cohort_library, sample_suffix, read_path):
    """
    Generate and run the scripted cmds.
    """
    library_DF = pd.read_csv(cohort_library)
    if read_path[-1] != '/':
        read_path = read_path+'/'
    library_DF['library'] = read_path+library_DF.library

    r1, r2 = ', '.join(list(library_DF.library.str.replace('{1/2}', '1'))),', '.join(list(library_DF.library.str.replace('{1/2}', '2')))
    cohort_index = cohort_library.split('cohort_')[1].split('_')[0]
    sample_name = f'cat_{cohort_index}_{sample_suffix}'
    cmd_r1, cmd_r2 = f'cat {r1} > {sample_name}_1.fastq.gz',f'cat {r2} > {sample_name}_2.fastq.gz'
    print(f"Running:{cmd_r1}\nRunning:{cmd_r2}")
    subprocess.run(cmd_r1, shell=True)
    subprocess.run(cmd_r2, shell=True)
    return sample_name

def main():
    args = parse_args()
    #sub_library_DF = select_DF(args.library,args.cohort_label,args.read_path)
    run_cmd(args.library, args.sample_suffix, args.read_path)

if __name__ == "__main__":
    main()
