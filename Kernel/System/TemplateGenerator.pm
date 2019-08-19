# --
# Modified version of the work: Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::TemplateGenerator;

use strict;
use warnings;

use Kernel::Language;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::AutoResponse',
    'Kernel::System::Contact',
    'Kernel::System::DynamicField',
    'Kernel::System::DynamicField::Backend',
    'Kernel::System::Encode',
    'Kernel::System::HTMLUtils',
    'Kernel::System::Log',
    'Kernel::System::Queue',
    'Kernel::System::Salutation',
    'Kernel::System::Signature',
    'Kernel::System::StandardTemplate',
    'Kernel::System::SystemAddress',
    'Kernel::System::Ticket',
    'Kernel::System::User',
    'Kernel::Output::HTML::Layout',
    'Kernel::System::JSON',

);

=head1 NAME

Kernel::System::TemplateGenerator - signature lib

=head1 SYNOPSIS

All signature functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $TemplateGeneratorObject = $Kernel::OM->Get('Kernel::System::TemplateGenerator');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{RichText} = $Kernel::OM->Get('Kernel::Config')->Get('Frontend::RichText');

    # KIX4OTRS-capeIT
    $Self->{UserLanguage} = $Param{UserLanguage};
    # EO KIX4OTRS-capeIT

    return $Self;
}

=item Sender()

generate sender address (FROM string) for emails

    my $Sender = $TemplateGeneratorObject->Sender(
        QueueID    => 123,
        UserID     => 123,
    );

returns:

    John Doe at Super Support <service@example.com>

and it returns the quoted real name if necessary

    "John Doe, Support" <service@example.tld>

=cut

