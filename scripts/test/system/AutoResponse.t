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

# get needed objects
my $ConfigObject        = $Kernel::OM->Get('Config');
my $AutoResponseObject  = $Kernel::OM->Get('AutoResponse');
my $SystemAddressObject = $Kernel::OM->Get('SystemAddress');
my $QueueObject         = $Kernel::OM->Get('Queue');

# get helper object
$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $HelperObject = $Kernel::OM->Get('UnitTest::Helper');

# get random id
my $RandomID = $HelperObject->GetRandomID();

# set queue name
my $QueueName = 'Some::Queue' . $RandomID;

# create new queue
my $QueueID = $QueueObject->QueueAdd(
    Name            => $QueueName,
    ValidID         => 1,
    SystemAddressID => 1,
    Signature       => '',
    Comment         => 'Some comment',
    UserID          => 1,
);

$Self->True(
    $QueueID,
    "QueueAdd() - $QueueName, $QueueID",
);

# add system address
$ConfigObject->Set(
    Key   => 'SendmailModule',
    Value => 'Email::Test',
);
$ConfigObject->Set(
    Key   => 'CheckEmailAddresses',
    Value => '0',
);

my $ContactID = $Kernel::OM->Get('Contact')->ContactAdd(
    Firstname  => 'John',
    Lastname   => 'Doe',
    PrimaryOrganisationID  => 1,
    OrganisationIDs => [
        1,
    ],
    Login      => "CustomerLogin#$RandomID",
    Email      => "customer$RandomID\@example.com",
    Password   => 'some_pass',
    ValidID    => 1,
    UserID     => 1,
);
$Self->True(
    $ContactID,
    # rkaiser - T#2017020290001194 - changed customer user to contact
    "Customer contact created."
);

# add system address
my $SystemAddressNameRand = 'SystemAddress' . $HelperObject->GetRandomID();
my $SystemAddressID       = $SystemAddressObject->SystemAddressAdd(
    Name     => $SystemAddressNameRand . '@example.com',
    Realname => $SystemAddressNameRand,
    ValidID  => 1,
    Comment  => 'Some Comment',
    UserID   => 1,
);
$Self->True(
    $SystemAddressID,
    'SystemAddressAdd()',
);

# add auto response
my $AutoResponseNameRand = 'AutoResponse' . $HelperObject->GetRandomID();

my $AutoResponseID = $AutoResponseObject->AutoResponseAdd(
    Name        => $AutoResponseNameRand,
    Subject     => 'Some Subject',
    Response    => 'Some Response',
    Comment     => 'Some Comment',
    AddressID   => $SystemAddressID,
    TypeID      => 1,
    ContentType => 'text/plain',
    ValidID     => 1,
    UserID      => 1,
);

$Self->True(
    $AutoResponseID,
    'AutoResponseAdd()',
);

my %AutoResponse = $AutoResponseObject->AutoResponseGet( ID => $AutoResponseID );

$Self->Is(
    $AutoResponse{Name} || '',
    $AutoResponseNameRand,
    'AutoResponseGet() - Name',
);
$Self->Is(
    $AutoResponse{Subject} || '',
    'Some Subject',
    'AutoResponseGet() - Subject',
);
$Self->Is(
    $AutoResponse{Response} || '',
    'Some Response',
    'AutoResponseGet() - Response',
);
$Self->Is(
    $AutoResponse{Comment} || '',
    'Some Comment',
    'AutoResponseGet() - Comment',
);
$Self->Is(
    $AutoResponse{ContentType} || '',
    'text/plain',
    'AutoResponseGet() - ContentType',
);
$Self->Is(
    $AutoResponse{AddressID} || '',
    $SystemAddressID,
    'AutoResponseGet() - AddressID',
);
$Self->Is(
    $AutoResponse{ValidID} || '',
    1,
    'AutoResponseGet() - ValidID',
);

my %AutoResponseList = $AutoResponseObject->AutoResponseList( Valid => 0 );
my $Hit = 0;
for ( sort keys %AutoResponseList ) {
    if ( $_ eq $AutoResponseID ) {
        $Hit = 1;
    }
}
$Self->True(
    $Hit eq 1,
    'AutoResponseList()',
);

# get a list of the queues that do not have auto response
my %AutoResponseWithoutQueue = $AutoResponseObject->AutoResponseWithoutQueue();

$Self->True(
    exists $AutoResponseWithoutQueue{$QueueID} && $AutoResponseWithoutQueue{$QueueID} eq $QueueName,
    'AutoResponseWithoutQueue() contains queue ' . $QueueName . ' with ID ' . $QueueID,
);

my $AutoResponseQueue = $AutoResponseObject->AutoResponseQueue(
    QueueID         => $QueueID,
    AutoResponseIDs => [$AutoResponseID],
    UserID          => 1,
);
$Self->True(
    $AutoResponseQueue,
    'AutoResponseQueue()',
);

