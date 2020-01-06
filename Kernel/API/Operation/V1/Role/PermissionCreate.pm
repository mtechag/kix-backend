# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Role::PermissionCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsString IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Role::PermissionCreate - API Role Permission Create Operation backend

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

    my %PermissionTypes = $Kernel::OM->Get('Kernel::System::Role')->PermissionTypeList(
        Valid => 1
    );

    return {        
        'RoleID' => {
            Datatype => 'NUMERIC',
            Required => 1
        },
        'Permission' => {
            Datatype => 'HASH',
            Required => 1
        },        
        'Permission::TypeID' => {
            Datatype => 'NUMERIC',
            Required => 1,
            OneOf    => \(keys %PermissionTypes),
        },
        'Permission::Target' => {
            Datatype => 'STRING',
            Required => 1
        },
    }
}

=item Run()

perform PermissionCreate Operation. This will return sucsess.

    my $Result = $OperationObject->Run(
        Data => {
            RoleID     => 6,
            Permission => {
                TypeID     => 1,
                Target     => '/tickets',
                Value      => 0x0003,
                IsRequired => 0,
                Comment    => 'just a comment'
            }
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      # 
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            PermissionID => 123
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim Permission parameter
    my $Permission = $Self->_Trim(
        Data => $Param{Data}->{Permission}
    );

    # check if role exists 
    my $Rolename = $Kernel::OM->Get('Kernel::System::Role')->RoleLookup(
        RoleID => $Param{Data}->{RoleID},
    );
  
    if ( !$Rolename ) {
        return $Self->_Error(
            Code => 'Object.ParentNotFound',
        );
    }

    # check for duplicate
    my $Exists = $Kernel::OM->Get('Kernel::System::Role')->PermissionLookup(
        RoleID       => $Param{Data}->{RoleID},
        TypeID       => $Permission->{TypeID},
        Target       => $Permission->{Target},
    );
    
    if ( $Exists ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "Cannot create permission. This permission already exists for role with ID $Param{Data}->{RoleID}.",
        );
    }

    # validate permission
    my $ValidationResult = $Kernel::OM->Get('Kernel::System::Role')->ValidatePermission(
        %{$Permission}
    );
    if ( !$ValidationResult ) {
        return $Self->_Error(
            Code    => 'BadRequest',
            Message => "Cannot create permission. The permission target doesn't match the possible ones for type PropertyValue.",
        );
    }

    # create Permission
    my $PermissionID = $Kernel::OM->Get('Kernel::System::Role')->PermissionAdd(
        RoleID     => $Param{Data}->{RoleID},
        TypeID     => $Permission->{TypeID},
        Target     => $Permission->{Target},
        Value      => $Permission->{Value},
        IsRequired => $Permission->{IsRequired},
        Comment    => $Permission->{Comment},
        UserID     => $Self->{Authorization}->{UserID},
    );

    if ( !$PermissionID ) {
        return $Self->_Error(
            Code => 'Object.UnableToCreate',
        );
    }
    
    # return result    
    return $Self->_Success(
        Code         => 'Object.Created',
        PermissionID => $PermissionID,
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