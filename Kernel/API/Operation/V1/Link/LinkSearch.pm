# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Link::LinkSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::Link::LinkGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Link::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Link::LinkSearch - API Link Search Operation backend

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

perform LinkSearch Operation. This will return a Link ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            Link => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # prepare search if given
    my %SearchParam;
    if ( IsArrayRefWithData($Self->{Search}->{Link}->{AND}) ) {
        foreach my $SearchItem ( @{$Self->{Search}->{Link}->{AND}} ) {
            # ignore everything that we don't support in the core DB search (the rest will be done in the generic API Searching)
            next if ($SearchItem->{Field} !~ /^(SourceObject|SourceKey|TargetObject|TargetKey|Type)$/g);
            next if ($SearchItem->{Operator} ne 'EQ');

            $SearchParam{$SearchItem->{Field}} = $SearchItem->{Value};
        }
    }

    # perform Link search
    my $LinkList = $Kernel::OM->Get('Kernel::System::LinkObject')->LinkSearch(
        UserID  => $Self->{Authorization}->{UserID},
        Limit   => IsHashRefWithData(\%SearchParam) ? undef : ($Self->{Limit}->{Link} || $Self->{Limit}->{'__COMMON'}),        # only apply DB side limit if no SearchParam exists
        %SearchParam,
    );

	# get already prepared Link data from LinkGet operation
    if ( IsArrayRefWithData($LinkList) ) {  	
        my $LinkGetResult = $Self->ExecOperation(
            OperationType => 'V1::Link::LinkGet',
            Data      => {
                LinkID => join(',', sort @{$LinkList}),
            }
        );    

        if ( !IsHashRefWithData($LinkGetResult) || !$LinkGetResult->{Success} ) {
            return $LinkGetResult;
        }

        my @LinkDataList = IsArrayRef($LinkGetResult->{Data}->{Link}) ? @{$LinkGetResult->{Data}->{Link}} : ( $LinkGetResult->{Data}->{Link} );

        if ( IsArrayRefWithData(\@LinkDataList) ) {
            return $Self->_Success(
                Link => \@LinkDataList,
            )
        }
    }

    # return result
    return $Self->_Success(
        Link => [],
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