# check again after assigning auto response to queue
%AutoResponseWithoutQueue = $AutoResponseObject->AutoResponseWithoutQueue();
$Self->False(
    exists $AutoResponseWithoutQueue{$QueueID} && $AutoResponseWithoutQueue{$QueueID} eq $QueueName,
    'AutoResponseWithoutQueue() does not contain queue ' . $QueueName . ' with ID ' . $QueueID,
);

my %Address = $AutoResponseObject->AutoResponseGetByTypeQueueID(
    QueueID => $QueueID,
    Type    => 'auto reply',
);
$Self->Is(
    $Address{Address} || '',
    $SystemAddressNameRand . '@example.com',
    'AutoResponseGetByTypeQueueID() - Address',
);
$Self->Is(
    $Address{Realname} || '',
    $SystemAddressNameRand,
    'AutoResponseGetByTypeQueueID() - Realname',
);

# get ticket object
my $TicketObject = $Kernel::OM->Get('Ticket');

# create a new ticket
my $TicketID = $TicketObject->TicketCreate(
    Title        => 'Some Ticket Title',
    QueueID      => $QueueID,
    Lock         => 'unlock',
    Priority     => '3 normal',
    State        => 'new',
    CustomerID   => "Customer#$RandomID",
    Contact => "CustomerLogin#$RandomID",
    OwnerID      => 1,
    UserID       => 1,
);
$Self->IsNot(
    $TicketID,
    undef,
    'TicketCreate() - TicketID should not be undef',
);

my $ArticleID1 = $TicketObject->ArticleCreate(
    TicketID       => $TicketID,
    Channel        => 'email',
    SenderType     => 'agent',
    From           => 'Some Agent <otrs@example.com>',
    To             => 'Suplier<suplier@example.com>',
    Subject        => 'Email for suplier',
    Body           => 'the message text',
    Charset        => 'utf8',
    MimeType       => 'text/plain',
    HistoryType    => 'OwnerUpdate',
    HistoryComment => 'Some free text!',
    UserID         => 1,
);
$Self->True(
    $ArticleID1,
    "First article created."
);

my $TestEmailObject = $Kernel::OM->Get('Email::Test');
my $CleanUpSuccess  = $TestEmailObject->CleanUp();
$Self->True(
    $CleanUpSuccess,
    'Cleanup Email backend',
);

my $ArticleID2 = $TicketObject->ArticleCreate(
    TicketID         => $TicketID,
    Channel          => 'email',
    SenderType       => 'external',
    From             => 'Suplier<suplier@example.com>',
    To               => 'Some Agent <otrs@example.com>',
    Subject          => 'some short description',
    Body             => 'the message text',
    Charset          => 'utf8',
    MimeType         => 'text/plain',
    HistoryType      => 'OwnerUpdate',
    HistoryComment   => 'Some free text!',
    UserID           => 1,
    AutoResponseType => 'auto reply',
    OrigHeader       => {
        From    => 'Some Agent <otrs@example.com>',
        Subject => 'some short description',
    },
);

$Self->True(
    $ArticleID2,
    "Second article created."
);

# check that email was sent
my $Emails = $TestEmailObject->EmailsGet();

# Make sure that auto-response is not sent to the customer (in CC) - See bug#12293
$Self->IsDeeply(
    $Emails->[0]->{ToArray},
    [
        'otrs@example.com'
    ],
    'Check AutoResponse recipients.'
);

$AutoResponseQueue = $AutoResponseObject->AutoResponseQueue(
    QueueID         => $QueueID,
    AutoResponseIDs => [],
    UserID          => 1,
);

my $AutoResponseUpdate = $AutoResponseObject->AutoResponseUpdate(
    ID          => $AutoResponseID,
    Name        => $AutoResponseNameRand . '1',
    Subject     => 'Some Subject1',
    Response    => 'Some Response1',
    Comment     => 'Some Comment1',
    AddressID   => $SystemAddressID,
    TypeID      => 1,
    ContentType => 'text/html',
    ValidID     => 2,
    UserID      => 1,
);

$Self->True(
    $AutoResponseUpdate,
    'AutoResponseUpdate()',
);

%AutoResponse = $AutoResponseObject->AutoResponseGet( ID => $AutoResponseID );

$Self->Is(
    $AutoResponse{Name} || '',
    $AutoResponseNameRand . '1',
    'AutoResponseGet() - Name',
);
$Self->Is(
    $AutoResponse{Subject} || '',
    'Some Subject1',
    'AutoResponseGet() - Subject',
);
$Self->Is(
    $AutoResponse{Response} || '',
    'Some Response1',
    'AutoResponseGet() - Response',
);
$Self->Is(
    $AutoResponse{Comment} || '',
    'Some Comment1',
    'AutoResponseGet() - Comment',
);
$Self->Is(
    $AutoResponse{ContentType} || '',
    'text/html',
    'AutoResponseGet() - ContentType',
);
$Self->Is(
    $AutoResponse{AddressID} || '',
    $SystemAddressID,
    'AutoResponseGet() - AddressID',
);
$Self->Is(
    $AutoResponse{ValidID} || '',
    2,
    'AutoResponseGet() - ValidID',
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
