use 5.008005;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Freq',
    VERSION_FROM      => 'lib/Freq.pm', # finds $VERSION
    PREREQ_PM         => { CDB_File => 0.01 }, # actually later
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Freq.pm', # retrieve abstract from module
       AUTHOR         => 'Ira Woodhead <ira at sweetpota dot to') : ()),
);
