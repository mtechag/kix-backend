# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Admin::Stats::Import;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Stats',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Install Package Stats');
    $Self->AddOption(
        Name        => 'file-prefix',
        Description => "Name of the file prefix which should be used.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/(.*)/smx,
    );

    return;
}

sub PreRun {
    my ( $Self, %Param ) = @_;

    # check prefix
    $Self->{FilePrefix} = $Self->GetOption('file-prefix');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Install stats with file prefix $Self->{FilePrefix}...</yellow>\n");

    $Kernel::OM->Get('Stats')->StatsInstall(
        FilePrefix => $Self->{FilePrefix},
        UserID     => 1,
    );

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
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
