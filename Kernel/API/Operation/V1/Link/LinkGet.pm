# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Link::LinkGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Link::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Link::LinkGet - API Link Get Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation::V1::Link::LinkGet->new();

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
    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::Link::LinkGet');

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
        'LinkID' => {
            Type     => 'ARRAY',
            DataType => 'NUMERIC',
            Required => 1
        }                
    }
}

=item Run()

perform LinkGet Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            LinkID => 123       # comma separated in case of multiple or arrayref (depending on transport)
        },
    );

    $Result = {
        Success      => 1,                           # 0 or 1
        Code         => '',                          # In case of an error
        Message      => '',                          # In case of an error
        Data         => {
            Link => [
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

    my @LinkList;

    # start loop
    foreach my $LinkID ( @{$Param{Data}->{LinkID}} ) {

        # get the Link data
        my %LinkData = $Kernel::OM->Get('Kernel::System::LinkObject')->LinkGet(
            LinkID => $LinkID,
            UserID  => $Self->{Authorization}->{UserID},
        );

        # remove unwanted attributes 
        foreach my $Attr ( qw(SourceObjectID TargetObjectID TypeID) ) {
            delete $LinkData{$Attr};
        }

        if ( !IsHashRefWithData( \%LinkData ) ) {
            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }
        
        # add
        push(@LinkList, \%LinkData);
    }

    if ( scalar(@LinkList) == 1 ) {
        return $Self->_Success(
            Link => $LinkList[0],
        );    
    }

    # return result
    return $Self->_Success(
        Link => \@LinkList,
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
