package Freq;

require 5.005_62;
use strict;
use warnings;
use vars qw( $VERSION );

$VERSION = '0.14';

use Fcntl;
use FileHandle;
use Freq::Isr;
use CDB_File;

# Constants for data about each word.
use constant NWORDS => 0;
use constant DATA   => 1;
use constant NDOCS  => 2;
use constant SIGMA  => 3; # Standard deviation of matches/document.

sub open_write {
	my $type = shift;
	my $path = shift; # Name of index (directory).

	my $self = {};

	if( -e "$path/conf" ){

		# Read in conf file.
		$self = _configure($path);

		my %cdb;
		tie %cdb, 'CDB_File', "$path/CDB" or die $!;
		$self->{cdb} = \%cdb;

		$self->{ids} = FileHandle->new(">>$path/ids");

		$self->{name} = $path;
		$self->{mem_isr_size} = 0;
		$self->{mem_isrs} = {}; 
		$self->{mode} = 'WRONLY';
	}
	else {		
		# Set up a default configuration.

		mkdir $path;

		$self = {
			name => $path,
			mem_isr_max_size => 10 * 1024 * 1024, # 1 m words
			mem_isr_size => 0,
			size => 0,
			mem_isrs => {},
			mode => 'WRONLY',
			ids => FileHandle->new(">$path/ids"),
			# What else?
		};

	}

	return bless $self, $type;
}

sub open_read {
	my $type = shift;
	my $path = shift;

	my $self = {};

	if( -e "$path/conf" ){
		$self = _configure($path);

		my %cdb;
		tie %cdb, 'CDB_File', "$path/CDB" or die $!;
		$self->{cdb} = \%cdb;

		open(IDS, "<$path/ids") or die $!;
		chomp( @{ $self->{ids} } = <IDS> );
		close IDS;

		$self->{name} = $path;
		$self->{mem_isr_size} = 0;
		$self->{mem_isrs} = {};
		$self->{mode} = 'RDONLY';
	}
	else {
		warn "Index $path does not exist\n";
		return undef;
	}

	return bless $self, $type;
}



sub close {
	my $self = shift;

	if( $self->{mode} eq 'WRONLY' ){
		$self->_flush_isrs();
		$self->_write_meta();
		$self->{ids}->close();
	}

	untie %{ $self->{cdb} };

	return 1;
}


sub _flush_isrs {
	my $self = shift;
	my $path = $self->{name};
	my $mem_isrs = $self->{mem_isrs};

	my $new = new CDB_File("$path/NEW", "$path/CDB.tmp") or 
		die "$0: new CDB_File failed: $!\n";

#debug 
#my $flush_count = 0;

	# Fold in everything from previous ISR file.
	if( -e "$path/CDB" ){

		for my $word ( keys %{ $self->{cdb} } ){


#debug
#if( (++$flush_count) % 50 == 0 ){
#	print STDERR chr(13), "(", $flush_count, ")\t\t";
#}



			my $isr = _read_isr($self, $word);
			my $newisr = '';

			my $old_length = $isr->[NWORDS];
			my $old_doc_count = $isr->[NDOCS];

			my ($additional_length, 
				$additional_data, 
				$additional_docs) = 
					exists $mem_isrs->{$word} ?
						($mem_isrs->{$word}->[NWORDS], 
						\$mem_isrs->{$word}->[DATA],
						$mem_isrs->{$word}->[NDOCS]) :
							(0, \'', 0);

			my $new_length = $old_length + $additional_length;
			my $new_doc_count = $old_doc_count + $additional_docs;


			$newisr .= pack "L", $new_length;
			$newisr .= pack "L", $new_doc_count;
			$newisr .= pack "f", 0; # obselete sigma value

			# concatenate and print
			$newisr .= $isr->[DATA];
			$newisr .= $$additional_data;

			$new->insert($word, $newisr);

		delete $mem_isrs->{ $word };

		}

		unlink "$path/CDB";

	}

#debug
#print STDERR "\nFolded $flush_count isrs from disk\n";
#$flush_count = 0;

	# Now flush all mem_isrs of words that are new this run.
	for my $word ( keys %{ $mem_isrs } ){


#debug
#if( (++$flush_count) % 50 == 0 ){
#	print STDERR chr(13), "(", $flush_count, ")\t\t";
#}


		next unless $word;
		my $newisr = '';
	
		$newisr .= pack "L", $mem_isrs->{$word}->[NWORDS]; # num of positions.
		$newisr .= pack "L", $mem_isrs->{$word}->[NDOCS];# num of docs
		$newisr .= pack("f", 0); # placeholder for sigma
		$newisr .= $mem_isrs->{$word}->[DATA]; # Positions themselves.

		$new->insert($word, $newisr);

	}
	%{ $mem_isrs } = ();
	$self->{mem_isr_size} = 0;

	$new->finish or die $!;

	untie %{ $self->{cdb} };
	rename "$path/NEW", "$path/CDB";
	tie %{ $self->{cdb} }, 'CDB_File', "$path/CDB";

#debug
#print STDERR "\nFinished flushing $flush_count mem_isrs.\n";

	return 1;
}

