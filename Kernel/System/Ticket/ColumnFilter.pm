# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::ColumnFilter;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

our @ObjectDependencies = (
    'Kernel::System::DB',
    'Kernel::System::Log',
    'Kernel::System::Main',
    'Kernel::System::User',
);

=head1 NAME

Kernel::System::Ticket::ColumnFilter - Column Filter library

=head1 SYNOPSIS

All functions for Column Filters.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $TicketColumnFilterObject = $Kernel::OM->Get('Kernel::System::Ticket::ColumnFilter');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item StateFilterValuesGet()

get a list of states within the given ticket is list

    my $Values = $ColumnFilterObject->StateFilterValuesGet(
        TicketIDs => [23, 1, 56, 74],                    # array ref list of ticket IDs
    );

    returns

    $Values = {
        1 => 'New',
        4 => 'Open',
    };

=cut

sub StateFilterValuesGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{TicketIDs} ) {
        return if !$Param{UserID};

        # get state list
        return $Self->_GeneralDataGet(
            ModuleName   => 'Kernel::System::State',
            FunctionName => 'StateList',
            UserID       => $Param{UserID},
        );
    }

    if ( !IsArrayRefWithData( $Param{TicketIDs} ) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'TicketIDs must be an array ref!',
        );
        return;
    }

    my $TicketIDString = $Self->_TicketIDStringGet(
        TicketIDs => $Param{TicketIDs},
    );

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    return if !$DBObject->Prepare(
        SQL => "SELECT DISTINCT(t.ticket_state_id), ts.name"
            . " FROM ticket t, ticket_state ts"
            . " WHERE t.ticket_state_id = ts.id"
            . $TicketIDString
            . " ORDER BY t.ticket_state_id DESC",
    );

    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        if ( $Row[0] ) {
            $Data{ $Row[0] } = $Row[1];
        }
    }

    return \%Data;
}

=item QueueFilterValuesGet()

get a list of queues within the given ticket is list

    my $Values = $ColumnFilterObject->QueueFilterValuesGet(
        TicketIDs => [23, 1, 56, 74],                    # array ref list of ticket IDs
    );

    returns

    $Values = {
        2 => 'raw',
        3 => 'Junk',
    };

=cut

sub QueueFilterValuesGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{TicketIDs} ) {

        # check needed param
        return if !$Param{UserID};

        # get queue list
        return $Self->_GeneralDataGet(
            ModuleName   => 'Kernel::System::Queue',
            FunctionName => 'QueueList',
            UserID       => $Param{UserID},
        );
    }

    if ( !IsArrayRefWithData( $Param{TicketIDs} ) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'TicketIDs must be an array ref!',
        );
        return;
    }

    my $TicketIDString = $Self->_TicketIDStringGet(
        TicketIDs => $Param{TicketIDs},
    );

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    return if !$DBObject->Prepare(
        SQL => "SELECT DISTINCT(t.queue_id), q.name"
            . " FROM ticket t, queue q"
            . " WHERE t.queue_id = q.id"
            . $TicketIDString
            . " ORDER BY t.queue_id DESC",
    );

    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        if ( $Row[0] ) {
            $Data{ $Row[0] } = $Row[1];
        }
    }

    return \%Data;
}

=item PriorityFilterValuesGet()

get a list of priorities within the given ticket is list

    my $Values = $ColumnFilterObject->PriorityFilterValuesGet(
        TicketIDs => [23, 1, 56, 74],                    # array ref list of ticket IDs
    );

    returns

    $Values = {
        3 => '3 Normal',
    };

=cut

sub PriorityFilterValuesGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{TicketIDs} ) {

        return if !$Param{UserID};

        # get priority list
        return $Self->_GeneralDataGet(
            ModuleName   => 'Kernel::System::Priority',
            FunctionName => 'PriorityList',
            UserID       => $Param{UserID},
        );
    }

    if ( !IsArrayRefWithData( $Param{TicketIDs} ) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'TicketIDs must be an array ref!',
        );
        return;
    }

    my $TicketIDString = $Self->_TicketIDStringGet(
        TicketIDs => $Param{TicketIDs},
    );

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    return if !$DBObject->Prepare(
        SQL => "SELECT DISTINCT(t.ticket_priority_id), tp.name"
            . " FROM ticket t, ticket_priority tp"
            . " WHERE t.ticket_priority_id = tp.id"
            . $TicketIDString
            . " ORDER BY t.ticket_priority_id DESC",
    );

    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        if ( $Row[0] ) {
            $Data{ $Row[0] } = $Row[1];
        }
    }

    return \%Data;
}

