# --
# Modified version of the work: Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Event::NotificationEvent;

use strict;
use warnings;

use List::Util qw(first);

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Contact',
    'Kernel::System::DB',
    'Kernel::System::DynamicField',
    'Kernel::System::DynamicField::Backend',
    'Kernel::System::Email',
    'Kernel::System::HTMLUtils',
    'Kernel::System::JSON',
    'Kernel::System::Log',
    'Kernel::System::NotificationEvent',
    'Kernel::System::Role',
    'Kernel::System::Queue',
    'Kernel::System::SystemAddress',
    'Kernel::System::TemplateGenerator',
    'Kernel::System::Ticket',
    'Kernel::System::Time',
    'Kernel::System::User',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Event Data Config UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    if ( !$Param{Data}->{TicketID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need TicketID in Data!',
        );
        return;
    }

    # get objects
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # return if no notification is active
    return 1 if $TicketObject->{SendNoNotification};

    # return if no ticket exists (e. g. it got deleted)
    my $TicketExists = $TicketObject->TicketNumberLookup(
        TicketID => $Param{Data}->{TicketID},
        UserID   => $Param{UserID},
    );

    return 1 if !$TicketExists;

    # get notification event object
    my $NotificationEventObject = $Kernel::OM->Get('Kernel::System::NotificationEvent');

    # check if event is affected
    my @IDs = $NotificationEventObject->NotificationEventCheck(
        Event => $Param{Event},
    );

    # return if no notification for event exists
    return 1 if !@IDs;

    # get ticket attribute matches
    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Param{Data}->{TicketID},
        UserID        => $Param{UserID},
        DynamicFields => 1,
    );

    # get dynamic field objects
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');

    # get dynamic fields
    my $DynamicFieldList = $DynamicFieldObject->DynamicFieldListGet(
        Valid      => 1,
        ObjectType => ['Ticket'],
    );

    # create a dynamic field config lookup table
    my %DynamicFieldConfigLookup;
    for my $DynamicFieldConfig ( @{$DynamicFieldList} ) {
        $DynamicFieldConfigLookup{ $DynamicFieldConfig->{Name} } = $DynamicFieldConfig;
    }

    NOTIFICATION:
    for my $ID (@IDs) {

        my %Notification = $NotificationEventObject->NotificationGet(
            ID => $ID,
        );

        # verify ticket and article conditions
        my $PassFilter = $Self->_NotificationFilter(
            %Param,
            Ticket                   => \%Ticket,
            Notification             => \%Notification,
            DynamicFieldConfigLookup => \%DynamicFieldConfigLookup,
        );

        next NOTIFICATION if !$PassFilter;

        # add attachments only on ArticleCreate or ArticleSend event
        my @Attachments;
        if (
            ( ( $Param{Event} eq 'ArticleCreate' ) || ( $Param{Event} eq 'ArticleSend' ) )
            && $Param{Data}->{ArticleID}
            )
        {

            # add attachments to notification
            if ( $Notification{Data}->{ArticleAttachmentInclude}->[0] ) {

                # get article, it is needed for the correct behavior of the
                # StripPlainBodyAsAttachment flag into the ArticleAttachmentIndex function
                my %Article = $Kernel::OM->Get('Kernel::System::Ticket')->ArticleGet(
                    ArticleID     => $Param{Data}->{ArticleID},
                    UserID        => $Param{UserID},
                    DynamicFields => 0,
                );

                my %Index = $TicketObject->ArticleAttachmentIndex(
                    ArticleID                  => $Param{Data}->{ArticleID},
                    Article                    => \%Article,
                    UserID                     => $Param{UserID},
                    StripPlainBodyAsAttachment => 3,
                );
                if (%Index) {
                    FILE_ID:
                    for my $FileID ( sort keys %Index ) {
                        my %Attachment = $TicketObject->ArticleAttachment(
                            ArticleID => $Param{Data}->{ArticleID},
                            FileID    => $FileID,
                            UserID    => $Param{UserID},
                        );
                        next FILE_ID if !%Attachment;

                        # KIX4OTRS-capeIT
                        # remove HTML-Attachments (HTML-Emails)
                        next
                            if (
                            $Index{$FileID}->{Filename} =~ /^file-[12]$/
                            && $Index{$FileID}->{ContentType} =~ /text\/html/i
                            );

                        # EO KIX4OTRS-capeIT

                        push @Attachments, \%Attachment;
                    }
                }
            }
        }

        # get recipients
        my @RecipientUsers = $Self->_RecipientsGet(
            %Param,
            Ticket       => \%Ticket,
            Notification => \%Notification,
        );

        my @NotificationBundle;

        # get template generator object;
        my $TemplateGeneratorObject = $Kernel::OM->Get('Kernel::System::TemplateGenerator');

        # parse all notification tags for each user
        for my $Recipient (@RecipientUsers) {

            my %ReplacedNotification = $TemplateGeneratorObject->NotificationEvent(
                TicketID              => $Param{Data}->{TicketID},
                Recipient             => $Recipient,
                Notification          => \%Notification,
                CustomerMessageParams => $Param{Data}->{CustomerMessageParams},
                UserID                => $Param{UserID},
            );

            my $UserNotificationTransport = $Kernel::OM->Get('Kernel::System::JSON')->Decode(
                Data => $Recipient->{Preferences}->{NotificationTransport},
            );

            push @NotificationBundle, {
                Recipient                      => $Recipient,
                Notification                   => \%ReplacedNotification,
                RecipientNotificationTransport => $UserNotificationTransport,
            };
        }

        # get config object
        my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

        # get notification transport config
        my %TransportConfig = %{ $ConfigObject->Get('Notification::Transport') || {} };

        # remember already sent agent notifications
        my %AlreadySent;

        # loop over transports for each notification
        TRANSPORT:
        for my $Transport ( sort keys %TransportConfig ) {

            # only configured transports for this notification
            if ( !grep { $_ eq $Transport } @{ $Notification{Data}->{Transports} } ) {
                next TRANSPORT;
            }

            next TRANSPORT if !IsHashRefWithData( $TransportConfig{$Transport} );
            next TRANSPORT if !$TransportConfig{$Transport}->{Module};

            # get transport object
            my $TransportObject;
            eval {
                $TransportObject = $Kernel::OM->Get( $TransportConfig{$Transport}->{Module} );
            };

            if ( !$TransportObject ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "Could not create a new $TransportConfig{$Transport}->{Module} object!",
                );

                next TRANSPORT;
            }

            if ( ref $TransportObject ne $TransportConfig{$Transport}->{Module} ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "$TransportConfig{$Transport}->{Module} object is invalid",
                );

                next TRANSPORT;
            }

            # check if transport is usable
            next TRANSPORT if !$TransportObject->IsUsable();

            BUNDLE:
            for my $Bundle (@NotificationBundle) {

                my $UserPreference = "Notification-$Notification{ID}-$Transport";

                # check if agent should get the notification
                my $AgentSendNotification = 0;
                if ( defined $Bundle->{RecipientNotificationTransport}->{$UserPreference} ) {
                    $AgentSendNotification = $Bundle->{RecipientNotificationTransport}->{$UserPreference};
                }
                elsif ( grep { $_ eq $Transport } @{ $Notification{Data}->{AgentEnabledByDefault} } ) {
                    $AgentSendNotification = 1;
                }
                elsif (
                    !IsArrayRefWithData( $Notification{Data}->{VisibleForAgent} )
                    || (
                        defined $Notification{Data}->{VisibleForAgent}->[0]
                        && !$Notification{Data}->{VisibleForAgent}->[0]
                    )
                    )
                {
                    $AgentSendNotification = 1;
                }

                # skip sending the notification if the agent has disabled it in its preferences
                if (
                    IsArrayRefWithData( $Notification{Data}->{VisibleForAgent} )
                    && $Notification{Data}->{VisibleForAgent}->[0]
                    && $Bundle->{Recipient}->{Type} eq 'Agent'
                    && !$AgentSendNotification
                    )
                {
                    next BUNDLE;
                }
                # Check if notification should not be send to the customer.
                if (
                    $Bundle->{Recipient}->{Type} eq 'Customer'
                    && $ConfigObject->Get('CustomerNotifyJustToRealCustomer')
                    )
                {
                    # No UserID means it's not a mapped customer.
                    next BUNDLE if !$Bundle->{Recipient}->{UserID};
                }

                my $Success = $Self->_SendRecipientNotification(
                    TicketID              => $Param{Data}->{TicketID},
                    Notification          => $Bundle->{Notification},
                    CustomerMessageParams => $Param{Data}->{CustomerMessageParams} || {},
                    Recipient             => $Bundle->{Recipient},
                    Event                 => $Param{Event},
                    Attachments           => \@Attachments,
                    Transport             => $Transport,
                    TransportObject       => $TransportObject,
                    UserID                => $Param{UserID},
                );

                # remember to have sent
                if ( $Bundle->{Recipient}->{UserID} ) {
                    $AlreadySent{ $Bundle->{Recipient}->{UserID} } = 1;
                }
            }

            # get special recipients specific for each transport
            my @TransportRecipients = $TransportObject->GetTransportRecipients(
                Notification => \%Notification,
            );

            next TRANSPORT if !@TransportRecipients;

            RECIPIENT:
            for my $Recipient (@TransportRecipients) {

                # replace all notification tags for each special recipient
                my %ReplacedNotification = $TemplateGeneratorObject->NotificationEvent(
                    TicketID              => $Param{Data}->{TicketID},
                    Recipient             => $Recipient,
                    Notification          => \%Notification,
                    CustomerMessageParams => $Param{Data}->{CustomerMessageParams} || {},
                    UserID                => $Param{UserID},
                );

                my $Success = $Self->_SendRecipientNotification(
                    TicketID              => $Param{Data}->{TicketID},
                    Notification          => \%ReplacedNotification,
                    CustomerMessageParams => $Param{Data}->{CustomerMessageParams} || {},
                    Recipient             => $Recipient,
                    Event                 => $Param{Event},
                    Attachments           => \@Attachments,
                    Transport             => $Transport,
                    TransportObject       => $TransportObject,
                    UserID                => $Param{UserID},
                );
            }
        }

        if ( %AlreadySent && $Param{Data}->{ArticleID} && $Param{Data}->{Channel} ) {

            # update to field
            my $UpdateToSuccess = $Self->_ArticleToUpdate(
                ArticleID   => $Param{Data}->{ArticleID},
                Channel     => $Param{Data}->{Channel},
                UserIDs     => \%AlreadySent,
                UserID      => $Param{UserID},
            );

            # check for errors
            if ( !$UpdateToSuccess ) {

                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "Could not update To field for Article: $Param{Data}->{ArticleID}.",
                );
            }
        }
    }

    return 1;
}

