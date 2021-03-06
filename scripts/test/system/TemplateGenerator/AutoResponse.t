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

# force rich text editor
my $Success = $ConfigObject->Set(
    Key   => 'Frontend::RichText',
    Value => 1,
);
$Self->True(
    $Success,
    'Force RichText with true',
);

# use DoNotSendEmail email backend
$Success = $ConfigObject->Set(
    Key   => 'SendmailModule',
    Value => 'Email::DoNotSendEmail',
);
$Self->True(
    $Success,
    'Set DoNotSendEmail backend with true',
);

# set Default Language
$Success = $ConfigObject->Set(
    Key   => 'DefaultLanguage',
    Value => 'en',
);
$Self->True(
    $Success,
    'Set default language to English',
);

my $RandomID = $Helper->GetRandomID();

# create customer users
my $TestUserLoginEN = $Helper->TestContactCreate(
    Language => 'en',
);
my $TestUserLoginDE = $Helper->TestContactCreate(
    Language => 'de',
);

# get queue object
my $QueueObject = $Kernel::OM->Get('Queue');

# create new queue
my $QueueName     = 'Some::Queue' . $RandomID;
my %QueueTemplate = (
    Name            => $QueueName,
    ValidID         => 1,
    GroupID         => 1,
    SystemAddressID => 1,
    Comment         => 'Some comment',
    UserID          => 1,
);
my $QueueID = $QueueObject->QueueAdd(%QueueTemplate);
$Self->IsNot(
    $QueueID,
    undef,
    'QueueAdd() - QueueID should not be undef',
);

# get auto response object
my $AutoResponseObject = $Kernel::OM->Get('AutoResponse');

# create new auto response
my $AutoResonseName      = 'Some::AutoResponse' . $RandomID;
my %AutoResponseTemplate = (
    Name        => $AutoResonseName,
    ValidID     => 1,
    Subject     => 'Some Subject..',
    Response    => 'S:&nbsp;&lt;KIX_TICKET_State&gt;',    # include non-breaking space (bug#12097)
    ContentType => 'text/html',
    AddressID   => 1,
    TypeID      => 4,                                      # auto reply/new ticket
    UserID      => 1,
);
my $AutoResponseID = $AutoResponseObject->AutoResponseAdd(%AutoResponseTemplate);
$Self->IsNot(
    $AutoResponseID,
    undef,
    'AutoResponseAdd() - AutoResonseID should not be undef',
);

# assign auto response to queue
$Success = $AutoResponseObject->AutoResponseQueue(
    QueueID         => $QueueID,
    AutoResponseIDs => [$AutoResponseID],
    UserID          => 1,
);
$Self->True(
    $Success,
    "AutoResponseQueue() - assigned auto response - $AutoResonseName to queue - $QueueName",
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
    CustomerID   => '123465',
    Contact => 'customer@example.com',
    OwnerID      => 1,
    UserID       => 1,
);
$Self->IsNot(
    $TicketID,
    undef,
    'TicketCreate() - TicketID should not be undef',
);

my $HTMLTemplate
    = '<!DOCTYPE html><html><head><meta http-equiv="Content-Type" content="text/html; charset=utf-8"/></head><body style="font-family:Geneva,Helvetica,Arial,sans-serif; font-size: 12px;">%s</body></html>';
my @Tests = (
    {
        Name           => 'English Language Customer',
        Contact   => $TestUserLoginEN,
        ExpectedResult => sprintf( $HTMLTemplate, 'S:&nbsp;new' ),
    },
    {
        Name           => 'German Language Customer',
        Contact   => $TestUserLoginDE,
        ExpectedResult => sprintf( $HTMLTemplate, 'S:&nbsp;neu' ),
    },
    {
        Name           => 'Not existing Customer',
        Contact   => 'customer@example.com',
        ExpectedResult => sprintf( $HTMLTemplate, 'S:&nbsp;new' ),
    },
);

# get template generator object
my $TemplateGeneratorObject = $Kernel::OM->Get('TemplateGenerator');

for my $Test (@Tests) {

    # set ticket customer
    my $Success = $TicketObject->TicketCustomerSet(
        User     => $Test->{Contact},
        TicketID => $TicketID,
        UserID   => 1,
    );
    $Self->True(
        $Success,
        "$Test->{Name} TicketCustomerSet() - for customer $Test->{Contact} with true",
    );

    # get assigned auto response
    my %AutoResponse = $TemplateGeneratorObject->AutoResponse(
        TicketID         => $TicketID,
        OrigHeader       => {},
        AutoResponseType => 'auto reply/new ticket',
        UserID           => 1,
    );
    $Self->Is(
        $AutoResponse{Text},
        $Test->{ExpectedResult},
        "$Test->{Name} AutoResponse() - Text"
    );

    # create auto response article (bug#12097)
    my $ArticleID = $TicketObject->SendAutoResponse(
        TicketID         => $TicketID,
        AutoResponseType => 'auto reply/new ticket',
        OrigHeader       => {
            From => $Test->{Contact},
        },
        UserID => 1,
    );
    $Self->IsNot(
        $ArticleID,
        undef,
        "$Test->{Name} SendAutoResponse() - ArticleID should not be undef"
    );
}

# Cleanup is done by RestoreDatabase.

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
