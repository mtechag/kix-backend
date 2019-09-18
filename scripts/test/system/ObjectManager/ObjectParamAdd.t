# --
# Modified version of the work: Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use vars (qw($Self));

use Kernel::System::ObjectManager;

local $Kernel::OM = Kernel::System::ObjectManager->new();

$Kernel::OM->ObjectParamAdd(
    'Kernel::Config' => {
        Data => 'Test payload',
    },
);

$Self->IsDeeply(
    $Kernel::OM->{Param}->{'Kernel::Config'},
    {
        Data => 'Test payload',
    },
    'ObjectParamAdd set key',
);

$Kernel::OM->ObjectParamAdd(
    'Kernel::Config' => {
        Data2 => 'Test payload 2',
    },
);

$Self->IsDeeply(
    $Kernel::OM->{Param}->{'Kernel::Config'},
    {
        Data  => 'Test payload',
        Data2 => 'Test payload 2',
    },
    'ObjectParamAdd set key',
);

$Kernel::OM->ObjectParamAdd(
    'Kernel::Config' => {
        Data => undef,
    },
);

$Self->IsDeeply(
    $Kernel::OM->{Param}->{'Kernel::Config'},
    {
        Data2 => 'Test payload 2',
    },
    'ObjectParamAdd removed key',
);

$Kernel::OM->ObjectParamAdd(
    'Kernel::Config' => {
        Data2 => undef,
    },
);

$Self->IsDeeply(
    $Kernel::OM->{Param}->{'Kernel::Config'},
    {},
    'ObjectParamAdd removed key',
);

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
