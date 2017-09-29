# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::TicketSearch::Database::TicketNumber;

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

Kernel::System::Ticket::TicketSearch::Database::TicketNumber - attribute module for database ticket search

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item GetSupportedAttributes()

defines the list of attributes this module is supporting

    my @AttributeList = $Object->GetSupportedAttributes();

    $Result = [
        ...
    ];

=cut

sub GetSupportedAttributes {
    my ( $Self, %Param ) = @_;

    return (
        'TicketNumber',
    );
}


=item Run()

run this module and return the SQL extensions

    my $Result = $Object->Run(
        Filter => {}
    );

    $Result = {
        SQLWhere   => [ ],
    };

=cut

sub Run {
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

    if ( $Param{Filter}->{Operation} eq 'EQ' ) {
        push( @SQLWhere, "st.tn='$Param{Filter}->{Value}'" );
    }
    elsif ( $Param{Filter}->{Operation} eq 'STARTSWITH' ) {
        push( @SQLWhere, "st.tn LIKE '$Param{Filter}->{Value}%'" );
    }
    elsif ( $Param{Filter}->{Operation} eq 'ENDSWITH' ) {
        push( @SQLWhere, "st.tn LIKE '%$Param{Filter}->{Value}" );
    }
    elsif ( $Param{Filter}->{Operation} eq 'CONTAINS' ) {
        push( @SQLWhere, "st.tn LIKE '%$Param{Filter}->{Value}%" );
    }
    elsif ( $Param{Filter}->{Operation} eq 'IN' ) {
        push( @SQLWhere, 'st.tn IN ('.(join(',', @{$Param{Filter}->{Value}})).')' );
    }
    else {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Unsupported operation $Param{Filter}->{Operation}!",
        );
        return;
    }

    return {
        SQLWhere => \@SQLWhere,
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
