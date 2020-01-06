# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Watcher::Ticket;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use vars qw(@ISA);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Cache',
    'Kernel::System::DB',
);

=head1 NAME

Kernel::System::Watcher::Ticket - Ticket backend for watcher lib

=head1 SYNOPSIS

Ticket related watcher functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $WatcherObject = $Kernel::OM->Get('Kernel::System::Watcher');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # 0=off; 1=on;
    $Self->{Debug} = $Param{Debug} || 0;

    return $Self;
}

=item WatcherAdd()

subscribe a watcher

    my $Success = $TicketObject->WatcherAdd(
        WatcherID   => 123,
        Object      => 'Ticket'
        ObjectID    => 123,
        WatchUserID => 123,
        UserID      => 123,
    );

Events:
    TicketSubscribe

=cut

sub WatcherAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(WatcherID Object ObjectID WatchUserID UserID)) {
        if ( !defined $Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    # get user data
    my %User = $Kernel::OM->Get('Kernel::System::User')->GetUserData(
        UserID => $Param{WatchUserID},
    );
 
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # add history
    $TicketObject->HistoryAdd(
        TicketID     => $Param{ObjectID},
        CreateUserID => $Param{UserID},
        HistoryType  => 'Subscribe',
        Name         => "\%\%$User{UserFirstname} $User{UserLastname} ($User{UserLogin})",
    );

    # trigger event
    $TicketObject->EventHandler(
        Event => 'TicketSubscribe',
        Data  => {
            TicketID => $Param{ObjectID},
        },
        UserID => $Param{UserID},
    );

    return 1;
}

=item WatcherDelete()

remove a watcher

    my $Success = $WatcherObject->WatcherDelete(
        WatcherID   => 123,
        Object      => 'Ticket'     # if no WatcherID is given
        ObjectID    => 123,         # if no WatcherID is given
        WatchUserID => 123,         # if no WatcherID is given
        UserID      => 123,
    );

Events:
    TicketUnsubscribe

=cut

sub WatcherDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Object ObjectID WatchUserID UserID)) {
        if ( !defined $Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    my %User = $Kernel::OM->Get('Kernel::System::User')->GetUserData(
        UserID => $Param{WatchUserID},
    );

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    $TicketObject->HistoryAdd(
        TicketID     => $Param{ObjectID},
        CreateUserID => $Param{UserID},
        HistoryType  => 'Unsubscribe',
        Name         => "\%\%$User{UserFirstname} $User{UserLastname} ($User{UserLogin})",
    );

    $TicketObject->EventHandler(
        Event => 'TicketUnsubscribe',
        Data  => {
            TicketID => $Param{ObjectID},
        },
        UserID => $Param{UserID},
    );

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
