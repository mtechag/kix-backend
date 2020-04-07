# --
# Modified version of the work: Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Maint::Loader::CacheGenerate;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Config',
    'Loader',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Generate the CSS/JS loader cache.');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Generating loader cache files...</yellow>\n");

    # Force loader also on development systems where it might be turned off.
    $Kernel::OM->Get('Config')->Set(
        Key   => 'Loader::Enabled::JS',
        Value => 1,
    );
    $Kernel::OM->Get('Config')->Set(
        Key   => 'Loader::Enabled::CSS',
        Value => 1,
    );
    my @FrontendModules = $Kernel::OM->Get('Loader')->CacheGenerate();
    if ( !@FrontendModules ) {
        $Self->PrintError("Loader cache files could not be generated.");
        return $Self->ExitCodeError();
    }
    $Self->Print("<green>Done.</green>\n");

    return $Self->ExitCodeOk();
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
