# --
# Modified version of the work: Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Automation::MacroAction::Ticket::DynamicFieldSet;

use strict;
use warnings;
use utf8;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Automation::MacroAction::Ticket::Common);

our @ObjectDependencies = (
    'Log',
    'Ticket',
    'DynamicField',
    'DynamicField::Backend'
);

=head1 NAME

Kernel::System::Automation::MacroAction::Ticket::DynamicFieldSet - A module to set a dynamic field value of a ticket

=head1 SYNOPSIS

All DynamicFieldSet functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Describe()

Describe this macro action module.

=cut

sub Describe {
    my ( $Self, %Param ) = @_;

    $Self->Description(Kernel::Language::Translatable('Sets a dynamic field value of a ticket.'));
    $Self->AddOption(
        Name        => 'DynamicFieldName',
        Label       => Kernel::Language::Translatable('Dynamic Field Name'),
        Description => Kernel::Language::Translatable('The name of the dynamic field.'),
        Required    => 1,
    );
    $Self->AddOption(
        Name        => 'DynamicFieldValue',
        Label       => Kernel::Language::Translatable('Dynamic Field Value'),
        Description => Kernel::Language::Translatable('The value for the dynamic field to be set.'),
        Required    => 1,
    );

    return;
}

=item Run()

Run this module. Returns 1 if everything is ok.

Example:
    my $Success = $Object->Run(
        TicketID => 123,
        Config   => {
            DynamicFieldName  => 'SomeDFName',
            DynamicFieldValue => 'New Value'
        },
        UserID   => 123,
    );

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check incoming parameters
    return if !$Self->_CheckParams(%Param);

    my $TicketObject = $Kernel::OM->Get('Ticket');

    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Param{TicketID},
        DynamicFields => 1
    );

    if (!%Ticket) {
        return;
    }

    # get required DynamicField config
    my $DynamicFieldConfig = $Kernel::OM->Get('DynamicField')->DynamicFieldGet(
        Name => $Param{Config}->{DynamicFieldName},
    );

    # check if we have a valid DynamicField
    if ( !IsHashRefWithData($DynamicFieldConfig) ) {
        $Kernel::OM->Get('Automation')->LogError(
            Referrer => $Self,
            Message  => "Can't get DynamicField config for DynamicField: \"$Param{Config}->{DynamicFieldName}\"!",
            UserID   => $Param{UserID}
        );
        return;
    }

    my $DFValue = $Kernel::OM->Get('TemplateGenerator')->ReplacePlaceHolder(
        RichText => 0,
        Text     => $Param{Config}->{DynamicFieldValue},
        TicketID => $Param{TicketID},
        Data     => {},
        UserID   => $Param{UserID},
    );

    # do nothing if the desired value is already set
    if ( 
        $Ticket{ "DynamicField_". $Param{Config}->{DynamicFieldName} } &&
        $Ticket{ "DynamicField_". $Param{Config}->{DynamicFieldName} } eq $DFValue
    ) {
        return 1;
    }

    # set the new value
    my $Success = $Kernel::OM->Get('DynamicField::Backend')->ValueSet(
        DynamicFieldConfig => $DynamicFieldConfig,
        ObjectID           => $Param{TicketID},
        Value              => $DFValue,
        UserID             => $Param{UserID},
    );

    if ( !$Success ) {
        $Kernel::OM->Get('Automation')->LogError(
            Referrer => $Self,
            Message  => "Couldn't update ticket $Param{TicketID} - setting dynamic field \"$Param{Config}->{DynamicFieldName}\" failed!",
            UserID   => $Param{UserID}
        );
        return;
    }

    return 1;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
