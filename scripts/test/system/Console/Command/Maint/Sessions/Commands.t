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

# get helper object
$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my %NewSessionData = (
    UserLogin => 'root',
    Email     => 'root@example.com',
    UserType  => 'User',
);

# get session object
my $SessionObject = $Kernel::OM->Get('AuthSession');

my $SessionID = $SessionObject->CreateSessionID(%NewSessionData);

$Self->True(
    $SessionID,
    "SessionID created",
);

my ( $Result, $ExitCode );

# get ListAll command object
my $ListAllCommandObject = $Kernel::OM->Get('Console::Command::Maint::Session::ListAll');
{
    local *STDOUT;
    open STDOUT, '>:utf8', \$Result;    ## no critic
    $ExitCode = $ListAllCommandObject->Execute();
}

$Self->Is(
    $ExitCode,
    0,
    "ListAll exit code",
);

$Self->True(
    scalar $Result =~ m{$SessionID}xms,
    "SessionID is listed",
);

# get DeleteAll command object
my $DeleteAllCommandObject = $Kernel::OM->Get('Console::Command::Maint::Session::DeleteAll');

$ExitCode = $DeleteAllCommandObject->Execute();

$Self->Is(
    $ExitCode,
    0,
    "DeleteAll exit code",
);

$Self->Is(
    scalar $SessionObject->GetAllSessionIDs(),
    0,
    "Sessions removed",
);

undef $Result;

{
    local *STDOUT;
    open STDOUT, '>:utf8', \$Result;    ## no critic
    $ExitCode = $ListAllCommandObject->Execute();
}

$Self->Is(
    $ExitCode,
    0,
    "ListAll exit code",
);

$Self->True(
    scalar $Result !~ m{$SessionID}xms,
    "SessionID is no longer listed",
);

$SessionID = $SessionObject->CreateSessionID(%NewSessionData);

# get DeleteExpired command object
my $DeleteExpiredCommandObject = $Kernel::OM->Get('Console::Command::Maint::Session::DeleteExpired');

$Kernel::OM->Get('Config')->Set(
    Key   => 'SessionMaxTime',
    Value => 10000
);

$ExitCode = $DeleteExpiredCommandObject->Execute();

$Self->Is(
    $ExitCode,
    0,
    "DeleteExpired exit code",
);

$Self->Is(
    scalar $SessionObject->GetAllSessionIDs(),
    1,
    "Sessions still alive",
);

undef $Result;

# get ListExpired command object
my $ListExpiredCommandObject = $Kernel::OM->Get('Console::Command::Maint::Session::ListExpired');
{
    local *STDOUT;
    open STDOUT, '>:utf8', \$Result;    ## no critic
    $ExitCode = $ListExpiredCommandObject->Execute();
}

$Self->Is(
    $ExitCode,
    0,
    "ListExpired exit code",
);

$Self->True(
    scalar $Result !~ m{$SessionID}xms,
    "SessionID is not listed as expired",
);

$Kernel::OM->Get('Config')->Set(
    Key   => 'SessionMaxTime',
    Value => -1
);

undef $Result;

{
    local *STDOUT;
    open STDOUT, '>:utf8', \$Result;    ## no critic
    $ExitCode = $ListExpiredCommandObject->Execute();
}

$Self->Is(
    $ExitCode,
    0,
    "ListExpired exit code",
);

$Self->True(
    scalar $Result =~ m{$SessionID}xms,
    "SessionID is listed as expired",
);

$ExitCode = $DeleteExpiredCommandObject->Execute();

$Self->Is(
    $ExitCode,
    0,
    "DeleteExpired exit code",
);

$Self->Is(
    scalar $SessionObject->GetAllSessionIDs(),
    0,
    "Expired sessions deleted",
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
