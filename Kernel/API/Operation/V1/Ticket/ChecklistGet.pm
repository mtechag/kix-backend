# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Ticket::ChecklistGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Ticket::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Ticket::ChecklistGet - API ChecklistGet Operation backend

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
        'TicketID' => {
            Required => 1
        },
        'ChecklistItemID' => {
            Type     => 'ARRAY',
            Required => 1
        },
    }
}

=item Run()

perform ArticleFlagGet Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            TicketID         => 123                                            # required
            ChecklistItemID  => 1                                              # required 
        },
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Code         => '',                               # In case of an error
        Message      => '',                               # In case of an error
        Data         => {
            ChecklistItem => {
                ID       => 1,
                Task     => 'text1',
                State    => 'open',
                Position => 1
            }
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my $Checklist = $Kernel::OM->Get('Kernel::System::Ticket')->TicketChecklistGet(
        TicketID => $Param{Data}->{TicketID},
        UserID   => $Self->{Authorization}->{UserID},
    );

    my @ItemList;

    if ( IsHashRefWithData($Checklist) ) {
        # start loop
        foreach my $ItemID ( sort @{$Param{Data}->{ChecklistItemID}} ) {
            push(@ItemList, $Checklist->{$ItemID});
        }
    }

    if ( scalar(@ItemList) == 0 ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }
    elsif ( scalar(@ItemList) == 1 ) {
        return $Self->_Success(
            ChecklistItem => $ItemList[0],
        );    
    }

    return $Self->_Success(
        ChecklistItem => \@ItemList,
    );
}

1;




=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
