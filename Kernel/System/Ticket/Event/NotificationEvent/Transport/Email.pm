# --
# Modified version of the work: Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Ticket::Event::NotificationEvent::Transport::Email;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);
use Kernel::Language qw(Translatable);

use base qw(Kernel::System::Ticket::Event::NotificationEvent::Transport::Base);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::Contact',
    'Kernel::System::Email',
    'Kernel::System::Log',
    'Kernel::System::Main',
    'Kernel::System::Queue',
    'Kernel::System::SystemAddress',
    'Kernel::System::Ticket',
    'Kernel::System::User',
    'Kernel::System::Web::Request',
    'Kernel::System::Crypt::PGP',
    'Kernel::System::Crypt::SMIME',
# NotificationEventX-capeIT
    'Kernel::System::DynamicField',
# EO NotificationEventX-capeIT
);

=head1 NAME

Kernel::System::Ticket::Event::NotificationEvent::Transport::Email - email transport layer

=head1 SYNOPSIS

Notification event transport layer.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create a notification transport object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new('');
    my $TransportObject = $Kernel::OM->Get('Kernel::System::Ticket::Event::NotificationEvent::Transport::Email');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub SendNotification {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(TicketID UserID Notification Recipient)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => 'Need $Needed!',
            );
            return;
        }
    }

    # cleanup event data
    $Self->{EventData} = undef;

    # get needed objects
    my $ConfigObject        = $Kernel::OM->Get('Kernel::Config');
    my $SystemAddressObject = $Kernel::OM->Get('Kernel::System::SystemAddress');
    my $LayoutObject        = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # get recipient data
    my %Recipient = %{ $Param{Recipient} };

    # Verify a customer have an email
    # check if recipient hash has DynamicField
    if (
        $Recipient{DynamicFieldName}
        && $Recipient{DynamicFieldType}
    ) {
        # get objects
        my $ContactObject = $Kernel::OM->Get('Kernel::System::Contact');
        my $TicketObject       = $Kernel::OM->Get('Kernel::System::Ticket');
        my $UserObject         = $Kernel::OM->Get('Kernel::System::User');

        # get ticket
        my %Ticket = $TicketObject->TicketGet(
            TicketID      => $Param{TicketID},
            DynamicFields => 1,
        );

        return 1 if ( !$Ticket{'DynamicField_' . $Recipient{DynamicFieldName}} );

        # get recipients from df
        my @DFRecipients = ();

        # process values from ticket data
        my @FieldRecipients = ();
        if (ref($Ticket{'DynamicField_' . $Recipient{DynamicFieldName}}) eq 'ARRAY') {
            @FieldRecipients = @{ $Ticket{'DynamicField_' . $Recipient{DynamicFieldName}} };
        } else {
            push(@FieldRecipients, $Ticket{'DynamicField_' . $Recipient{DynamicFieldName}});
        }
        FIELDRECIPIENT:
        for my $FieldRecipient (@FieldRecipients) {
            next FIELDRECIPIENT if !$FieldRecipient;

            my $AddressLine = '';
            # handle dynamic field by type
            if ($Recipient{DynamicFieldType} eq 'User') {
                my $ExistingUserID = $Kernel::OM->('Kernel::System::User')->UserLookup(
                    UserLogin => $FieldRecipient,
                );
                my %UserContactData = $ContactObject->ContactGet(
                    UserID => $ExistingUserID,
                    Valid  => 1,
                );
                next FIELDRECIPIENT if !$UserContactData{Email};
                $AddressLine = $UserContactData{Email};
            } elsif ($Recipient{DynamicFieldType} eq 'Contact') {
                my %Contact = $ContactObject->ContactGet(
                    ID => $FieldRecipient,
                );
                next FIELDRECIPIENT if !$Contact{Email};
                $AddressLine = $Contact{Email};
            } else {
                $AddressLine = $FieldRecipient;
            }

            # generate recipient
            my %DFRecipient = (
                Realname  => '',
                UserEmail => $AddressLine,
                Type      => $Recipient{Type},
            );

            # check recipients
            if ( $DFRecipient{UserEmail} && $DFRecipient{UserEmail} =~ /@/ ) {
                push (@DFRecipients, \%DFRecipient);
            }
        }

        # handle recipients
        for my $DFRecipient (@DFRecipients) {
            $Self->SendNotification(
                TicketID              => $Param{TicketID},
                UserID                => $Param{UserID},
                Notification          => $Param{Notification},
                CustomerMessageParams => $Param{CustomerMessageParams},
                Recipient             => $DFRecipient,
                Event                 => $Param{Event},
                Attachments           => $Param{Attachments},
            );
        }

        # done
        return 1;
    }
    # EO NotificationEventX-capeIT

    # Verify a customer have an email
    if ( $Recipient{Type} eq 'Customer' ) {
        if ( !$Recipient{Email} && $Recipient{ID} ) {
            my %Contact = $Kernel::OM->Get('Kernel::System::Contact')->ContactGet(
                ID => $Recipient{ID},
            );

            if ( !$Contact{Email} ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'info',
                    Message  => "Send no customer notification because of missing "
                        . "customer email (ContactID=$Contact{ContactID})!",
                );
                return;
            }

            # Set calculated email.
            $Recipient{UserEmail} = $Contact{Email};
        }
        else {
            # prepare UserEmail to be compatible with agent users
            $Recipient{UserEmail} = $Recipient{Email};
        }
    }

    return if !$Recipient{UserEmail};

    return if $Recipient{UserEmail} !~ /@/;

    my $IsLocalAddress = $Kernel::OM->Get('Kernel::System::SystemAddress')->SystemAddressIsLocalAddress(
        Address => $Recipient{UserEmail},
    );

    return if $IsLocalAddress;

    # create new array to prevent attachment growth (see bug#5114)
    my @Attachments = @{ $Param{Attachments} };

    my %Notification = %{ $Param{Notification} };

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    if ( $Param{Notification}->{ContentType} && $Param{Notification}->{ContentType} eq 'text/html' ) {

        # Get configured template with fallback to Default.
        my $EmailTemplate = $Param{Notification}->{Data}->{TransportEmailTemplate}->[0] || 'Default';

        my $Home        = $Kernel::OM->Get('Kernel::Config')->Get('Home');
        my $TemplateDir = "$Home/Kernel/Output/HTML/Templates/Notification/Email";

        if ( !-r "$TemplateDir/$EmailTemplate.tt" ) {
            $EmailTemplate = 'Default';
        }

        # generate HTML
        $Notification{Body} = $LayoutObject->Output(
            TemplateFile => "Notification/Email/$EmailTemplate",
            Data         => {
                TicketID => $Param{TicketID},
                Body     => $Notification{Body},
                Subject  => $Notification{Subject},
            },
        );
    }

    if (
        $Notification{Data}->{RecipientAttachmentDF}
        && ref($Notification{Data}->{RecipientAttachmentDF}) eq 'ARRAY'
    ) {
        # get objects
        my $DFAttachmentObject = $Kernel::OM->Get('Kernel::System::DFAttachment');
        my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');

        # get ticket
        my %Ticket = $TicketObject->TicketGet(
            TicketID      => $Param{TicketID},
            DynamicFields => 1,
        );

        my @FieldAttachments = ();
        for my $ID ( sort( @{ $Notification{Data}->{RecipientAttachmentDF} } ) ) {
            my $DynamicField = $DynamicFieldObject->DynamicFieldGet(
                ID => $ID,
            );
            # gather values from ticket data
            if (ref($Ticket{'DynamicField_' . $DynamicField->{Name}}) eq 'ARRAY') {
                push(@FieldAttachments, @{ $Ticket{'DynamicField_' . $DynamicField->{Name}} });
            } else {
                push(@FieldAttachments, $Ticket{'DynamicField_' . $DynamicField->{Name}});
            }
        }
        ATTACHMENT:
        for my $Attachment ( @FieldAttachments ) {
            # read file from virtual fs
            my %File = $Kernel::OM->Get('Kernel::System::DFAttachment')->Read(
                Filename        => $Attachment,
                Mode            => 'binary',
                DisableWarnings => 1,
            );
            next ATTACHMENT if ( !%File );

            # prepare attachment data
            my %Data = (
                'Filename'           => $File{Preferences}->{Filename},
                'Content'            => ${$File{Content}},
                'ContentType'        => $File{Preferences}->{ContentType},
                'ContentID'          => '',
                'ContentAlternative' => '',
                'Filesize'           => $File{Preferences}->{Filesize},
                'FilesizeRaw'        => $File{Preferences}->{FilesizeRaw},
                'Disposition'        => 'attachment',
            );
            # add attachment
            push( @{ $Param{Attachments} }, \%Data );
        }

    }

    # send notification
    # prepare subject
    if (
        defined( $Notification{Data}->{RecipientSubject} )
        && defined( $Notification{Data}->{RecipientSubject}->[0] )
        && !$Notification{Data}->{RecipientSubject}->[0]
    ) {
        my $TicketNumber = $TicketObject->TicketNumberLookup(
            TicketID => $Param{TicketID},
        );

        $Notification{Subject} = $TicketObject->TicketSubjectClean(
            TicketNumber => $TicketNumber,
            Subject      => $Notification{Subject},
            Size         => 0,
        );
    }
    # EO NotificationEventX-capeIT

    # send notification
    if ( $Recipient{Type} eq 'Agent' ) {

        my $FromEmail = $ConfigObject->Get('NotificationSenderEmail');

        # send notification
        my $From = $ConfigObject->Get('NotificationSenderName') . ' <'
            . $FromEmail . '>';

        # security part
        my $SecurityOptions = $Self->SecurityOptionsGet( %Param, FromEmail => $FromEmail );
        return if !$SecurityOptions;

        my $Sent = $Kernel::OM->Get('Kernel::System::Email')->Send(
            From       => $From,
            To         => $Recipient{UserEmail},
            Subject    => $Notification{Subject},
            MimeType   => $Notification{ContentType},
            Type       => $Notification{ContentType},
            Charset    => 'utf-8',
            Body       => $Notification{Body},
            Loop       => 1,
            Attachment => $Param{Attachments},
            %{$SecurityOptions},
        );

        if ( !$Sent ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "'$Notification{Name}' notification could not be sent to agent '$Recipient{UserEmail} ",
            );

            return;
        }

        if ( IsArrayRefWithData($Param{Notification}->{Data}->{CreateArticle}) && $Param{Notification}->{Data}->{CreateArticle}->[0] ) {
            # create an article if requested
            my $ArticleID = $Self->CreateArticle(
                %Param,
                %{$SecurityOptions},
                Recipient => \%Recipient,
                Address   => {
                    RealName => $ConfigObject->Get('NotificationSenderName'),
                    Email    => $FromEmail,
                }
            );
        }

        # log event
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'info',
            Message  => "Sent agent '$Notification{Name}' notification to '$Recipient{UserEmail}'.",
        );

        # set event data
        $Self->{EventData} = {
            Event => 'ArticleAgentNotification',
            Data  => {
                TicketID => $Param{TicketID},

                # KIX4OTRS-capeIT
                # out of office-substitute notification
                RecipientMail => $Recipient{UserEmail},
                Notification  => \%Notification,
                Attachment    => $Param{Attachments},

                # EO KIX4OTRS-capeIT
            },
            UserID => $Param{UserID},
        };
    }
    else {
        # get queue object
        my $QueueObject = $Kernel::OM->Get('Kernel::System::Queue');

        # get article
        my %Article = $TicketObject->ArticleLastCustomerArticle(
            TicketID      => $Param{TicketID},
            DynamicFields => 0,
        );

        # set "From" address from Article if exist, otherwise use ticket information, see bug# 9035
        my %Ticket = $TicketObject->TicketGet(
            TicketID => $Param{TicketID},
        );
        my $QueueID = $Ticket{QueueID};
        
        # get queue
        my %Queue = $QueueObject->QueueGet(
            ID => $QueueID,
        );

        my %Address = $Kernel::OM->Get('Kernel::System::Queue')->GetSystemAddress( 
            QueueID => $QueueID
        );

        # security part
        my $SecurityOptions = $Self->SecurityOptionsGet(
            %Param,
            FromEmail => $Address{Email},
            Queue     => \%Queue
        );
        return if !$SecurityOptions;

        my $Sent = $Kernel::OM->Get('Kernel::System::Email')->Send(
            From       => $Address{Email},
            To         => $Recipient{UserEmail},
            Subject    => $Notification{Subject},
            MimeType   => $Notification{ContentType},
            Type       => $Notification{ContentType},
            Charset    => 'utf-8',
            Body       => $Notification{Body},
            Loop       => 1,
            Attachment => $Param{Attachments},
            %{$SecurityOptions},
        );

        if ( !$Sent ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "'$Notification{Name}' notification could not be sent to customer '$Recipient{UserEmail} ",
            );

            return;
        }

        my $ArticleID;
        if ( IsArrayRefWithData($Param{Notification}->{Data}->{CreateArticle}) && $Param{Notification}->{Data}->{CreateArticle}->[0] ) {
            # create an article if requested
            $ArticleID = $Self->CreateArticle(
                %Param,
                %{$SecurityOptions},
                Recipient => \%Recipient,
                Address   => \%Address,
            );
        }

        # log event
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'info',
            Message  => "Sent customer '$Notification{Name}' notification to '$Recipient{UserEmail}'.",
        );

        # set event data
        $Self->{EventData} = {
            Event => 'ArticleCustomerNotification',
            Data  => {
                TicketID  => $Param{TicketID},
                ArticleID => $ArticleID,
            },
            UserID => $Param{UserID},
        };
    }

    return 1;
}

