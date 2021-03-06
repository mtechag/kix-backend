# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::KIXSidebarFAQ;

use strict;
use warnings;

use utf8;

our @ObjectDependencies = (
    'FAQ',
    'LinkObject'
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    $Self->{FAQObject}  = $Kernel::OM->Get('FAQ');
    $Self->{LinkObject} = $Kernel::OM->Get('LinkObject');

    return $Self;
}

sub KIXSidebarFAQSearch {
    my ( $Self, %Param ) = @_;

    my $StateTypeList = $Self->{FAQObject}->StateTypeList(
        UserID => 1,
    );
    my %StateTypes;
    my @StateTypeArray = split( /,/, $Param{SearchStateTypes} || '' );
    for my $StateType (@StateTypeArray) {
        for my $StateTypeID ( keys %{$StateTypeList} ) {
            if ( $StateTypeList->{$StateTypeID} =~ m/^$StateType/i ) {
                $StateTypes{$StateTypeID} = $StateTypeList->{$StateTypeID};
            }
        }
    }

    my %Result;

    if ( $Param{TicketID} && $Param{LinkMode} ) {
        my %LinkKeyList = $Self->{LinkObject}->LinkKeyList(
            Object1 => 'Ticket',
            Key1    => $Param{TicketID},
            Object2 => 'FAQ',
            State   => $Param{LinkMode},
            UserID  => 1,
        );

        for my $ID ( keys %LinkKeyList ) {
            my %FAQ = $Self->{FAQObject}->FAQGet(
                ItemID => $ID,
                UserID => 1,
            );
            if ( %FAQ && $FAQ{StateTypeID} && $StateTypes{ $FAQ{StateTypeID} } ) {
                $Result{$ID}->{'Title'} = $FAQ{Title};
                $Result{$ID}->{'Link'}  = 1;

                # Check if limit is reached
                return \%Result if ( $Param{Limit} && ( scalar keys %Result ) == $Param{Limit} );
            }
        }
    }

    if ( $Param{SearchString} ) {

        $Param{SearchString} =~ s/\s\s/ /g;
        if ( $Param{MatchAll} ) {
            $Param{SearchString} =~ s/\s/&&/g;
        }
        else {
            $Param{SearchString} =~ s/\s/||/g;
        }

        my %Search = ();
        $Param{SearchMode} = $Param{SearchMode} || '';
        if ( $Param{SearchMode} =~ m/^keyword$/i ) {
            $Search{Keyword} = $Param{SearchString};
        }
        elsif ( $Param{SearchMode} =~ m/^title$/i ) {
            $Search{Title} = $Param{SearchString};
        }
        else {
            $Search{What} = $Param{SearchString};
        }

        my @IDs = $Self->{FAQObject}->FAQSearch(
            %Search,
            States    => \%StateTypes,
            Interface => {
                Name => $Param{Interface},
            },
            UserID => 1,
            Limit  => $Param{Limit},
        );

        for my $ID (@IDs) {

            # Skip entries added by LinkKeyList
            next if ( $Result{$ID} );

            my %FAQ = $Self->{FAQObject}->FAQGet(
                ItemID => $ID,
                UserID => 1,
            );
            if (%FAQ) {
                $Result{$ID}->{'Title'} = $FAQ{Title};
                $Result{$ID}->{'Link'}  = 0;

                # Check if limit is reached
                return \%Result if ( $Param{Limit} && ( scalar keys %Result ) == $Param{Limit} );
            }
        }
    }

    return \%Result;
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
