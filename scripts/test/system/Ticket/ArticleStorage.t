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

use Unicode::Normalize;

# get needed objects
my $ConfigObject = $Kernel::OM->Get('Config');
my $MainObject   = $Kernel::OM->Get('Main');
my $TicketObject = $Kernel::OM->Get('Ticket');

# get helper object
$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        RestoreDatabase  => 1,
        UseTmpArticleDir => 1,
    },
);
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my $TicketID = $TicketObject->TicketCreate(
    Title        => 'Some Ticket_Title',
    Queue        => 'Junk',
    Lock         => 'unlock',
    Priority     => '3 normal',
    State        => 'closed',
    OrganisationID => '123465',
    ContactID    => 'customer@example.com',
    OwnerID      => 1,
    UserID       => 1,
);
$Self->True(
    $TicketID,
    'TicketCreate()',
);

my $ArticleID = $TicketObject->ArticleCreate(
    TicketID       => $TicketID,
    Channels       => 'note',
    SenderType     => 'agent',
    From           => 'Some Agent <email@example.com>',
    To             => 'Some Customer <customer-a@example.com>',
    Subject        => 'some short description',
    Body           => 'the message text',
    ContentType    => 'text/plain; charset=ISO-8859-15',
    HistoryType    => 'OwnerUpdate',
    HistoryComment => 'Some free text!',
    UserID         => 1,
    NoAgentNotify  => 1,                                          # if you don't want to send agent notifications
);

$Self->True(
    $ArticleID,
    'ArticleCreate()',
);

# article attachment checks
for my $Backend (qw(DB FS)) {

    # make sure that the TicketObject gets recreated for each loop.
    $Kernel::OM->ObjectsDiscard( Objects => ['Ticket'] );

    $ConfigObject->Set(
        Key   => 'Ticket::StorageModule',
        Value => 'Ticket::ArticleStorage' . $Backend,
    );

    my $TicketObject = $Kernel::OM->Get('Ticket');

    $Self->True(
        $TicketObject->isa( 'Ticket::ArticleStorage' . $Backend ),
        "TicketObject loaded the correct backend",
    );

    for my $File (
        qw(Ticket-Article-Test1.xls Ticket-Article-Test1.txt Ticket-Article-Test1.doc
        Ticket-Article-Test1.png Ticket-Article-Test1.pdf Ticket-Article-Test-utf8-1.txt Ticket-Article-Test-utf8-1.bin)
        )
    {
        my $Location = $ConfigObject->Get('Home')
            . "/scripts/test/system/sample/Ticket/$File";
        my $ContentRef = $MainObject->FileRead(
            Location => $Location,
            Mode     => 'binmode',
        );

        for my $FileName (
            'SimpleFile',
            'ÄÖÜカスタマ-',          # Unicode NFC
            'Второй_файл',    # Unicode NFD
            )
        {
            my $Content                = ${$ContentRef};
            my $FileNew                = $FileName . $File;
            my $MD5Orig                = $MainObject->MD5sum( String => $Content );
            my $ArticleWriteAttachment = $TicketObject->ArticleWriteAttachment(
                Content     => $Content,
                Filename    => $FileNew,
                ContentType => 'image/png',
                ArticleID   => $ArticleID,
                UserID      => 1,
            );
            $Self->True(
                $ArticleWriteAttachment,
                "$Backend ArticleWriteAttachment() - $FileNew",
            );

            my %AttachmentIndex = $TicketObject->ArticleAttachmentIndex(
                ArticleID => $ArticleID,
                UserID    => 1,
            );

            my $TargetFilename = $FileName . $File;

            # Mac OS (HFS+) will store all filenames as NFD internally.
            if ( $^O eq 'darwin' && $Backend eq 'FS' ) {
                $TargetFilename = Unicode::Normalize::NFD($TargetFilename);
            }

            $Self->Is(
                $AttachmentIndex{1}->{Filename},
                $TargetFilename,
                "$Backend ArticleAttachmentIndex() Filename - $FileNew"
            );

            my %Data = $TicketObject->ArticleAttachment(
                ArticleID => $ArticleID,
                FileID    => 1,
                UserID    => 1,
            );
            $Self->True(
                $Data{Content},
                "$Backend ArticleAttachment() Content - $FileNew",
            );
            $Self->True(
                $Data{ContentType},
                "$Backend ArticleAttachment() ContentType - $FileNew",
            );
            $Self->True(
                $Data{Content} eq $Content,
                "$Backend ArticleWriteAttachment() / ArticleAttachment() - $FileNew",
            );
            $Self->True(
                $Data{ContentType} eq 'image/png',
                "$Backend ArticleWriteAttachment() / ArticleAttachment() - $File",
            );
            my $MD5New = $MainObject->MD5sum( String => $Data{Content} );
            $Self->Is(
                $MD5Orig || '1',
                $MD5New  || '2',
                "$Backend MD5 - $FileNew",
            );
            my $Delete = $TicketObject->ArticleDeleteAttachment(
                ArticleID => $ArticleID,
                UserID    => 1,
            );
            $Self->True(
                $Delete,
                "$Backend ArticleDeleteAttachment() - $FileNew",
            );

            %AttachmentIndex = $TicketObject->ArticleAttachmentIndex(
                ArticleID => $ArticleID,
                UserID    => 1,
            );

            $Self->IsDeeply(
                \%AttachmentIndex,
                {},
                "$Backend ArticleAttachmentIndex() after delete - $FileNew"
            );
        }
    }
}

