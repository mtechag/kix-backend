# --
# Modified version of the work: Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ProcessManagement::TransitionAction::TicketStateSet;

use strict;
use warnings;
use utf8;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::ProcessManagement::TransitionAction::Base);

our @ObjectDependencies = (
    'Log',
    'State',
    'Ticket',
    'Time',
);

=head1 NAME

Kernel::System::ProcessManagement::TransitionAction::TicketStateSet - A module to set the ticket state

=head1 SYNOPSIS

All TicketStateSet functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $TicketStateSetObject = $Kernel::OM->Get('ProcessManagement::TransitionAction::TicketStateSet');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item Run()

    Run Data

    my $TicketStateSetResult = $TicketStateSetActionObject->Run(
        UserID                   => 123,
        Ticket                   => \%Ticket,   # required
        ProcessEntityID          => 'P123',
        ActivityEntityID         => 'A123',
        TransitionEntityID       => 'T123',
        TransitionActionEntityID => 'TA123',
        Config                   => {
            State   => 'open',
            # or
            StateID => 3,

            PendingTimeDiff => 123,             # optional, used for pending states, difference in seconds from
                                                #   current time to desired pending time (e.g. a value of 3600 means
                                                #   that the pending time will be 1 hr after the Transition Action is
                                                #   executed)
            UserID  => 123,                     # optional, to override the UserID from the logged user
        }
    );
    Ticket contains the result of TicketGet including DynamicFields
    Config is the Config Hash stored in a Process::TransitionAction's  Config key
    Returns:

    $TicketStateSetResult = 1; # 0

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # define a common message to output in case of any error
    my $CommonMessage = "Process: $Param{ProcessEntityID} Activity: $Param{ActivityEntityID}"
        . " Transition: $Param{TransitionEntityID}"
        . " TransitionAction: $Param{TransitionActionEntityID} - ";

    # check for missing or wrong params
    my $Success = $Self->_CheckParams(
        %Param,
        CommonMessage => $CommonMessage,
    );
    return if !$Success;

    # override UserID if specified as a parameter in the TA config
    $Param{UserID} = $Self->_OverrideUserID(%Param);

    # use ticket attributes if needed
    $Self->_ReplaceTicketAttributes(%Param);

    if ( !$Param{Config}->{StateID} && !$Param{Config}->{State} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => $CommonMessage . "No State or StateID configured!",
        );
        return;
    }

    $Success = 0;
    my %StateData;

    # If Ticket's StateID is already the same as the Value we
    # should set it to, we got nothing to do and return success
    if (
        defined $Param{Config}->{StateID}
        && $Param{Config}->{StateID} eq $Param{Ticket}->{StateID}
        )
    {
        return 1;
    }

    # If Ticket's StateID is not the same as the Value we
    # should set it to, set the StateID
    elsif (
        defined $Param{Config}->{StateID}
        && $Param{Config}->{StateID} ne $Param{Ticket}->{StateID}
        )
    {
        %StateData = $Kernel::OM->Get('State')->StateGet(
            ID => $Param{Config}->{StateID},
        );
        $Success = $Kernel::OM->Get('Ticket')->TicketStateSet(
            TicketID => $Param{Ticket}->{TicketID},
            StateID  => $Param{Config}->{StateID},
            UserID   => $Param{UserID},
        );

        if ( !$Success ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => $CommonMessage
                    . 'Ticket StateID '
                    . $Param{Config}->{StateID}
                    . ' could not be updated for Ticket: '
                    . $Param{Ticket}->{TicketID} . '!',
            );
        }
    }

    # If Ticket's State is already the same as the Value we
    # should set it to, we got nothing to do and return success
    elsif (
        defined $Param{Config}->{State}
        && $Param{Config}->{State} eq $Param{Ticket}->{State}
        )
    {
        return 1;
    }

    # If Ticket's State is not the same as the Value we
    # should set it to, set the State
    elsif (
        defined $Param{Config}->{State}
        && $Param{Config}->{State} ne $Param{Ticket}->{State}
        )
    {
        %StateData = $Kernel::OM->Get('State')->StateGet(
            Name => $Param{Config}->{State},
        );
        $Success = $Kernel::OM->Get('Ticket')->TicketStateSet(
            TicketID => $Param{Ticket}->{TicketID},
            State    => $Param{Config}->{State},
            UserID   => $Param{UserID},
        );

        if ( !$Success ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => $CommonMessage
                    . 'Ticket State '
                    . $Param{Config}->{State}
                    . ' could not be updated for Ticket: '
                    . $Param{Ticket}->{TicketID} . '!',
            );
        }
    }
    else {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => $CommonMessage
                . "Couldn't update Ticket State - can't find valid State parameter!",
        );
        return;
    }

    # set pending time
    if (
        $Success
        && IsHashRefWithData( \%StateData )
        && $StateData{TypeName} =~ m{\A pending}msxi
        && IsNumber( $Param{Config}->{PendingTimeDiff} )
        )
    {

        # get time object
        my $TimeObject = $Kernel::OM->Get('Time');

        # get current time
        my $PendingTime = $TimeObject->SystemTime();

        # add PendingTimeDiff
        $PendingTime += $Param{Config}->{PendingTimeDiff};

        # convert pending time to time stamp
        my $PendingTimeString = $TimeObject->SystemTime2TimeStamp(
            SystemTime => $PendingTime,
        );

        # set pending time
        $Kernel::OM->Get('Ticket')->TicketPendingTimeSet(
            UserID   => $Param{UserID},
            TicketID => $Param{Ticket}->{TicketID},
            String   => $PendingTimeString,
        );
    }

    return $Success;
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
