
use Test::More tests => 10;
use Freq;

my $index = Freq->open_read( 'testindex' );
ok( $index, 'index opened for reading' );

my $theisr = Freq::isr('the');

my $result = $index->search('the');
is_deeply( $result, 
           { 'test_doc_2' => [
                            25,
                            34,
                            45,
                            66
                          ],
             'test_doc_1' => [
                            44,
                            74,
                            77,
                            81,
                            84,
                            96,
                            107,
                            113,
                            148,
                            170,
                            182,
                            202,
                            215,
                            232,
                            244,
                            248
                          ]
        },
           'single-word search results correct');

$result = $index->search('the only');
is_deeply( $result, { test_doc_2 => [25] }, 
           'two adjacent words query correct'); 
 
$result = $index->search('the only way we are ever');
is_deeply( $result, { test_doc_2 => [25] }, 
           'multiple adjacent words query correct'); 

$result = $index->search('the #w3 we #w2 ever');
is_deeply( $result, { test_doc_2 => [25] }, 
           'multiple #w query correct'); 
 
$result = $index->search('the * * we * ever');
is_deeply( $result, { test_doc_2 => [25] }, 
           'multiple wildcard query correct'); 

$result = $index->search('the * * * we * ever');
ok( (keys %$result) == 0, 
           'multiple wildcard incorrect query incorrect'); 

$result = $index->search('the * * we #w2 ever');
is_deeply( $result, { test_doc_2 => [25] }, 
           'wildcard + #w query correct'); 
 
$result = $index->search('grand poobah');
ok( (keys %$result) == 0, 
           'nonexistent words query correct'); 

my $retval = $index->close_index();
ok( $retval, 'index closed' );


exit 0;

