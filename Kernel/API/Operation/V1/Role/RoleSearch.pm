# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Role::RoleSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::Role::RoleGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Role::RoleSearch - API Role Search Operation backend

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

perform RoleSearch Operation. This will return a Role ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            Role => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform Role search
    my %RoleList = $Kernel::OM->Get('Role')->RoleList(
        Result => 'HASH',
    );

	# get already prepared Role data from RoleGet operation
    if ( IsHashRefWithData(\%RoleList) ) {  	
        my $RoleGetResult = $Self->ExecOperation(
            OperationType            => 'V1::Role::RoleGet',
            SuppressPermissionErrors => 1,
            Data      => {
                RoleID => join(',', sort keys %RoleList),
            }
        );    

        if ( !IsHashRefWithData($RoleGetResult) || !$RoleGetResult->{Success} ) {
            return $RoleGetResult;
        }

        my @RoleDataList = IsArrayRef($RoleGetResult->{Data}->{Role}) ? @{$RoleGetResult->{Data}->{Role}} : ( $RoleGetResult->{Data}->{Role} );

        if ( IsArrayRefWithData(\@RoleDataList) ) {
            return $Self->_Success(
                Role => \@RoleDataList,
            )
        }
    }

    # return result
    return $Self->_Success(
        Role => [],
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
