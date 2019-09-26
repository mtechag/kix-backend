# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Role::RoleUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Role::RoleUpdate - API Role Create Operation backend

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

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::RoleUpdate');

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
        'RoleID' => {
            Required => 1
        },
        'Role' => {
            Type => 'HASH',
            Required => 1
        },
    }
}

=item Run()

perform RoleUpdate Operation. This will return the updated RoleID.

    my $Result = $OperationObject->Run(
        Data => {
            RoleID => 123,
            Role   => {
	            Name    => '...',
	            Comment => '...',
	            ValidID => 1,
            }
	    },
	);
    

    $Result = {
        Success     => 1,                       # 0 or 1
        Code        => '',                      # in case of error
        Message     => '',                      # in case of error
        Data        => {                        # result data payload after Operation
            RoleID  => 123,                     # ID of the updated Role 
        },
    };
   
=cut


sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim Role parameter
    my $Role = $Self->_Trim(
        Data => $Param{Data}->{Role}
    );

    # check if Role exists 
    my %RoleData = $Kernel::OM->Get('Kernel::System::Role')->RoleGet(
        ID => $Param{Data}->{RoleID},
    );
  
    if ( !%RoleData ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    # update Role
    my $Success = $Kernel::OM->Get('Kernel::System::Role')->RoleUpdate(
        ID      => $Param{Data}->{RoleID},
        Name    => $Role->{Name} || $RoleData{Name},
        Comment => exists $Role->{Comment} ? $Role->{Comment} : $RoleData{Comment},
        ValidID => defined $Role->{ValidID} ? $Role->{ValidID} : $RoleData{ValidID},
        UserID  => $Self->{Authorization}->{UserID},
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code => 'Object.UnableToUpdate',
        );
    }

    # return result    
    return $Self->_Success(
        RoleID => $Param{Data}->{RoleID},
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
