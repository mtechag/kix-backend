# --
# Modified version of the work: Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PostMaster::NewTicket;

use strict;
use warnings;

our @ObjectDependencies = (
    'Config',
    'Contact',
    'DynamicField',
    'DynamicField::Backend',
    # KIX4OTRS-capeIT
    'HTMLUtils',
    # EO KIX4OTRS-capeIT
    'LinkObject',
    'Log',
    'Priority',
    'Queue',
    'Service',
     # KIX4OTRS-capeIT
    'SLA',
    # EO KIX4OTRS-capeIT
    'State',
    'Ticket',
    'Time',
    'Type',
    'User',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get parser object
    $Self->{ParserObject} = $Param{ParserObject} || die "Got no ParserObject!";

    $Self->{Debug} = $Param{Debug} || 0;

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(InmailUserID GetParam)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }
    my %GetParam         = %{ $Param{GetParam} };
    my $Comment          = $Param{Comment} || '';
    my $AutoResponseType = $Param{AutoResponseType} || '';

    # KIX4OTRS-capeIT
    # get ticket template
    my %TicketTemplate;
    if ( $GetParam{'X-KIX-TicketTemplate'} ) {
        %TicketTemplate = $Kernel::OM->Get('Ticket')->TicketTemplateGet(
            Name => $GetParam{'X-KIX-TicketTemplate'},
        );
    }

    # EO KIX4OTRS-capeIT

    # get queue id and name
    # KIX4OTRS-capeIT
    # my $QueueID = $Param{QueueID} || die "need QueueID!";
    my $QueueID = $TicketTemplate{QueueID} || $Param{QueueID} || die "need QueueID!";

    # EO KIX4OTRS-capeIT

    my $Queue = $Kernel::OM->Get('Queue')->QueueLookup(
        QueueID => $QueueID,
    );

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Config');

    # get state
    # KIX4OTRS-capeIT
    # my $State = $ConfigObject->Get('PostmasterDefaultState') || 'new';
    my $State;
    if ( defined $TicketTemplate{StateID} ) {
        $State = $Kernel::OM->Get('State')->StateLookup( StateID => $TicketTemplate{StateID} );
    }
    else {
        $State = $ConfigObject->Get('PostmasterDefaultState') || 'new';
    }

    # EO KIX4OTRS-capeIT

    if ( $GetParam{'X-KIX-State'} ) {

        my $StateID = $Kernel::OM->Get('State')->StateLookup(
            State => $GetParam{'X-KIX-State'},
        );

        if ($StateID) {
            $State = $GetParam{'X-KIX-State'};
        }
        else {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "State ".$GetParam{'X-KIX-State'}." does not exist, falling back to $State!"
            );
        }
    }

    # get priority
    # KIX4OTRS-capeIT
    # my $Priority = $Self->{ConfigObject}->Get('PostmasterDefaultPriority') || '3 normal';
    my $Priority;
    if ( defined $TicketTemplate{PriorityID} ) {
        $Priority
            = $Kernel::OM->Get('Priority')->PriorityLookup( PriorityID => $TicketTemplate{PriorityID} );
    }
    else {
        $Priority = $ConfigObject->Get('PostmasterDefaultPriority') || '3 normal';
    }

    # EO KIX4OTRS-capeIT

    if ( $GetParam{'X-KIX-Priority'} ) {

        my $PriorityID = $Kernel::OM->Get('Priority')->PriorityLookup(
            Priority => $GetParam{'X-KIX-Priority'},
        );

        if ($PriorityID) {
            $Priority = $GetParam{'X-KIX-Priority'};
        }
        else {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message =>
                    "Priority ".$GetParam{'X-KIX-Priority'}." does not exist, falling back to $Priority!"
            );
        }
    }

    my $TypeID;

    if ( $GetParam{'X-KIX-Type'} ) {

        # Check if type exists
        $TypeID = $Kernel::OM->Get('Type')->TypeLookup( Type => $GetParam{'X-KIX-Type'} );

        if ( !$TypeID ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message =>
                    "Type ".$GetParam{'X-KIX-Type'}." does not exist, falling back to default type."
            );
        }
    }

    # get sender email
    my @EmailAddresses = $Self->{ParserObject}->SplitAddressLine(
        Line => $GetParam{From},
    );
    for my $Address (@EmailAddresses) {
        $GetParam{SenderEmailAddress} = $Self->{ParserObject}->GetEmailAddress(
            Email => $Address,
        );
    }

    # get customer id if X-KIX-CustomerNo is given
    if ( $GetParam{'X-KIX-CustomerNo'} ) {

        # get organisation object
        my $OrgObject = $Kernel::OM->Get('Organisation');

        # search organisation based on X-KIX-CustomerNo
        my %OrgList = $OrgObject->OrganisationSearch(
            Number => $GetParam{'X-KIX-CustomerNo'},
            Limit  => 1,
            Valid  => 0
        );

        if (%OrgList) {
            $GetParam{'X-KIX-CustomerNo'} = (keys %OrgList)[0];
        }
    }

    # get customer user data form From: (sender address)
    if ( !$GetParam{'X-KIX-Contact'} ) {

        my %ContactData;
        if ( $GetParam{From} ) {

            my @EmailAddresses = $Self->{ParserObject}->SplitAddressLine(
                Line => $GetParam{From},
            );

            for my $Address (@EmailAddresses) {
                $GetParam{EmailFrom} = $Self->{ParserObject}->GetEmailAddress(
                    Email => $Address,
                );
            }

            if ( $GetParam{EmailFrom} ) {

                # get customer user object
                my $ContactObject = $Kernel::OM->Get('Contact');

                my %List = $ContactObject->ContactSearch(
                    PostMasterSearch => lc( $GetParam{EmailFrom} ),
                    Limit            => 1,
                    Valid            => 0
                );

                if ( %List ) {
                    %ContactData = $ContactObject->ContactGet(
                        ID => (keys %List)[0],
                    );
                }
            }
        }

        # take PrimaryOrganisationID from contact lookup or from "from" field
        if ( $ContactData{ID} && !$GetParam{'X-KIX-Contact'} ) {
            $GetParam{'X-KIX-Contact'} = $ContactData{ID};

            # notice that Login is from contact data
            $Kernel::OM->Get('Log')->Log(
                Priority => 'notice',
                Message  => "Take Login ($ContactData{ID}) from contact based on ($GetParam{'EmailFrom'}).",
            );
        }
        if ( $ContactData{PrimaryOrganisationID} && !$GetParam{'X-KIX-CustomerNo'} ) {
            $GetParam{'X-KIX-CustomerNo'} = $ContactData{PrimaryOrganisationID};

            # notice that PrimaryOrganisationID is from customer source backend
            $Kernel::OM->Get('Log')->Log(
                Priority => 'notice',
                Message  => "Take PrimaryOrganisationID ($ContactData{PrimaryOrganisationID})"
                    . " from contact based on ($GetParam{'EmailFrom'}).",
            );
        }
    }
    else {
        # transform X-KIX-Contact to ID
        my %ContactData;

        # get contact object
        my $ContactObject = $Kernel::OM->Get('Contact');

        my %List = $ContactObject->ContactSearch(
            PostMasterSearch => $GetParam{'X-KIX-Contact'},
            Limit            => 1,
            Valid            => 0
        );

        if ( %List ) {
            $GetParam{'X-KIX-Contact'} = (keys %List)[0];
        }
    }

    # if there is no customer user found!
    if ( !$GetParam{'X-KIX-Contact'} ) {
        $GetParam{'X-KIX-Contact'} = $GetParam{SenderEmailAddress};
    }

    # get ticket owner
    # KIX4OTRS-capeIT
    my $OwnerID = $GetParam{'X-KIX-OwnerID'} || $TicketTemplate{OwnerID} || $Param{InmailUserID};

    # EO KIX4OTRS-capeIT
    if ( $GetParam{'X-KIX-Owner'} ) {

        my $TmpOwnerID = $Kernel::OM->Get('User')->UserLookup(
            UserLogin => $GetParam{'X-KIX-Owner'},
        );

        $OwnerID = $TmpOwnerID || $OwnerID;
    }

    my %Opts;
    if ( $GetParam{'X-KIX-ResponsibleID'} ) {
        $Opts{ResponsibleID} = $GetParam{'X-KIX-ResponsibleID'};
    }

    # KIX4OTRS-capeIT
    elsif ( defined $TicketTemplate{ResponsibleID} ) {
        $Opts{ResponsibleID} = $TicketTemplate{ResponsibleID};
    }

    # EO KIX4OTRS-capeIT

    if ( $GetParam{'X-KIX-Responsible'} ) {

        my $TmpResponsibleID = $Kernel::OM->Get('User')->UserLookup(
            UserLogin => $GetParam{'X-KIX-Responsible'},
        );

        $Opts{ResponsibleID} = $TmpResponsibleID || $Opts{ResponsibleID};
    }

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Ticket');

    # KIX4OTRS-capeIT
    # get ticket type
    my $Type;
    if ( $ConfigObject->Get('Ticket::Type') && defined $TicketTemplate{TypeID} ) {
        $Type = $Kernel::OM->Get('Type')->TypeLookup( TypeID => $TicketTemplate{TypeID} );
    }

    # get service
    my $Service;
    if ( defined $TicketTemplate{ServiceID} ) {
        $Service = $Kernel::OM->Get('Service')->ServiceLookup( ServiceID => $TicketTemplate{ServiceID} );
    }

    # get sla
    my $SLA;
    if ( defined $TicketTemplate{SLAID} ) {
        $SLA = $Kernel::OM->Get('SLA')->SLALookup( SLAID => $TicketTemplate{SLAID} );
    }

