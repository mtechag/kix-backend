# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

use Kernel::GenericInterface::Debugger;
use Kernel::GenericInterface::Operation::Ticket::TicketCreate;
use Kernel::GenericInterface::Operation::Session::SessionCreate;

# get helper object
# skip SSL certificate verification
$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        SkipSSLVerify   => 1,
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

my $RandomID = $Helper->GetRandomID();

# create webservice object
my $WebserviceObject = $Kernel::OM->Get('Kernel::System::GenericInterface::Webservice');

$Self->Is(
    'Kernel::System::GenericInterface::Webservice',
    ref $WebserviceObject,
    "Create webservice object",
);

# set webservice name
my $WebserviceName = '-Test-' . $RandomID;

my $WebserviceID = $WebserviceObject->WebserviceAdd(
    Name   => $WebserviceName,
    Config => {
        Debugger => {
            DebugThreshold => 'debug',
        },
        Provider => {
            Transport => {
                Type => '',
            },
        },
    },
    ValidID => 1,
    UserID  => 1,
);
$Self->True(
    $WebserviceID,
    "Added Webservice",
);

# debugger object
my $DebuggerObject = Kernel::GenericInterface::Debugger->new(
    DebuggerConfig => {
        DebugThreshold => 'debug',
        TestMode       => 1,
    },
    WebserviceID      => $WebserviceID,
    CommunicationType => 'Provider',
);
$Self->Is(
    ref $DebuggerObject,
    'Kernel::GenericInterface::Debugger',
    'DebuggerObject instantiate correctly',
);

# Operation::Common is not an Object but a base class, instantiate any operation that uses it.
my $TicketOperationObject = Kernel::GenericInterface::Operation::Ticket::TicketCreate->new(
    DebuggerObject => $DebuggerObject,
    WebserviceID   => $WebserviceID,
);
$Self->Is(
    ref $TicketOperationObject,
    'Kernel::GenericInterface::Operation::Ticket::TicketCreate',
    'OperationObject instantiate correctly',
);

# Session::Common is not an Object but a base class, instantiate any operation that uses it.
my $SessionOperationObject = Kernel::GenericInterface::Operation::Session::SessionCreate->new(
    DebuggerObject => $DebuggerObject,
    WebserviceID   => $WebserviceID,
);
$Self->Is(
    ref $SessionOperationObject,
    'Kernel::GenericInterface::Operation::Session::SessionCreate',
    'SessionCommonObject instantiate correctly',
);

# set user details
my $UserLogin    = $Helper->TestUserCreate();
my $UserPassword = $UserLogin;
my $UserID       = $Kernel::OM->Get('Kernel::System::User')->UserLookup(
    UserLogin => $UserLogin,
);
my $UserSessionID = $SessionOperationObject->CreateSessionID(
    Data => {
        UserLogin => $UserLogin,
        Password  => $UserPassword,
    },
);

# set customer user details
my $ContactLogin     = $Helper->TestContactCreate();
my $ContactPassword  = $ContactLogin;
my $ContactID        = $ContactLogin;
my $ContactSessionID = $SessionOperationObject->CreateSessionID(
    Data => {
        ContactLogin => $ContactLogin,
        Password          => $ContactPassword,
    },
);

# sanity checks
$Self->IsNot(
    $UserSessionID,
    undef,
    "CreateSessionID() for User"
);
$Self->IsNot(
    $ContactSessionID,
    undef,
    "CreateSessionID() for Contact"
);

# Tests for Auth()
my @Tests = (
    {
        Name    => 'Empty',
        Data    => {},
        Success => 0,
    },
    {
        Name    => 'No SessionID',
        Data    => {},
        Success => 0,
    },
    {
        Name => 'Invalid SessionID',
        Data => {
            SessionID => $RandomID,
        },
        Success => 0,
    },
    {
        Name => 'UserLogin No Password',
        Data => {
            UserLogin => $UserLogin,
        },
        Success => 0,
    },
    {
        Name => 'ContactLogin No Password',
        Data => {
            ContactLogin => $ContactLogin,
        },
        Success => 0,
    },
    {
        Name => 'Password No UserLogin',
        Data => {
            Password => $UserPassword,
        },
        Success => 0,
    },
    {
        Name => 'UserLogin Invalid Password',
        Data => {
            UserLogin => $UserLogin,
            Password  => $RandomID,
        },
        Success => 0,
    },
    {
        Name => 'ContactLogin Invalid Password',
        Data => {
            ContactLogin => $ContactLogin,
            Password          => $RandomID,
        },
        Success => 0,
    },
    {
        Name => 'Invalid UserLogin Correct Password',
        Data => {
            UserLogin => $RandomID,
            Password  => $UserPassword,
        },
        Success => 0,
    },
    {
        Name => 'Invalid ContactLogin Correct Password',
        Data => {
            ContactLogin => $RandomID,
            Password          => $ContactPassword,
        },
        Success => 0,
    },
    {
        Name => 'Correct User SessionID',
        Data => {
            SessionID => $UserSessionID,
        },
        ExpectedResult => {
            User     => $UserID,
            UserType => 'User',
        },
        Success => 1,
    },
    {
        Name => 'Correct CustomerSessionID',
        Data => {
            SessionID => $ContactSessionID,
        },
        ExpectedResult => {
            User     => $ContactID,
            UserType => 'Customer',
        },
        Success => 1,
    },
    {
        Name => 'Correct UserLogin and Password',
        Data => {
            UserLogin => $UserLogin,
            Password  => $UserPassword,
        },
        ExpectedResult => {
            User     => $UserID,
            UserType => 'User',
        },
        Success => 1,
    },
    {
        Name => 'Correct ContactLogin and Password',
        Data => {
            ContactLogin => $ContactLogin,
            Password          => $ContactPassword,
        },
        ExpectedResult => {
            User     => $ContactID,
            UserType => 'Customer',
        },
        Success => 1,
    },
);

for my $Test (@Tests) {
    my ( $User, $UserType ) = $TicketOperationObject->Auth(
        Data => $Test->{Data},
    );

    if ( $Test->{Success} ) {
        $Self->Is(
            $User,
            $Test->{ExpectedResult}->{User},
            "Auth() - $Test->{Name}: User",
        );
        $Self->Is(
            $UserType,
            $Test->{ExpectedResult}->{UserType},
            "Auth() - $Test->{Name}: UserType",
        );
    }

    else {
        $Self->Is(
            $User,
            0,
            "Auth() - $Test->{Name}: User",
        );
        $Self->Is(
            $UserType,
            undef,
            "Auth() - $Test->{Name}: UserType",
        );
    }
}

# cleanup is done by RestoreDatabase.

1;


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