sub _NotificationFilter {
    my ( $Self, %Param ) = @_;

    # check needed params
    for my $Needed (qw(Ticket Notification DynamicFieldConfigLookup)) {
        return if !$Param{$Needed};
    }

    # set local values
    my %Notification = %{ $Param{Notification} };

    # get dynamic field backend object
    my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

    KEY:
    for my $Key ( sort keys %{ $Notification{Data} } ) {

        # ignore not ticket or article related attributes
        next KEY if $Key !~ /^(Ticket|Article)::(.*?)$/;

        # store extracted attribute name
        my $Attribute = $2;

        my %Article;
        if ( $Param{Data}->{ArticleID} ) {
            %Article = $Kernel::OM->Get('Kernel::System::Ticket')->ArticleGet(
                ArticleID     => $Param{Data}->{ArticleID},
                UserID        => $Param{UserID},
                DynamicFields => 0,
            );
        }

        # ignore anything that isn't ok
        next KEY if !$Notification{Data}->{$Key};
        next KEY if !@{ $Notification{Data}->{$Key} };
        next KEY if !defined $Notification{Data}->{$Key}->[0];
        my $Match = 0;

        VALUE:
        for my $Value ( @{ $Notification{Data}->{$Key} } ) {

            next VALUE if !defined $Value;

            if ( $Key =~ /^Ticket::/ ) {

                # check if key is a search dynamic field
                if ( $Attribute =~ m{\A DynamicField_(.*?)$}xms ) {

                    # remove search prefix
                    my $DynamicFieldName = $1;

                    # get the dynamic field config for this field
                    my $DynamicFieldConfig = $Param{DynamicFieldConfigLookup}->{$DynamicFieldName};

                    last VALUE if !$DynamicFieldConfig;

                    my $IsNotificationEventCondition = $DynamicFieldBackendObject->HasBehavior(
                        DynamicFieldConfig => $DynamicFieldConfig,
                        Behavior           => 'IsNotificationEventCondition',
                    );

                    last VALUE if !$IsNotificationEventCondition;

                    # Get match value from the dynamic field backend, if applicable (bug#12257).
                    my $MatchValue;
                    my $SearchFieldParameter = $DynamicFieldBackendObject->SearchFieldParameterBuild(
                        DynamicFieldConfig => $DynamicFieldConfig,
                        Profile            => {
                            $Key => $Value,
                        },
                    );
                    if ( defined $SearchFieldParameter->{Parameter}->{Equals} ) {
                        $MatchValue = $SearchFieldParameter->{Parameter}->{Equals};
                    }
                    else {
                        $MatchValue = $Value;
                    }

                    $Match = $DynamicFieldBackendObject->ObjectMatch(
                        DynamicFieldConfig => $DynamicFieldConfig,
                        Value              => $MatchValue,
                        ObjectAttributes   => $Param{Ticket},
                    );

                    last VALUE if $Match;
                }
                else {

                    if ( $Param{Ticket}->{$Attribute} && $Value eq $Param{Ticket}->{$Attribute} ) {
                        $Match = 1;
                        last VALUE;
                    }
                }
            }
            elsif ( $Key =~ /^Article::/ ) {
                # only accept relevant events
                next KEY if $Param{Event} !~ /ArticleCreate|ArticleSend/ || !IsHashRefWithData(\%Article);

                if ( $Article{$Attribute} && $Attribute =~ /(Body|Subject)/ && $Article{$Attribute} =~ /\Q$Value\E/i ) {
                    $Match = 1;
                    last VALUE;
                }
                elsif ( $Article{$Attribute} && $Value eq $Article{$Attribute} ) {
                    $Match = 1;
                    last VALUE;
                }
            }
        }

        return if !$Match;
    }

    return 1;
}

