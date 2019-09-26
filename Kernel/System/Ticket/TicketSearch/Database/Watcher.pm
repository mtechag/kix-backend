# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Ticket::TicketSearch::Database::Watcher;

use strict;
use warnings;

use base qw(
    Kernel::System::Ticket::TicketSearch::Database::Common
);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Log',
);

=head1 NAME

Kernel::System::Ticket::TicketSearch::Database::Watcher - attribute module for database ticket search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item GetSupportedAttributes()

defines the list of attributes this module is supporting

    my $AttributeList = $Object->GetSupportedAttributes();

    $Result = {
        Search => [ ],
        Sort   => [ ],
    };

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        Search => [
            'WatcherUserID',
        ],
        Sort => []
    };
}

=item Search()

run this module and return the SQL extensions

    my $Result = $Object->Search(
        BoolOperator => 'AND' | 'OR',
        Search       => {}
    );

    $Result = {
        SQLJoin    => [ ],
    };

=cut

sub Search {
    my ( $Self, %Param ) = @_;
    my @SQLJoin;
    my @SQLWhere;

    # check params
    if ( !$Param{Search} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need Search!",
        );
        return;
    }

    # check if we have to add a join
    if ( !$Self->{ModuleData}->{AlreadyJoined} ) {
        if ( $Param{BoolOperator} eq 'OR') {
            push( @SQLJoin, 'LEFT OUTER JOIN ticket_watcher tw_left ON st.id = tw_left.ticket_id' );
            push( @SQLJoin, 'RIGHT OUTER JOIN ticket_watcher tw_right ON st.id = tw_right.ticket_id' );
        } else {
            push( @SQLJoin, 'INNER JOIN ticket_watcher tw ON st.id = tw.ticket_id' );
        }
        $Self->{ModuleData}->{AlreadyJoined} = 1;
    }

    if ( $Param{Search}->{Operator} eq 'EQ' ) {
        if ( $Param{BoolOperator} eq 'OR') {
            push( @SQLWhere, 'tw_left.user_id = '.$Param{Search}->{Value} );
            push( @SQLWhere, 'tw_right.user_id = '.$Param{Search}->{Value} );
        } else {
            push( @SQLWhere, 'tw.user_id = '.$Param{Search}->{Value} );
        }
    }
    elsif ( $Param{Search}->{Operator} eq 'IN' ) {
        if ( $Param{BoolOperator} eq 'OR') {
            push( @SQLWhere, 'tw_left.user_id IN ('.(join(',', @{$Param{Search}->{Value}})).')' );
            push( @SQLWhere, 'tw_right.user_id IN ('.(join(',', @{$Param{Search}->{Value}})).')' );
        } else {
            push( @SQLWhere, 'tw.user_id IN ('.(join(',', @{$Param{Search}->{Value}})).')' );
        }
    }
    else {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Unsupported Operator $Param{Search}->{Operator}!",
        );
        return;
    }

    return {
        SQLJoin  => \@SQLJoin,
        SQLWhere => \@SQLWhere,
    };        
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
