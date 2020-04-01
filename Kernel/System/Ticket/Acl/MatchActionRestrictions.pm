# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Ticket::Acl::MatchActionRestrictions;

use strict;
use warnings;

our @ObjectDependencies = (
    'Config',
    'Log',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # create required objects
    $Self->{ConfigObject} = $Kernel::OM->Get('Config');
    $Self->{LogObject}    = $Kernel::OM->Get('Log');

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get required params...
    for (qw(Config Acl)) {
        if ( !$Param{$_} ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    # get ticket data match properties and restricted ticket actions
    my $RestrictionDataRef
        = $Self->{ConfigObject}->Get('Match::ExcludedAction') || '';
    return if ( !$RestrictionDataRef || ref($RestrictionDataRef) ne 'HASH' );

    # build ACL for each restriction
    my $Counter = 1;
    for my $CurrRestriction ( keys %{$RestrictionDataRef} ) {
        next if !$CurrRestriction;
        next if !$RestrictionDataRef->{$CurrRestriction};

        # build ticket data restriction as hash with array references (e.g. Type => ['default'], Queue => ['Raw'])
        my %PropertiesTicket;
        my @MatchRestrictions = split( '\|\|\|', $CurrRestriction );
        for my $Criteria (@MatchRestrictions) {
            my @MatchRestriction = split( ':::', $Criteria );
            if ( $MatchRestriction[0] && $MatchRestriction[1] ) {
                my @MatchValues = split( ';', $MatchRestriction[1] );
                $PropertiesTicket{ $MatchRestriction[0] } = \@MatchValues;
            }
        }

        # build blacklist as hash with array references (e.g. Type => ['default'], Queue => ['Raw'])
        my @TicketActions = split( ';', $RestrictionDataRef->{$CurrRestriction} );
        if (scalar @TicketActions) {
            $Param{Acl}->{ '803_MatchActionRestrictions' . $Counter } = {
                Properties => {
                    Ticket => \%PropertiesTicket,
                },
                PossibleNot => {
                    Action => \@TicketActions,
                },
            };
        }
        $Counter++;
    }

    return 1;
}

1;




=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
