
use Test;
use Freq;

BEGIN { plan tests => 4 }

my $testdoc1 = ' _3_ _2_ _9_ _3_ _6_ _2_ december _3_ _1_ _1_ _9_ _9_ _0_ monday home edition metro part b page _4_ column _4_ letters desk _2_ _3_ _9_ words vietnam ready for business in response to articles on vietnam seeking to rejoin the international economy front page dec _2_ _3_ _2_ _4_ your article getting back to business in vietnam was an excellent coverage for business purposes it did not however address the reason for the trade embargo with the welfare of the vietnamese people in mind due to loss of life suffered by the boat people who did not make it in addition to the cost of hard cash that the united states and other benevolent nations are contributing to care for those who made it no profit from any business could be justified as long as vietnam is still dotted with concentration camps and the people still risk their lives trying to escape at a time when communism is collapsing or already collapsed in many countries the vietnamese people would be betrayed by any attempt to shore up the shaky communist regime in hanoi there is enough proof as unveiled recently that socialism marxist style does not benefit the people but just a small group of party members practicing totalitarian dictatorship the american ideal of freedom and pursuit of happiness should not be further strained by greed and the chase for a fast buck there is plenty of business in the united states for the taker a few more years of patient pressure will result in a vietnam with freedom and democracy where people will take a boat out for fishing and not for escaping';

my $testdoc2 = 'december _3_ _1_ _1_ _9_ _9_ _0_ monday home edition metro part b page _4_ column _3_ letters desk _3_ _3_ words tagger arrest the only way we are ever going to end the nasty filthy graffiti problem is to come down hard on the idiots doing it i would be happy to contribute to a reward fund irv bush marina del rey letter to the editor';


my $index = Freq->open_write( 'testindex' );
ok( $index );

my $count = $index->index_document( 'test_doc_1', $testdoc1 );
ok( $count );

$count = $index->index_document( 'test_doc_2', $testdoc2 );
ok( $count );

my $retval = $index->close();
ok( $retval );

exit 0;