sub _RecipientsGet {
    my ( $Self, %Param ) = @_;

    # check needed params
    for my $Needed (qw(Ticket Notification)) {
        return if !$Param{$Needed};
    }

    # set local values
    my %Notification = %{ $Param{Notification} };
    my %Ticket       = %{ $Param{Ticket} };

    # get needed objects
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    my @RecipientUserIDs;
    my @RecipientUsers;

    # add pre-calculated recipient
    if ( IsArrayRefWithData( $Param{Data}->{Recipients} ) ) {
        push @RecipientUserIDs, @{ $Param{Data}->{Recipients} };
    }

    # remember pre-calculated user recipients for later comparisons
    my %PrecalculatedUserIDs = map { $_ => 1 } @RecipientUserIDs;

    # get recipients by Recipients
    if ( $Notification{Data}->{Recipients} ) {

        # get needed objects
        my $QueueObject        = $Kernel::OM->Get('Kernel::System::Queue');
        my $ContactObject = $Kernel::OM->Get('Kernel::System::Contact');

        # KIX4OTRS-capeIT
        my @LinkedAgents = ();
        my @LinkedCustomers = ();
        my %SelectedRecipientTypes = map {$_ => 1} grep { $_ =~ /^LinkedPerson/ } @{ $Notification{Data}->{Recipients} };
        if ( %SelectedRecipientTypes ) {

            # get linked persons
            my @LinkedRecipients = $Kernel::OM->Get('Kernel::System::Web::Request')->GetArray( Param => 'LinkedPersonToInform' );

            my @RecipientType = ();
            for my $LinkedRecipient ( @LinkedRecipients ) {
                my @RecipientParts = split(/:::/,$LinkedRecipient);
                if ( $RecipientParts[0] eq 'Agent' && $SelectedRecipientTypes{LinkedPersonAgent} && $RecipientParts[1] && !grep { $_ eq $RecipientParts[1] } @LinkedAgents ) {
                    push @LinkedAgents, $RecipientParts[1];
                }
                elsif ( $RecipientParts[0] eq 'Customer' && $SelectedRecipientTypes{LinkedPersonCustomer} && $RecipientParts[1] && !grep { $_ eq $RecipientParts[1] } @LinkedCustomers ) {
                    push @LinkedCustomers, $RecipientParts[1];
                }
                elsif ( $RecipientParts[0] eq '3rdParty' && $SelectedRecipientTypes{LinkedPerson3rdPerson} && $RecipientParts[1] && !grep { $_ eq $RecipientParts[1] } @LinkedCustomers ) {
                    push @LinkedCustomers, $RecipientParts[1];
                    $RecipientParts[0] = 'Customer';
                }
                else {
                    # not possible to add recipient
                    next;
                }
                next if grep { $_ eq $RecipientParts[0] } @RecipientType;
                push @RecipientType, $RecipientParts[0];
                push @{ $Notification{Data}->{Recipients} }, $RecipientParts[0].'LinkedPerson';
            }
        }
        # EO KIX4OTRS-capeIT

        RECIPIENT:
        for my $Recipient ( @{ $Notification{Data}->{Recipients} } ) {

            if (
                $Recipient
                # KIX4OTRS-capeIT
                =~ /^Agent(Owner|Responsible|Watcher|ReadPermissions|WritePermissions|MyQueues|MyServices|MyQueuesMyServices|)$/
                # EO KIX4OTRS-capeIT
                )
            {

                if ( $Recipient eq 'AgentOwner' ) {
                    push @{ $Notification{Data}->{RecipientAgents} }, $Ticket{OwnerID};
                }
                elsif ( $Recipient eq 'AgentResponsible' ) {

                    # add the responsible agent to the notification list
                    if ( $ConfigObject->Get('Ticket::Responsible') && $Ticket{ResponsibleID} ) {

                        push @{ $Notification{Data}->{RecipientAgents} },
                            $Ticket{ResponsibleID};
                    }
                }
                elsif ( $Recipient eq 'AgentWatcher' ) {

                    # its checked on TicketWatchGet function
                    push @{ $Notification{Data}->{RecipientAgents} }, $TicketObject->TicketWatchGet(
                        TicketID => $Param{Data}->{TicketID},
                        Result   => 'ARRAY',
                    );
                }
                elsif ( $Recipient eq 'AgentReadPermissions' ) {

                    # check each valid user if he has READ permission on /tickets
                    my @UserIDs;
                    my %UserList = $Kernel::OM->Get('Kernel::System::User')->UserList(
                        Valid => 1,
                        Short => 1,
                    );
                    foreach my $UserID ( sort keys %UserList ) {
                        my ($Granted) = $Kernel::OM->Get('Kernel::System::User')->CheckResourcePermission(
                            UserID              => $UserID,
                            Target              => '/tickets/' . $Ticket{TicketID},
                            RequestedPermission => 'READ'
                        );
                        if ( $Granted ) {
                            push @UserIDs, $UserID;
                        }
                    }

                    push @{ $Notification{Data}->{RecipientAgents} }, @UserIDs;
                }
                elsif ( $Recipient eq 'AgentWritePermissions' ) {

                    # check each valid user if he has UPDATE permission on /tickets
                    my @UserIDs;
                    my %UserList = $Kernel::OM->Get('Kernel::System::User')->UserList(
                        Valid => 1,
                        Short => 1,
                    );
                    foreach my $UserID ( sort keys %UserList ) {
                        my ($Granted) = $Kernel::OM->Get('Kernel::System::User')->CheckResourcePermission(
                            UserID              => $UserID,
                            Target              => '/tickets/' . $Ticket{TicketID},
                            RequestedPermission => 'UPDATE'
                        );
                        if ( $Granted ) {
                            push @UserIDs, $UserID;
                        }
                    }

                    push @{ $Notification{Data}->{RecipientAgents} }, @UserIDs;
                }
                elsif ( $Recipient eq 'AgentMyQueues' ) {

                    # get subscribed users
                    my %MyQueuesUserIDs = map { $_ => 1 } $TicketObject->GetSubscribedUserIDsByQueueID(
                        QueueID => $Ticket{QueueID}
                    );

                    my @UserIDs = sort keys %MyQueuesUserIDs;

                    push @{ $Notification{Data}->{RecipientAgents} }, @UserIDs;
                }
                elsif ( $Recipient eq 'AgentMyServices' ) {

                    # get subscribed users
                    my %MyServicesUserIDs;
                    if ( $Ticket{ServiceID} ) {
                        %MyServicesUserIDs = map { $_ => 1 } $TicketObject->GetSubscribedUserIDsByServiceID(
                            ServiceID => $Ticket{ServiceID},
                        );
                    }

                    my @UserIDs = sort keys %MyServicesUserIDs;

                    push @{ $Notification{Data}->{RecipientAgents} }, @UserIDs;
                }
                elsif ( $Recipient eq 'AgentMyQueuesMyServices' ) {

                    # get subscribed users
                    my %MyQueuesUserIDs = map { $_ => 1 } $TicketObject->GetSubscribedUserIDsByQueueID(
                        QueueID => $Ticket{QueueID}
                    );

                    # get subscribed users
                    my %MyServicesUserIDs;
                    if ( $Ticket{ServiceID} ) {
                        %MyServicesUserIDs = map { $_ => 1 } $TicketObject->GetSubscribedUserIDsByServiceID(
                            ServiceID => $Ticket{ServiceID},
                        );
                    }

                    # combine both subscribed users list (this will also remove duplicates)
                    my %SubscribedUserIDs = ( %MyQueuesUserIDs, %MyServicesUserIDs );

                    for my $UserID ( sort keys %SubscribedUserIDs ) {
                        if ( !$MyQueuesUserIDs{$UserID} || !$MyServicesUserIDs{$UserID} ) {
                            delete $SubscribedUserIDs{$UserID};
                        }
                    }

                    my @UserIDs = sort keys %SubscribedUserIDs;

                    push @{ $Notification{Data}->{RecipientAgents} }, @UserIDs;
                }
                # KIX4OTRS-capeIT
                elsif ( $Recipient eq 'AgentLinkedPerson' ) {
                    push @{ $Notification{Data}->{RecipientAgents} }, @LinkedAgents;
                }
                # EO KIX4OTRS-capeIT
            }

            elsif ( $Recipient eq 'Customer' ) {

                # get old article for quoting
                my %Article = $TicketObject->ArticleLastCustomerArticle(
                    TicketID      => $Param{Data}->{TicketID},
                    DynamicFields => 0,
                );

                # get the raw ticket data
                my %Ticket = $TicketObject->TicketGet(
                    TicketID      => $Param{Data}->{TicketID},
                    DynamicFields => 0,
                );

                my %Recipient;

                # Check if we actually do have an article
                if ( defined $Article{SenderType} ) {
                    if ( $Article{SenderType} eq 'external' ) {
                        $Recipient{Email} = $Article{From};
                    }
                    else {
                        $Recipient{Email} = $Article{To};
                    }
                }
                $Recipient{Type} = 'Customer';

                # check if customer notifications should be send
                if (
                    $ConfigObject->Get('CustomerNotifyJustToRealCustomer')
                    && !$Ticket{ContactID}
                    )
                {
                    $Kernel::OM->Get('Kernel::System::Log')->Log(
                        Priority => 'info',
                        Message  => 'Send no customer notification because no customer is set!',
                    );
                    next RECIPIENT;
                }

                # get language and send recipient
                $Recipient{Language} = $ConfigObject->Get('DefaultLanguage') || 'en';

                if ( $Ticket{ContactID} ) {

                    my %Contact = $ContactObject->ContactGet(
                        ID => $Ticket{ContactID},
                    );

                    # join Recipient data with Contact data
                    %Recipient = ( %Recipient, %Contact );

                    # get user language
                    if ( $Contact{Language} ) {
                        $Recipient{Language} = $Contact{Language};
                    }

                    $Recipient{Realname} = $Contact{Firstname}.' '.$Contact{Lastname};
                }

                if ( !$Recipient{Realname} ) {
                    $Recipient{Realname} = $Article{From} || '';
                    $Recipient{Realname} =~ s/<.*>|\(.*\)|\"|;|,//g;
                    $Recipient{Realname} =~ s/( $)|(  $)//g;
                }

                push @RecipientUsers, \%Recipient;
            }
        }
    }

    # add recipient agents
    if ( IsArrayRefWithData( $Notification{Data}->{RecipientAgents} ) ) {
        push @RecipientUserIDs, @{ $Notification{Data}->{RecipientAgents} };
    }

    # hash to keep track which agents are already receiving this notification
    my %AgentUsed = map { $_ => 1 } @RecipientUserIDs;

    # get recipients by RecipientRoles
    if ( $Notification{Data}->{RecipientRoles} ) {

        RECIPIENT:
        for my $RoleID ( @{ $Notification{Data}->{RecipientRoles} } ) {

            my @RoleMemberList = $Kernel::OM->Get('Kernel::System::Role')->RoleUserList(
                RoleID => $RoleID,
            );

            ROLEMEMBER:
            for my $UserID ( sort @RoleMemberList ) {

                next ROLEMEMBER if $UserID == 1;
                next ROLEMEMBER if $AgentUsed{$UserID};

                $AgentUsed{$UserID} = 1;

                push @RecipientUserIDs, $UserID;
            }
        }
    }

    # get needed objects
    my $UserObject = $Kernel::OM->Get('Kernel::System::User');

    my %SkipRecipients;
    if ( IsArrayRefWithData( $Param{Data}->{SkipRecipients} ) ) {
        %SkipRecipients = map { $_ => 1 } @{ $Param{Data}->{SkipRecipients} };
    }

    # agent 1 should not receive notifications
    $SkipRecipients{'1'} = 1;

    # remove recipients should not receive a notification
    @RecipientUserIDs = grep { !$SkipRecipients{$_} } @RecipientUserIDs;

    # get valid users list
    my %ValidUsersList = $UserObject->UserList(
        Type          => 'Short',
        Valid         => 1,
        NoOutOfOffice => 0,
    );

    # remove invalid users
    @RecipientUserIDs = grep { $ValidUsersList{$_} } @RecipientUserIDs;

    # remove duplicated
    my %TempRecipientUserIDs = map { $_ => 1 } @RecipientUserIDs;
    @RecipientUserIDs = sort keys %TempRecipientUserIDs;

    # get time object
    my $TimeObject = $Kernel::OM->Get('Kernel::System::Time');

    # get current time-stamp
    my $Time = $TimeObject->SystemTime();

    # get all data for recipients as they should be needed by all notification transports
    RECIPIENT:
    for my $UserID (@RecipientUserIDs) {

        my %User = $UserObject->GetUserData(
            UserID => $UserID,
            Valid  => 1,
        );
        next RECIPIENT if !%User;

        # skip user that triggers the event (it should not be notified) but only if it is not
        #   a pre-calculated recipient
        if (
            !$ConfigObject->Get('AgentSelfNotifyOnAction')
            && $User{UserID} == $Param{UserID}
            && !$PrecalculatedUserIDs{ $Param{UserID} }
            )
        {
            next RECIPIENT;
        }

        # skip users out of the office if configured
        if ( !$Notification{Data}->{SendOnOutOfOffice} && $User{Preferences}->{OutOfOffice} ) {
            my $Start = sprintf(
                "%04d-%02d-%02d 00:00:00",
                $User{Preferences}->{OutOfOfficeStartYear}, $User{Preferences}->{OutOfOfficeStartMonth},
                $User{Preferences}->{OutOfOfficeStartDay}
            );
            my $TimeStart = $TimeObject->TimeStamp2SystemTime(
                String => $Start,
            );
            my $End = sprintf(
                "%04d-%02d-%02d 23:59:59",
                $User{Preferences}->{OutOfOfficeEndYear}, $User{Preferences}->{OutOfOfficeEndMonth},
                $User{Preferences}->{OutOfOfficeEndDay}
            );
            my $TimeEnd = $TimeObject->TimeStamp2SystemTime(
                String => $End,
            );

            next RECIPIENT if $TimeStart < $Time && $TimeEnd > $Time;
        }

        # skip users with out READ permissions
        my ($Granted) = $UserObject->CheckResourcePermission(
            UserID              => $User{UserID},
            Target              => '/tickets/' . $Ticket{TicketID},
            RequestedPermission => 'READ'
        );
        next RECIPIENT if !$Granted;

        # skip PostMasterUserID
        my $PostmasterUserID = $ConfigObject->Get('PostmasterUserID') || 1;
        next RECIPIENT if $User{UserID} == $PostmasterUserID;

        $User{Type} = 'Agent';

        push @RecipientUsers, \%User;
    }

    return @RecipientUsers;
}