=item TypeFilterValuesGet()

get a list of ticket types within the given ticket is list

    my $Values = $ColumnFilterObject->TypeFilterValuesGet(
        TicketIDs => [23, 1, 56, 74],                    # array ref list of ticket IDs
    );

    returns

    $Values = {
        1 => 'Default',
    };

=cut

sub TypeFilterValuesGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{TicketIDs} ) {

        return if !$Param{UserID};

        # get type list
        return $Self->_GeneralDataGet(
            ModuleName   => 'Kernel::System::Type',
            FunctionName => 'TypeList',
            UserID       => $Param{UserID},
        );
    }

    if ( !IsArrayRefWithData( $Param{TicketIDs} ) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'TicketIDs must be an array ref!',
        );
        return;
    }

    my $TicketIDString = $Self->_TicketIDStringGet(
        TicketIDs => $Param{TicketIDs},
    );

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    return if !$DBObject->Prepare(
        SQL => "SELECT DISTINCT(t.type_id), tt.name"
            . " FROM ticket t, ticket_type tt"
            . " WHERE t.type_id = tt.id"
            . $TicketIDString
            . " ORDER BY t.type_id DESC",
    );

    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        if ( $Row[0] ) {
            $Data{ $Row[0] } = $Row[1];
        }
    }

    return \%Data;
}

=item LockFilterValuesGet()

get a list of ticket lock values within the given ticket is list

    my $Values = $ColumnFilterObject->LockFilterValuesGet(
        TicketIDs => [23, 1, 56, 74],                    # array ref list of ticket IDs
    );

    returns

    $Values = {
        1 => 'unlock',
        4 => 'lock',
    };

=cut

sub LockFilterValuesGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{TicketIDs} ) {

        return if !$Param{UserID};

        # get lock list
        return $Self->_GeneralDataGet(
            ModuleName   => 'Kernel::System::Lock',
            FunctionName => 'LockList',
            UserID       => $Param{UserID},
        );
    }

    if ( !IsArrayRefWithData( $Param{TicketIDs} ) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'TicketIDs must be an array ref!',
        );
        return;
    }

    my $TicketIDString = $Self->_TicketIDStringGet(
        TicketIDs => $Param{TicketIDs},
    );

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    return if !$DBObject->Prepare(
        SQL => "SELECT DISTINCT(t.ticket_lock_id), tlt.name"
            . " FROM ticket t, ticket_lock_type tlt"
            . " WHERE ticket_lock_id = tlt.id"
            . $TicketIDString
            . " ORDER BY t.ticket_lock_id DESC",
    );

    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        if ( $Row[0] ) {
            $Data{ $Row[0] } = $Row[1];
        }
    }

    return \%Data;
}

=item ServiceFilterValuesGet()

get a list of services within the given ticket is list

    my $Values = $ColumnFilterObject->ServiceFilterValuesGet(
        TicketIDs => [23, 1, 56, 74],                    # array ref list of ticket IDs
    );

    returns

    $Values = {
        1 => 'My Service',
    };

=cut

sub ServiceFilterValuesGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{TicketIDs} ) {

        return if !$Param{UserID};

        # get service list
        return $Self->_GeneralDataGet(
            ModuleName   => 'Kernel::System::Service',
            FunctionName => 'ServiceList',
            UserID       => $Param{UserID},
        );
    }

    if ( !IsArrayRefWithData( $Param{TicketIDs} ) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'TicketIDs must be an array ref!',
        );
        return;
    }

    my $TicketIDString = $Self->_TicketIDStringGet(
        TicketIDs => $Param{TicketIDs},
    );

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    return if !$DBObject->Prepare(
        SQL => "SELECT DISTINCT(t.service_id), s.name"
            . " FROM ticket t, service s"
            . " WHERE t.service_id = s.id"
            . $TicketIDString
            . " ORDER BY t.service_id DESC",
    );

    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        if ( $Row[0] ) {
            $Data{ $Row[0] } = $Row[1];
        }
    }

    return \%Data;
}

=item SLAFilterValuesGet()

