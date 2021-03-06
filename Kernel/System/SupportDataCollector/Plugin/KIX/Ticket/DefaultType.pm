# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::SupportDataCollector::Plugin::KIX::Ticket::DefaultType;

use strict;
use warnings;

use base qw(Kernel::System::SupportDataCollector::PluginBase);

use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Config',
    'Type',
);

sub GetDisplayPath {
    return Translatable('KIX');
}

sub Run {
    my $Self = shift;

    # check, if Ticket::Type is enabled
    my $TicketType = $Kernel::OM->Get('Config')->Get('Ticket::Type');

    # if not enabled, stop here
    if ( !$TicketType ) {
        return $Self->GetResults();
    }

    my $TypeObject = $Kernel::OM->Get('Type');

    # get default ticket type from config
    my $DefaultTicketType = $Kernel::OM->Get('Config')->Get('Ticket::Type::Default');

    # get list of all ticket types
    my %AllTicketTypes = reverse $TypeObject->TypeList();

    if ( $AllTicketTypes{$DefaultTicketType} ) {
        $Self->AddResultOk(
            Label => Translatable('Default Ticket Type'),
            Value => $DefaultTicketType,
        );
    }
    else {
        $Self->AddResultWarning(
            Label => Translatable('Default Ticket Type'),
            Value => $DefaultTicketType,
            Message =>
                Translatable(
                'The configured default ticket type is invalid or missing. Please change the setting Ticket::Type::Default and select a valid ticket type.'
                ),
        );
    }

    return $Self->GetResults();
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
