
use Test;
use Freq;

BEGIN { plan tests => 10 }

my $index = Freq->open_read( 'testindex' );
ok( $index );

my( $words_in_corpus, $docs_in_corpus ) = $index->index_info();
ok( $words_in_corpus );
ok( $docs_in_corpus );
#print STDERR "Words: $words_in_corpus\nDocs: $docs_in_corpus\n";

my @termstats = $index->stats( 'the' );

ok( $termstats[0] == 20 );
ok( $termstats[1] == 1 );
for( @termstats ){
	ok( $_ );
}

#print STDERR "Stats: ", join("\t", @termstats), "\n";

my $retval = $index->close();
ok( $retval );

unlink "testindex/CDB";
unlink "testindex/conf";
unlink "testindex/ids";
rmdir "testindex";

exit 0;

