# Montage workflow written in Rakefile

## Montage Installation

* Download Montage Version 3.3 from [Montage download page](http://montage.ipac.caltech.edu/docs/download.html).

        $ wget https://github.com/masa16/pwrake-demo/archive/master.tar.gz -O pwrake-demo-master.tar.gz
        $ tar xzf pwrake-demo-master.tar.gz
        $ tar xzf Montage_v3.3.tar.gz
        $ cd Montage_v3.3
        $ patch -p1 <../pwrake-demo-master/Montage_v3.3.patch
        $ make
        $ cp bin/* [somewhere_in_your_path]

## Running Montage with Montage tutorial files

[Montage Tutorial](http://montage.ipac.caltech.edu/docs/m101tutorial.html)
Download and Extract files

        $ wget http://montage.ipac.caltech.edu/docs/m101Example/tutorial-initial.tar.gz
        $ tar xzf pwrake-demo-master.tar.gz
        $ cd pwrake-demo-master/montage
        $ tar xvzf ../../tutorial-initial.tar.gz
        m101/
        m101/rawdir/
        m101/rawdir/2mass-atlas-990214n-j1100244.fits
        m101/rawdir/2mass-atlas-990214n-j1100256.fits
        m101/rawdir/2mass-atlas-990214n-j1110021.fits
        m101/rawdir/2mass-atlas-990214n-j1110032.fits
        m101/rawdir/2mass-atlas-990214n-j1180244.fits
        m101/rawdir/2mass-atlas-990214n-j1180256.fits
        m101/rawdir/2mass-atlas-990214n-j1190021.fits
        m101/rawdir/2mass-atlas-990214n-j1190032.fits
        m101/rawdir/2mass-atlas-990214n-j1200244.fits
        m101/rawdir/2mass-atlas-990214n-j1200256.fits
        m101/template.hdr
        m101/projdir/
        m101/diffdir/
        m101/corrdir/
        m101/final/

Prepare Workflow

        $ rake -f Rakefile.prepare INPUT_DIR=m101/rawdir REGION_HDR=m101/template.hdr

Run Workflow

        $ pwrake INPUT_DIR=m101/rawdir REGION_HDR=m101/template.hdr

Remove Intermediate files

        $ rake -f Rakefile.clean clean   # remove workflow-phase files
        $ rake -f Rakefile.clean clobber # remove workflow-and-prepare-phase files

## Option files to edit

* pwrake_conf.yaml
* hosts
* params.rb
* tile_param.rb
