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

# get ticket object
my $ColumnFilterObject = $Kernel::OM->Get('Ticket::ColumnFilter');

# get helper object
$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my @Tests = (
    {
        Name   => 'No array',
        Params => {
            ColumnName => 'ticket.id',
            TicketIDs  => 1,
        },
        Result => undef,
    },
    {
        Name   => 'Single Integer',
        Params => {
            ColumnName => 'ticket.id',
            TicketIDs  => [1],
        },
        Result => ' AND (  ticket.id IN (1)  ) ',
    },
    {
        Name   => 'Single Integer, default table',
        Params => {
            TicketIDs => [1],
        },
        Result => ' AND (  t.id IN (1)  ) ',
    },
    {
        Name   => 'Single Integer, no AND',
        Params => {
            TicketIDs  => [1],
            IncludeAdd => 0,
        },
        Result => ' t.id IN (1) ',
    },
    {
        Name   => 'Sorted values',
        Params => {
            ColumnName => 'ticket.id',
            TicketIDs  => [ 2, 1, -1, 0 ],
        },
        Result => ' AND (  ticket.id IN (-1, 0, 1, 2)  ) ',
    },
    {
        Name   => 'Invalid value',
        Params => {
            ColumnName => 'ticket.id',
            TicketIDs  => [1.1],
        },
        Result => undef,
    },
    {
        Name   => 'Mix of valid and invalid values',
        Params => {
            ColumnName => 'ticket.id',
            TicketIDs  => [ 1, 1.1 ],
        },
        Result => undef,
    },
);

for my $Test (@Tests) {
    $Self->Is(
        scalar $ColumnFilterObject->_TicketIDStringGet( %{ $Test->{Params} } ),
        $Test->{Result},
        "$Test->{Name} _TicketIDStringGet()"
    );
}

# cleanup is done by RestoreDatabase.

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
