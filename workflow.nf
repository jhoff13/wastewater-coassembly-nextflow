//V4: Parse DF with splitCsv & pass tupled reads with map & groupTuple

/*********************
|   READ PROCESSING   |
**********************/

//takes in the library_DF and returns a list of all the unique cohort names for a list channel
process FEED_COHORTS {
  label "single"
  label "pandas"
  input:
    tuple val(sample_suffix), path(libraries), val(read_path) //clean this up eventually
  output:
     path('coassembly_master_DF.csv')
  shell:
      '''
      #!/usr/bin/env python3

      import pandas as pd
      import ast

      library_DF = pd.read_csv('!{libraries}')
      # DF processing:
      assert 'coassembly' in library_DF.columns and 'library' in library_DF.columns and len(library_DF.columns) == 2, \
          'Column names need to be "library" & "coassembly"'
      # convert str to list
      if type(library_DF.coassembly.iloc[0]) == str:
          library_DF.coassembly = library_DF.coassembly.apply(lambda x: ast.literal_eval(x))

      library_DF = library_DF.explode('coassembly')
      library_DF['fwd_reads'] = library_DF.library.str.replace('{1/2}','1',regex=True)
      library_DF['rev_reads'] = library_DF.library.str.replace('{1/2}','2',regex=True)
      library_DF = library_DF.reset_index(drop=True)
      library_DF.to_csv("coassembly_master_DF.csv",index=None)
      '''
}

//Cats reads from cohort_reads_ch
process CONCAT_READS {
  label "single"
  publishDir "${pubDir}/reads", mode: "symlink"
  input:
      each val(cohort) path("*1.fastq.gz"), path("*2.fastq.gz") //tuple?
      tuple val(sample_suffix), path(libraries), val(read_path)
  output:
      tuple env(sample), path("cat_*_1.fastq.gz"), path("cat_*_2.fastq.gz")
  shell:
      '''
      sample=$('cat_!{cohort}_!{sample_suffix}') #Check this syntax
      cat !{fwd_reads} > ${sample}_1.fastq.gz
      cat !{rev_reads} > ${sample}_1.fastq.gz
      '''
  }


/*****************
|   ASSEMBLERS   |
*****************/

process METASPADES {
    label "metaspades"
    label "large"
    publishDir "${params.pub_dir}", mode: "symlink"
    input:
        tuple val(sample), path(read1), path(read2)
    output:
        tuple val(sample), val('metaspades'), path("metaspades")
    shell:
        '''
        in1=!{read1}
        in2=!{read2}
        out=metaspades
        io="-1 ${in1} -2 ${in2}"
        par="-k {params.metaspades.k} -t !{task.cpus}"
        metaspades.py -1 ${in1} -2 ${in2} -k !{params.metaspades.k} -t !{task.cpus} -o ${out}
        '''
}

process MEGAHIT {
    label "megahit"
    label "large"
    publishDir "${params.pub_dir}", mode: "symlink"
    input:
        tuple val(sample), path(read1), path(read2)
    output:
        tuple val(sample), val('megahit'), path("megahit")
    shell:
        '''
        in1=!{read1}
        in2=!{read2}
        out=megahit
        io="-1 ${in1} -2 ${in2}"
        par="-k {params.megahit.k} -t !{task.cpus}"
        megahit -1 ${in1} -2 ${in2} --k-list !{params.megahit.k} -t !{task.cpus} -o ${out}
        '''
}

process QUAST {
    label "quast"
    label "small"
    publishDir "${params.pub_dir}", mode: "symlink"
    input:
      tuple val(sample), val(assembler), path(assembly)
    output:
      path("quast/${sample}_${assembler}_report")
    shell:
      '''
      out=quast/!{sample}_!{assembler}_report
      io="-s !{assembly}/scaffolds.fasta"
      par="--contig-thresholds 0,1000,2500 -t !{task.cpus}"
      quast.py ${par} ${io} -o ${out}
      '''
}

/*****************
| MAIN WORKFLOWS |
*****************/

Channel
  .of([params.sample_suffix, params.library_tab, params.raw_dir])
  .set{ lib_inputs_ch }

workflow {
  cohort_csv_ch = FEED_COHORTS(lib_inputs_ch)//.flatten() //is this functioning as a path?
  cohort_reads_ch = cohort_csv_ch
    .flatMap { file -> file.readLines() }
    .splitCsv( header: true )
    .map { row ->
        [row.coassembly, [file(row.fwd_reads), file(row.rev_reads)]] }
  cohort_reads_ch.view()
  //CONCAT_READS(cohort_reads_ch, lib_inputs_ch).set{assembly_inputs_ch}
  //METASPADES(assembly_inputs_ch).set{metaspades_out}
  //MEGAHIT(assembly_inputs_ch).set{megahit_out}
  //assembler_outputs = metaspades_out.mix(megahit_out)
  //QUAST(assembler_outputs)
  //SUMMARIZE_ASSEMBLY()
}