sub _SendRecipientNotification {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(TicketID UserID Notification Recipient Event Transport TransportObject)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
        }
    }

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # check if the notification needs to be sent just one time per day
    if ( 
        IsArrayRefWithData($Param{Notification}->{Data}->{OncePerDay}) 
        && $Param{Notification}->{Data}->{OncePerDay}->[0]
        && $Param{Recipient}->{UserLogin} 
    ) {

        # get ticket history
        my @HistoryLines = $TicketObject->HistoryGet(
            TicketID => $Param{TicketID},
            UserID   => $Param{UserID},
        );

        # get last notification sent ticket history entry for this transport and this user
        my $LastNotificationHistory = first {
            $_->{HistoryType} eq 'SendAgentNotification'
                && $_->{Name} eq
                "\%\%$Param{Notification}->{Name}\%\%$Param{Recipient}->{UserLogin}\%\%$Param{Transport}"
        }
        reverse @HistoryLines;

        if ( $LastNotificationHistory && $LastNotificationHistory->{CreateTime} ) {

            # get time object
            my $TimeObject = $Kernel::OM->Get('Kernel::System::Time');

            # get last notification date
            my ( $Sec, $Min, $Hour, $Day, $Month, $Year, $WeekDay ) = $TimeObject->SystemTime2Date(
                SystemTime => $TimeObject->TimeStamp2SystemTime(
                    String => $LastNotificationHistory->{CreateTime},
                    )
            );

            # get current date
            my ( $CurrSec, $CurrMin, $CurrHour, $CurrDay, $CurrMonth, $CurrYear, $CurrWeekDay )
                = $TimeObject->SystemTime2Date(
                SystemTime => $TimeObject->SystemTime(),
                );

            # do not send the notification if it has been sent already today
            if (
                $CurrYear == $Year
                && $CurrMonth == $Month
                && $CurrDay == $Day
                )
            {
                return;
            }
        }
    }

    my $TransportObject = $Param{TransportObject};

    # send notification to each recipient
    my $Success = $TransportObject->SendNotification(
        TicketID              => $Param{TicketID},
        UserID                => $Param{UserID},
        Notification          => $Param{Notification},
        CustomerMessageParams => $Param{CustomerMessageParams},
        Recipient             => $Param{Recipient},
        Event                 => $Param{Event},
        Attachments           => $Param{Attachments},
    );

    return if !$Success;

    # create separate history entries if no article has been created
    if ( !IsArrayRefWithData($Param{Notification}->{Data}->{CreateArticle}) || !$Param{Notification}->{Data}->{CreateArticle}->[0] ) {
        if ( $Param{Recipient}->{Type} eq 'Agent'&& $Param{Recipient}->{UserLogin} ) {
            # write history
            $TicketObject->HistoryAdd(
                TicketID     => $Param{TicketID},
                HistoryType  => 'SendAgentNotification',
                Name         => "\%\%$Param{Notification}->{Name}\%\%$Param{Recipient}->{UserLogin}\%\%$Param{Transport}",
                CreateUserID => $Param{UserID},
            );
        }
        elsif ( $Param{Recipient}->{Type} eq 'Customer' && $Param{Recipient}->{Email} ) {        
            # write history
            $TicketObject->HistoryAdd(
                TicketID     => $Param{TicketID},
                HistoryType  => 'SendCustomerNotification',
                Name         => "\%\%$Param{Recipient}->{Email}",
                CreateUserID => $Param{UserID},
            );
        }
    }

    my %EventData = %{ $TransportObject->GetTransportEventData() };

    return 1 if !%EventData;

    if ( !$EventData{Event} || !$EventData{Data} || !$EventData{UserID} ) {

        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Could not trigger notification post send event",
        );

        return;
    }

    # ticket event
    $TicketObject->EventHandler(
        %EventData,
    );

    return 1;
}

