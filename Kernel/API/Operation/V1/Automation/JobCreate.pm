# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Automation::JobCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Automation::JobCreate - API Job Create Operation backend

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
        'Job' => {
            Type     => 'HASH',
            Required => 1
        },
        'Job::Type' => {
            Required => 1,
            OneOf    => [ 'Ticket' ]
        },
        'Job::Name' => {
            Required => 1
        },
    }
}

=item Run()

perform JobCreate Operation. This will return the created JobID.

    my $Result = $OperationObject->Run(
        Data => {
            Job  => {                
                Name    => 'Item Name',
                Type    => 'Ticket',
                Comment => 'Comment',              # optional
                Filter  => {},                     # optional
                ExecPlanIDs  => [                  # optional
                    123
                ],
                MacroIDs => [                      # optional
                    123
                ],
                ValidID => 1,                      # optional
            },
        },
    );

    $Result = {
        Success => 1,                       # 0 or 1
        Code    => '',                      # 
        Message => '',                      # in case of error
        Data    => {                        # result data payload after Operation
            JobID  => '',    # ID of the created Job
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim Job parameter
    my $Job = $Self->_Trim(
        Data => $Param{Data}->{Job}
    );

    my $JobID = $Kernel::OM->Get('Kernel::System::Automation')->JobLookup(
        Name => $Job->{Name},
    );

    if ( $JobID ) {
        return $Self->_Error(
            Code    => 'Object.AlreadyExists',
            Message => "Cannot create job. A job with the same name '$Job->{Name}' already exists.",
        );
    }

    # create job
    my $JobID = $Kernel::OM->Get('Kernel::System::Automation')->JobAdd(
        Name     => $Job->{Name},
        Type     => $Job->{Type},
        Filter   => $Job->{Filter},
        Comment  => $Job->{Comment} || '',
        ValidID  => $Job->{ValidID} || 1,
        UserID   => $Self->{Authorization}->{UserID}
    );

    if ( !$JobID ) {
        return $Self->_Error(
            Code => 'Object.UnableToCreate',
        );
    }

    # assign execution plans
    if ( IsArrayRefWithData($Job->{ExecPlanIDs}) ) {

        foreach my $ExecPlanID ( @{$Job->{ExecPlanIDs}} ) {
            my $Result = $Self->ExecOperation(
                OperationType => 'V1::Automation::JobExecPlanIDCreate',
                Data          => {
                    JobID      => $JobID,
                    ExecPlanID => $ExecPlanID,
                }
            );

            if ( !$Result->{Success} ) {
                return $Self->_Error(
                    %{$Result},
                )
            }
        }
    }

    # assign macros
    if ( IsArrayRefWithData($Job->{MacroIDs}) ) {

        foreach my $MacroID ( @{$Job->{MacroIDs}} ) {
            my $Result = $Self->ExecOperation(
                OperationType => 'V1::Automation::JobMacroIDCreate',
                Data          => {
                    JobID   => $JobID,
                    MacroID => $MacroID,
                }
            );

            if ( !$Result->{Success} ) {
                return $Self->_Error(
                    %{$Result},
                )
            }
        }
    }

    # return result
    return $Self->_Success(
        Code   => 'Object.Created',
        JobID => $JobID,
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
