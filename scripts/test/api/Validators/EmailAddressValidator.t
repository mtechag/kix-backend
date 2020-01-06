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
use Kernel::API::Validator::EmailAddressValidator;

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
my $ValidatorObject = Kernel::API::Validator::EmailAddressValidator->new(
    DebuggerObject => $DebuggerObject
);

# get helper object
$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

my %ValidData = (
    '#01 simple' => 'test@test.org',
    '#02 complex' => 'test <test@test.org>',
    '#03 complex - with quotation marks' => '"test test" <test@test.org>',
    '#04 multiple simple - no spaces' => 'test@test.org,test2@test.org,test3@test.org',
    '#05 multiple simple - with spaces' => 'test@test.org, test2@test.org, test3@test.org',
    '#06 multiple simple - no spaces' => 'test@test.org,test2@test.org,test3@test.org',
    '#07 multiple complex - no spaces' => 'test <test@test.org>,test2 <test2@test.org>,test3 <test3@test.org>',
    '#08 multiple complex - with spaces' => 'test <test@test.org>, test2 <test2@test.org>, test3 <test3@test.org>',
    '#09 multiple complex - with quotation marks and no spaces' => '"test" <test@test.org>,"test2" <test2@test.org>,"test3" <test3@test.org>',
    '#10 multiple complex - with quotation marks and with spaces' => '"test" <test@test.org>, "test2" <test2@test.org>, "test3" <test3@test.org>',
);

my $InvalidData = 'invalid-EmailAddress';

# validate valid EmailAddress
foreach my $TestID ( sort keys %ValidData ) {
    # run test for each supported attribute
    foreach my $Attribute ( qw(From To Cc Bcc) ) {
        my $Result = $ValidatorObject->Validate(
            Attribute => $Attribute,
            Data      => {
                $Attribute => $ValidData{$TestID},
            }
        );

        $Self->True(
            $Result->{Success},
            "Validate() - valid EmailAddress - $Attribute - $TestID",
        );
    }
}

# validate invalid EmailAddress
# run test for each supported attribute
foreach my $Attribute ( qw(From To Cc Bcc) ) {
    my $Result = $ValidatorObject->Validate(
        Attribute => $Attribute,
        Data      => {
            $Attribute => $InvalidData,
        }
    );

    $Self->False(
        $Result->{Success},
        "Validate() - invalid EmailAddress - $Attribute",
    );
}

# validate invalid attribute
my $Result = $ValidatorObject->Validate(
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