use Inline::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteInlineMakefile(
    'NAME'		=> 'Freq',
    'VERSION_FROM'	=> 'Freq.pm', # finds $VERSION
    'PREREQ_PM'		=> { Inline => '0.30',
						 Fcntl => '1.00',
#						 Bloom16 => '0.01',
						 CDB_File => '0.01', #actually leter but...
						 },
	'INSTALLSCRIPT'	=> '/usr/local/bin',
	'EXE_FILES'		=> [ 	'bin/stats', 
							'bin/tokenize', 
							'bin/indexstream',
							'bin/ngrams',
							'bin/stopstop',
							'bin/freqprime' ]

	);
