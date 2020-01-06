# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

use Kernel::API::Debugger;
use Kernel::API::Validator::TicketValidator;

my $DebuggerObject = Kernel::API::Debugger->new(
    DebuggerConfig   => {
        DebugThreshold  => 'debug',
        TestMode        => 1,
    },
    WebserviceID      => 1,
    CommunicationType => 'Provider',
    RemoteIP          => 'localhost',
);

# get validator object
my $ValidatorObject = Kernel::API::Validator::TicketValidator->new(
    DebuggerObject => $DebuggerObject
);

# get helper object
$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

my $TicketID = $Kernel::OM->Get('Kernel::System::Ticket')->TicketCreate(
    Title           => 'Testticket Unittest',
    TypeID          => 1,
    Contact    => 'customer@test.org',
    StateID         => 1,
    PriorityID      => 1,
    QueueID         => 1,
    OwnerID         => 1,
    UserID          => 1,
    LockID          => 1,
);

$Self->True(
    $TicketID,
    'create test ticket',
);

my $ValidData = {
    TicketID => $TicketID,
};

my %InvalidData = (
    '#01 invalid data type' => {
        TicketID => 'unknown'
    },
    '#02 invalid TicketD' => {
        TicketID => -9999,
    }    
);

# validate valid Type
my $Result = $ValidatorObject->Validate(
    Attribute => 'TicketID',
    Data      => $ValidData,
);

$Self->True(
    $Result->{Success},
    'Validate() - valid TicketID',
);

# validate invalid TicketID
foreach my $TestID ( sort keys %InvalidData ) {
    # run test for each supported attribute
    $Result = $ValidatorObject->Validate(
        Attribute => 'TicketID',
        Data      => $InvalidData{$TestID},
    );

    $Self->False(
        $Result->{Success},
        "Validate() - $TestID",
    );
}

# validate invalid attribute
$Result = $ValidatorObject->Validate(
    Attribute => 'InvalidAttribute',
    Data      => {},
);

$Self->False(
    $Result->{Success},
    'Validate() - invalid attribute',
);

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