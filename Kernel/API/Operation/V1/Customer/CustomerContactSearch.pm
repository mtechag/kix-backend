# --
# Kernel/API/Operation/Customer/CustomerSearch.pm - API Customer Search operation backend
# based upon Kernel/API/Operation/Ticket/TicketSearch.pm
# original Copyright (C) 2001-2015 OTRS AG, http://otrs.com/
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Customer::CustomerContactSearch;

use strict;
use warnings;

use Kernel::System::VariableCheck qw( :all );

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Customer::CustomerContactSearch - API Customer Contact Search Operation backend

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

=item ParameterDefinition()

define parameter preparation and check for this operation

    my $Result = $OperationObject->ParameterDefinition(
        Data => {
            ...
        },
    );

    $Result = {
        ...
    };

=cut

sub ParameterDefinition {
    my ( $Self, %Param ) = @_;

    return {
        'CustomerID' => {
            Required => 1
        }                
    }
}

=item Run()

perform CustomerContactSearch Operation. This will return a Customer list.

    my $Result = $OperationObject->Run(
        Data => {
        }
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Message => '',                               # In case of an error
        Data         => {
            Contact => [
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

    # perform contact search
    my %ContactList = $Kernel::OM->Get('Kernel::System::CustomerUser')->CustomerSearch(
        CustomerID => $Param{Data}->{CustomerID},
        Valid      => 0,
    );

    if (IsHashRefWithData(\%ContactList)) {
        
        # get already prepared Contact data from ContactGet operation
        my $ContactGetResult = $Self->ExecOperation(
            OperationType => 'V1::Contact::ContactGet',
            Data          => {
                ContactID => join(',', sort keys %ContactList),
            }
        );
        if ( !IsHashRefWithData($ContactGetResult) || !$ContactGetResult->{Success} ) {
            return $ContactGetResult;
        }

        my @ResultList = IsArrayRefWithData($ContactGetResult->{Data}->{Contact}) ? @{$ContactGetResult->{Data}->{Contact}} : ( $ContactGetResult->{Data}->{Contact} );
        
        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                Contact => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        Contact => [],
    );
}

1;