#rbo - T2016121190001552 - added KIX placeholders
    # get subject
    my $Subject = $GetParam{Subject};
    if ( defined $TicketTemplate{Subject}
        && $TicketTemplate{Subject} =~ m/(.*?)<KIX_EMAIL_SUBJECT>(.*)/g )
    {
        $Subject = $1 . $Subject . $3;
    }

    # EO KIX4OTRS-capeIT

    # create new ticket
    my $NewTn    = $TicketObject->TicketCreateNumber();
    my $TicketID = $TicketObject->TicketCreate(
        TN              => $NewTn,
        Title           => $Subject,
        QueueID         => $QueueID || $TicketTemplate{QueueID},
        Lock            => $GetParam{'X-KIX-Lock'} || 'unlock',
        Priority        => $Priority,
        State           => $State,
        Type            => $Type    || $GetParam{'X-KIX-Type'}    || '',
        Service         => $Service || $GetParam{'X-KIX-Service'} || '',
        SLA             => $SLA     || $GetParam{'X-KIX-SLA'}     || '',
        TicketTemplate  => (%TicketTemplate && $TicketTemplate{ID}) ? $TicketTemplate{ID} : '',
        OrganisationID  => $GetParam{'X-KIX-CustomerNo'},
        ContactID       => $GetParam{'X-KIX-Contact'},
        OwnerID         => $OwnerID,
        UserID          => $Param{InmailUserID},
        %Opts,
    );

    if ( !$TicketID ) {
        return;
    }

    # debug
    if ( $Self->{Debug} > 0 ) {
        print "New Ticket created!\n";
        print "TicketNumber: $NewTn\n";
        print "TicketID: $TicketID\n";
        print "Priority: $Priority\n";
        print "State: $State\n";
        print "OrganisationID: ".$GetParam{'X-KIX-CustomerNo'}."\n";
        print "ContactID: ".$GetParam{'X-KIX-Contact'}."\n";
        for my $Value (qw(Type Service SLA Lock)) {

            if ( $GetParam{ 'X-KIX-' . $Value } ) {
                print "Type: " . $GetParam{ 'X-KIX-' . $Value } . "\n";
            }
        }
    }

    # set pending time
    if ( $GetParam{'X-KIX-State-PendingTime'} ) {

  # You can specify absolute dates like "2010-11-20 00:00:00" or relative dates, based on the arrival time of the email.
  # Use the form "+ $Number $Unit", where $Unit can be 's' (seconds), 'm' (minutes), 'h' (hours) or 'd' (days).
  # Only one unit can be specified. Examples of valid settings: "+50s" (pending in 50 seconds), "+30m" (30 minutes),
  # "+12d" (12 days). Note that settings like "+1d 12h" are not possible. You can specify "+36h" instead.

        my $TargetTimeStamp = $GetParam{'X-KIX-State-PendingTime'};

        my ( $Sign, $Number, $Unit ) = $TargetTimeStamp =~ m{^\s*([+-]?)\s*(\d+)\s*([smhd]?)\s*$}smx;

        if ($Number) {
            $Sign ||= '+';
            $Unit ||= 's';

            my $Seconds = $Sign eq '-' ? ( $Number * -1 ) : $Number;

            my %UnitMultiplier = (
                s => 1,
                m => 60,
                h => 60 * 60,
                d => 60 * 60 * 24,
            );

            $Seconds = $Seconds * $UnitMultiplier{$Unit};

            # get time object
            my $TimeObject = $Kernel::OM->Get('Time');

            $TargetTimeStamp = $TimeObject->SystemTime2TimeStamp(
                SystemTime => $TimeObject->SystemTime() + $Seconds,
            );
        }

        my $Set = $TicketObject->TicketPendingTimeSet(
            String   => $TargetTimeStamp,
            TicketID => $TicketID,
            UserID   => $Param{InmailUserID},
        );

        # debug
        if ( $Set && $Self->{Debug} > 0 ) {
            print "State-PendingTime: ".$GetParam{'X-KIX-State-PendingTime'}."\n";
        }
    }

    # get dynamic field objects
    my $DynamicFieldObject        = $Kernel::OM->Get('DynamicField');
    my $DynamicFieldBackendObject = $Kernel::OM->Get('DynamicField::Backend');

    # dynamic fields
    my $DynamicFieldList =
        $DynamicFieldObject->DynamicFieldList(
        Valid      => 1,
        ResultType => 'HASH',
        ObjectType => 'Ticket',
        );

    # set dynamic fields for Ticket object type
    DYNAMICFIELDID:
    for my $DynamicFieldID ( sort keys %{$DynamicFieldList} ) {
        next DYNAMICFIELDID if !$DynamicFieldID;
        next DYNAMICFIELDID if !$DynamicFieldList->{$DynamicFieldID};
        my $Key = 'X-KIX-DynamicField-' . $DynamicFieldList->{$DynamicFieldID};

        if ( defined $GetParam{$Key} && length $GetParam{$Key} ) {

            # get dynamic field config
            my $DynamicFieldGet = $DynamicFieldObject->DynamicFieldGet(
                ID => $DynamicFieldID,
            );

            $DynamicFieldBackendObject->ValueSet(
                DynamicFieldConfig => $DynamicFieldGet,
                ObjectID           => $TicketID,
                Value              => $GetParam{$Key},
                UserID             => $Param{InmailUserID},
            );

            if ( $Self->{Debug} > 0 ) {
                print "$Key: " . $GetParam{$Key} . "\n";
            }
        }
    }

    # reverse dynamic field list
    my %DynamicFieldListReversed = reverse %{$DynamicFieldList};

    # set ticket free text
    # for backward compatibility (should be removed in a future version)
    my %Values =
        (
        'X-KIX-TicketKey'   => 'TicketFreeKey',
        'X-KIX-TicketValue' => 'TicketFreeText',
        );
    for my $Item ( sort keys %Values ) {
        for my $Count ( 1 .. 16 ) {
            my $Key = $Item . $Count;
            if (
                defined $GetParam{$Key}
                && length $GetParam{$Key}
                && $DynamicFieldListReversed{ $Values{$Item} . $Count }
                )
            {
                # get dynamic field config
                my $DynamicFieldGet = $DynamicFieldObject->DynamicFieldGet(
                    ID => $DynamicFieldListReversed{ $Values{$Item} . $Count },
                );
                if ($DynamicFieldGet) {
                    my $Success = $DynamicFieldBackendObject->ValueSet(
                        DynamicFieldConfig => $DynamicFieldGet,
                        ObjectID           => $TicketID,
                        Value              => $GetParam{$Key},
                        UserID             => $Param{InmailUserID},
                    );
                }

                if ( $Self->{Debug} > 0 ) {
                    print "TicketKey$Count: " . $GetParam{$Key} . "\n";
                }
            }
        }
    }

    # set ticket free time
    # for backward compatibility (should be removed in a future version)
    for my $Count ( 1 .. 6 ) {

        my $Key = 'X-KIX-TicketTime' . $Count;

        if ( defined $GetParam{$Key} && length $GetParam{$Key} ) {

            # get time object
            my $TimeObject = $Kernel::OM->Get('Time');

            my $SystemTime = $TimeObject->TimeStamp2SystemTime(
                String => $GetParam{$Key},
            );

            if ( $SystemTime && $DynamicFieldListReversed{ 'TicketFreeTime' . $Count } ) {

                # get dynamic field config
                my $DynamicFieldGet = $DynamicFieldObject->DynamicFieldGet(
                    ID => $DynamicFieldListReversed{ 'TicketFreeTime' . $Count },
                );

                if ($DynamicFieldGet) {
                    my $Success = $DynamicFieldBackendObject->ValueSet(
                        DynamicFieldConfig => $DynamicFieldGet,
                        ObjectID           => $TicketID,
                        Value              => $GetParam{$Key},
                        UserID             => $Param{InmailUserID},
                    );
                }

                if ( $Self->{Debug} > 0 ) {
                    print "TicketTime$Count: " . $GetParam{$Key} . "\n";
                }
            }
        }
    }

    # # KIX4OTRS-capeIT
    # # get body
    # my $Body = $GetParam{Body};
    # my $RichTextUsed = $ConfigObject->Get('Frontend::RichText');
    # if ( defined $TicketTemplate{Body} ) {
    #     if ( $RichTextUsed && $TicketTemplate{Body} =~ m/(.*?)&lt;KIX_EMAIL_BODY&gt;(.*)/msg ) {
    #         $Body = $1 . $Body . $3;
    #         $GetParam{'Content-Type'} = 'text/html';
    #     }
    #     elsif ( !$RichTextUsed && $TicketTemplate{Body} =~ m/(.*?)<KIX_EMAIL_BODY>(.*)/msg ) {
    #         $Body = $1 . $Body . $3;
    #     }
    # }

    # get channel
    my $Channel;
    if ( defined $TicketTemplate{Channel} ) {
        $Channel = $Kernel::OM->Get('Channel')->ChannelLookup( ID => $TicketTemplate{Channel} );
    }

    # EO KIX4OTRS-capeIT

    # do article db insert
    my $ArticleID = $TicketObject->ArticleCreate(
        TicketID         => $TicketID,
        Channel          => $GetParam{'X-KIX-Channel'} || $Channel,
        SenderType       => $GetParam{'X-KIX-SenderType'},
        From             => $GetParam{From},
        ReplyTo          => $GetParam{ReplyTo},
        To               => $GetParam{To},
        Cc               => $GetParam{Cc},
        Subject          => $Subject,
        MessageID        => $GetParam{'Message-ID'},
        InReplyTo        => $GetParam{'In-Reply-To'},
        References       => $GetParam{'References'},
        ContentType      => $GetParam{'Content-Type'},
        Charset          => $GetParam{'Charset'},
        MimeType         => $GetParam{'Content-Type'},
        Body             => $GetParam{Body},
        UserID           => $Param{InmailUserID},
        HistoryType      => 'EmailCustomer',
        HistoryComment   => "\%\%$Comment",
        OrigHeader       => \%GetParam,
        AutoResponseType => $AutoResponseType,
        Queue            => $Queue,
    );

    # close ticket if article create failed!
    if ( !$ArticleID ) {
        $TicketObject->TicketDelete(
            TicketID => $TicketID,
            UserID   => $Param{InmailUserID},
        );
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Can't process email with MessageID <$GetParam{'Message-ID'}>! "
                . "Please create a bug report with this email (From: $GetParam{From}, Located "
                . "under var/spool/problem-email*) on http://www.kixdesk.com/!",
        );
        return;
    }

    if ( $Param{LinkToTicketID} ) {

        my $SourceKey = $Param{LinkToTicketID};
        my $TargetKey = $TicketID;

        $Kernel::OM->Get('LinkObject')->LinkAdd(
            SourceObject => 'Ticket',
            SourceKey    => $SourceKey,
            TargetObject => 'Ticket',
            TargetKey    => $TargetKey,
            Type         => 'Normal',
            UserID       => $Param{InmailUserID},
        );
    }

    # debug
    if ( $Self->{Debug} > 0 ) {
        ATTRIBUTE:
        for my $Attribute ( sort keys %GetParam ) {
            next ATTRIBUTE if !$GetParam{$Attribute};
            print "$Attribute: $GetParam{$Attribute}\n";
        }
    }

    # dynamic fields
    $DynamicFieldList =
        $DynamicFieldObject->DynamicFieldList(
        Valid      => 1,
        ResultType => 'HASH',
        ObjectType => 'Article',
        );

    # set dynamic fields for Article object type
    DYNAMICFIELDID:
    for my $DynamicFieldID ( sort keys %{$DynamicFieldList} ) {
        next DYNAMICFIELDID if !$DynamicFieldID;
        next DYNAMICFIELDID if !$DynamicFieldList->{$DynamicFieldID};
        my $Key = 'X-KIX-DynamicField-' . $DynamicFieldList->{$DynamicFieldID};
        
        if ( defined $GetParam{$Key} && length $GetParam{$Key} ) {

            # get dynamic field config
            my $DynamicFieldGet = $DynamicFieldObject->DynamicFieldGet(
                ID => $DynamicFieldID,
            );

            $DynamicFieldBackendObject->ValueSet(
                DynamicFieldConfig => $DynamicFieldGet,
                ObjectID           => $ArticleID,
                Value              => $GetParam{$Key},
                UserID             => $Param{InmailUserID},
            );

            if ( $Self->{Debug} > 0 ) {
                print "$Key: " . $GetParam{$Key} . "\n";
            }
        }
    }

    # reverse dynamic field list
    %DynamicFieldListReversed = reverse %{$DynamicFieldList};

    # set free article text
    # for backward compatibility (should be removed in a future version)
    %Values =
        (
        'X-KIX-ArticleKey'   => 'ArticleFreeKey',
        'X-KIX-ArticleValue' => 'ArticleFreeText',
        );
    for my $Item ( sort keys %Values ) {
        for my $Count ( 1 .. 16 ) {
            my $Key = $Item . $Count;
            if (
                defined $GetParam{$Key}
                && length $GetParam{$Key}
                && $DynamicFieldListReversed{ $Values{$Item} . $Count }
                )
            {
                # get dynamic field config
                my $DynamicFieldGet = $DynamicFieldObject->DynamicFieldGet(
                    ID => $DynamicFieldListReversed{ $Values{$Item} . $Count },
                );
                if ($DynamicFieldGet) {
                    my $Success = $DynamicFieldBackendObject->ValueSet(
                        DynamicFieldConfig => $DynamicFieldGet,
                        ObjectID           => $ArticleID,
                        Value              => $GetParam{$Key},
                        UserID             => $Param{InmailUserID},
                    );
                }

                if ( $Self->{Debug} > 0 ) {
                    print "TicketKey$Count: " . $GetParam{$Key} . "\n";
                }
            }
        }
    }

    # write plain email to the storage
    $TicketObject->ArticleWritePlain(
        ArticleID => $ArticleID,
        Email     => $Self->{ParserObject}->GetPlainEmail(),
        UserID    => $Param{InmailUserID},
    );

    # write attachments to the storage
    for my $Attachment ( $Self->{ParserObject}->GetAttachments() ) {
        $TicketObject->ArticleWriteAttachment(
            Filename           => $Attachment->{Filename},
            Content            => $Attachment->{Content},
            ContentType        => $Attachment->{ContentType},
            ContentID          => $Attachment->{ContentID},
            ContentAlternative => $Attachment->{ContentAlternative},
            Disposition        => $Attachment->{Disposition},
            ArticleID          => $ArticleID,
            UserID             => $Param{InmailUserID},
        );
    }

    return $TicketID;
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
