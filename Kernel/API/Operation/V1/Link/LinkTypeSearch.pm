# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Link::LinkTypeSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Link::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Link::LinkTypeSearch - API LinkType Search Operation backend

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw(DebuggerObject WebserviceID)) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => 'Operation.InternalError',
                Message => "Got no $Needed!"
            );
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    return $Self;
}

=item Run()

perform LinkTypeSearch Operation. This will return a LinkType list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            LinkType => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform Type search
    my %TypeList = $Kernel::OM->Get('Kernel::System::LinkObject')->PossibleLinkList();

	# get already prepared Type data from LinkTypeGet operation
    if ( IsHashRefWithData(\%TypeList) ) {  	

        my @Result;
        foreach my $LinkType ( sort keys %TypeList ) {
            my $TypeID = $Kernel::OM->Get('Kernel::System::LinkObject')->TypeLookup(
                Name   => $TypeList{$LinkType}->{Type},
                UserID => $Self->{Authorization}->{UserID},
            );
            my %TypeData = $Kernel::OM->Get('Kernel::System::LinkObject')->TypeGet(
                TypeID => $TypeID,
            );

            # delete some unused information
            foreach my $Attr ( qw(CreateBy CreateTime ChangeBy ChangeTime )) {
                delete $TypeData{$Attr};
            }

            my %Type = (
                Source  => $TypeList{$LinkType}->{Object1},
                Target  => $TypeList{$LinkType}->{Object2},
                %TypeData,
            );
            push(@Result, \%Type);
        }

        return $Self->_Success(
            LinkType => \@Result,
        )

    }

    # return result
    return $Self->_Success(
        LinkType => [],
    );
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
