# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Ticket::TicketSearch::Database::ArticleFlag;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::Ticket::TicketSearch::Database::Common
);

our @ObjectDependencies = (
    'Config',
    'Log',
);

=head1 NAME

Kernel::System::Ticket::TicketSearch::Database::ArticleFlag - attribute module for database ticket search

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
        Search => [ 'ArticleFlag' ],
        Sort   => []
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
        SQLWhere   => [ ],
    };

=cut

sub Search {
    my ( $Self, %Param ) = @_;
    my @SQLJoin;
    my @SQLWhere;

    # check params
    if ( !$Param{Search} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need Search!",
        );
        return;
    }

    if ( !IsArrayRefWithData($Param{Search}->{Value}) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Invalid Search value!",
        );
        return;
    }

    if ( $Param{Search}->{Operator} eq 'EQ' ) {
        my $Index = 1;
        foreach my $SearchValue ( sort @{ $Param{Search}->{Value} } ) {
            if ( !IsHashRefWithData($SearchValue) ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Invalid Search value!",
                );
                return;
            }
            
            if ( !$Param{Search}->{Not} ) {
                if ( $Param{BoolOperator} eq 'OR') {
                    push( @SQLJoin, "LEFT OUTER JOIN article art_for_aflag$Index\_left ON st.id = art_for_aflag$Index\_left.ticket_id" );
                    push( @SQLJoin, "RIGHT OUTER JOIN article art_for_aflag$Index\_right ON st.id = art_for_aflag$Index\_right.ticket_id" );
                    push( @SQLJoin, "INNER JOIN article_flag af$Index ON art_for_aflag\_left$Index.id = af$Index.article_id OR art_for_aflag\_right$Index.id = af$Index.article_id" );
                    push( @SQLWhere, "af$Index.article_key = '$SearchValue->{Flag}'" );
                } else {
                    push( @SQLJoin, "INNER JOIN article art_for_aflag$Index ON st.id = art_for_aflag$Index.ticket_id" );
                    push( @SQLJoin, "INNER JOIN article_flag af$Index ON art_for_aflag$Index.id = af$Index.article_id" );
                    push( @SQLWhere, "af$Index.article_key = '$SearchValue->{Flag}'" );
                }
            }
            else {
                if ( $Param{BoolOperator} eq 'OR') {
                    push( @SQLJoin, "LEFT OUTER JOIN article art_for_aflag$Index\_left ON st.id = art_for_aflag$Index\_left.ticket_id" );
                    push( @SQLJoin, "RIGHT OUTER JOIN article art_for_aflag$Index\_right ON st.id = art_for_aflag$Index\_right.ticket_id" );
                    push( @SQLJoin, "LEFT JOIN article_flag naf$Index ON art_for_aflag\_left$Index.id = naf$Index.article_id OR art_for_aflag\_right$Index.id = naf$Index.article_id" );
                    push( @SQLWhere, "naf$Index.article_key = '$SearchValue->{Flag}'" );
                } else {
                    push( @SQLJoin, "INNER JOIN article art_for_aflag$Index ON st.id = art_for_aflag$Index.ticket_id" );
                    push( @SQLJoin, "LEFT JOIN article_flag naf$Index ON art_for_aflag$Index.id = naf$Index.article_id" );
                    push( @SQLWhere, "naf$Index.article_key = '$SearchValue->{Flag}'" );
                }
            }

            # add value restriction if given
            if ( $SearchValue->{Value} ) {
                if ( !$Param{Search}->{Not} ) {
                    push( @SQLWhere, "af$Index.article_value = '$SearchValue->{Value}'" );
                }
                else {
                    push( @SQLWhere, "(naf$Index.article_value IS NULL OR naf$Index.article_value <> '$SearchValue->{Value}')" );
                }
            }

            # add user restriction if given
            if ( $SearchValue->{UserID} ) {
                if ( !$Param{Search}->{Not} ) {
                    push( @SQLWhere, "af$Index.create_by = $SearchValue->{UserID}" );
                }
                else {
                    push( @SQLWhere, "naf$Index.create_by = $SearchValue->{UserID}" );                    
                }
            }
            $Index++;
        }
    }
    else {
        $Kernel::OM->Get('Log')->Log(
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
