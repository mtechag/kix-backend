# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Ticket::Event::TicketServiceQueueAssignment;

use strict;
use warnings;

our @ObjectDependencies = (
    'Config',
    'Log',
    'Service',
    'Ticket',
);

=item new()

create an object.

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # 0=off; 1=on;
    $Self->{Debug} = $Param{Debug} || 0;

    # create needed objects
    $Self->{ConfigObject}  = $Kernel::OM->Get('Config');
    $Self->{LogObject}     = $Kernel::OM->Get('Log');
    $Self->{ServiceObject} = $Kernel::OM->Get('Service');
    $Self->{TicketObject}  = $Kernel::OM->Get('Ticket');

    return $Self;
}

=item Run()

Run - contains the actions performed by this event handler.

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check required params...
    if ( !$Param{Data}->{TicketID} ) {
        $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
        return;
    }

    my $ServiceQueueAssigment = $Self->{ConfigObject}->Get('Ticket::ServiceQueueAssignment');
    return 1 if ( !$ServiceQueueAssigment || ref($ServiceQueueAssigment) ne 'HASH' );

    # get ticket data...
    my %Ticket = $Self->{TicketObject}->TicketGet(
        TicketID => $Param{Data}->{TicketID},
        UserID   => 1,
    );
    return 1 if ( !%Ticket );
    return 1 if ( !$Ticket{ServiceID} );

    # retrieve excluded ticket type- and states...
    my $TypeStateExlusions = $ServiceQueueAssigment->{TypeStateExclusions};
    if ( $TypeStateExlusions && ref($TypeStateExlusions) eq 'HASH' ) {
        for my $CurrKey ( sort( keys( %{$TypeStateExlusions} ) ) ) {
            if ( $TypeStateExlusions->{$CurrKey} && $CurrKey =~ (/(.+):::(.+):::(.+)/) ) {
                my $TypeRegexp  = $2;
                my $StateRegexp = $3;
                return 1
                    if (
                    ( $Ticket{Type} =~ /$TypeRegexp/ )
                    && ( $Ticket{State} =~ /$StateRegexp/ )
                    );
            }
        }
    }

    # retrieve service data...
    my %ServiceData = $Self->{ServiceObject}->ServiceGet(
        ServiceID => $Ticket{ServiceID},
        UserID    => 1,
    );

    # move or not to move...
    if (
        %ServiceData
        && $ServiceData{AssignedQueueID}
        && $ServiceData{AssignedQueueID} != $Ticket{QueueID}
        )
    {
        my $Success = $Self->{TicketObject}->TicketQueueSet(
            QueueID  => $ServiceData{AssignedQueueID},
            TicketID => $Param{Data}->{TicketID},
            UserID   => 1,
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
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
