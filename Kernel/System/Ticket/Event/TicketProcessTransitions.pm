# --
# Modified version of the work: Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Event::TicketProcessTransitions;

use strict;
use warnings;

our @ObjectDependencies = (
    'Config',
    'Log',
    'ProcessManagement::Process',
    'Ticket',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{Debug} = 0;

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Data Event Config UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    # listen to all kinds of events
    if ( !$Param{Data}->{TicketID} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need TicketID in Data!",
        );
        return;
    }

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Ticket');

    my $CacheKey = '_TicketProcessTransitions::AlreadyProcessed';

    # loop protection: only execute this handler once for each ticket, as multiple events may be
    #   fired, for example TicketTitleUpdate and TicketPriorityUpdate.
    return if ( $TicketObject->{$CacheKey}->{ $Param{Data}->{TicketID} } );

    # get ticket data in silent mode, it could be that the ticket was deleted
    #   in the meantime.
    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Param{Data}->{TicketID},
        DynamicFields => 1,
        Silent        => 1,
    );

    if ( !%Ticket ) {

        # remember that the event was executed for this TicketID to avoid multiple executions.
        #   Store the information on the ticketobject
        $TicketObject->{$CacheKey}->{ $Param{Data}->{TicketID} } = 1;

        return;
    }

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Config');

    my $ProcessIDField  = $ConfigObject->Get("Process::DynamicFieldProcessManagementProcessID");
    my $ProcessEntityID = $Ticket{"DynamicField_$ProcessIDField"};

    my $ActivityIDField  = $ConfigObject->Get("Process::DynamicFieldProcessManagementActivityID");
    my $ActivityEntityID = $Ticket{"DynamicField_$ActivityIDField"};

    # ticket can be ignored if it is no process ticket. Don't set the cache key in this case as
    #   later events might make a transition check neccessary.
    return if ( !$ProcessEntityID || !$ActivityEntityID );

    # ok, now we know that we need to call the transition logic for this ticket.

    # get process object
    my $ProcessObject = $Kernel::OM->Get('ProcessManagement::Process');

    # Remember that the event was executed for this ticket to avoid multiple executions.
    #   Store the information on the ticketobject, this needs to be done before the execution of the
    #   transitions as it could happen that the transition generates new events that will be
    #   processed in the mean time, before the chache is set, see bug#9748
    $TicketObject->{$CacheKey}->{ $Param{Data}->{TicketID} } = 1;

    my $TransitionApplied = $ProcessObject->ProcessTransition(
        ProcessEntityID  => $ProcessEntityID,
        ActivityEntityID => $ActivityEntityID,
        TicketID         => $Param{Data}->{TicketID},
        UserID           => $Param{UserID},
    );

    if ( $Self->{Debug} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message =>
                "Transition for to TicketID: $Param{Data}->{TicketID}"
                . "  ProcessEntityID: $ProcessEntityID OldActivityEntityID: $ActivityEntityID "
                . ( $TransitionApplied ? "was applied." : "was not applied." ),
        );
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