sub Sender {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw( UserID QueueID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get sender attributes
    my %Address = $Kernel::OM->Get('Kernel::System::Queue')->GetSystemAddress(
        QueueID => $Param{QueueID},
    );

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # check config for agent real name
    my $UseAgentRealName = $ConfigObject->Get('Ticket::DefineEmailFrom');
    if ( $UseAgentRealName && $UseAgentRealName =~ /^(AgentName|AgentNameSystemAddressName)$/ ) {

        # get data from current agent
        my %UserData = $Kernel::OM->Get('Kernel::System::User')->GetUserData(
            UserID        => $Param{UserID},
            NoOutOfOffice => 1,
        );

        # set real name with user name
        if ( $UseAgentRealName eq 'AgentName' ) {

            # check for user data
            if ( $UserData{UserLastname} && $UserData{UserFirstname} ) {

                # rewrite RealName
                $Address{RealName} = "$UserData{UserFirstname} $UserData{UserLastname}";
            }
        }

        # set real name with user name
        if ( $UseAgentRealName eq 'AgentNameSystemAddressName' ) {

            # check for user data
            if ( $UserData{UserLastname} && $UserData{UserFirstname} ) {

                # rewrite RealName
                my $Separator = ' ' . $ConfigObject->Get('Ticket::DefineEmailFromSeparator')
                    || '';
                $Address{RealName} = $UserData{UserFirstname} . ' ' . $UserData{UserLastname}
                    . $Separator . ' ' . $Address{RealName};
            }
        }
    }

    # prepare realname quote
    if ( $Address{RealName} =~ /([.]|,|@|\(|\)|:)/ && $Address{RealName} !~ /^("|')/ ) {
        $Address{RealName} =~ s/"//g;    # remove any quotes that are already present
        $Address{RealName} = '"' . $Address{RealName} . '"';
    }
    my $Sender = "$Address{RealName} <$Address{Email}>";

    return $Sender;
}

=item Template()

generate template

    my $Template = $TemplateGeneratorObject->Template(
        TemplateID => 123
        TicketID   => 123,                  # Optional
        Data       => $ArticleHashRef,      # Optional
        UserID     => 123,
    );

Returns:

    $Template =>  'Some text';

=cut

sub Template {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(TemplateID UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    my %Template = $Kernel::OM->Get('Kernel::System::StandardTemplate')->StandardTemplateGet(
        ID => $Param{TemplateID},
    );

    # do text/plain to text/html convert
    if (
        $Self->{RichText}
        && $Template{ContentType} =~ /text\/plain/i
        && $Template{Template}
        )
    {
        $Template{ContentType} = 'text/html';
        $Template{Template}    = $Kernel::OM->Get('Kernel::System::HTMLUtils')->ToHTML(
            String => $Template{Template},
        );
    }

    # do text/html to text/plain convert
    if (
        !$Self->{RichText}
        && $Template{ContentType} =~ /text\/html/i
        && $Template{Template}
        )
    {
        $Template{ContentType} = 'text/plain';
        $Template{Template}    = $Kernel::OM->Get('Kernel::System::HTMLUtils')->ToAscii(
            String => $Template{Template},
        );
    }

    # get user language
    my $Language;
    if ( defined $Param{TicketID} ) {

        # get ticket data
        my %Ticket = $Kernel::OM->Get('Kernel::System::Ticket')->TicketGet(
            TicketID => $Param{TicketID},
        );

        # get recipient
        my %User = $Kernel::OM->Get('Kernel::System::Contact')->ContactGet(
            ID => $Ticket{ContactID},
        );
        $Language = $User{UserLanguage};
    }

    # if customer language is not defined, set default language
    $Language //= $Kernel::OM->Get('Kernel::Config')->Get('DefaultLanguage') || 'en';

    # replace place holder stuff
    my @ListOfUnSupportedTag = qw/KIX_AGENT_SUBJECT KIX_AGENT_BODY KIX_CUSTOMER_BODY KIX_CUSTOMER_SUBJECT/;

    my $TemplateText = $Self->_RemoveUnSupportedTag(
        Text => $Template{Template} || '',
        ListOfUnSupportedTag => \@ListOfUnSupportedTag,
    );

    # replace place holder stuff
    $TemplateText = $Self->_Replace(
        RichText => $Self->{RichText},
        Text     => $TemplateText || '',
        TicketID => $Param{TicketID} || '',
        Data     => $Param{Data} || {},
        UserID   => $Param{UserID},
        Language => $Language,
    );

    return $TemplateText;
}

=item Attributes()

generate attributes

    my %Attributes = $TemplateGeneratorObject->Attributes(
        TicketID   => 123,
        ArticleID  => 123,
        ResponseID => 123
        UserID     => 123,
        Action     => 'Forward', # Possible values are Reply and Forward, Reply is default.
    );

returns
    StandardResponse
    Salutation
    Signature

=cut

sub Attributes {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(TicketID Data UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # get queue
    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Param{TicketID},
        DynamicFields => 0,
    );

    # prepare subject ...
    $Param{Data}->{Subject} = $TicketObject->TicketSubjectBuild(
        TicketNumber => $Ticket{TicketNumber},
        Subject      => $Param{Data}->{Subject} || '',
        Action       => $Param{Action} || '',
    );

    # get sender address
    $Param{Data}->{From} = $Self->Sender(
        QueueID => $Ticket{QueueID},
        UserID  => $Param{UserID},
    );

    return %{ $Param{Data} };
}

=item AutoResponse()

generate response

AutoResponse
    TicketID
        Owner
        Responsible
        CUSTOMER_DATA
    ArticleID
        CUSTOMER_SUBJECT
        CUSTOMER_EMAIL
    UserID

    To
    Cc
    Bcc
    Subject
    Body
    ContentType

    my %AutoResponse = $TemplateGeneratorObject->AutoResponse(
        TicketID         => 123,
        OrigHeader       => {},
        AutoResponseType => 'auto reply',
        UserID           => 123,
    );

=cut

sub AutoResponse {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(TicketID AutoResponseType OrigHeader UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # get ticket
    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Param{TicketID},
        DynamicFields => 0,
    );

    # get auto default responses
    my %AutoResponse = $Kernel::OM->Get('Kernel::System::AutoResponse')->AutoResponseGetByTypeQueueID(
        QueueID => $Ticket{QueueID},
        Type    => $Param{AutoResponseType},
    );

    return if !%AutoResponse;

    # get old article for quoting
    my %Article = $TicketObject->ArticleLastCustomerArticle(
        TicketID      => $Param{TicketID},
        DynamicFields => 0,
    );

    for (qw(From To Cc Subject Body)) {
        if ( !$Param{OrigHeader}->{$_} ) {
            $Param{OrigHeader}->{$_} = $Article{$_} || '';
        }
        chomp $Param{OrigHeader}->{$_};
    }

    # format body (only if longer than 86 chars)
    if ( $Param{OrigHeader}->{Body} ) {
        if ( length $Param{OrigHeader}->{Body} > 86 ) {
            my @Lines = split /\n/, $Param{OrigHeader}->{Body};
            LINE:
            for my $Line (@Lines) {
                my $LineWrapped = $Line =~ s/(^>.+|.{4,86})(?:\s|\z)/$1\n/gm;

                next LINE if $LineWrapped;

                # if the regex does not match then we need
                # to add the missing new line of the split
                # else we will lose e.g. empty lines of the body.
                # (bug#10679)
                $Line .= "\n";
            }
            $Param{OrigHeader}->{Body} = join '', @Lines;
        }
    }

    # fill up required attributes
    for (qw(Subject Body)) {
        if ( !$Param{OrigHeader}->{$_} ) {
            $Param{OrigHeader}->{$_} = "No $_";
        }
    }

    # get recipient
    my %Contact = $Kernel::OM->Get('Kernel::System::Contact')->ContactGet(
        ID => $Ticket{ContactID},
    );

    # get user language
    my $Language = $Contact{Language} || $Kernel::OM->Get('Kernel::Config')->Get('DefaultLanguage') || 'en';

    # do text/plain to text/html convert
    if ( $Self->{RichText} && $AutoResponse{ContentType} =~ /text\/plain/i ) {
        $AutoResponse{ContentType} = 'text/html';
        $AutoResponse{Text}        = $Kernel::OM->Get('Kernel::System::HTMLUtils')->ToHTML(
            String => $AutoResponse{Text},
        );
    }

    # do text/html to text/plain convert
    if ( !$Self->{RichText} && $AutoResponse{ContentType} =~ /text\/html/i ) {
        $AutoResponse{ContentType} = 'text/plain';
        $AutoResponse{Text}        = $Kernel::OM->Get('Kernel::System::HTMLUtils')->ToAscii(
            String => $AutoResponse{Text},
        );
    }

    # replace place holder stuff
    $AutoResponse{Text} = $Self->_Replace(
        RichText => $Self->{RichText},
        Text     => $AutoResponse{Text},
        Data     => {
            %{ $Param{OrigHeader} },
            From => $Param{OrigHeader}->{To},
            To   => $Param{OrigHeader}->{From},
        },
        TicketID => $Param{TicketID},
        UserID   => $Param{UserID},
        Language => $Language,
    );
    $AutoResponse{Subject} = $Self->_Replace(
        RichText => 0,
        Text     => $AutoResponse{Subject},
        Data     => {
            %{ $Param{OrigHeader} },
            From => $Param{OrigHeader}->{To},
            To   => $Param{OrigHeader}->{From},
        },
        TicketID => $Param{TicketID},
        UserID   => $Param{UserID},
        Language => $Language,
    );

    $AutoResponse{Subject} = $TicketObject->TicketSubjectBuild(
        TicketNumber => $Ticket{TicketNumber},
        Subject      => $AutoResponse{Subject},
        Type         => 'New',
        NoCleanup    => 1,
    );

    # get sender attributes based on auto response type
    if ( $AutoResponse{SystemAddressID} ) {

        my %Address = $Kernel::OM->Get('Kernel::System::SystemAddress')->SystemAddressGet(
            ID => $AutoResponse{SystemAddressID},
        );

        $AutoResponse{SenderAddress}  = $Address{Name};
        $AutoResponse{SenderRealname} = $Address{Realname};
    }

    # get sender attributes based on queue
    else {

        my %Address = $Kernel::OM->Get('Kernel::System::Queue')->GetSystemAddress(
            QueueID => $Ticket{QueueID},
        );

        $AutoResponse{SenderAddress}  = $Address{Email};
        $AutoResponse{SenderRealname} = $Address{RealName};
    }

    # add urls and verify to be full html document
    if ( $Self->{RichText} ) {

        $AutoResponse{Text} = $Kernel::OM->Get('Kernel::System::HTMLUtils')->LinkQuote(
            String => $AutoResponse{Text},
        );

        $AutoResponse{Text} = $Kernel::OM->Get('Kernel::System::HTMLUtils')->DocumentComplete(
            Charset => 'utf-8',
            String  => $AutoResponse{Text},
        );
    }

    return %AutoResponse;
}

=item NotificationEvent()

replace all KIX placeholders in the notification body and subject

    my %NotificationEvent = $TemplateGeneratorObject->NotificationEvent(
        TicketID              => 123,
        Recipient             => $UserDataHashRef,          # Agent or Customer data get result
        Notification          => $NotificationDataHashRef,
        CustomerMessageParams => $ArticleHashRef,           # optional
        UserID                => 123,
    );

=cut

sub NotificationEvent {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(TicketID Notification Recipient UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    if ( !IsHashRefWithData( $Param{Notification} ) ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "Notification is invalid!",
        );
        return;
    }

    my %Notification = %{ $Param{Notification} };

    # exchanging original reference prevent it to grow up
    if ( ref $Param{CustomerMessageParams} && ref $Param{CustomerMessageParams} eq 'HASH' ) {
        my %LocalCustomerMessageParams = %{ $Param{CustomerMessageParams} };
        $Param{CustomerMessageParams} = \%LocalCustomerMessageParams;
    }

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # get ticket
    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Param{TicketID},
        DynamicFields => 0,
    );

    # get last article from customer
    my %Article = $TicketObject->ArticleLastCustomerArticle(
        TicketID      => $Param{TicketID},
        DynamicFields => 0,
    );

    # get last article from agent
    my @ArticleBoxAgent = $TicketObject->ArticleGet(
        TicketID      => $Param{TicketID},
        UserID        => $Param{UserID},
        DynamicFields => 0,
    );

    my %ArticleAgent;

    ARTICLE:
    for my $Article ( reverse @ArticleBoxAgent ) {

        next ARTICLE if $Article->{SenderType} ne 'agent';

        %ArticleAgent = %{$Article};

        last ARTICLE;
    }

    # get  HTMLUtils object
    my $HTMLUtilsObject = $Kernel::OM->Get('Kernel::System::HTMLUtils');

    # set the accounted time as part of the articles information
    ARTICLE:
    for my $ArticleData ( \%Article, \%ArticleAgent ) {

        next ARTICLE if !$ArticleData->{ArticleID};

        # get accounted time
        my $AccountedTime = $TicketObject->ArticleAccountedTimeGet(
            ArticleID => $ArticleData->{ArticleID},
        );

        $ArticleData->{TimeUnit} = $AccountedTime;
    }

    # get system default language
    my $DefaultLanguage = $Kernel::OM->Get('Kernel::Config')->Get('DefaultLanguage') || 'en';

    my $Languages = [ $Param{Recipient}->{UserLanguage}, $DefaultLanguage, 'en' ];

    my $Language;
    LANGUAGE:
    for my $Item ( @{$Languages} ) {
        next LANGUAGE if !$Item;
        next LANGUAGE if !$Notification{Message}->{$Item};

        # set language
        $Language = $Item;
        last LANGUAGE;
    }

    # if no language, then take the first one available
    if ( !$Language ) {
        my @NotificationLanguages = sort keys %{ $Notification{Message} };
        $Language = $NotificationLanguages[0];
    }

    # copy the correct language message attributes to a flat structure
    for my $Attribute (qw(Subject Body ContentType)) {
        $Notification{$Attribute} = $Notification{Message}->{$Language}->{$Attribute};
    }

    for my $Key (qw(From To Cc Subject Body ContentType Channel)) {
        if ( !$Param{CustomerMessageParams}->{$Key} ) {
            $Param{CustomerMessageParams}->{$Key} = $Article{$Key} || '';
        }
        chomp $Param{CustomerMessageParams}->{$Key};
    }

    # format body (only if longer the 86 chars)
    if ( $Param{CustomerMessageParams}->{Body} ) {
        if ( length $Param{CustomerMessageParams}->{Body} > 86 ) {
            my @Lines = split /\n/, $Param{CustomerMessageParams}->{Body};
            LINE:
            for my $Line (@Lines) {
                my $LineWrapped = $Line =~ s/(^>.+|.{4,86})(?:\s|\z)/$1\n/gm;

                next LINE if $LineWrapped;

                # if the regex does not match then we need
                # to add the missing new line of the split
                # else we will lose e.g. empty lines of the body.
                # (bug#10679)
                $Line .= "\n";
            }
            $Param{CustomerMessageParams}->{Body} = join '', @Lines;
        }
    }

    # KIX4OTRS-capeIT
    # get customer article data for replacing
    # (KIX_COMMENT and KIX_CUSTOMER_BODY and KIX_CUSTOMER_EMAIL could be the same)
    $Param{CustomerMessageParams}->{CustomerBody} = $Article{Body} || '';
    if (
        $Param{CustomerMessageParams}->{CustomerBody}
        && length $Param{CustomerMessageParams}->{CustomerBody} > 86
        )
    {
        $Param{CustomerMessageParams}->{CustomerBody} =~ s/(^>.+|.{4,86})(?:\s|\z)/$1\n/gm;
    }

    # EO KIX4OTRS-capeIT

    # fill up required attributes
    for my $Text (qw(Subject Body)) {
        if ( !$Param{CustomerMessageParams}->{$Text} ) {
            $Param{CustomerMessageParams}->{$Text} = "No $Text";
        }
    }

    my $Start = '<';
    my $End   = '>';
    if ( $Notification{ContentType} =~ m{text\/html} ) {
        $Start = '&lt;';
        $End   = '&gt;';
    }

    # replace <KIX_CUSTOMER_DATA_*> tags early from CustomerMessageParams, the rests will be replaced
    # by ticket customer user
    KEY:
    for my $Key ( sort keys %{ $Param{CustomerMessageParams} || {} } ) {

        next KEY if !$Param{CustomerMessageParams}->{$Key};

        $Notification{Body} =~ s/${Start}KIX_CUSTOMER_DATA_$Key${End}/$Param{CustomerMessageParams}->{$Key}/gi;
        $Notification{Subject} =~ s/<KIX_CUSTOMER_DATA_$Key>/$Param{CustomerMessageParams}->{$Key}{$_}/gi;
    }

    # do text/plain to text/html convert
    if ( $Self->{RichText} && $Notification{ContentType} =~ /text\/plain/i ) {
        $Notification{ContentType} = 'text/html';
        $Notification{Body}        = $Kernel::OM->Get('Kernel::System::HTMLUtils')->ToHTML(
            String => $Notification{Body},
        );
    }

    # do text/html to text/plain convert
    if ( !$Self->{RichText} && $Notification{ContentType} =~ /text\/html/i ) {
        $Notification{ContentType} = 'text/plain';
        $Notification{Body}        = $Kernel::OM->Get('Kernel::System::HTMLUtils')->ToAscii(
            String => $Notification{Body},
        );
    }

    # get notify texts
    for my $Text (qw(Subject Body)) {
        if ( !$Notification{$Text} ) {
            $Notification{$Text} = "No Notification $Text for $Param{Type} found!";
        }
    }

    # replace place holder stuff
    $Notification{Body} = $Self->_Replace(
        RichText  => $Self->{RichText},
        Text      => $Notification{Body},
        Recipient => $Param{Recipient},
        Data      => $Param{CustomerMessageParams},
        DataAgent => \%ArticleAgent,
        TicketID  => $Param{TicketID},
        UserID    => $Param{UserID},
        Language  => $Language,

        # KIX4OTRS-capeIT
        ArticleID => $Param{ArticleID} || '',

        # EO KIX4OTRS-capeIT
    );
    $Notification{Subject} = $Self->_Replace(
        RichText  => 0,
        Text      => $Notification{Subject},
        Recipient => $Param{Recipient},
        Data      => $Param{CustomerMessageParams},
        DataAgent => \%ArticleAgent,
        TicketID  => $Param{TicketID},
        UserID    => $Param{UserID},
        Language  => $Language,

        # KIX4OTRS-capeIT
        ArticleID => $Param{ArticleID} || '',

        # EO KIX4OTRS-capeIT
    );

    $Notification{Subject} = $TicketObject->TicketSubjectBuild(
        TicketNumber => $Ticket{TicketNumber},
        Subject      => $Notification{Subject} || '',
        Type         => 'New',
    );

    # add URLs and verify to be full HTML document
    if ( $Self->{RichText} ) {

        $Notification{Body} = $Kernel::OM->Get('Kernel::System::HTMLUtils')->LinkQuote(
            String => $Notification{Body},
        );
    }

    return %Notification;
}

# KIX4OTRS-capeIT

=item ReplacePlaceHolder()
    just a wrapper for external access to sub _Replace
=cut

sub ReplacePlaceHolder {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Text Data UserID)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    if ( !defined $Param{Language} || !$Param{Language}) {
        my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
        $Param{Language}
            = $Self->{UserLanguage}
            || $ConfigObject->Get('DefaultLanguage')
            || 'en';
    }

    return $Self->_Replace(
        %Param,
    );
}

# EO KIX4OTRS-capeIT

=begin Internal:

=cut

sub _Replace {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Text RichText Data UserID)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # check for mailto links
    # since the subject and body of those mailto links are
    # uri escaped we have to uri unescape them, replace
    # possible placeholders and then re-uri escape them
    $Param{Text} =~ s{
        (href="mailto:[^\?]+\?)([^"]+")
    }
    {
        my $MailToHref        = $1;
        my $MailToHrefContent = $2;

        $MailToHrefContent =~ s{
            ((?:subject|body)=)(.+?)("|&)
        }
        {
            my $SubjectOrBodyPrefix  = $1;
            my $SubjectOrBodyContent = $2;
            my $SubjectOrBodySuffix  = $3;

            my $SubjectOrBodyContentUnescaped = URI::Escape::uri_unescape $SubjectOrBodyContent;

            my $SubjectOrBodyContentReplaced = $Self->_Replace(
                %Param,
                Text     => $SubjectOrBodyContentUnescaped,
                RichText => 0,
            );

            my $SubjectOrBodyContentEscaped = URI::Escape::uri_escape_utf8 $SubjectOrBodyContentReplaced;

            $SubjectOrBodyPrefix . $SubjectOrBodyContentEscaped . $SubjectOrBodySuffix;
        }egx;

        $MailToHref . $MailToHrefContent;
    }egx;

    my $Start = '<';
    my $End   = '>';
    if ( $Param{RichText} ) {
        $Start = '&lt;';
        $End   = '&gt;';
        $Param{Text} =~ s/(\n|\r)//g;
    }

    my %Ticket;
    if ( $Param{TicketID} ) {
        %Ticket = $Kernel::OM->Get('Kernel::System::Ticket')->TicketGet(
            TicketID      => $Param{TicketID},
            DynamicFields => 1,
        );
    }

    # translate ticket values if needed
    if ( $Param{Language} ) {

        my $LanguageObject = Kernel::Language->new(
            UserLanguage => $Param{Language},
        );

        # Translate the diffrent values.
        for my $Field (qw(Type State StateType Lock Priority)) {
            $Ticket{$Field} = $LanguageObject->Translate( $Ticket{$Field} );
        }

        # Transform the date values from the ticket data (but not the dynamic field values).
        ATTRIBUTE:
        for my $Attribute ( sort keys %Ticket ) {
            next ATTRIBUTE if $Attribute =~ m{ \A DynamicField_ }xms;
            next ATTRIBUTE if !$Ticket{$Attribute};

            if ( $Ticket{$Attribute} =~ m{\A(\d\d\d\d)-(\d\d)-(\d\d)\s(\d\d):(\d\d):(\d\d)\z}xi ) {
                $Ticket{$Attribute} = $LanguageObject->FormatTimeString(
                    $Ticket{$Attribute},
                    'DateFormat',
                    'NoSeconds',
                );
            }
        }
    }

    my %Queue;
    if ( $Param{QueueID} ) {
        %Queue = $Kernel::OM->Get('Kernel::System::Queue')->QueueGet(
            ID => $Param{QueueID},
        );
    }

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    #rbo - T2016121190001552 - added KIX placeholders
    # replace config options
    my $Tag = $Start . 'KIX_CONFIG_';
    $Param{Text} =~ s{$Tag(.+?)$End}{
        my $Replace = '';
        # Mask secret config options.
        if ($1 =~ m{(Password|Pw)\d*$}smxi) {
            $Replace = 'xxx';
        }
        else {
            $Replace = $ConfigObject->Get($1) // '';
        }
        $Replace;
    }egx;

    # cleanup
    $Param{Text} =~ s/$Tag.+?$End/-/gi;

    my %Recipient = %{ $Param{Recipient} || {} };

    # get user object
    my $UserObject = $Kernel::OM->Get('Kernel::System::User');

    if ( !%Recipient && $Param{RecipientID} ) {

        %Recipient = $UserObject->GetUserData(
            UserID        => $Param{RecipientID},
            NoOutOfOffice => 1,
        );
    }

    my $HashGlobalReplace = sub {
        my ( $Tag, %H ) = @_;

        # Generate one single matching string for all keys to save performance.
        my $Keys = join '|', map {quotemeta} grep { defined $H{$_} } keys %H;

        # Add all keys also as lowercase to be able to match case insensitive,
        #   e. g. <KIX_CUSTOMER_From> and <KIX_CUSTOMER_FROM>.
        for my $Key ( sort keys %H ) {
            $H{ lc $Key } = $H{$Key};
        }

        $Param{Text} =~ s/(?:$Tag)($Keys)$End/$H{ lc $1 }/ieg;
    };

    # get recipient data and replace it with <KIX_...
    $Tag = $Start . 'KIX_';

    # include more readable tag <KIX_NOTIFICATION_RECIPIENT
    my $RecipientTag = $Start . 'KIX_NOTIFICATION_RECIPIENT_';

    if (%Recipient) {

        # HTML quoting of content
        if ( $Param{RichText} ) {
            ATTRIBUTE:
            for my $Attribute ( sort keys %Recipient ) {
                next ATTRIBUTE if !$Recipient{$Attribute};
                $Recipient{$Attribute} = $Kernel::OM->Get('Kernel::System::HTMLUtils')->ToHTML(
                    String => $Recipient{$Attribute},
                );
            }
        }

        $HashGlobalReplace->( "$Tag|$RecipientTag", %Recipient );
    }

    # cleanup
    $Param{Text} =~ s/$RecipientTag.+?$End/-/gi;

    # get owner data and replace it with <KIX_OWNER_...
    $Tag = $Start . 'KIX_OWNER_';

    # include more readable version <KIX_TICKET_OWNER
    my $OwnerTag = $Start . 'KIX_TICKET_OWNER_';

    if ( $Ticket{OwnerID} ) {

        my %Owner = $UserObject->GetUserData(
            UserID        => $Ticket{OwnerID},
            NoOutOfOffice => 1,
        );

        # html quoting of content
        if ( $Param{RichText} ) {

            ATTRIBUTE:
            for my $Attribute ( sort keys %Owner ) {
                next ATTRIBUTE if !$Owner{$Attribute};
                $Owner{$Attribute} = $Kernel::OM->Get('Kernel::System::HTMLUtils')->ToHTML(
                    String => $Owner{$Attribute},
                );
            }
        }

        $HashGlobalReplace->( "$Tag|$OwnerTag", %Owner );
    }

    # cleanup
    $Param{Text} =~ s/$Tag.+?$End/-/gi;
    $Param{Text} =~ s/$OwnerTag.+?$End/-/gi;

    # get owner data and replace it with <KIX_RESPONSIBLE_...
    $Tag = $Start . 'KIX_RESPONSIBLE_';

    # include more readable version <KIX_TICKET_RESPONSIBLE
    my $ResponsibleTag = $Start . 'KIX_TICKET_RESPONSIBLE_';

    if ( $Ticket{ResponsibleID} ) {
        my %Responsible = $UserObject->GetUserData(
            UserID        => $Ticket{ResponsibleID},
            NoOutOfOffice => 1,
        );

        # HTML quoting of content
        if ( $Param{RichText} ) {

            ATTRIBUTE:
            for my $Attribute ( sort keys %Responsible ) {
                next ATTRIBUTE if !$Responsible{$Attribute};
                $Responsible{$Attribute} = $Kernel::OM->Get('Kernel::System::HTMLUtils')->ToHTML(
                    String => $Responsible{$Attribute},
                );
            }
        }

        $HashGlobalReplace->( "$Tag|$ResponsibleTag", %Responsible );
    }

    # cleanup
    $Param{Text} =~ s/$Tag.+?$End/-/gi;
    $Param{Text} =~ s/$ResponsibleTag.+?$End/-/gi;

    # KIX4OTRS-capeIT
    # my $Tag2        = $Start . 'KIX_CURRENT_';
    my $Tag2;

    if (
        $Param{UserID}
        && ( !$Param{Frontend} || ( $Param{Frontend} && $Param{Frontend} ne 'Customer' ) )
        )
    {
        $Tag = $Start . 'KIX_Agent_';

        $Tag2 = $Start . 'KIX_CURRENT_';

        # EO KIX4OTRS-capeIT

        my %CurrentUser = $UserObject->GetUserData(
            UserID        => $Param{UserID},
            NoOutOfOffice => 1,
        );

        # html quoting of content
        if ( $Param{RichText} ) {

            ATTRIBUTE:
            for my $Attribute ( sort keys %CurrentUser ) {
                next ATTRIBUTE if !$CurrentUser{$Attribute};
                $CurrentUser{$Attribute} = $Kernel::OM->Get('Kernel::System::HTMLUtils')->ToHTML(
                    String => $CurrentUser{$Attribute},
                );
            }
        }

        $HashGlobalReplace->( "$Tag|$Tag2", %CurrentUser );

        # replace other needed stuff
        $Param{Text} =~ s/$Start KIX_FIRST_NAME $End/$CurrentUser{UserFirstname}/gxms;
        $Param{Text} =~ s/$Start KIX_LAST_NAME $End/$CurrentUser{UserLastname}/gxms;

        # cleanup
        $Param{Text} =~ s/$Tag2.+?$End/-/gi;

        # KIX4OTRS-capeIT
    }

    # EO KIX4OTRS-capeIT

    # ticket data
    $Tag = $Start . 'KIX_TICKET_';

    # html quoting of content
    if ( $Param{RichText} ) {

        ATTRIBUTE:
        for my $Attribute ( sort keys %Ticket ) {
            next ATTRIBUTE if !$Ticket{$Attribute};
            $Ticket{$Attribute} = $Kernel::OM->Get('Kernel::System::HTMLUtils')->ToHTML(
                String => $Ticket{$Attribute},
            );
        }
    }

    # Dropdown, Checkbox and MultipleSelect DynamicFields, can store values (keys) that are
    # different from the the values to display
    # <KIX_TICKET_DynamicField_NameX> returns the stored key
    # <KIX_TICKET_DynamicField_NameX_Value> returns the display value

    my %DynamicFields;

    # For systems with many Dynamic fields we do not want to load them all unless needed
    # Find what Dynamic Field Values are requested
    while ( $Param{Text} =~ m/$Tag DynamicField_(\S+?)(_Value)? $End/gixms ) {
        $DynamicFields{$1} = 1;
    }

    # to store all the required DynamicField display values
    my %DynamicFieldDisplayValues;

    # get dynamic field objects
    my $DynamicFieldObject        = $Kernel::OM->Get('Kernel::System::DynamicField');
    my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

    # get the dynamic fields for ticket object
    my $DynamicFieldList = $DynamicFieldObject->DynamicFieldListGet(
        Valid      => 1,
        ObjectType => ['Ticket'],
    ) || [];

    # cycle through the activated Dynamic Fields for this screen
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{$DynamicFieldList} ) {

        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

        # we only load the ones requested
        next DYNAMICFIELD if !$DynamicFields{ $DynamicFieldConfig->{Name} };

        my $LanguageObject;

        # translate values if needed
        if ( $Param{Language} ) {
            $LanguageObject = Kernel::Language->new(
                UserLanguage => $Param{Language},
            );
        }

        # get the display value for each dynamic field
        my $DisplayValue = $DynamicFieldBackendObject->ValueLookup(
            DynamicFieldConfig => $DynamicFieldConfig,
            Key                => $Ticket{ 'DynamicField_' . $DynamicFieldConfig->{Name} },
            LanguageObject     => $LanguageObject,
        );

        # get the readable value (value) for each dynamic field
        my $DisplayValueStrg = $DynamicFieldBackendObject->ReadableValueRender(
            DynamicFieldConfig => $DynamicFieldConfig,
            Value              => $DisplayValue,
        );

        # fill the DynamicFielsDisplayValues
        if ($DisplayValueStrg) {
            $DynamicFieldDisplayValues{ 'DynamicField_' . $DynamicFieldConfig->{Name} . '_Value' }
                = $DisplayValueStrg->{Value};
        }

        # get the readable value (key) for each dynamic field
        my $ValueStrg = $DynamicFieldBackendObject->ReadableValueRender(
            DynamicFieldConfig => $DynamicFieldConfig,
            Value              => $Ticket{ 'DynamicField_' . $DynamicFieldConfig->{Name} },
        );

        # replace ticket content with the value from ReadableValueRender (if any)
        if ( IsHashRefWithData($ValueStrg) ) {
            $Ticket{ 'DynamicField_' . $DynamicFieldConfig->{Name} } = $ValueStrg->{Value};
        }
    }

    # replace it
    $HashGlobalReplace->( $Tag, %Ticket, %DynamicFieldDisplayValues );

    # COMPAT
    $Param{Text} =~ s/$Start KIX_TICKET_ID $End/$Ticket{TicketID}/gixms;
    $Param{Text} =~ s/$Start KIX_TICKET_NUMBER $End/$Ticket{TicketNumber}/gixms;
    if ( $Param{TicketID} ) {
        $Param{Text} =~ s/$Start KIX_QUEUE $End/$Ticket{Queue}/gixms;
    }
    if ( $Param{QueueID} ) {
        $Param{Text} =~ s/$Start KIX_TICKET_QUEUE $End/$Queue{Name}/gixms;
    }

    # KIXBase-capeIT
    if ( $Ticket{Service} && $Param{Text} ) {
        my $LevelSeparator        = $ConfigObject->Get('TemplateGenerator::LevelSeparator');
        my $ServiceLevelSeparator = '::';
        if ( $LevelSeparator && ref($LevelSeparator) eq 'HASH' && $LevelSeparator->{Service} ) {
            $ServiceLevelSeparator = $LevelSeparator->{Service};
        }
        my @Service = split( $ServiceLevelSeparator, $Ticket{Service} );

        my $MatchPattern = $Start . "KIX_TICKET_Service_Level_(.*?)" . $End;
        while ( $Param{Text} =~ /$MatchPattern/ ) {
            my $ReplacePattern = $Start . "KIX_TICKET_Service_Level_" . $1 . $End;
            my $Level = ( $1 eq 'MAX' ) ? -1 : ($1) - 1;
            if ( $Service[$Level] ) {
                $Param{Text} =~ s/$ReplacePattern/$Service[$Level]/gixms
            }
            else {
                $Param{Text} =~ s/$ReplacePattern/-/gixms
            }

        }
    }

    # EO KIXBase-capeIT

    # cleanup
    $Param{Text} =~ s/$Tag.+?$End/-/gi;
 
    # get customer and agent params and replace it with <KIX_CUSTOMER_... or <KIX_AGENT_...
    my %ArticleData = (
        'KIX_CUSTOMER_' => $Param{Data}      || {},
        'KIX_AGENT_'    => $Param{DataAgent} || {},
    );

    # use a list to get customer first
    for my $DataType (qw(KIX_CUSTOMER_ KIX_AGENT_)) {
        my %Data = %{ $ArticleData{$DataType} };

        # HTML quoting of content
        if (
            $Param{RichText}
            && ( !$Data{ContentType} || $Data{ContentType} !~ /application\/json/ )
            )
        {

            ATTRIBUTE:
            for my $Attribute ( sort keys %Data ) {
                next ATTRIBUTE if !$Data{$Attribute};

                $Data{$Attribute} = $Kernel::OM->Get('Kernel::System::HTMLUtils')->ToHTML(
                    String => $Data{$Attribute},
                );
            }
        }

        if (%Data) {

            # Check if content type is JSON
            if ( $Data{'ContentType'} && $Data{'ContentType'} =~ /application\/json/ ) {

                # if article is chat related
                if ( $Data{'Channel'} =~ /chat/ ) {

                    # remove spaces
                    $Data{Body} =~ s/\n/ /gms;

                    my $Body = $Kernel::OM->Get('Kernel::System::JSON')->Decode(
                        Data => $Data{Body},
                    );

                    # replace body with HTML text
                    $Data{Body} = $Kernel::OM->Get('Kernel::Output::HTML::Layout')->Output(
                        TemplateFile => "ChatDisplay",
                        Data         => {
                            ChatMessages => $Body,
                        },
                    );
                }
            }

            # check if original content isn't text/plain, don't use it
            if ( $Data{'Content-Type'} && $Data{'Content-Type'} !~ /(text\/plain|\btext\b)/i ) {
                $Data{Body} = '-> no quotable message <-';
            }

            # replace <KIX_CUSTOMER_*> and <KIX_AGENT_*> tags
            $Tag = $Start . $DataType;
            $HashGlobalReplace->( $Tag, %Data );

            # prepare body (insert old email) <KIX_CUSTOMER_EMAIL[n]>, <KIX_CUSTOMER_NOTE[n]>
            #   <KIX_CUSTOMER_BODY[n]>, <KIX_AGENT_EMAIL[n]>..., <KIX_COMMENT>
            if ( $Param{Text} =~ /$Start(?:(?:$DataType(EMAIL|NOTE|BODY)\[(.+?)\])|(?:KIX_COMMENT))$End/g ) {

                my $Line       = $2 || 2500;
                my $NewOldBody = '';
                my @Body       = split( /\n/, $Data{Body} );

                for my $Counter ( 0 .. $Line - 1 ) {

                    # 2002-06-14 patch of Pablo Ruiz Garcia
                    # http://lists.otrs.org/pipermail/dev/2002-June/000012.html
                    if ( $#Body >= $Counter ) {

                        # add no quote char, do it later by using DocumentCleanup()
                        if ( $Param{RichText} ) {
                            $NewOldBody .= $Body[$Counter];
                        }

                        # add "> " as quote char
                        else {
                            $NewOldBody .= "> $Body[$Counter]";
                        }

                        # add new line
                        if ( $Counter < ( $Line - 1 ) ) {
                            $NewOldBody .= "\n";
                        }
                    }
                    $Counter++;
                }

                chomp $NewOldBody;

                # HTML quoting of content
                if ( $Param{RichText} && $NewOldBody ) {

                    # remove trailing new lines
                    for ( 1 .. 10 ) {
                        $NewOldBody =~ s/(<br\/>)\s{0,20}$//gs;
                    }

                    # add quote
                    $NewOldBody = "<blockquote type=\"cite\">$NewOldBody</blockquote>";
                    $NewOldBody = $Kernel::OM->Get('Kernel::System::HTMLUtils')->DocumentCleanup(
                        String => $NewOldBody,
                    );
                }

                # replace tag
                $Param{Text}
                    =~ s/$Start(?:(?:$DataType(EMAIL|NOTE|BODY)\[(.+?)\])|(?:KIX_COMMENT))$End/$NewOldBody/g;
            }

            # replace <KIX_CUSTOMER_SUBJECT[]>  and  <KIX_AGENT_SUBJECT[]> tags
            $Tag = "$Start$DataType" . 'SUBJECT';
            if ( $Param{Text} =~ /$Tag\[(.+?)\]$End/g ) {

                my $SubjectChar = $1;
                my $Subject     = $Kernel::OM->Get('Kernel::System::Ticket')->TicketSubjectClean(
                    TicketNumber => $Ticket{TicketNumber},
                    Subject      => $Data{Subject},
                );

                $Subject =~ s/^(.{$SubjectChar}).*$/$1 [...]/;
                $Param{Text} =~ s/$Tag\[.+?\]$End/$Subject/g;
            }

            # KIX4OTRS-capeIT
            # replace <KIX_> tags
            $Tag = $Start . 'KIX_';
            for ( keys %Data ) {
                next if !defined $Data{$_};
                $Param{Text} =~ s/$Tag$_$End/$Data{$_}/gi;
            }

            # EO KIX4OTRS-capeIT

            if ( $DataType eq 'KIX_CUSTOMER_' ) {

                # Arnold Ligtvoet - otrs@ligtvoet.org
                # get <KIX_EMAIL_DATE[]> from body and replace with received date
                use POSIX qw(strftime);
                $Tag = $Start . 'KIX_EMAIL_DATE';

                if ( $Param{Text} =~ /$Tag\[(.+?)\]$End/g ) {

                    my $TimeZone = $1;
                    my $EmailDate = strftime( '%A, %B %e, %Y at %T ', localtime );    ## no critic
                    $EmailDate .= "($TimeZone)";
                    $Param{Text} =~ s/$Tag\[.+?\]$End/$EmailDate/g;
                }
            }
        }

        if ( $DataType eq 'KIX_CUSTOMER_' ) {

            # get and prepare realname
            $Tag = $Start . 'KIX_CUSTOMER_REALNAME';
            if ( $Param{Text} =~ /$Tag$End/i ) {

                my $From = '';

                if ( $Ticket{ContactID} ) {

                    my %ContactData = $Kernel::OM->Get('Kernel::System::Contact')
                        ->ContactGet( ID => $Ticket{ContactID} );

                    if (

                        # Check if Customer 'UserEmail' match article data 'From'.
                        # Or check if this is auto response replacement.
                        # Take ticket customer as 'From'.
                        (
                            $ContactData{UserEmail}
                            && $Data{From}
                            && $ContactData{UserEmail} =~ /$Data{From}/
                        )
                        || $Param{AutoResponse}
                        )
                    {
                        $From = $Kernel::OM->Get('Kernel::System::Contact')->CustomerName(
                            UserLogin => $Ticket{ContactID}
                        );
                    }
                    else {
                        $From = $Data{From};
                    }

                }

                # try to get the real name directly from the data
                $From //= $Recipient{Realname};

                # get real name based on reply-to
                if ( $Data{ReplyTo} ) {
                    $From = $Data{ReplyTo};

                    # remove email addresses
                    $From =~ s/&lt;.*&gt;|<.*>|\(.*\)|\"|&quot;|;|,//g;

                    # remove leading/trailing spaces
                    $From =~ s/^\s+//g;
                    $From =~ s/\s+$//g;
                }

                # generate real name based on sender line
                if ( !$From ) {
                    $From = $Data{To} || '';

                    # remove email addresses
                    $From =~ s/&lt;.*&gt;|<.*>|\(.*\)|\"|&quot;|;|,//g;

                    # remove leading/trailing spaces
                    $From =~ s/^\s+//g;
                    $From =~ s/\s+$//g;
                }

                # replace <KIX_CUSTOMER_REALNAME> with from
                $Param{Text} =~ s/$Tag$End/$From/g;
            }
        }
    }

    # get customer data and replace it with <KIX_CUSTOMER_DATA_...
    $Tag  = $Start . 'KIX_CUSTOMER_';
    $Tag2 = $Start . 'KIX_CUSTOMER_DATA_';

    # KIX4OTRS-capeIT
    # if ( $Ticket{ContactID} || $Param{Data}->{ContactID} ) {
    if ( $Ticket{ContactID} || $Param{Data}->{ContactID} || ( defined $Param{Frontend} && $Param{Frontend} eq 'Customer' ) )
    {

        my $ContactID = $Param{Data}->{ContactID} || $Ticket{ContactID};

        my %Contact = $Kernel::OM->Get('Kernel::System::Contact')->ContactGet(
            ID => $ContactID,
        );

        # HTML quoting of content
        if ( $Param{RichText} ) {

            ATTRIBUTE:
            for my $Attribute ( sort keys %Contact ) {
                next ATTRIBUTE if !$Contact{$Attribute};
                $Contact{$Attribute} = $Kernel::OM->Get('Kernel::System::HTMLUtils')->ToHTML(
                    String => $Contact{$Attribute},
                );
            }
        }

        # replace it
        $HashGlobalReplace->( "$Tag|$Tag2", %Contact );
    }

    # cleanup all not needed <KIX_CUSTOMER_DATA_ tags
    $Param{Text} =~ s/(?:$Tag|$Tag2).+?$End/-/gi;

    # cleanup all not needed <KIX_AGENT_ tags
    $Tag = $Start . 'KIX_AGENT_';
    $Param{Text} =~ s/$Tag.+?$End/-/gi;

    # KIX4OTRS-capeIT
    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # get article data and replace it with <KIX_ARTICLE_DATA_...
    $Tag  = $Start . 'KIX_ARTICLE_';
    $Tag2 = $Start . 'KIX_ARTICLE_DATA_';
    if ( $Param{ArticleID} ) {
        my %Article = $TicketObject->ArticleGet(
            ArticleID => $Param{ArticleID},
        );

        # html quoteing of content
        if ( $Param{RichText} ) {
            for ( keys %Article ) {
                next if !$Article{$_};
                $Article{$_} = $Kernel::OM->Get('Kernel::System::HTMLUtils')->ToHTML(
                    String => $Article{$_},
                );
            }
        }

        # replace it
        for my $Key ( keys %Article ) {
            next if !defined $Article{$Key};
            $Param{Text} =~ s/$Tag$Key$End/$Article{$Key}/gi;
            $Param{Text} =~ s/$Tag2$Key$End/$Article{$Key}/gi;
        }
    }

    # cleanup all not needed <KIX_ARTICLE_ and <KIX_ARTICLE_DATA_ tags
    $Param{Text} =~ s/$Tag.+?$End/-/gi;
    $Param{Text} =~ s/$Tag2.+?$End/-/gi;

    # get first article data and replace it with <KIX_FIRST_...
    $Tag = $Start . 'KIX_FIRST_';
    if ( $Param{Text} =~ /$Tag.+$End/i ) {
        my %Article = $TicketObject->ArticleFirstArticle(
            TicketID => $Param{TicketID},
        );

        # replace <KIX_FIRST_BODY> and <KIX_FIRST_COMMENT> tags
        for my $Key (qw(KIX_FIRST_BODY KIX_FIRST_COMMENT)) {
            $Tag2 = $Start . $Key;
            if ( $Param{Text} =~ /$Tag2$End(\n|\r|)/g ) {
                my $Line       = 2500;
                my @Body       = split( /\n/, $Article{Body} );
                my $NewOldBody = '';
                for ( my $i = 0; $i < $Line; $i++ ) {
                    if ( $#Body >= $i ) {

                        # add no quote char, do it later by using DocumentStyleCleanup()
                        if ( $Param{RichText} ) {
                            $NewOldBody .= $Body[$i];
                        }

                        # add "> " as quote char
                        else {
                            $NewOldBody .= "> $Body[$i]";
                        }

                        # add new line
                        if ( $i < ( $Line - 1 ) ) {
                            $NewOldBody .= "\n";
                        }
                    }
                    else {
                        last;
                    }
                }
                chomp $NewOldBody;

                # html quoting of content
                if ( $Param{RichText} && $NewOldBody ) {

                    # remove trailing new lines
                    for ( 1 .. 10 ) {
                        $NewOldBody =~ s/(<br\/>)\s{0,20}$//gs;
                    }

                    # add quote
                    $NewOldBody = "<blockquote type=\"cite\">$NewOldBody</blockquote>";
                    $NewOldBody
                        = $Kernel::OM->Get('Kernel::System::HTMLUtils')->DocumentStyleCleanup(
                        String => $NewOldBody,
                        );
                }

                # replace tag
                $Param{Text} =~ s/$Tag2$End/$NewOldBody/g;
            }
        }

        # replace <KIX_FIRST_EMAIL[]> tags
        $Tag2 = $Start . 'KIX_FIRST_EMAIL';
        if ( $Param{Text} =~ /$Tag2\[(.+?)\]$End/g ) {
            my $Line       = $1;
            my @Body       = split( /\n/, $Article{Body} );
            my $NewOldBody = '';
            for ( my $i = 0; $i < $Line; $i++ ) {

                # 2002-06-14 patch of Pablo Ruiz Garcia
                # http://lists.otrs.org/pipermail/dev/2002-June/000012.html
                if ( $#Body >= $i ) {

                    # add no quote char, do it later by using DocumentStyleCleanup()
                    if ( $Param{RichText} ) {
                        $NewOldBody .= $Body[$i];
                    }

                    # add "> " as quote char
                    else {
                        $NewOldBody .= "> $Body[$i]";
                    }

                    # add new line
                    if ( $i < ( $Line - 1 ) ) {
                        $NewOldBody .= "\n";
                    }
                }
            }
            chomp $NewOldBody;

            # html quoting of content
            if ( $Param{RichText} && $NewOldBody ) {

                # remove trailing new lines
                for ( 1 .. 10 ) {
                    $NewOldBody =~ s/(<br\/>)\s{0,20}$//gs;
                }

                # add quote
                $NewOldBody = "<blockquote type=\"cite\">$NewOldBody</blockquote>";
                $NewOldBody
                    = $Kernel::OM->Get('Kernel::System::HTMLUtils')->DocumentStyleCleanup(
                    String => $NewOldBody,
                    );
            }

            # replace tag
            $Param{Text} =~ s/$Tag2\[.+?\]$End/$NewOldBody/g;
        }

        # replace <KIX_FIRST_SUBJECT[]> tags
        $Tag2 = $Start . 'KIX_FIRST_SUBJECT';
        if ( $Param{Text} =~ /$Tag2\[(.+?)\]$End/g ) {
            my $SubjectChar = $1;
            my $Subject     = $TicketObject->TicketSubjectClean(
                TicketNumber => $Ticket{TicketNumber},
                Subject      => $Article{Subject},
            );
            $Subject =~ s/^(.{$SubjectChar}).*$/$1 [...]/;
            $Param{Text} =~ s/$Tag2\[.+?\]$End/$Subject/g;
        }

        # html quoteing of content
        if ( $Param{RichText} ) {
            for ( keys %Article ) {
                next if !$Article{$_};
                $Article{$_} = $Kernel::OM->Get('Kernel::System::HTMLUtils')->ToHTML(
                    String => $Article{$_},
                );
            }
        }

        # replace it
        for my $Key ( keys %Article ) {
            next if !defined $Article{$Key};
            $Param{Text} =~ s/$Tag$Key$End/$Article{$Key}/gi;
        }
    }

    # cleanup all not needed <KIX_FIRST_ tags
    $Param{Text} =~ s/$Tag.+?$End/-/gi;

    # EO KIX4OTRS-capeIT

    return $Param{Text};
}

=head2 _RemoveUnSupportedTag()

cleanup all not supported tags

    my $Text = $TemplateGeneratorObject->_RemoveUnSupportedTag(
        Text => $SomeTextWithTags,
        ListOfUnSupportedTag => \@ListOfUnSupportedTag,
    );

=cut

sub _RemoveUnSupportedTag {

    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Item (qw(Text ListOfUnSupportedTag)) {
        if ( !defined $Param{$Item} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Item!"
            );
            return;
        }
    }

    my $Start = '<';
    my $End   = '>';
    if ( $Self->{RichText} ) {
        $Start = '&lt;';
        $End   = '&gt;';
        $Param{Text} =~ s/(\n|\r)//g;
    }

    # cleanup all not supported tags
    my $NotSupportedTag = $Start . "(?:" . join( "|", @{ $Param{ListOfUnSupportedTag} } ) . ")" . $End;
    $Param{Text} =~ s/$NotSupportedTag/-/gi;

    return $Param{Text};

}

1;

=end Internal:


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
