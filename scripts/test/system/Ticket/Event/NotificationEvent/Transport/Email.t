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

# get config object
my $ConfigObject = $Kernel::OM->Get('Config');

# get helper object
$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        RestoreDatabase => 1,

    },
);
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# disable rich text editor
my $Success = $ConfigObject->Set(
    Key   => 'Frontend::RichText',
    Value => 0,
);

$Self->True(
    $Success,
    "Disable RichText with true",
);

# use Test email backend
$Success = $ConfigObject->Set(
    Key   => 'SendmailModule',
    Value => 'Email::Test',
);

$Self->True(
    $Success,
    "Set Email Test backend with true",
);

# set not self notify
$Success = $ConfigObject->Set(
    Key   => 'AgentSelfNotifyOnAction',
    Value => 0,
);

$Self->True(
    $Success,
    "Disable Agent Self Notify On Action",
);

my $TestEmailObject = $Kernel::OM->Get('Email::Test');

$Success = $TestEmailObject->CleanUp();
$Self->True(
    $Success,
    'Initial cleanup',
);

$Self->IsDeeply(
    $TestEmailObject->EmailsGet(),
    [],
    'Test backend empty after initial cleanup',
);

# get a random id
my $RandomID = $Helper->GetRandomID();

my $RoleID = $Kernel::OM->Get('UnitTest::Helper')->TestRoleCreate(
    Name        => "ticket_read_$RandomID",
    Permissions => {
        Resource => [
            {
                Target => '/tickets',
                Value  => Kernel::System::Role::Permission->PERMISSION->{READ},
            }
        ]
    }
);

# create a new user for current test
my $UserLogin = $Kernel::OM->Get('UnitTest::Helper')->TestUserCreate(
    Roles => ["ticket_read_$RandomID"],
);

my %UserData = $Kernel::OM->Get('User')->GetUserData(
    User => $UserLogin,
);

my $UserID = $UserData{UserID};

my %UserContactData = $Kernel::OM->Get('Contact')->ContactGet(
    UserID => $UserID,
);

# get ticket object
my $TicketObject = $Kernel::OM->Get('Ticket');

# create ticket
my $TicketID = $TicketObject->TicketCreate(
    Title        => 'Ticket One Title',
    QueueID      => 1,
    Lock         => 'unlock',
    Priority     => '3 normal',
    State        => 'new',
    OrganisationID => 'example.com',
    ContactID    => $UserData{UserLogin},
    OwnerID      => $UserID,
    UserID       => $UserID,
);

# sanity check
$Self->True(
    $TicketID,
    "TicketCreate() successful for Ticket ID $TicketID",
);

my $ArticleID = $TicketObject->ArticleCreate(
    TicketID       => $TicketID,
    Channel        => 'note',
    CustomerVisible => 1,
    SenderType     => 'external',
    From           => 'customerOne@example.com, customerTwo@example.com',
    To             => 'Some Agent A <agent-a@example.com>',
    Subject        => 'some short description',
    Body           => 'the message text',
    Charset        => 'utf8',
    MimeType       => 'text/plain',
    HistoryType    => 'OwnerUpdate',
    HistoryComment => 'Some free text!',
    UserID         => 1,
);

# sanity check
$Self->True(
    $ArticleID,
    "ArticleCreate() successful for Article ID $ArticleID",
);

# get dynamic field object
my $DynamicFieldObject = $Kernel::OM->Get('DynamicField');

# create a dynamic field
my $FieldID = $DynamicFieldObject->DynamicFieldAdd(
    Name       => "DFT1$RandomID",
    Label      => 'Description',
    FieldOrder => 9991,
    FieldType  => 'Text',
    ObjectType => 'Ticket',
    Config     => {
        DefaultValue => 'Default',
    },
    ValidID => 1,
    UserID  => 1,
    Reorder => 0,
);