sub _ArticleToUpdate {
    my ( $Self, %Param ) = @_;

    # check needed params
    for my $Needed (qw(ArticleID Channel UserIDs UserID)) {
        return if !$Param{$Needed};
    }

    # not update for User 1
    return 1 if $Param{UserID} eq 1;

    # get needed objects
    my $DBObject   = $Kernel::OM->Get('Kernel::System::DB');
    my $UserObject = $Kernel::OM->Get('Kernel::System::User');
    my $ContactObject = $Kernel::OM->Get('Kernel::System::Contact');

    # not update if its not a note article
    return 1 if $Param{Channel} ne 'note';

    my $NewTo = $Param{To} || '';
    for my $UserID ( sort keys %{ $Param{UserIDs} } ) {
        my %ContactData = $ContactObject->ContactGet(
            UserID => $UserID,
            Valid  => 1,
        );
        if ($NewTo) {
            $NewTo .= ', ';
        }
        $NewTo .= "$ContactData{Firstname} $ContactData{Lastname} <$ContactData{Email}>";
    }

    # not update if To is the same
    return 1 if !$NewTo;

    return if !$DBObject->Do(
        SQL  => 'UPDATE article SET a_to = ? WHERE id = ?',
        Bind => [ \$NewTo, \$Param{ArticleID} ],
    );

    return 1;
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
