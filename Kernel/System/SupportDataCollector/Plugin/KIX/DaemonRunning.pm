# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::SupportDataCollector::Plugin::KIX::DaemonRunning;

use strict;
use warnings;

use Kernel::System::ObjectManager;

use base qw(Kernel::System::SupportDataCollector::PluginBase);

use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Config',
    'Cache',
);

sub GetDisplayPath {
    return Translatable('KIX');
}

sub Run {
    my $Self = shift;

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Config');

    # get the NodeID from the SysConfig settings, this is used on High Availability systems.
    my $NodeID = $ConfigObject->Get('NodeID') || 1;

    # get running daemon cache
    my $Running = $Kernel::OM->Get('Cache')->Get(
        Type => 'DaemonRunning',
        Key  => $NodeID,
    );

    if ($Running) {
        $Self->AddResultOk(
            Label   => Translatable('Daemon'),
            Value   => 1,
            Message => Translatable('Daemon is running.'),
        );
    }
    else {
        $Self->AddResultProblem(
            Label   => Translatable('Daemon'),
            Value   => 0,
            Message => Translatable('Daemon is not running.'),
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
