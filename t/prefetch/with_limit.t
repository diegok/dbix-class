# Test to ensure we get a consistent result set wether or not we use the
# prefetch option in combination rows (LIMIT).
use strict;
use warnings;

use Test::More;
use Test::Exception;
use lib qw(t/lib);
use DBICTest;
use DBIC::SqlMakerTest;

my $schema = DBICTest->init_schema();


my $no_prefetch = $schema->resultset('Artist')->search(
  [   # search deliberately contrived
    { 'artwork.cd_id' => undef },
    { 'tracks.title' => { '!=' => 'blah-blah-1234568' }}
  ],
  { rows => 3, join => { cds => [qw/artwork tracks/] },
 }
);

my $use_prefetch = $no_prefetch->search(
  {},
  {
    select => ['me.artistid', 'me.name'],
    as => ['artistid', 'name'],
    prefetch => 'cds',
    order_by => { -desc => 'name' },
  }
);

is($no_prefetch->count, $use_prefetch->count, '$no_prefetch->count == $use_prefetch->count');
is(
  scalar ($no_prefetch->all),
  scalar ($use_prefetch->all),
  "Amount of returned rows is right"
);

my $artist_many_cds = $schema->resultset('Artist')->search ( {}, {
  join => 'cds',
  group_by => 'me.artistid',
  having => \ 'count(cds.cdid) > 1',
})->first;


$no_prefetch = $schema->resultset('Artist')->search(
  { artistid => $artist_many_cds->id },
  { rows => 1 }
);

$use_prefetch = $no_prefetch->search ({}, { prefetch => 'cds' });

my $normal_artist = $no_prefetch->single;
my $prefetch_artist = $use_prefetch->find({ name => $artist_many_cds->name });
my $prefetch2_artist = $use_prefetch->first;

is(
  $prefetch_artist->cds->count,
  $normal_artist->cds->count,
  "Count of child rel with prefetch + rows => 1 is right (find)"
);
is(
  $prefetch2_artist->cds->count,
  $normal_artist->cds->count,
  "Count of child rel with prefetch + rows => 1 is right (first)"
);

is (
  scalar ($prefetch_artist->cds->all),
  scalar ($normal_artist->cds->all),
  "Amount of child rel rows with prefetch + rows => 1 is right (find)"
);
is (
  scalar ($prefetch2_artist->cds->all),
  scalar ($normal_artist->cds->all),
  "Amount of child rel rows with prefetch + rows => 1 is right (first)"
);

throws_ok (
  sub { $use_prefetch->single },
  qr/resultsets prefetching has_many/,
  'single() with multiprefetch is illegal',
);

my $artist = $use_prefetch->search({'cds.title' => $artist_many_cds->cds->first->title })->next;
is($artist->cds->count, 1, "count on search limiting prefetched has_many");

# try with double limit
my $artist2 = $use_prefetch->search({'cds.title' => { '!=' => $artist_many_cds->cds->first->title } })->slice (0,0)->next;
is($artist2->cds->count, 2, "count on search limiting prefetched has_many");

# make sure 1:1 joins do not force a subquery (no point to exercise the optimizer, if at all available)
# get cd's that have any tracks and their artists
my $single_prefetch_rs = $schema->resultset ('CD')->search (
  { 'me.year' => 2010, 'artist.name' => 'foo' },
  { prefetch => ['tracks', 'artist'], rows => 15 },
);
is_same_sql_bind (
  $single_prefetch_rs->as_query,
  '(
    SELECT
        me.cdid, me.artist, me.title, me.year, me.genreid, me.single_track,
        tracks.trackid, tracks.cd, tracks.position, tracks.title, tracks.last_updated_on, tracks.last_updated_at, tracks.small_dt,
        artist.artistid, artist.name, artist.rank, artist.charfield
      FROM (
        SELECT
            me.cdid, me.artist, me.title, me.year, me.genreid, me.single_track
          FROM cd me
          JOIN artist artist ON artist.artistid = me.artist
        WHERE ( ( artist.name = ? AND me.year = ? ) )
        LIMIT 15
      ) me
      LEFT JOIN track tracks
        ON tracks.cd = me.cdid
      JOIN artist artist
        ON artist.artistid = me.artist
    WHERE ( ( artist.name = ? AND me.year = ? ) )
    ORDER BY tracks.cd
  )',
  [
    [ 'artist.name' => 'foo' ],
    [ 'me.year'     => 2010  ],
    [ 'artist.name' => 'foo' ],
    [ 'me.year'     => 2010  ],
  ],
  'No grouping of non-multiplying resultsets',
);

done_testing;