# filename collision checks
for my $Backend (qw(DB FS)) {

    # Make sure that the TicketObject gets recreated for each loop.
    $Kernel::OM->ObjectsDiscard( Objects => ['Ticket'] );

    $ConfigObject->Set(
        Key   => 'Ticket::StorageModule',
        Value => 'Ticket::ArticleStorage' . $Backend,
    );

    my $TicketObject = $Kernel::OM->Get('Ticket');

    $Self->True(
        $TicketObject->isa( 'Ticket::ArticleStorage' . $Backend ),
        "TicketObject loaded the correct backend",
    );

    # Store file 2 times
    my $FileName               = "[Terminology Guide äöß].pdf";
    my $Content                = '123';
    my $FileNew                = $FileName;
    my $ArticleWriteAttachment = $TicketObject->ArticleWriteAttachment(
        Content     => $Content,
        Filename    => $FileNew,
        ContentType => 'image/png',
        ArticleID   => $ArticleID,
        UserID      => 1,
    );
    $Self->True(
        $ArticleWriteAttachment,
        "$Backend ArticleWriteAttachment() - collision check created $FileNew",
    );

    $ArticleWriteAttachment = $TicketObject->ArticleWriteAttachment(
        Content     => $Content,
        Filename    => $FileNew,
        ContentType => 'image/png',
        ArticleID   => $ArticleID,
        UserID      => 1,
    );
    $Self->True(
        $ArticleWriteAttachment,
        "$Backend ArticleWriteAttachment() - collision check created $FileNew second time",
    );

    my %AttachmentIndex = $TicketObject->ArticleAttachmentIndex(
        ArticleID => $ArticleID,
        UserID    => 1,
    );

    my $TargetFilename = '[Terminology Guide äöß]';

    if ( $Backend eq 'FS' ) {

        $TargetFilename = '_Terminology_Guide_äöß_';

        # Mac OS (HFS+) will store all filenames as NFD internally.
        if ( $^O eq 'darwin' ) {
            $TargetFilename = Unicode::Normalize::NFD($TargetFilename);
        }
    }

    $Self->Is(
        scalar keys %AttachmentIndex,
        2,
        "$Backend ArticleWriteAttachment() - collision check number of attachments",
    );

    my ($Entry1) = grep { $AttachmentIndex{$_}->{Filename} eq "$TargetFilename.pdf" } keys %AttachmentIndex;
    my ($Entry2) = grep { $AttachmentIndex{$_}->{Filename} eq "$TargetFilename-1.pdf" }
        keys %AttachmentIndex;

    $Self->IsDeeply(
        $AttachmentIndex{$Entry1},
        {
            'ContentAlternative' => '',
            'ContentID'          => '',
            'ContentType'        => 'image/png',
            'Filename'           => "$TargetFilename.pdf",
            'Filesize'           => '3 Bytes',
            'FilesizeRaw'        => '3',
            'Disposition'        => 'attachment',
        },
        "$Backend ArticleAttachmentIndex - collision check entry 1",
    );

    $Self->IsDeeply(
        $AttachmentIndex{$Entry2},
        {
            'ContentAlternative' => '',
            'ContentID'          => '',
            'ContentType'        => 'image/png',
            'Filename'           => "$TargetFilename-1.pdf",
            'Filesize'           => '3 Bytes',
            'FilesizeRaw'        => '3',
            'Disposition'        => 'attachment',
        },
        "$Backend ArticleAttachmentIndex - collision check entry 2",
    );

    my $Delete = $TicketObject->ArticleDeleteAttachment(
        ArticleID => $ArticleID,
        UserID    => 1,
    );

    $Self->True(
        $Delete,
        "$Backend ArticleDeleteAttachment()",
    );

    %AttachmentIndex = $TicketObject->ArticleAttachmentIndex(
        ArticleID => $ArticleID,
        UserID    => 1,
    );

    $Self->IsDeeply(
        \%AttachmentIndex,
        {},
        "$Backend ArticleAttachmentIndex() after delete",
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
