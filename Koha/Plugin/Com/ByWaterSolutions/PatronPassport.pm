package Koha::Plugin::Com::ByWaterSolutions::PatronPassport;

use Modern::Perl;

use Mojo::JSON qw(decode_json to_json);

use base qw(Koha::Plugins::Base);

use Cwd qw(abs_path);
use Encode qw(decode);
use File::Slurp qw(read_file);
use YAML::XS;

use HTTP::Request::Common;
use LWP::UserAgent;
use Parallel::Loops;
use Try::Tiny;

use C4::Auth;
use C4::Context;
use Koha::Patrons;
use Koha::Patron::Attribute::Types;
use Koha::Patron::Attributes;

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

    # we only want to look up externally if we are at the checkout screen
    my ($package, $filename, $line) = caller 3;
    return unless $filename =~ /circulation.pl$/;

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

            my $request;
            my $url = "$address/api/v1/contrib/patron_passport/patron/check/$cardnumber";
            try {
                $request = GET $url;
            }
            catch {
                warn "caught error: $_";
            };

            $request->authorization_basic( $username, $password );

            my $response = $ua->request($request);
            push(
                @returnValues,
                {
                    server   => $_,
                    response => $response,
                }
            );
        }
    );

    my $patron_data;
    my $server;
    foreach my $d (@returnValues) {
        my $r = $d->{response};
        if ( $r->is_success && $r->code eq '200' ) {
            $patron_data = decode_json( $d->{response}->decoded_content );
            $server = $d->{server};
            last;
        }
    }

    my $settings = { map { $_->{name} => $_->{value} } @{ $conf->{setting} } };

    delete $patron_data->{borrowernumber};

    $patron_data->{branchcode} = $settings->{default_branchcode}
      if $settings->{default_branchcode};
    $patron_data->{categorycode} = $settings->{default_categorycode}
      if $settings->{default_categorycode};

    $patron_data->{branchcode} =
        C4::Context->userenv
      ? C4::Context->userenv->{'branch'}
      : $patron_data->{branchcode}
      if $settings->{use_logged_in_branchcode};

    try {
        my $patron = Koha::Patron->new($patron_data)->store();
        $patron->add_extended_attribute({ code => 'PASSPORTED', attribute => $server->{name} });
    }
    catch {
        warn "caught error: $_";
    };
}

sub cronjob_nightly {
    my ( $self ) = @_;

    my $conf    = C4::Context->config('patron_passport');
    my $servers = { map { $_->{name} => $_ } @{ $conf->{servers}->{server}  } };
    my $settings = { map { $_->{name} => $_->{value} } @{ $conf->{setting} } };

    my $attrs = Koha::Patron::Attributes->search({ code => 'PASSPORTED' }); 
    while ( my $a = $attrs->next ) {
        next unless $a->attribute;

        my $server = $servers->{$a->attribute};
        next unless $server;

        my $patron = Koha::Patrons->find( $a->borrowernumber );
        next unless $patron;

        my $ua = LWP::UserAgent->new();

        my $address  = $server->{address};
        my $username = $server->{username};
        my $password = $server->{password};

        my $cardnumber = $patron->cardnumber;

        my $request;
        my $url = "$address/api/v1/contrib/patron_passport/patron/check/$cardnumber";
        try {
            $request = GET $url;
        }
        catch {
            warn "caught error: $_";
        };

        $request->authorization_basic( $username, $password );

        my $response = $ua->request($request);
        next unless $response->is_success && $response->code eq '200';

        my $patron_data = decode_json( $response->decoded_content );
        delete $patron_data->{borrowernumber};
        delete $patron_data->{categorycode};
        $patron->update($patron_data);
    }
}

sub install {
    my ( $self, $args ) = @_;

    my $attribute_type = Koha::Patron::Attribute::Types->find('PASSPORTED');
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

sub uninstall {
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
