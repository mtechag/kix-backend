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

# Get helper object.
$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $HelperObject = $Kernel::OM->Get('UnitTest::Helper');

# Get ticket object.
my $TicketObject = $Kernel::OM->Get('Ticket');

# Create ticket.
my $TicketID = $TicketObject->TicketCreate(
    Title        => 'Ticket One Title',
    QueueID      => 1,
    Lock         => 'unlock',
    Priority     => '3 normal',
    State        => 'new',
    CustomerID   => '123465',
    Contact => 'customerOne@example.com',
    OwnerID      => 1,
    UserID       => 1,
);

# Sanity check.
$Self->IsNot(
    $TicketID,
    undef,
    "TicketCreate() successful for Ticket ID $TicketID",
);

my $RandomID = $HelperObject->GetRandomID();

# Get Queue object.
my $QueueObject = $Kernel::OM->Get('Queue');

# Create queues.
my $QueueID1 = $QueueObject->QueueAdd(
    Name            => "Queue1$RandomID",
    ValidID         => 1,
    GroupID         => 1,
    SystemAddressID => 1,
    Comment         => 'Some comment',
    UserID          => 1,
);

# Sanity check.
$Self->IsNot(
    $QueueID1,
    undef,
    "QueueAdd() successful for Queue ID $QueueID1",
);

my $QueueID2 = $QueueObject->QueueAdd(
    Name            => "Queue2$RandomID",
    ValidID         => 1,
    GroupID         => 1,
    SystemAddressID => 1,
    Comment         => 'Some comment',
    UserID          => 1,
);

# Sanity check.
$Self->IsNot(
    $QueueID2,
    undef,
    "QueueAdd() successful for Queue ID $QueueID2",
);

# Create new users.
my $TestUserLogin = $HelperObject->TestUserCreate(
    Groups => [ 'admin', 'users' ],
);
my $TestUserID = $Kernel::OM->Get('User')->UserLookup(
    UserLogin => $TestUserLogin,
);

my $TestContactLogin = $HelperObject->TestContactCreate();

# Cleanup and set ACLs.
my $ConfigObject = $Kernel::OM->Get('Config');

$ConfigObject->Set(
    Key   => 'TicketAcl',
    Value => {
        UnitTestUser => {
            Possible => {
                Ticket => {
                    Queue => [ "Queue1$RandomID", ],
                },
            },
            Properties => {
                User => {
                    UserLogin => [ $TestUserLogin, ],
                },
            },
            StopAfterMatch => 1,
        },
        UnitTestContact => {
            Possible => {
                Ticket => {
                    Queue => [ "Queue2$RandomID", ],
                },
            },
            Properties => {
                Contact => {
                    UserLogin => [ $TestContactLogin, ],
                },
            },
            StopAfterMatch => 1,
        },
    },
);

my @Tests = (
    {
        Name    => 'No Params',
        Config  => {},
        Success => 0,
    },
    {
        Name   => 'Missing UserID and ContactID',
        Config => {
            Type => 'create',
        },
        Success => 0,
    },
    {
        Name   => 'Missing Type, QueueID and TicketID',
        Config => {
            UserID => 1,
        },
        Success => 0,
    },
    {
        Name   => 'Correct With Type and UserID',
        Config => {
            Type   => 'create',
            UserID => 1,
        },
        Success         => 1,
        ExpectedResults => [ '1', $QueueID1, $QueueID2, ],
    },
    {
        Name   => 'Correct With QueueID and UserID',
        Config => {
            QueueID => 1,
            UserID  => 1,
        },
        Success         => 1,
        ExpectedResults => [ '1', $QueueID1, $QueueID2, ],
    },
    {
        Name   => 'Correct With TicketID and UserID',
        Config => {
            TicketID => 1,
            UserID   => 1,
        },
        Success         => 1,
        ExpectedResults => [ '1', $QueueID1, $QueueID2, ],
    },
    {
        Name   => 'Correct With TicketID UserID and ACLs',
        Config => {
            TicketID => 1,
            UserID   => $TestUserID,
        },
        Success            => 1,
        ExpectedResults    => [ $QueueID1, ],
        NotExpectedResults => [ '1', $QueueID2, ],

    },
    {
        Name   => 'Correct With Type and ContactID',
        Config => {
            Type           => 'create',
            ContactID => $RandomID,
        },
        Success         => 1,
        ExpectedResults => [ '1', $QueueID1, $QueueID2, ],
    },
    {
        Name   => 'Correct With QueueID and ContactID',
        Config => {
            QueueID        => 1,
            ContactID => $RandomID,
        },
        Success         => 1,
        ExpectedResults => [ '1', $QueueID1, $QueueID2, ],
    },
    {
        Name   => 'Correct With TicketID and ContactID',
        Config => {
            TicketID       => 1,
            ContactID => $RandomID,
        },
        Success         => 1,
        ExpectedResults => [ '1', $QueueID1, $QueueID2, ],
    },
    {
        Name   => 'Correct With TicketID UserID and ACLs',
        Config => {
            TicketID       => 1,
            ContactID => $TestContactLogin,
        },
        Success            => 1,
        ExpectedResults    => [ $QueueID2, ],
        NotExpectedResults => [ '1', $QueueID1, ],
    },
);

TEST:
for my $Test (@Tests) {

    my %Queues = $TicketObject->TicketMoveList( %{ $Test->{Config} } );

    if ( !$Test->{Success} ) {
        $Self->IsDeeply(
            \%Queues,
            {},
            "$Test->{Name} TicketMoveList() - Failure",
        );

        next TEST;
    }

    for my $QueueID ( @{ $Test->{ExpectedResults} } ) {
        my $Result = $Queues{$QueueID} //= '';
        $Self->IsNot(
            $Result,
            '',
            "$Test->{Name} TicketMoveList() - Found queue for QueueID $QueueID",
        );
    }

    next TEST if !defined $Test->{NotExpectedResults};

    for my $QueueID ( @{ $Test->{NotExpectedResults} } ) {
        my $Result = $Queues{$QueueID} //= '';
        $Self->Is(
            $Result,
            '',
            "$Test->{Name} TicketMoveList() - Not found queue for QueueID $QueueID",
        );
    }
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
