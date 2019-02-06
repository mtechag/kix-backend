# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::TicketSearch::Database::ArticleAttachment;

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

Kernel::System::Ticket::TicketSearch::Database::ArticleAttachment - attribute module for database ticket search

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
        Search => [ 'AttachmentName' ],
        Sort   => []
    }
}


=item Search()

run this module and return the SQL extensions

    my $Result = $Object->Search(
        BoolOperator => 'AND' | 'OR',
        Search       => {}
    );

    $Result = {
        SQLJoin    => [ ],
        SQLWhere   => [ ],
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

    my %JoinType = (
        'AND' => 'INNER',
        'OR'  => 'FULL OUTER'
    );

    # check if we have to add a join
    if ( !$Self->{ModuleData}->{AlreadyJoined} ) {
        my $StorageModule = $Kernel::OM->Get('Kernel::Config')->Get('Ticket::StorageModule');
        if ( $StorageModule !~ /::StorageDB$/ ) {
            # we can only search article attachments if they are stored in the DB
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'notice',
                Message  => "Attachments cannot be searched if articles are not stored in the database!",
            );            
            return;
        }
        push( @SQLJoin, $JoinType{$Param{BoolOperator}}.' JOIN article art_for_att ON st.id = art_for_att.ticket_id' );
        push( @SQLJoin, 'INNER JOIN article_attachment att ON att.article_id = art_for_att.id' );
        $Self->{ModuleData}->{AlreadyJoined} = 1;
    }

    my $Field      = 'att.filename';
    my $FieldValue = $Param{Search}->{Value};

    if ( $Param{Search}->{Operator} eq 'EQ' ) {
        # no special handling
    }
    elsif ( $Param{Search}->{Operator} eq 'STARTSWITH' ) {
        $FieldValue = $FieldValue.'%';
    }
    elsif ( $Param{Search}->{Operator} eq 'ENDSWITH' ) {
        $FieldValue = '%'.$FieldValue;
    }
    elsif ( $Param{Search}->{Operator} eq 'CONTAINS' ) {
        $FieldValue = '%'.$FieldValue.'%';
    }
    elsif ( $Param{Search}->{Operator} eq 'LIKE' ) {
        $FieldValue =~ s/\*/%/g;
    }
    else {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Unsupported Operator $Param{Search}->{Operator}!",
        );
        return;
    }

    # check if database supports LIKE in large text types (in this case for body)
    if ( $Self->{DBObject}->GetDatabaseFunction('CaseSensitive') ) {
        if ( $Self->{DBObject}->GetDatabaseFunction('LcaseLikeInLargeText') ) {
            $Field      = "LCASE($Field)";
            $FieldValue = "LCASE('$FieldValue')";
        }
        else {
            $Field      = "LOWER($Field)";
            $FieldValue = "LOWER('$FieldValue')";
        }
    }
    else {
        $FieldValue = "'$FieldValue'";
    }

    push( @SQLWhere, $Field.' LIKE '.$FieldValue );

    # restrict search from customers to only customer articles
    if ( $Param{UserType} eq 'Customer' ) {
        push( @SQLWhere, 'art_for_att.customer_visible = 1)' );
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
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