get a list of service level agreements within the given ticket is list

    my $Values = $ColumnFilterObject->SLAFilterValuesGet(
        TicketIDs => [23, 1, 56, 74],                    # array ref list of ticket IDs
    );

    returns

    $Values = {
        1 => 'MySLA',
    };

=cut

sub SLAFilterValuesGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{TicketIDs} ) {

        return if !$Param{UserID};

        # get sla list
        return $Self->_GeneralDataGet(
            ModuleName   => 'Kernel::System::SLA',
            FunctionName => 'SLAList',
            UserID       => $Param{UserID},
        );
    }

    if ( !IsArrayRefWithData( $Param{TicketIDs} ) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'TicketIDs must be an array ref!',
        );
        return;
    }

    my $TicketIDString = $Self->_TicketIDStringGet(
        TicketIDs => $Param{TicketIDs},
    );

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    return if !$DBObject->Prepare(
        SQL => "SELECT DISTINCT(t.sla_id), s.name"
            . " FROM ticket t, sla s"
            . " WHERE t.sla_id = s.id"
            . $TicketIDString
            . " ORDER BY t.sla_id DESC",
    );

    my %Data;
    while ( my @Row = $DBObject->FetchrowArray() ) {
        if ( $Row[0] ) {
            $Data{ $Row[0] } = $Row[1];
        }
    }

    return \%Data;
}

=begin Internal:

=item _GeneralDataGet()

get data list

    my $Values = $ColumnFilterObject->_GeneralDataGet(
            ModuleName   => 'Kernel::System::Object',
            FunctionName => 'FunctionNameList',
            UserID       => $Param{UserID},
    );

    returns

    $Values = {
        1 => 'ValueA',
        2 => 'ValueB',
        3 => 'ValueC'
    };

=cut

sub _GeneralDataGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(ModuleName FunctionName UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    my $FuctionName = $Param{FunctionName};

    # set the backend file
    my $BackendModule = $Param{ModuleName};

    # check if backend field exists
    if ( !$Kernel::OM->Get('Kernel::System::Main')->Require($BackendModule) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Can't load backend module $BackendModule!",
        );
        return;
    }

    # create a backend object
    my $BackendObject = $BackendModule->new( %{$Self} );

    if ( !$BackendObject ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Couldn't create a backend object for $BackendModule!",
        );
        return;
    }

    if ( ref $BackendObject ne $BackendModule ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Backend object for $BackendModule was not created successfuly!",
        );
        return;
    }

    # get data list
    my %DataList = $BackendObject->$FuctionName(
        Valid  => 1,
        UserID => $Param{UserID},
    );

    return \%DataList;
}

sub _TicketIDStringGet {
    my ( $Self, %Param ) = @_;

    $Param{IncludeAdd} = 1 if !defined $Param{IncludeAdd};

    my $ColumnName = $Param{ColumnName} || 't.id';

    if ( !$Param{TicketIDs} || ref $Param{TicketIDs} ne 'ARRAY' || !@{ $Param{TicketIDs} } ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need TicketIDs.",
        );
        return;
    }

    # sort ids to cache the SQL query
    my @SortedIDs = sort { $a <=> $b } @{ $Param{TicketIDs} };

    # Error out if some values were not integers.
    @SortedIDs = map { $Kernel::OM->Get('Kernel::System::DB')->Quote( $_, 'Integer' ) } @SortedIDs;
    return if scalar @SortedIDs != scalar @{ $Param{TicketIDs} };

    my $TicketIDString = '';

    # split IN statement with more than 900 elements in more statements bombined with OR
    # because Oracle doesn't support more than 1000 elements in one IN statement.
    my @SQLStrings;
    while ( scalar @SortedIDs ) {

        # remove section in the array
        my @SortedIDsPart = splice @SortedIDs, 0, 900;

        # link together IDs
        my $IDString = join ', ', @SortedIDsPart;

        # add new statement
        push @SQLStrings, " $ColumnName IN ($IDString) ";
    }

    my $SQLString = join ' OR ', @SQLStrings;

    if ( $Param{IncludeAdd} ) {
        $TicketIDString .= ' AND ( ' . $SQLString . ' ) ';
    }
    else {
        $TicketIDString = $SQLString
    }

    return $TicketIDString;
}

1;

=end Internal:




=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
