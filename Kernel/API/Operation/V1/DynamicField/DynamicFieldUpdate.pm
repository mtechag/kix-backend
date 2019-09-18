# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::DynamicField::DynamicFieldUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::DynamicField::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::DynamicField::DynamicFieldUpdate - API DynamicField Update Operation backend

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

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::DynamicFieldUpdate');

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

    my $GeneralCatalogItemList = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemList(
        Class => 'DynamicField::DisplayGroup',
    );
    my @DisplayGroupIDs;
    if ( IsHashRefWithData($GeneralCatalogItemList) ) {
       @DisplayGroupIDs = keys %{$GeneralCatalogItemList};
    }
    
    return {
        'DynamicFieldID' => {
            Required => 1
        },
        'DynamicField' => {
            Type => 'HASH',
            Required => 1
        },
        'DynamicField::DisplayGroupID' => {
            RequiresValueIfUsed => 1,
            OneOf => \@DisplayGroupIDs
        },
    }
}

=item Run()

perform DynamicFieldUpdate Operation. This will return the updated DynamicFieldID.

    my $Result = $OperationObject->Run(
        Data => {
            DynamicFieldID => 123,
            DynamicField   => {
	            Name            => '...',            # optional
	            Label           => '...',            # optional
                FieldType       => '...',            # optional
                DisplayGroupID  => 123,              # optional
                ObjectType      => '...',            # optional
                Config          => { }               # optional
	            ValidID         => 1,                # optional
            }
	    },
	);
    

    $Result = {
        Success     => 1,                       # 0 or 1
        Code        => '',                      # in case of error
        Message     => '',                      # in case of error
        Data        => {                        # result data payload after Operation
            DynamicFieldID  => 123,             # ID of the updated DynamicField 
        },
    };
   
=cut


sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim DynamicField parameter
    my $DynamicField = $Self->_Trim(
        Data => $Param{Data}->{DynamicField}
    );

    # check attribute values
    my $CheckResult = $Self->_CheckDynamicField( 
        DynamicField => $DynamicField
    );

    if ( !$CheckResult->{Success} ) {
        return $Self->_Error(
            %{$CheckResult},
        );
    }

    # check if name is duplicated
    my %DynamicFieldsList = %{
        $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldList(
            Valid      => 0,
            ResultType => 'HASH',
        )
    };

    %DynamicFieldsList = reverse %DynamicFieldsList;

    if ( $DynamicField->{Name} && $DynamicFieldsList{ $DynamicField->{Name} } && $DynamicFieldsList{ $DynamicField->{Name} } ne $Param{Data}->{DynamicFieldID} ) {

        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => 'Can not update DynamicField. Another DynamicField with same name already exists.',
        );
    }

    # check if DynamicField exists 
    my $DynamicFieldData = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldGet(
        ID => $Param{Data}->{DynamicFieldID},
    );
  
    if ( !IsHashRefWithData($DynamicFieldData) ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    # check if df is writeable
    if ( $DynamicFieldData->{InternalField} == 1 ) {
        return $Self->_Error(
            Code    => 'Forbidden',
            Message => "Cannot update DynamicField. DynamicField with ID '$Param{Data}->{DynamicFieldID}' is internal and cannot be changed.",
        );        
    }

    # if it's an internal field, it's name should not change
    if ( $DynamicField->{Name} && $DynamicFieldData->{InternalField} && $DynamicField->{Name} ne $DynamicFieldData->{Name} ) {
        return $Self->_Error(
            Code    => 'Object.UnableToUpdate',
            Message => 'Cannot update name of DynamicField, because it is an internal field.',
        );
    }

    # update DynamicField
    my $Success = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldUpdate(
        ID              => $Param{Data}->{DynamicFieldID},
        Name            => $DynamicField->{Name} || $DynamicFieldData->{Name},
        Label           => $DynamicField->{Label} || $DynamicFieldData->{Label},
        FieldType       => $DynamicField->{FieldType} || $DynamicFieldData->{FieldType},
        DisplayGroupID  => $DynamicField->{DisplayGroupID} || $DynamicFieldData->{DisplayGroupID},
        ObjectType      => $DynamicField->{ObjectType} || $DynamicFieldData->{ObjectType},
        Config          => $DynamicField->{Config} || $DynamicFieldData->{Config},
        ValidID         => $DynamicField->{ValidID} || $DynamicFieldData->{ValidID},
        UserID          => $Self->{Authorization}->{UserID},
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code => 'Object.UnableToUpdate'
        );
    }

    # return result    
    return $Self->_Success(
        DynamicFieldID => $Param{Data}->{DynamicFieldID},
    );    
}


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
