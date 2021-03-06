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

my $CommandObject = $Kernel::OM->Get('Console::Command::Admin::StandardTemplate::QueueLink');

# get helper object
$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my $TemplateName = 'template' . $Helper->GetRandomID();

# try to execute command without any options
my $ExitCode = $CommandObject->Execute();
$Self->Is(
    $ExitCode,
    1,
    "No options",
);

# provide only one option
$ExitCode = $CommandObject->Execute( '--template-name', $TemplateName );
$Self->Is(
    $ExitCode,
    1,
    "Only one options",
);

# provide invalid template name
$ExitCode = $CommandObject->Execute( '--template-name', $TemplateName, '--queue-name', 'Junk' );
$Self->Is(
    $ExitCode,
    1,
    "Invalid template name",
);

# provide invalid queue name
my $QueueName = 'queue' . $Helper->GetRandomID();
$ExitCode = $CommandObject->Execute( '--template-name', 'test answer', '--queue-name', $QueueName );
$Self->Is(
    $ExitCode,
    1,
    "Invalid queue name",
);

my $StandardTemplateID = $Kernel::OM->Get('StandardTemplate')->StandardTemplateAdd(
    Name         => $TemplateName,
    Template     => 'Thank you for your email.',
    ContentType  => 'text/plain; charset=utf-8',
    TemplateType => 'Answer',
    ValidID      => 1,
    UserID       => 1,
);

$Self->True(
    $StandardTemplateID,
    "Test standard template is created - $StandardTemplateID",
);

my $QueueID = $Kernel::OM->Get('Queue')->QueueAdd(
    Name            => $QueueName,
    ValidID         => 1,
    GroupID         => 1,
    SystemAddressID => 1,
    Signature       => '',
    Comment         => 'Some comment',
    UserID          => 1,
);

$Self->True(
    $QueueID,
    "Test queue is created - $QueueID",
);

# provide valid options
$ExitCode = $CommandObject->Execute( '--template-name', $StandardTemplateID, '--queue-name', $QueueName );
$Self->Is(
    $ExitCode,
    0,
    "Valid options",
);

# cleanup is done by RestoreDatabase

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