# _read_isr returns a reference to an isr structure, an array of
# 0:count of entries, 1:the entries, packed integers in a string.
# Isrs are cached in $self->{'mem_isrs'}.
sub _read_isr {
	my $self = shift;
	my $word = shift;
	my $cdb = $self->{cdb};

	# return the empty isr if no occurrence.
	return [0, '', 0, 0] unless exists $cdb->{$word};

	my $isr = [];
	my $ISR = $cdb->{$word};

	my $length =     unpack "L", substr($ISR, 0, 4);
	my $docs_count = unpack "L", substr($ISR, 4, 4);
	my $sigma =      0;
	substr($ISR, 0, 12) = '';

#print STDERR "position = $pos, length = $length\n";
	$isr->[NWORDS] = $length;
	$isr->[NDOCS] = $docs_count;
	$isr->[SIGMA] = $sigma;
	$isr->[DATA]  = $ISR;


#$isr->[4] = "OLDSTYLEISR";
	return $isr;
}

# Now returns CIsr structures, yay!
sub _cache_isr {
	my $self = shift;
	my $word = shift;

	# purge something from the cache if there are too many isrs.
	if( 100 < scalar (keys %{ $self->{mem_isrs} }) ){
		print STDERR chr(13), "Purging isrs.";
		my $tmp = $self->{mem_isrs}->{_eof_};
		my @keys = (keys %{ $self->{mem_isrs} });
		for ( @keys ){
		#	$self->{'mem_isrs'}->{ $_ }->DESTROY();
			delete $self->{mem_isrs}->{ $_ };
		} 
		$self->{mem_isrs}->{_eof_} = $tmp;
	}

	my $cisr;
	if( !exists $self->{cdb}->{$word} ){
		$cisr = undef;
	}
	elsif( !exists $self->{mem_isrs}->{$word} ){
		my $isr = _read_isr( $self, $word );
		$cisr = Freq::Isr->new( $isr->[DATA], $isr->[NDOCS] );
		$self->{mem_isrs}->{$word} = $cisr;
	}
	else {
		$cisr = $self->{mem_isrs}->{$word};
	}

	return $cisr;
}

sub index_document {
	my $self = shift;
	my $doc_name = shift;
	my $document = shift;
	my $position = $self->{size};
	my $mem_isrs = $self->{mem_isrs};
	my $mem_isr_size = $self->{mem_isr_size};
	my $words_this_doc = 0;
	my %seen_in_doc = ();

	for my $word ( split /\W+/, $document ){
		$mem_isrs->{$word}->[NWORDS]++;
		$mem_isrs->{$word}->[DATA] .= pack "L", $position++;
		$mem_isrs->{$word}->[NDOCS]++ unless exists $seen_in_doc{$word};
		$seen_in_doc{$word} = 1;
		$mem_isr_size++;
		$words_this_doc++;
	}
	$mem_isrs->{_eof_}->[NWORDS]++;
	$mem_isrs->{_eof_}->[DATA] .= pack "L", $position;
	$mem_isrs->{_eof_}->[NDOCS]++;
	$self->{ids}->print("$doc_name\n");

	$self->{size} = $position;
	$self->{mem_isr_size} = $mem_isr_size;
	
	if( $mem_isr_size >= $self->{mem_isr_max_size} ){
		$self->_flush_isrs();
		$self->_write_meta();
	}
	return $words_this_doc;
}


