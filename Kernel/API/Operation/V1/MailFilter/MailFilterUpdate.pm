# --
# Kernel/API/Operation/MailFilter/MailFilterUpdate.pm - API MailFilter Update operation backend
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Ricky(dot)Kaiser(at)cape(dash)it(dot)de
#
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::MailFilter::MailFilterUpdate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(Kernel::API::Operation::V1::Common);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::MailFilter::MailFilterUpdate - API MailFilter Update Operation backend

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
        'MailFilterID' => {
            Required => 1
        },
        'MailFilter' => {
            Type     => 'HASH',
            Required => 1
        },
        'MailFilter::Name' => {
            RequiresValueIfUsed => 1
        },
        'MailFilter::StopAfterMatch' => {
            RequiresValueIfUsed => 1,
            OneOf => [ 0, 1 ]
        },
        'MailFilter::ValidID' => {
            RequiresValueIfUsed => 1,
            OneOf => [ 1, 2, 3 ]
        },
        'MailFilter::Match' => {
            RequiresValueIfUsed => 1,
            Type                => 'ARRAY'
        },
        'MailFilter::Set' => {
            RequiresValueIfUsed => 1,
            Type                => 'ARRAY'
        },
    };
}

=item Run()

perform MailFilterUpdate Operation. This will return the updated TypeID.

    my $Result = $OperationObject->Run(
        Data => {
            MailFilterID => 123,
            MailFilter  => {
                Name           => 'some name',          # optional
                StopAfterMatch => 1 | 0,                # optional, default 0
                Comment        => 'some comment',       # optional
                ValidID        => 1,                    # optional
                Match          => [                     # optional
                    {
                        Key    => 'From',
                        Value  => 'email@example.com',
                        Not    => 0                     # optional
                    },
                    { 
                        Key    => 'Subject',
                        Value  => 'Test',
                        Not    => 1                     # optional
                    }
                ],
                Set            => [                     # optional
                    {
                        Key    => 'X-KIX-Queue',
                        Value  => 'Some::Queue'
                    }
                ]
            }
        }
    );

    $Result = {
        Success           => 1,                       # 0 or 1
        Code              => '',                      # in case of error
        Message           => '',                      # in case of error
        Data              => {                        # result data payload after Operation
            MailFilterID  => 123,                     # ID of the updated MailFilter 
        },
    };
   
=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim MailFilter parameter
    my $MailFilter = $Self->_Trim( Data => $Param{Data}->{MailFilter} );

    if ( exists $MailFilter->{Name} && !$MailFilter->{Name} ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => "Name is invalid!"
        );
    }

    # check if another filter with name already exists
    my $Exists = $Kernel::OM->Get('Kernel::System::PostMaster::Filter')->NameExistsCheck(
        Name => $MailFilter->{Name},
        ID   => $Param{Data}->{MailFilterID}
    );
    if ($Exists) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "The name of the filter is already used."
        );
    }

    # get "old" data of MailFilter
    my %MailFilterData = $Kernel::OM->Get('Kernel::System::PostMaster::Filter')->FilterGet(
        ID     => $Param{Data}->{MailFilterID},
        UserID => $Self->{Authorization}->{UserID},
    );
    if ( !%MailFilterData ) {
        return $Self->_Error( Code => 'Object.NotFound', );
    }

    $Self->_PrepareFilter( Filter => $MailFilter );

    # update MailFilter
    my $Success = $Kernel::OM->Get('Kernel::System::PostMaster::Filter')->FilterUpdate(
        ID             => $Param{Data}->{MailFilterID},
        Name           => $MailFilter->{Name} || $MailFilterData{Name},
        ValidID        => $MailFilter->{ValidID} || $MailFilterData{ValidID},
        StopAfterMatch => defined $MailFilter->{StopAfterMatch} ? $MailFilter->{StopAfterMatch} : $MailFilterData{StopAfterMatch},
        Comment        => exists $MailFilter->{Comment} ? $MailFilter->{Comment} : $MailFilterData{Comment},
        Match          => $MailFilter->{Match} || $MailFilterData{Match},
        Set            => $MailFilter->{Set}   || $MailFilterData{Set},
        Not            => $MailFilter->{Not}   || $MailFilterData{Not},
        UserID         => $Self->{Authorization}->{UserID},
    );

    if ( !$Success ) {
        return $Self->_Error( Code => 'Object.UnableToUpdate', );
    }

    # return result
    return $Self->_Success( MailFilterID => $Param{Data}->{MailFilterID} );
}

sub _PrepareFilter {
    my ( $Self, %Param ) = @_;

    if ( IsArrayRefWithData( $Param{Filter}->{Match} ) ) {
        my %NotData   = ();
        my %MatchData = ();
        for my $Match ( @{ $Param{Filter}->{Match} } ) {
            $MatchData{ $Match->{Key} } = $Match->{Value};
            $NotData{ $Match->{Key} }   = $Match->{Not} ? 1 : 0;
        }
        $Param{Filter}->{Match} = \%MatchData;
        $Param{Filter}->{Not}   = \%NotData;
    }

    if ( IsArrayRefWithData( $Param{Filter}->{Set} ) ) {
        my %SetData = ();
        for my $Set ( @{ $Param{Filter}->{Set} } ) {
            $SetData{ $Set->{Key} } = $Set->{Value};
        }
        $Param{Filter}->{Set} = \%SetData;
    }
}

1;