sub GetTransportRecipients {
    my ( $Self, %Param ) = @_;

    for my $Needed (qw(Notification)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed",
            );
        }
    }

    my @Recipients;

    # get recipients by RecipientEmail
    if ( $Param{Notification}->{Data}->{RecipientEmail} ) {
        if ( $Param{Notification}->{Data}->{RecipientEmail}->[0] ) {
            my %Recipient;
            $Recipient{Realname}  = '';
            $Recipient{Type}      = 'Customer';
            $Recipient{Email} = $Param{Notification}->{Data}->{RecipientEmail}->[0];

            # check if we have a specified channel
            if ( $Param{Notification}->{Data}->{ChannelID} ) {
                $Recipient{NotificationChannel} = $Kernel::OM->Get('Kernel::System::Channel')->ChannelLookup(
                    ID => $Param{Notification}->{Data}->{ChannelID}->[0]
                ) || 'email';
            }

            # check recipients
            if ( $Recipient{Email} && $Recipient{Email} =~ /@/ ) {
                push @Recipients, \%Recipient;
            }
        }
    }

# NotificationEventX-capeIT
    # get object
    my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');

    # get dynamic fields
    my $DynamicFieldList = $DynamicFieldObject->DynamicFieldListGet(
        Valid      => 1,
        ObjectType => ['Ticket'],
    );

    # get dynamic fields config
    my %DynamicFieldConfig;
    for my $DynamicField (@{$DynamicFieldList}) {
        $DynamicFieldConfig{ $DynamicField->{ID} } = \%{$DynamicField};
    }

    # get recipients by RecipientAgentDF
    if (
        $Param{Notification}->{Data}->{RecipientAgentDF}
        && ref($Param{Notification}->{Data}->{RecipientAgentDF}) eq 'ARRAY'
    ) {
        FIELD:
        for my $ID ( sort( @{ $Param{Notification}->{Data}->{RecipientAgentDF} } ) ) {
            next FIELD if !$DynamicFieldConfig{$ID};

            # generate recipient
            my %Recipient = (
                DynamicFieldName => $DynamicFieldConfig{$ID}->{Name},
                DynamicFieldType => $DynamicFieldConfig{$ID}->{FieldType},
                Type             => 'Agent',
            );
            push (@Recipients, \%Recipient);
        }
    }

    # get recipients by RecipientCustomerDF
    if (
        $Param{Notification}->{Data}->{RecipientCustomerDF}
        && ref($Param{Notification}->{Data}->{RecipientCustomerDF}) eq 'ARRAY'
    ) {
        FIELD:
        for my $ID ( sort( @{ $Param{Notification}->{Data}->{RecipientCustomerDF} } ) ) {
            next FIELD if !$DynamicFieldConfig{$ID};

            # generate recipient
            my %Recipient = (
                DynamicFieldName => $DynamicFieldConfig{$ID}->{Name},
                DynamicFieldType => $DynamicFieldConfig{$ID}->{FieldType},
                Type             => 'Customer',
            );
            push (@Recipients, \%Recipient);
        }
    }
