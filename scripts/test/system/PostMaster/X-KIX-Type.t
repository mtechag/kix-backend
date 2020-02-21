# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

use Kernel::System::PostMaster;

# get needed objects
my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

# get helper object
$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

$Kernel::OM->Get('Kernel::System::Type')->TypeAdd(
#rbo - T2016121190001552 - renamed X-KIX headers
    Name    => "X-KIX-Type-Test",
    ValidID => 1,
    UserID  => 1,
);

# filter test
my @Tests = (
    {
        Name  => 'Valid ticket type (Unclassified)',
        Email => 'From: Sender <sender@example.com>
To: Some Name <recipient@example.com>
X-KIX-Type: Unclassified
Subject: Test

Some Content in Body',
        NewTicket => 1,
        Check     => {
            Type => 'Unclassified',
            }
    },
    {
        Name  => 'Valid ticket type (Unclassified)',
        Email => 'From: Sender <sender@example.com>
To: Some Name <recipient@example.com>
X-KIX-Type: X-KIX-Type-Test
Subject: Test

Some Content in Body',
        NewTicket => 1,
        Check     => {
            Type => 'X-KIX-Type-Test',
            }
    },
    {
        Name  => 'Invalid ticket type, ticket still needs to be created',
        Email => 'From: Sender <sender@example.com>
To: Some Name <recipient@example.com>
X-KIX-Type: Nonexisting
Subject: Test

Some Content in Body',
        NewTicket => 1,
        Check     => {
            Type => 'Unclassified',
            }
    },
);

for my $Test (@Tests) {

    my @Return;
    {
        my $PostMasterObject = Kernel::System::PostMaster->new(
            Email => \$Test->{Email},
            Debug => 2,
        );

        @Return = $PostMasterObject->Run();
        @Return = @{ $Return[0] || [] };
    }

    $Self->Is(
        $Return[0] || 0,
        $Test->{NewTicket},
        "#Filter Run() - NewTicket",
    );
    $Self->True(
        $Return[1] || 0,
        "#Filter  Run() - NewTicket/TicketID",
    );
    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Return[1],
        DynamicFields => 1,
    );

    for my $Key ( sort keys %{ $Test->{Check} } ) {
        $Self->Is(
            $Ticket{$Key},
            $Test->{Check}->{$Key},
            "#Filter Run() - $Key",
        );
    }
}

# cleanup is done by RestoreDatabase.

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
