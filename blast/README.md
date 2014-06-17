# Blast Workflow Example

* See also [Blast Benchmark](http://fiehnlab.ucdavis.edu/staff/kind/Collector/Benchmark/Blast_Benchmark)

# Requirement
* Obtain Blast programs from [here](ftp://ftp.ncbi.nih.gov/blast/executables/LATEST) and put programs to your path.
* Obtain Blast benchmark files [here](ftp://ftp.ncbi.nih.gov/blast/demo/benchmark/benchmark2013.tar.gz) (1.8GB)

# Obtain workflow
        $ git clone https://github.com/masa16/pwrake-demo.git
        $ cd pwrake-demo/blast

# Obtain database
        $ wget ftp://ftp.ncbi.nih.gov/blast/demo/benchmark/benchmark2013.tar.gz
        $ tar tvf benchmark2013.tar.gz --strip-components=1 --exclude='n?.01.*'

# Run Workflow
        $ pwrake
