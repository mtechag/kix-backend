# --
# Kernel/API/Operation/FAQ/FAQCategoryDelete.pm - API FAQCategory Delete operation backend
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

package Kernel::API::Operation::V1::FAQ::FAQCategoryDelete;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsString IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::FAQ::FAQCategoryDelete - API FAQCategory FAQCategoryDelete Operation backend

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
        'FAQCategoryID' => {
            DataType => 'NUMERIC',
            Type     => 'ARRAY',
            Required => 1
        },
    }
}

=item Run()

perform FAQCategoryDelete Operation. This will return the deleted FAQCategoryID.

    my $Result = $OperationObject->Run(
        Data => {
            FAQCategoryID => 1,                      # comma separated in case of multiple or arrayref (depending on transport)
        },      
    );

    $Result = {
        Message    => '',                      # in case of error
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;
        
    # start loop
    foreach my $FAQCategoryID ( @{$Param{Data}->{FAQCategoryID}} ) {

        my @ArticleIDs = $Kernel::OM->Get('Kernel::System::FAQ')->FAQSearch(
            CategoryIDs => [ $FAQCategoryID ],
            UserID      => $Self->{Authorization}->{UserID},
        );

        if ( @ArticleIDs ) {
            return $Self->_Error(
                Code    => 'Object.DependingObjectExists',
                Message => 'Cannot delete FAQCategory. At least one article is assigned to this category.',
            );
        }

        # delete FAQCategory        
        my $Success = $Kernel::OM->Get('Kernel::System::FAQ')->CategoryDelete(
            CategoryID => $FAQCategoryID,
            UserID     => $Self->{Authorization}->{UserID},
        );
 
        if ( !$Success ) {
            return $Self->_Error(
                Code    => 'Object.UnableToDelete',
                Message => 'Could not delete FAQCategory, please contact the system administrator',
            );
        }
    }

    # return result
    return $Self->_Success();
}

1;
