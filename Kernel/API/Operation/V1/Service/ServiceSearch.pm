# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Service::ServiceSearch;

use strict;
use warnings;

use Kernel::API::Operation::V1::Service::ServiceGet;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Service::ServiceSearch - API Service Search Operation backend

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

perform ServiceSearch Operation. This will return a Service ID list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success => 1,                                # 0 or 1
        Code    => '',                          # In case of an error
        Message => '',                          # In case of an error
        Data    => {
            Service => [
                {},
                {}
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # perform Service search
    my %ServiceList = $Kernel::OM->Get('Service')->ServiceList(
        UserID  => $Self->{Authorization}->{UserID},
    );

	# get already prepared Service data from ServiceGet operation
    if ( IsHashRefWithData(\%ServiceList) ) {  	
        my $ServiceGetResult = $Self->ExecOperation(
            OperationType            => 'V1::Service::ServiceGet',
            SuppressPermissionErrors => 1,
            Data      => {
                ServiceID => join(',', sort keys %ServiceList),
            }
        );    

        if ( !IsHashRefWithData($ServiceGetResult) || !$ServiceGetResult->{Success} ) {
            return $ServiceGetResult;
        }

        my @ServiceDataList = IsArrayRef($ServiceGetResult->{Data}->{Service}) ? @{$ServiceGetResult->{Data}->{Service}} : ( $ServiceGetResult->{Data}->{Service} );

        if ( IsArrayRefWithData(\@ServiceDataList) ) {
            return $Self->_Success(
                Service => \@ServiceDataList,
            )
        }
    }

    # return result
    return $Self->_Success(
        Service => [],
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
