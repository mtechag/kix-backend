# --
# Modified version of the work: Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

use File::stat();

# get helper object
$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my $ZZZAAuto = $Kernel::OM->Get('Config')->Get('Home') . '/Kernel/Config/Files/ZZZAAuto.pm';
my $Before   = File::stat::stat($ZZZAAuto);
sleep 2;

# get command object
my $CommandObject = $Kernel::OM->Get('Console::Command::Maint::Config::Rebuild');
my $ExitCode      = $CommandObject->Execute();

my $After = File::stat::stat($ZZZAAuto);

$Self->Is(
    $ExitCode,
    0,
    "Exit code",
);

$Self->IsNot(
    $Before->ctime(),
    $After->ctime(),
    "ZZZAAuto ctime",
);

# cleanup cache is done by RestoreDatabase

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