# EO NotificationEventX-capeIT

    return @Recipients;
}

sub IsUsable {
    my ( $Self, %Param ) = @_;

    # define if this transport is usable on
    # this specific moment
    return 1;
}

sub SecurityOptionsGet {
    my ( $Self, %Param ) = @_;

    # Verify security options are enabled.
    my $EnableSecuritySettings = $Param{Notification}->{Data}->{EmailSecuritySettings}->[0] || '';

    # Return empty hash ref to continue with email sending (without security options).
    return {} if !$EnableSecuritySettings;

    # Verify if the notification has to be signed or encrypted
    my $SignEncryptNotification = $Param{Notification}->{Data}->{EmailSigningCrypting}->[0] || '';

    # Return empty hash ref to continue with email sending (without security options).
    return {} if !$SignEncryptNotification;

    my %Queue = %{ $Param{Queue} || {} };

    # Define who is going to be the sender (from the given parameters)
    my $NotificationSenderEmail = $Param{FromEmail};

    # Define security options container
    my %SecurityOptions;
    my @SignKeys;
    my @EncryptKeys;
    my $KeyField;
    my $Method;
    my $Subtype = 'Detached';

    # Get private and public keys for the given backend (PGP or SMIME)
    if ( $SignEncryptNotification =~ /^PGP/i ) {
        @SignKeys = $Kernel::OM->Get('Kernel::System::Crypt::PGP')->PrivateKeySearch(
            Search => $NotificationSenderEmail,
        );

        # take just valid keys
        @SignKeys = grep { $_->{Status} eq 'good' } @SignKeys;

        # get public keys
        @EncryptKeys = $Kernel::OM->Get('Kernel::System::Crypt::PGP')->PublicKeySearch(
            Search => $Param{Recipient}->{UserEmail},
        );

        # Get PGP method (Detached or In-line).
        if ( !$Kernel::OM->Get('Kernel::Output::HTML::Layout')->{BrowserRichText} ) {
            $Subtype = $Kernel::OM->Get('Kernel::Config')->Get('PGP::Method') || 'Detached';
        }
        $Method   = 'PGP';
        $KeyField = 'Key';
    }
    elsif ( $SignEncryptNotification =~ /^SMIME/i ) {
        @SignKeys = $Kernel::OM->Get('Kernel::System::Crypt::SMIME')->PrivateSearch(
            Search => $NotificationSenderEmail,
        );

        @EncryptKeys = $Kernel::OM->Get('Kernel::System::Crypt::SMIME')->CertificateSearch(
            Search => $Param{Recipient}->{UserEmail},
        );

        $Method   = 'SMIME';
        $KeyField = 'Filename';
    }

    # Initialize sign key container
    my %SignKey;

    # Initialize crypt key container
    my %EncryptKey;

    # Get default signing key from the queue (if applies).
    if ( $Queue{DefaultSignKey} ) {

        my $DefaultSignKey;

        # Convert legacy stored default sign keys.
        if ( $Queue{DefaultSignKey} =~ m{ (?: Inline|Detached ) }msx ) {
            my ( $Type, $SubType, $Key ) = split /::/, $Queue{DefaultSignKey};
            $DefaultSignKey = $Key;
        }
        else {
            my ( $Type, $Key ) = split /::/, $Queue{DefaultSignKey};
            $DefaultSignKey = $Key;
        }

        if ( grep { $_->{$KeyField} eq $DefaultSignKey } @SignKeys ) {
            $SignKey{$KeyField} = $DefaultSignKey;
        }
    }

    # Otherwise take the first signing key available.
    if ( !%SignKey ) {
        SIGNKEY:
        for my $SignKey (@SignKeys) {
            %SignKey = %{$SignKey};
            last SIGNKEY;
        }
    }

    # Also take the first encryption key available.
    CRYPTKEY:
    for my $EncryptKey (@EncryptKeys) {
        %EncryptKey = %{$EncryptKey};
        last CRYPTKEY;
    }

    my $OnMissingSigningKeys = $Param{Notification}->{Data}->{EmailMissingSigningKeys}->[0] || '';

    # Add options to sign the notification
    if ( $SignEncryptNotification =~ /Sign/i ) {

        # Take an action if there are missing signing keys.
        if ( !IsHashRefWithData( \%SignKey ) ) {

            my $Message
                = "Could not sign notification '$Param{Notification}->{Name}' due to missing $Method sign key for '$NotificationSenderEmail'";

            if ( $OnMissingSigningKeys eq 'Skip' ) {

                # Log skipping notification (return nothing to stop email sending).
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'notice',
                    Message  => $Message . ', skipping notification distribution!',
                );

                return;
            }

            # Log sending unsigned notification.
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'notice',
                Message  => $Message . ', sending unsigned!',
            );
        }

        # Add signature option if a sign key is available
        else {
            $SecurityOptions{Sign} = {
                Type    => $Method,
                SubType => $Subtype,
                Key     => $SignKey{$KeyField},
            };
        }
    }

    my $OnMissingEncryptionKeys = $Param{Notification}->{Data}->{EmailMissingCryptingKeys}->[0] || '';

    # Add options to encrypt the notification
    if ( $SignEncryptNotification =~ /Crypt/i ) {

        # Take an action if there are missing encryption keys.
        if ( !IsHashRefWithData( \%EncryptKey ) ) {

            my $Message
                = "Could not encrypt notification '$Param{Notification}->{Name}' due to missing $Method encryption key for '$Param{Recipient}->{UserEmail}'";

            if ( $OnMissingEncryptionKeys eq 'Skip' ) {

                # Log skipping notification (return nothing to stop email sending).
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'notice',
                    Message  => $Message . ', skipping notification distribution!',
                );

                return;
            }

            # Log sending unencrypted notification.
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'notice',
                Message  => $Message . ', sending unencrypted!',
            );
        }

        # Add encrypt option if a encrypt key is available
        else {
            $SecurityOptions{Crypt} = {
                Type    => $Method,
                SubType => $Subtype,
                Key     => $EncryptKey{$KeyField},
            };
        }
    }

    return \%SecurityOptions;

}

