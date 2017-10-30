# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::TicketSearch::Database::State;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::Ticket::TicketSearch::Database::Common
);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Log',
);

=head1 NAME

Kernel::System::Ticket::TicketSearch::Database::State - attribute module for database ticket search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item GetSupportedAttributes()

defines the list of attributes this module is supporting

    my $AttributeList = $Object->GetSupportedAttributes();

    $Result = {
        Filter => [ ],
        Sort   => [ ],
    };

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return {
        Filter => [
            'StateID',
            'StateType',
            'StateTypeID',
        ],
        Sort => [
            'StateID',
        ]
    };
}


=item Filter()

run this module and return the SQL extensions

    my $Result = $Object->Filter(
        Filter => {}
    );

    $Result = {
        SQLWhere   => [ ],
    };

=cut

sub Filter {
    my ( $Self, %Param ) = @_;
    my @SQLWhere;

    # check params
    if ( !$Param{Filter} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Need Filter!",
        );
        return;
    }

    my $Operator = $Param{Filter}->{Operator};
    my $Value    = $Param{Filter}->{Value};
    my @StateIDs;

    # special handling for StateType
    if ( $Param{Filter}->{Field} eq 'StateType' ) {

        # get all StateIDs for the given StateTypes
        my @StateTypes = ( $Value );
        if ( IsArrayRefWithData($Value) ) {
            @StateTypes = @{$Value};
        }
       
        foreach my $StateType ( @StateTypes ) {
            
            if ( $StateType eq 'Open' ) {
                # get all viewable states
                my @ViewableStateIDs = $Kernel::OM->Get('Kernel::System::State')->StateGetStatesByType(
                    Type   => 'Viewable',
                    Result => 'ID',
                );
                push(@StateIDs, @ViewableStateIDs);
            }
            elsif ( $StateType eq 'Closed' ) {
                # get all non-viewable states
                my %AllStateIDs = $Kernel::OM->Get('Kernel::System::State')->StateList(
                    UserID => 1,
                );
                my %ViewableStateIDs = $Kernel::OM->Get('Kernel::System::State')->StateGetStatesByType(
                    Type   => 'Viewable',
                    Result => 'HASH',
                );
                foreach my $StateID ( sort keys %AllStateIDs ) {
                    next if $ViewableStateIDs{$StateID};
                    push(@StateIDs, $StateID);
                }
            }
            else {
                my @StateTypeStateIDs = $Kernel::OM->Get('Kernel::System::State')->StateGetStatesByType(
                    StateType => $StateType,
                    Result    => 'ID',
                );
                if ( !@StateTypeStateIDs ) {
                    $Kernel::OM->Get('Kernel::System::Log')->Log(
                        Priority => 'error',
                        Message  => "No states found for StateType $StateType!",
                    );
                    return;
                }                
                push(@StateIDs, @StateTypeStateIDs);
            }
        }

        if (!@StateIDs) {
            # we need to restrict to something
            push(@StateIDs, -1);
        }

        # we have to do an IN seasrch in this case
        $Operator = 'IN';
    }
    elsif ( $Param{Filter}->{Field} eq 'StateTypeID' ) {

        # get all StateIDs for the given StateTypeIDs
        my @StateTypeIDs = ( $Value );
        if ( IsArrayRefWithData($Value) ) {
            @StateTypeIDs = @{$Value};
        }

        foreach my $StateTypeID ( @StateTypeIDs ) {       
            my $StateType = $Kernel::OM->Get('Kernel::System::State')->StateTypeLookup(
                StateTypeID => $StateTypeID,
            );
            if ( !$StateType ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "No StateType with ID $StateTypeID!",
                );
                return;
            }
            my @StateTypeStateIDs = $Kernel::OM->Get('Kernel::System::State')->StateGetStatesByType(
                StateType => $StateType,
                Result    => 'ID',
            );

            push(@StateIDs, @StateTypeStateIDs);
        }

        if (!@StateIDs) {
            # we need to restrict to something
            push(@StateIDs, -1);
        }

        # we have to do an IN seasrch in this case
        $Operator = 'IN';
    }
    elsif ( $Param{Filter}->{Field} eq 'State' ) {
        my @StateList = ( $Param{Filter}->{Value} );
        if ( IsArrayRefWithData($Param{Filter}->{Value}) ) {
            @StateList = @{$Param{Filter}->{Value}}
        }
        foreach my $State ( @StateList ) {
            my $StateID = $Kernel::OM->Get('Kernel::System::State')->StateLookup(
                State => $State,
            );
            if ( !$StateID ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "Unknown state $State!",
                );
                return;
            }                

            push( @StateIDs, $StateID );
        }
    }
    else {
        @StateIDs = ( $Param{Filter}->{Value} );
        if ( IsArrayRefWithData($Param{Filter}->{Value}) ) {
            @StateIDs = @{$Param{Filter}->{Value}}
        }
    }

    if ( $Operator eq 'EQ' ) {
        push( @SQLWhere, 'st.ticket_state_id = '.$StateIDs[0] );
    }
    elsif ( $Operator eq 'IN' ) {
        push( @SQLWhere, 'st.ticket_state_id IN ('.(join(',', @StateIDs)).')' );
    }
    else {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Unsupported Operator $Param{Filter}->{Operator}!",
        );
        return;
    }

    return {
        SQLWhere => \@SQLWhere,
    };        
}

=item Sort()

run this module and return the SQL extensions

    my $Result = $Object->Sort(
        Attribute => '...'      # required
    );

    $Result = {
        SQLAttrs   => [ ],          # optional
        SQLOrderBy => [ ]           # optional
    };

=cut

sub Sort {
    my ( $Self, %Param ) = @_;

    return {
        SQLAttrs => [
            'st.ticket_state_id'
        ],
        SQLOrderBy => [
            'st.ticket_state_id'
        ],
    };       
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
