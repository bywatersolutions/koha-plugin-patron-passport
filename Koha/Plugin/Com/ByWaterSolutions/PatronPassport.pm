package Koha::Plugin::Com::ByWaterSolutions::PatronPassport;

use Modern::Perl;

use Mojo::JSON qw(decode_json to_json);

use base qw(Koha::Plugins::Base);

use Cwd qw(abs_path);
use Encode qw(decode);
use File::Slurp qw(read_file);
use YAML::XS;

use Parallel::Loops;
use LWP::UserAgent;
use HTTP::Request::Common;

use C4::Auth;
use C4::Context;
use Koha::Patron::Attribute::Type;

our $VERSION         = "{VERSION}";
our $MINIMUM_VERSION = "{MINIMUM_VERSION}";

our $metadata = {
    name            => 'Patron Passport',
    author          => 'Kyle M Hall, ByWater Solutions',
    date_authored   => '2021-02-03',
    date_updated    => "1900-01-01",
    minimum_version => $MINIMUM_VERSION,
    maximum_version => undef,
    version         => $VERSION,
    description =>
'Enable separate instances of Koha to automatically import patrons from other Koha servers',
};

sub new {
    my ( $class, $args ) = @_;

    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    my $self = $class->SUPER::new($args);

    return $self;
}

sub patron_barcode_transform {
    my ( $self, $cardnumber_ref ) = @_;

    my $cardnumber = $$cardnumber_ref;

    my $patron = Koha::Patrons->search(
        {
            -or => [
                cardnumber => $cardnumber,
                userid     => $cardnumber,
            ]
        }
    )->single;

    return if $patron;    # Patron exists

    my $conf    = C4::Context->config('patron_passport');
    my $servers = $conf->{servers}->{server};
    warn Data::Dumper::Dumper($servers);

    my $pl = Parallel::Loops->new(99);
    my @returnValues;
    $pl->share( \@returnValues );

    $pl->foreach(
        $servers,
        sub {
            my $ua = LWP::UserAgent->new();

            my $address  = $_->{address};
            my $username = $_->{username};
            my $password = $_->{password};

            my $request = GET "$address/api/v1/libraries";

            $request->authorization_basic( $username, $password );

            my $response = $ua->request($request);
            warn $response->as_string();
            push(
                @returnValues,
                {
                    server => $_,
                    response => $response,
                }
            );
        }
    );

    my $data;
    foreach my $d ( @returnValues ) {
        my $r = $d->{response};
        if ( $r->is_success && $r->code eq '200' ) {
            my $patron = decode_json( $d->{response}->decoded_content );
            warn "PATRON: " . Data::Dumper::Dumper( $patron );
        }
    }
}

sub install() {
    my ( $self, $args ) = @_;

    my $attribute_type = Koha::Patron::Attribute::Type->find('PASSPORTED');
    Koha::Patron::Attribute::Type->new(
        {
            code        => 'PASSPORTED',
            description => 'ILS patron was imported from',
        }
    )->store()
      unless $attribute_type;

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

    my $spec_str = $self->mbf_read('openapi.yaml');
    my $spec     = Load($spec_str);

    return $spec;
}

sub api_namespace {
    my ($self) = @_;

    return 'patron_passport';
}

1;
