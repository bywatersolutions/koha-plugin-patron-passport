package Koha::Plugin::Com::ByWaterSolutions::PatronPassport;

use Modern::Perl;

use Mojo::JSON qw(decode_json to_json);

use base qw(Koha::Plugins::Base);

use Cwd qw(abs_path);
use Encode qw(decode);
use File::Slurp qw(read_file);
use Module::Metadata;

use C4::Auth;
use C4::Context;

our $VERSION         = "{VERSION}";
our $MINIMUM_VERSION = "{MINIMUM_VERSION}";

our $metadata = {
    name            => 'Patron Passport',
    author          => 'Kyle M Hall, ByWater Solutions',
    date_authored   => '2021-01-25',
    date_updated    => "1900-01-01",
    minimum_version => $MINIMUM_VERSION,
    maximum_version => undef,
    version         => $VERSION,
    description     => 'Allows separate instances of Koha to automatically import patrons from other Koha servers',
};

sub new {
    my ( $class, $args ) = @_;

    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    my $self = $class->SUPER::new($args);

    return $self;
}


sub install() {
    my ( $self, $args ) = @_;

    my $dbh = C4::Context->dbh;
    $dbh->do(q{INSERT IGNORE INTO `borrower_attribute_types` VALUES ('PASSPORTED','Imported from other ILS',0,0,0,0,0,'YES_NO',0,NULL,'',0,0)});
    return 1;
}

sub upgrade {
    my ( $self, $args ) = @_;
    return 1;
}

sub uninstall() {
    my ( $self, $args ) = @_;
    return 1;
}

sub api_routes {
    my ( $self, $args ) = @_;

    my $spec_str = $self->mbf_read('openapi.json');
    my $spec     = decode_json($spec_str);

    return $spec;
}

sub api_namespace {
    my ($self) = @_;

    return 'patron_passport';
}

1;
