# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::CMDB::ConfigItemImageGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::CMDB::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::CMDB::ConfigItemImageGet - API ConfigItemImageGet Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation::V1->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw(DebuggerObject WebserviceID)) {
        if ( !$Param{$Needed} ) {
            return {
                Success      => 0,
                ErrorMessage => "Got no $Needed!",
            };
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
        'ConfigItemID' => {
            DataType => 'NUMERIC',
            Required => 1
        },
        'ImageID' => {
            Type     => 'ARRAY',
            Required => 1
        },
    }
}

=item Run()

perform ConfigItemImageGet Operation.

    my $Result = $OperationObject->Run(
        ConfigItemID => 1,                                # required 
        ImageID      => 1                                 # required
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Code         => '',                               # In case of an error
        Message      => '',                               # In case of an error
        Data         => {
            Image => [
                {
                    ...
                },
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;     

    # if necessary check if config item is accessible for current customer user
    my $CustomerCheck = $Self->_CheckCustomerAssignedConfigItem(
        ConfigItemIDList => $Param{Data}->{ConfigItemID}
    );
    if ( !$CustomerCheck->{Success} ) {
        return $Self->_Error(
            %{$CustomerCheck},
        );
    }

    # check if ConfigItem exists
    my $ConfigItem = $Kernel::OM->Get('ITSMConfigItem')->ConfigItemGet(
        ConfigItemID => $Param{Data}->{ConfigItemID},
    );

    if (!IsHashRefWithData($ConfigItem)) {
        return $Self->_Error(
            Code => 'ParentObject.NotFound',
        );
    }

    my @ImageList;
    foreach my $ImageID ( @{$Param{Data}->{ImageID}} ) {                 

        my %Image = $Kernel::OM->Get('ITSMConfigItem')->ImageGet(
            ConfigItemID => $Param{Data}->{ConfigItemID},
            ImageID      => $ImageID,
        );

        if (!IsHashRefWithData(\%Image)) {
            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }

        if ( !$Param{Data}->{include}->{Content} ) {
            delete $Image{Content};
        }

        # add ImageID to result
        $Image{ID} = $ImageID;

        # add ConfigItemID to result
        $Image{ConfigItemID} = $Param{Data}->{ConfigItemID};

        push(@ImageList, \%Image);
    }

    if ( scalar(@ImageList) == 0 ) {
        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "Could not get data for ImageID ".join(',', $Param{Data}->{ImageID}),
        );
    }
    elsif ( scalar(@ImageList) == 1 ) {
        return $Self->_Success(
            Image => $ImageList[0],
        );    
    }

    return $Self->_Success(
        Image => \@ImageList,
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
