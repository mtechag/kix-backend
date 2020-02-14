# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Contact::ContactCreate;

use strict;
use warnings;

use Data::UUID;
use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::Contact::V1::ContactCreate - API Contact Create Operation backend

=head1 SYNOPSIS

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
    for my $Needed (qw( DebuggerObject WebserviceID )) {
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
        'Contact' => {
            Type     => 'HASH',
            Required => 1
        },          
        'Contact::Firstname' => {
            Required => 1
        },            
        'Contact::Lastname' => {
            Required => 1
        },
    }
}

=item Run()

perform ContactCreate Operation. This will return the created ContactID.

    my $Result = $OperationObject->Run(
        Data => {
            Contact => {
                ...                 # attributes
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      # 
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            ContactID  => '',                       # ContactID 
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim Contact parameter
    my $Contact = $Self->_Trim(
        Data => $Param{Data}->{Contact}
    );

    # check assigned User exists and is not assigned to another contact
    if ($Contact->{AssignedUserID}) {
        my $ExistingUser = $Kernel::OM->Get('Kernel::System::User')->UserLookup(
            UserID => $Contact->{AssignedUserID},
            Silent => 1,
        );
        if (!$ExistingUser) {
            return $Self->_Error(
                Code    => 'Object.NotFound',
                Message => "Cannot create contact. No user with given ID exists.",
            );
        }
        else {
            my $ExistingContact = $Kernel::OM->Get('Kernel::System::Contact')->ContactLookup(
                UserID => $Contact->{AssignedUserID},
                Silent => 1,
            );
            if ($ExistingContact) {
                return $Self->_Error(
                    Code    => 'Object.AlreadyExists',
                    Message => "Cannot create contact. User is already assigned.",
                );
            }
        }
    }

    # check if Email is provided and if so if it exists
    if ($Contact->{Email}) {
        my $ExistingContact = $Kernel::OM->Get('Kernel::System::Contact')->ContactLookup(
            Email => $Contact->{Email},
            Silent           => 1,
        );
        if ($ExistingContact) {
            return $Self->_Error(
                Code    => 'Object.AlreadyExists',
                Message => 'Cannot create contact. Another contact with same email address already exists.',
            );
        }
    }

    # check if primary OrganisationID exists
    if ($Contact->{PrimaryOrganisationID}) {
        my %OrgData = $Kernel::OM->Get('Kernel::System::Organisation')->OrganisationGet(
            ID => $Contact->{PrimaryOrganisationID},
        );

        if (!%OrgData || $OrgData{ValidID} != 1) {
            return $Self->_Error(
                Code    => 'BadRequest',
                Message => 'Validation failed. No valid organisation found for primary organisation ID "' . $Contact->{PrimaryOrganisationID} . '".',
            );
        }
    }

    if (IsArrayRefWithData($Contact->{OrganisationIDs})) {
        my @OrgIDs;
        # check if primary OrganisationID is contained in assigned OrganisationIDs
        @OrgIDs = @{$Contact->{OrganisationIDs}};
        if (!grep /$Contact->{PrimaryOrganisationID}/, @OrgIDs) {
            return $Self->_Error(
                Code    => 'BadRequest',
                Message => 'Validation failed. Primary organisation ID "' . $Contact->{PrimaryOrganisationID} .
                    '" is not available in assigned organisation IDs "' . (join(", ", @OrgIDs)) . '".',
            );
        }
        # check if each assigned orga exists and is valid
        foreach my $OrgID (@OrgIDs) {
            my %OrgData = $Kernel::OM->Get('Kernel::System::Organisation')->OrganisationGet(
                ID => $OrgID,
            );
            if (!%OrgData || $OrgData{ValidID} != 1) {
                return $Self->_Error(
                    Code    => 'BadRequest',
                    Message => 'Validation failed. No valid organisation found for assigned organisation ID "' . $OrgID . '".',
                );
            }
        }
    }
    else {
        $Contact->{OrganisationIDs} = ($Contact->{PrimaryOrganisationID}) ? [$Contact->{PrimaryOrganisationID}] : undef;
    }

    # create Contact
    my $ContactID = $Kernel::OM->Get('Kernel::System::Contact')->ContactAdd(
        %{$Contact},
        ValidID         => $Contact->{ValidID} || 1,
        UserID          => $Self->{Authorization}->{UserID},
    );    
    if ( !$ContactID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create Contact, please contact the system administrator',
        );
    }
    
    return $Self->_Success(
        Code   => 'Object.Created',
        ContactID => 0 + $ContactID,
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
