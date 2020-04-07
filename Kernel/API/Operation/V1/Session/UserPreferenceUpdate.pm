# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Session::UserPreferenceUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Session::UserPreferenceUpdate - API Session UserPreference Update Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to Update an instance of this
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
        'UserPreferenceID' => {
            Required => 1
        },
        'UserPreference' => {
            Type     => 'HASH',
            Required => 1
        },
        'UserPreference::Value' => {
            Required => 1
        },
    }
}

=item Run()

perform UserPreferenceUpdate Operation. This will return success.

    my $Result = $OperationObject->Run(
        Data => {
            UserPreferenceID => '...',
            UserPreference   => {
                Value => '...'
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      # 
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            UserPreferenceID => '...'
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim Preference parameter
    my $Preference = $Self->_Trim(
        Data => $Param{Data}->{UserPreference},
    );

    # check if user exists and if preference exists for given user
    my %UserData = $Kernel::OM->Get('User')->GetUserData(
        UserID => $Self->{Authorization}->{UserID}
    );
    if ( !%UserData ) {
        return $Self->_Error(
            Code => 'ParentObject.NotFound',
        );
    }
    if ( !exists $UserData{Preferences}->{$Param{Data}->{UserPreferenceID}} ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    # add user preference
    my $Success = $Kernel::OM->Get('User')->SetPreferences(
        UserID => $Self->{Authorization}->{UserID},
        Key    => $Param{Data}->{UserPreferenceID},
        Value  => $Preference->{Value},
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code => 'Object.UnableToUpdate',
        );
    }
    
    # return result    
    return $Self->_Success(
        UserPreferenceID => $Param{Data}->{UserPreferenceID}
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
