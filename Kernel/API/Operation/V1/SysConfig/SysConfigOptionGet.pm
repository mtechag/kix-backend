# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::SysConfig::SysConfigOptionGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::SysConfig::SysConfigOptionGet - API SysConfigOption Get Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation::V1::SysConfig::SysConfigOptionGet->new();

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

    # get config for this screen
    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::SysConfig::SysConfigOptionGet');

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
        'Option' => {
            Type     => 'ARRAY',
            Required => 1
        },
    }
}

=item Run()

perform SysConfigOptionGet Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            Option => 123       # comma separated in case of multiple or arrayref (depending on transport)
        },
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Code         => '',                          # In case of an error
        Message      => '',                          # In case of an error
        Data         => {
            SysConfigOption => [
                {
                    ...
                },
                {
                    ...
                },
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my @SysConfigList;

    # start loop 
    foreach my $Option ( @{$Param{Data}->{Option}} ) {

        my $OrgOption = $Option;

        my $SubOption;
        if ( $Option =~ /^(.*?)###(.*?)$/g ) {
            $Option = $1;
            $SubOption = $2;
        }

        if ( !$Kernel::OM->Get('Kernel::Config')->Exists($Option) ) {
            # the option is not contained in the config hash, check if it exists
            if ( !$Kernel::OM->Get('Kernel::System::SysConfig')->Exists(Name => $OrgOption) ) {
                return $Self->_Error(
                    Code => 'Object.NotFound',
                    Message => "Config option \"$Option\" does not exist",
                );
            }
        }

        # get the SysConfig data
        my $Value = $Kernel::OM->Get('Kernel::Config')->Get(
            $Option,
        );

        # extract sub item if requested
        if ( $SubOption ) {
            $Option = $SubOption;
            $Value  = $Value->{$SubOption};
        }

        # add
        push(@SysConfigList, { 
            Name  => $OrgOption,
            Value => $Value
        });
    }

    if ( scalar(@SysConfigList) == 1 ) {
        return $Self->_Success(
            SysConfigOption => $SysConfigList[0],
        );    
    }

    # return result
    return $Self->_Success(
        SysConfigOption => \@SysConfigList,
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
