package Koha::Plugin::Com::ByWaterSolutions::PatronPassport::ApiController;

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# This program comes with ABSOLUTELY NO WARRANTY;

use Modern::Perl;

use Mojo::Base 'Mojolicious::Controller';
use Try::Tiny;

use Koha::Patrons;

sub check {
    my $c = shift->openapi->valid_input or return;

    my $cardnumber = $c->param('cardnumber');

    return try {

        my $patron = $c->objects->find_rs( Koha::Patrons->new, { cardnumber => $cardnumber } );

        unless ($patron) {
            return $c->render(
                status  => 404,
                openapi => { error => 'Patron not found' }
            );
        }

        my $attr = $patron->extended_attributes->search( { code => 'PASSPORTED' } )->single;

        if ( $attr && $attr->attribute ) {    ## This patron is a clone and should not be returned
            return $c->render(
                status  => 404,
                openapi => { error => "Patron not found" }
            );
        }

        return $c->render(
            status  => 200,
            openapi => $c->objects->to_api($patron),
        );
    } catch {
        $c->unhandled_exception($_);
    };
}

1;
