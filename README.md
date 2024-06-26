## Netxtflow Co-assembly Wastewater Pipepline

This pipeline was designed to take filtered assemblies and assemble them with different assemblers for analysis with Quast. 

<img width="1130" alt="image" src="https://github.com/jhoff13/wastewater-coassembly-nextflow/assets/84932390/10193ae2-e0e5-42eb-9c9e-428b48cd4ae5">

### Using the workflow:
To use the workflow you need to
1) Supply a ref/libraries.csv which can be generated from the git_notebooks/coassembly_csv_formater.ipynb. This is a csv file has the format of **library** refering to the read_file_name_{1/2}.fastq.gz (the read path is defined in the .config under $raw_dir) and the **coassembly** which is a list of all the co-assembly cohorts you want a sample to be a part of.
2) In the nextflow dir run the command below. The --sample_suffix flag specifies what do you want your samples suffix to be, they will use the cohort number label from the **coassembly** tab will also be applied as such: cat_!{cohort}_!{sample_suffix} </br>

*nextflow workflow.nf --sample_suffix SUFFIX -resume*

3) Analysis of output quast files can be done with the attached *Coassembly_analysis.ipynb* notebook. 

![image](https://github.com/jhoff13/wastewater-coassembly-nextflow/assets/84932390/8d5d0106-1b9d-4fc1-acd3-71664ac21941)

### Future Work:
The trouble was getting Nextflow to concatenate the reads stored on S3. I was treating the paths as strings and trying to solve pythonically which was flawed. You need to pass them as paths and use NextFlow (fusion enabled) to handle them.

Below is a gitpage with a coassembly workflow that could be referenced for future work: 

https://github.com/nf-core/mag/blob/2.5.4/workflows/mag.nf

```java
// Ensure we don't have nests of nests so that structure is in form expected for assembly
ch_short_reads_catskipped = ch_short_reads_forcat.skip_cat
                                .map { meta, reads ->
                                    def new_reads = meta.single_end ? reads[0] : reads.flatten()
                                [ meta, new_reads ]
                            }

// Combine single run and multi-run-merged data
ch_short_reads = Channel.empty()
ch_short_reads = CAT_FASTQ.out.reads.mix(ch_short_reads_catskipped)
ch_versions    = ch_versions.mix(CAT_FASTQ.out.versions.first())
'''
