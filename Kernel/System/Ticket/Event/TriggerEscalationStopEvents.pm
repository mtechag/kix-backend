# --
# Modified version of the work: Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Event::TriggerEscalationStopEvents;

use strict;
use warnings;

our @ObjectDependencies = (
    'Log',
    'Ticket',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Event UserID Config)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }
    for my $Needed (qw(OldTicketData TicketID)) {
        if ( !$Param{Data}->{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed in Data!"
            );
            return;
        }
    }

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Ticket');

    # get the current escalation status
    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Param{Data}->{TicketID},
        UserID        => $Param{UserID},
        DynamicFields => 0,
    );

    # compare old and the current escalation status
    my %Attr2Event = (
        FirstResponseTimeEscalation => 'EscalationResponseTimeStop',
        UpdateTimeEscalation        => 'EscalationUpdateTimeStop',
        SolutionTimeEscalation      => 'EscalationSolutionTimeStop',
    );

    while ( my ( $Attr, $Event ) = each %Attr2Event ) {

        if ( $Param{Data}->{OldTicketData}->{$Attr} && !$Ticket{$Attr} ) {

            # trigger the event
            $TicketObject->EventHandler(
                Event  => $Event,
                UserID => $Param{UserID},
                Data   => {
                    TicketID      => $Param{Data}->{TicketID},
                    OldTicketData => $Param{Data}->{OldTicketData},
                },
            );

            # log the triggered event in the history
            $TicketObject->HistoryAdd(
                TicketID     => $Param{Data}->{TicketID},
                HistoryType  => $Event,
                Name         => "%%$Event%%triggered",
                CreateUserID => $Param{UserID},
            );
        }
    }

    return 1;
}

1;




=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