sub _configure {
	my $path = shift;
	my $self = {};	

	# File "conf" contains mem_isr_max_size, size.

	open CONF, "<$path/conf";
	while(<CONF>){
		next if m|^#|;
		chomp;
		my ($key, $value) = split m|:|;
		$self->{$key} = $value;
	}
	CORE::close CONF;

	return $self;
}


sub _write_meta {
	my $self = shift;
	my $name = $self->{name};

	open CONF, ">$name/conf";
	binmode CONF;
	print CONF 'mem_isr_max_size:', $self->{mem_isr_max_size}, "\n";
	print CONF "# DO NOT EDIT BELOW THIS LINE\n";
	print CONF 'size:', $self->{size}, "\n";
	CORE::close CONF;

	return 1;
}



sub stats {
	my $self = shift;
	my $term = shift;
	
	my $docs_hash = $self->doc_hash($term);

	return (0, 0, 0, 0) unless $docs_hash->{MATCHES}; 

	my $doc_sigma = Freq::Isr::_doc_sigma($docs_hash->{MATCHES}, 
								$docs_hash->{DOCMATCHES} );

	my $term_sigma = Freq::Isr::_term_sigma($docs_hash->{MATCHES},
									$self->{size},
									$docs_hash->{INTERVALS} );

	return ($docs_hash->{MATCHES}, 
			scalar @{$docs_hash->{DOCIDS}},
			$doc_sigma,
			$term_sigma);
}


# Returns size in words and documents.
sub index_info {
	my $self = shift;

	my $eof_isr = $self->_cache_isr('_eof_');
	return ( $self->{size},
			 $eof_isr->length
			);
}

# Return the hash of docno -> per doc termcount.
# This is a hash of lists. 
sub doc_hash {
	my $self = shift;
	my $term = shift;
	my $_eof_ = $self->_cache_isr('_eof_');
	my $docs_hash;

	if($term =~ m|\s|){
		my @terms = split(/\s/, $term);
		my @term_isrs = ();
		for my $t (@terms){
			my $cisr = $self->_cache_isr($t);
			return {} unless $cisr;
			push @term_isrs, $cisr;
		}
		$docs_hash = $_eof_->_doc_hash_multiword( @term_isrs );
	}
	else {
		my $cisr = $self->_cache_isr( $term );
		return {} unless $cisr;
		$docs_hash = $_eof_->_doc_hash_singleword( $cisr );
	}

	@{ $docs_hash->{DOCIDS} } = 
		map { $self->{ids}->[$_] } 
			@{ $docs_hash->{DOCIDS} };

	return $docs_hash;
}


1;

=pod

=head1 NAME

Freq - A purpose-built inverted text index for making term frequency calculations.

=head1 SYNOPSIS

Index documents:

  # cat textcorpus.txt | tokenize | indexstream corpus_dir

Create ngram list:

  # cat textcorpus.txt | tokenize | ngrams [N-size] [threshold] 

Get statistics on word frequencies:

  # cat termlist.txt | stats --everything corpus_dir

Get help:

  # tokenize --help
  # stats --help
  # indexstream --help
  # ngrams --help

=head1 PROGRAMMING API

  use Freq;

  $index = Freq->open_write( "indexname" );
  $index->index_document( "docname", $string );
  $index->close();

  $index = Freq->open_read( "indexname" );
  my ( $words_in_corpus, $docs_in_corpus ) = $index->index_info();

  # Find all docs containing a phrase
  $hashref = $index->doc_hash( "this phrase and no other phrase" );

  # Total number of matches for this phrase/word.
  my $matches = $hashref->{MATCHES};

  # The consecutive ID of each document.
  my @docids = @{ $hashref->{DOCIDS} };

  # The number of matches found in each document.
  my @docmatches = @{ $hashref->{DOCMATCHES} };

  # The number of words between each consecutive match.
  my @intervals = @{ $hashref->{INTERVALS} };

  # Get matches, doc count, standard deviation of terms/document, standard deviation of intervals/match.
  my ($matches, $doc_count, $docsigma, $intsigma ) = 
		$index->stats("some phrase or other");

  $index->close();

=head1 DESCRIPTION

Blah blah blah.

=head2 EXPORT

None. Use programming API as shown.


=head1 AUTHOR

Ira Joseph Woodhead, ira@ejemoni.com

=head1 SEE ALSO

DBIx::FullTextSearch, Search::InvertedIndex

=cut

