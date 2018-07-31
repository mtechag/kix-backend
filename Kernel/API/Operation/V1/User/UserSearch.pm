# --
# Kernel/API/Operation/User/UserSearch.pm - API User Search operation backend
# based upon Kernel/API/Operation/Ticket/TicketSearch.pm
# original Copyright (C) 2001-2015 OTRS AG, http://otrs.com/
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::User::UserSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw( :all );

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::User::UserSearch - API User Search Operation backend

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

perform UserSearch Operation. This will return a User ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Message => '',                               # In case of an error
        Data         => {
            User => [
                {
                },
                {                    
                }
            ],
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform user search
    my %UserList = $Kernel::OM->Get('Kernel::System::User')->UserList(
        Type => 'Short',
    );

    if (IsHashRefWithData(\%UserList)) {

        # get already prepared user data from UserGet operation
        my $UserGetResult = $Self->ExecOperation(
            OperationType => 'V1::User::UserGet',
            Data          => {
                UserID => join(',', sort keys %UserList),
            }
        );
        if ( !IsHashRefWithData($UserGetResult) || !$UserGetResult->{Success} ) {
            return $UserGetResult;
        }

        my @ResultList = IsArrayRefWithData($UserGetResult->{Data}->{User}) ? @{$UserGetResult->{Data}->{User}} : ( $UserGetResult->{Data}->{User} );
        
        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                User => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        User => [],
    );
}

1;