sub CreateArticle {
    my ( $Self, %Param ) = @_;

    for my $Needed (qw(Address Notification Recipient TicketID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed",
            );
        }
    }

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    my $Channel = 'note';
    if ( IsArrayRefWithData( $Param{Notification}->{Data}->{Channel} ) ) {
        $Channel = $Param{Notification}->{Data}->{Channel}->[0],
    }

    my $VisibleForCustomer = 0;
    if ( IsArrayRefWithData( $Param{Notification}->{Data}->{VisibleForCustomer} ) ) {
        $VisibleForCustomer = $Param{Notification}->{Data}->{VisibleForCustomer}->[0],
    }

    my $ArticleID = $TicketObject->ArticleCreate(
        Channel        => $Channel,
        CustomerVisible => $VisibleForCustomer,
        SenderType     => 'system',
        TicketID       => $Param{TicketID},
        HistoryType    => $Param{Recipient}->{Type} eq 'Agent' ? 'SendAgentNotification' : 'SendCustomerNotification',
        HistoryComment => $Param{Recipient}->{Type} eq 'Agent' ? "\%\%$Param{Notification}->{Name}\%\%$Param{Recipient}->{UserLogin}\%\%Email" : "\%\%$Param{Recipient}->{UserEmail}",
        From           => "$Param{Address}->{RealName} <$Param{Address}->{Email}>",
        To             => $Param{Recipient}->{UserEmail},
        Subject        => $Param{Notification}->{Subject},
        Body           => $Param{Notification}->{Body},
        MimeType       => $Param{Notification}->{ContentType},
        Type           => $Param{Notification}->{ContentType},
        Charset        => 'utf-8',
        UserID         => $Param{UserID},
        Loop           => 1,
        Attachment     => $Param{Attachments},
        %{$Param{SecurityOptions}},
    );

    if ( !$ArticleID ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "'$Param{Notification}->{Name}' notification could not be sent to customer '$Param{Recipient}->{UserEmail} ",
        );

        return;
    }

    # if required mark new article as seen for all users
    if ( $Param{Notification}->{Data}->{MarkAsSeenForAgents} ) {
        my %UserList = $Kernel::OM->Get('Kernel::System::User')->UserList();
        for my $UserID ( keys %UserList ) {
            $TicketObject->ArticleFlagSet(
                ArticleID => $ArticleID,
                Key       => 'Seen',
                Value     => 1,
                UserID    => $UserID,
            );
        }
    }

    return $ArticleID;
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
