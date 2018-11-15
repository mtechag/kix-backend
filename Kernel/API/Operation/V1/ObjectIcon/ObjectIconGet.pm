# --
# Kernel/API/Operation/V1/ObjectIcon/ObjectIconGet.pm - API ObjectIcon Get operation backend
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Rene(dot)Boehm(at)cape(dash)it(dot)de
# 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::ObjectIcon::ObjectIconGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::ObjectIcon::ObjectIconGet - API ObjectIcon ObjectIconGet Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation::V1::ObjectIcon::ObjectIconGet->new();

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
    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::ObjectIcon::ObjectIconGet');

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
        'ObjectIconID' => {
            Type     => 'ARRAY',
            DataType => 'NUMERIC',
            Required => 1
        }                
    }
}

=item Run()

perform ObjectIconGet Operation. This function is able to return
one or more address entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            ObjectIconID => 123       # comma separated in case of multiple or arrayref (depending on transport)
        },
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Code         => '',                          # In case of an error
        Message      => '',                          # In case of an error
        Data         => {
            ObjectIcon => [
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

    my @ObjectIconList;

    # start loop
    foreach my $ObjectIconID ( @{$Param{Data}->{ObjectIconID}} ) {

        # get the ObjectIcon data
        my %ObjectIconData = $Kernel::OM->Get('Kernel::System::ObjectIcon')->ObjectIconGet(
            ID => $ObjectIconID,             
        );

        if ( !IsHashRefWithData( \%ObjectIconData ) ) {
            return $Self->_Error(
                Code    => 'Object.NotFound',
                Message => "No data found for ObjectIconID $ObjectIconID.",
            );
        }
        
        # add
        push(@ObjectIconList, \%ObjectIconData);
    }
  
    if ( scalar(@ObjectIconList) == 1 ) {
        return $Self->_Success(
            ObjectIcon => $ObjectIconList[0],
        );    
    }

    # return result
    return $Self->_Success(
        ObjectIcon => \@ObjectIconList,
    );
}

1;