my @Tests = (
    {
        Name => 'Single RecipientAgent',
        Data => {
            Events          => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            RecipientAgents => [$UserID],
        },
        ExpectedResults => [
            {
                ToArray => [ $UserContactData{Email} ],
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserContactData{Firstname}=\n",
            },
        ],
    },
    {
        Name => 'RecipientAgent + RecipientEmail',
        Data => {
            Events          => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            RecipientAgents => [$UserID],
            RecipientEmail  => ['test@kixexample.com'],
        },
        ExpectedResults => [
            {
                ToArray => [ $UserContactData{Email} ],
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserContactData{Firstname}=\n",
            },
            {
                ToArray => ['test@kixexample.com'],
                Body    => "JobName $TicketID Kernel::System::Email::Test $UserContactData{Firstname}=\n",
            },
        ],
    },
    {
        Name => 'Recipient Customer - JustToRealCustomer enabled',
        Data => {
            Events     => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            Recipients => ['Customer'],
        },
        ExpectedResults    => [],
        JustToRealCustomer => 1,
    },
    {
        Name => 'Recipient Customer - JustToRealCustomer disabled',
        Data => {
            Events     => [ 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update' ],
            Recipients => ['Customer'],
        },
        ExpectedResults => [
            {
                ToArray => [ 'customerOne@example.com', 'customerTwo@example.com' ],
                Body => "JobName $TicketID Kernel::System::Email::Test $UserContactData{Firstname}=\n",
            },
        ],
        JustToRealCustomer => 0,
    },
);

my $NotificationEventObject      = $Kernel::OM->Get('NotificationEvent');
my $EventNotificationEventObject = $Kernel::OM->Get('Ticket::Event::NotificationEvent');

my $Count = 0;
for my $Test (@Tests) {

    # add transport setting
    $Test->{Data}->{Transports} = ['Email'];

    # set just to real customer
    my $JustToRealCustomer = $Test->{JustToRealCustomer} || 0;
    $Success = $ConfigObject->Set(
        Key   => 'CustomerNotifyJustToRealCustomer',
        Value => $JustToRealCustomer,
    );

    $Self->True(
        $Success,
        "Set notifications just to real customer: $JustToRealCustomer.",
    );

    my $NotificationID = $NotificationEventObject->NotificationAdd(
        Name    => "JobName$Count-$RandomID",
        Data    => $Test->{Data},
        Message => {
            en => {
                Subject     => 'JobName',
                Body        => 'JobName <KIX_TICKET_TicketID> <KIX_CONFIG_SendmailModule> <KIX_OWNER_Firstname>',
                ContentType => 'text/plain',
            },
        },
        Comment => 'An optional comment',
        ValidID => 1,
        UserID  => 1,
    );

    # sanity check
    $Self->IsNot(
        $NotificationID,
        undef,
        "$Test->{Name} - NotificationAdd() should not be undef",
    );

    my $Result = $EventNotificationEventObject->Run(
        Event => 'TicketDynamicFieldUpdate_DFT1' . $RandomID . 'Update',
        Data  => {
            TicketID => $TicketID,
        },
        Config => {},
        UserID => 1,
    );

    my $Emails = $TestEmailObject->EmailsGet();

    # remove not needed data
    for my $Email ( @{$Emails} ) {
        for my $Attribute (qw(From Header)) {
            delete $Email->{$Attribute};
        }

        # de-reference body
        $Email->{Body} = ${ $Email->{Body} };
    }

    $Self->IsDeeply(
        $Emails,
        $Test->{ExpectedResults},
        "$Test->{Name} - Recipients",
    );

    # delete notification event
    my $NotificationDelete = $NotificationEventObject->NotificationDelete(
        ID     => $NotificationID,
        UserID => 1,
    );

    # sanity check
    $Self->True(
        $NotificationDelete,
        "$Test->{Name} - NotificationDelete() successful for Notification ID $NotificationID",
    );

    $TestEmailObject->CleanUp();

    $Count++;
}

# cleanup

# delete the dynamic field
my $DFDelete = $DynamicFieldObject->DynamicFieldDelete(
    ID      => $FieldID,
    UserID  => 1,
    Reorder => 0,
);

# sanity check
$Self->True(
    $DFDelete,
    "DynamicFieldDelete() successful for Field ID $FieldID",
);

# delete the ticket
my $TicketDelete = $TicketObject->TicketDelete(
    TicketID => $TicketID,
    UserID   => $UserID,
);

# sanity check
$Self->True(
    $TicketDelete,
    "TicketDelete() successful for Ticket ID $TicketID",
);

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
