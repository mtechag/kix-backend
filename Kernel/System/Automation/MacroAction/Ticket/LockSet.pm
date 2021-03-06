# --
# Modified version of the work: Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Automation::MacroAction::Ticket::LockSet;

use strict;
use warnings;
use utf8;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Automation::MacroAction::Ticket::Common);

our @ObjectDependencies = (
    'Log',
    'Ticket',
    'Lock'
);

=head1 NAME

Kernel::System::Automation::MacroAction::Ticket::LockSet - A module to lock or unlock a ticket

=head1 SYNOPSIS

All LockSet functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Describe()

Describe this macro action module.

=cut

sub Describe {
    my ( $Self, %Param ) = @_;

    $Self->Description(Kernel::Language::Translatable('Sets the lock state of a ticket.'));
    $Self->AddOption(
        Name        => 'Lock',
        Label       => Kernel::Language::Translatable('Lock'),
        Description => Kernel::Language::Translatable('The lock state to be set.'),
        Required    => 1,
    );

    return;
}

=item Run()

Run this module. Returns 1 if everything is ok.

Example:
    my $Success = $Object->Run(
        TicketID => 123,
        Config   => {
            Lock => 'unlock',
        },
        UserID   => 123,
    );

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check incoming parameters
    return if !$Self->_CheckParams(%Param);

    my $TicketObject = $Kernel::OM->Get('Ticket');

    my %Ticket = $TicketObject->TicketGet(
        TicketID => $Param{TicketID},
    );

    if (!%Ticket) {
        return;
    }

    my $Lock = $Kernel::OM->Get('TemplateGenerator')->ReplacePlaceHolder(
        RichText => 0,
        Text     => $Param{Config}->{Lock},
        TicketID => $Param{TicketID},
        Data     => {},
        UserID   => $Param{UserID},
    );

    # set the new lock
    my $LockID = $Kernel::OM->Get('Lock')->LockLookup(
        Lock => $Lock,
    );

    if ( !$LockID ) {
        $Kernel::OM->Get('Automation')->LogError(
            Referrer => $Self,
            Message  => "Couldn't update ticket $Param{TicketID} - can't find lock state \"$Param{Config}->{Lock}\"!",
            UserID   => $Param{UserID}
        );
        return;
    }

    # do nothing if the desired lock state is already set
    if ( $LockID eq $Ticket{LockID} ) {
        return 1;
    }

    my $Success = $TicketObject->LockSet(
        TicketID => $Param{TicketID},
        LockID   => $LockID,
        UserID   => $Param{UserID},
    );

    if ( !$Success ) {
        $Kernel::OM->Get('Automation')->LogError(
            Referrer => $Self,
            Message  => "Couldn't update ticket $Param{TicketID} - setting the lock state \"$Param{Config}->{Lock}\" failed!",
            UserID   => $Param{UserID}
        );
        return;
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
