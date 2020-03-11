# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Ticket::ArticleCreate;

use strict;
use warnings;

use MIME::Base64();

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Ticket::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Ticket::ArticleCreate - API Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation::V1->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw( DebuggerObject WebserviceID )) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => 'Operation.InternalError',
                Message => "Got no $Needed!"
            );
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::ArticleCreate');

    return $Self;
}

=item ParameterDefinition()

define parameter preparation and check for this operation

    my $Result = $OperationObject->ParameterDefinition(
        Data => {
            ...
        },
    );

    $Result = {
        ...
    };

=cut

sub ParameterDefinition {
    my ( $Self, %Param ) = @_;

    return {
        'TicketID' => {
            Required => 1
        },
        'Article' => {
            Type     => 'HASH',
            Required => 1
        },
        'Article::Subject' => {
            Required => 1
        },
        'Article::Body' => {
            Required => 1
        },
        'Article::ContentType' => {
            RequiredIfNot => [ 'Article::MimeType', 'Article::Charset' ],
        },
        'Article::MimeType' => {
            RequiredIfNot => [ 'Article::ContentType' ],
            RequiredIf    => [ 'Article::Charset' ],
        },
        'Article::Charset' => {
            RequiredIfNot => [ 'Article::ContentType' ],
            RequiredIf    => [ 'Article::MimeType' ],
        },
    }
}

=item Run()

perform ArticleCreate Operation. This will return the created ArticleID.

    my $Result = $OperationObject->Run(
        Data => {
            TicketID => 123                                                    # required
            Article  => {                                                      # required
                Subject                         => 'some subject',             # required
                Body                            => 'some body'                 # required
                ContentType                     => 'some content type',        # ContentType or MimeType and Charset is requieed
                MimeType                        => 'some mime type',           
                Charset                         => 'some charset',           

                IncomingTime                    => 'YYYY-MM-DD HH24:MI:SS',    # optional
                ChannelID                       => 123,                        # optional
                Channel                         => 'some channel name',        # optional
                CustomerVisible                 => 0|1,                        # optional
                SenderTypeID                    => 123,                        # optional
                SenderType                      => 'some sender type name',    # optional
                AutoResponseType                => 'some auto response type',  # optional
                From                            => 'some from string',         # optional
                To                              => 'some to string',           # optional
                Cc                              => 'some Cc string',           # optional
                Bcc                             => 'some Bcc string',          # optional
                ReplyTo                         => 'some ReplyTo string',      # optional
                HistoryType                     => 'some history type',        # optional
                HistoryComment                  => 'Some  history comment',    # optional
                TimeUnit                        => 123,                        # optional
                NoAgentNotify                   => 1,                          # optional
                ForceNotificationToUserID       => [1, 2, 3]                   # optional
                ExcludeNotificationToUserID     => [1, 2, 3]                   # optional
                ExcludeMuteNotificationToUserID => [1, 2, 3]                   # optional
                Attachments => [
                    {
                        Content     => 'content'                               # base64 encoded
                        ContentType => 'some content type'
                        Filename    => 'some fine name'
                    },
                    # ...
                ],                    
                DynamicFields => [                                                     # optional
                    {
                        Name   => 'some name',                                          
                        Value  => $Value,                                              # value type depends on the dynamic field
                    },
                    # ...
                ],
            }
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      #
        Message    => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            ArticleID   => 123,                     # ID of created article
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # get ticket data
    my %Ticket = $TicketObject->TicketGet(
        TicketID => $Param{Data}->{TicketID},
    );

    if ( !%Ticket ) {
        return $Self->_Error(
            Code => 'ParentObject.NotFound',
        );
    }

    # isolate and trim Article parameter
    my $Article = $Self->_Trim(
        Data => $Param{Data}->{Article}
    );

    # add UserType
    $Article->{UserType} = $Self->{Authorization}->{UserType};

    # set defaults from operation config
    if ( !$Article->{AutoResponseType} ) {
        $Article->{AutoResponseType} = $Self->{Config}->{AutoResponseType} || '';
    }
    if ( !$Article->{ChannelID} && !$Article->{Channel} ) {
        $Article->{Channel} = $Self->{Config}->{Channel} || '';
    }
    if ( !$Article->{SenderTypeID} && !$Article->{SenderType} ) {
        $Article->{SenderType} = lc($Self->{Authorization}->{UserType});
    }
    if ( !$Article->{HistoryType} ) {
        $Article->{HistoryType} = $Self->{Config}->{HistoryType} || '';
    }
    if ( !$Article->{HistoryComment} ) {
        $Article->{HistoryComment} = $Self->{Config}->{HistoryComment} || '';
    }

    # check Article attribute values
    my $ArticleCheck = $Self->_CheckArticle( 
        Article => $Article 
    );

    if ( !$ArticleCheck->{Success} ) {
        return $Self->_Error(
            %{$ArticleCheck},
        );
    }

    # everything is ok, let's create the article
    return $Self->_ArticleCreate(
        Ticket   => \%Ticket,
        Article  => $Article,
        UserID   => $Self->{Authorization}->{UserID},
    );
}

=begin Internal:

=item _ArticleCreate()

creates a ticket with its article and sets dynamic fields and attachments if specified.

    my $Response = $OperationObject->_ArticleCreate(
        Ticket       => $Ticket,                  
        Article      => $Article,                 
        UserID       => 123,
    );

    returns:

    $Response = {
        Success => 1,                               # if everything is OK
        Data => {
            ArticleID  => 123,
        }
    }

    $Response = {
        Success => 0,                         # if unexpected error
        Code    => '...',  
        Message => '...'
    }

=cut

sub _ArticleCreate {
    my ( $Self, %Param ) = @_;

    my $Ticket           = $Param{Ticket};
    my $Article          = $Param{Article};

    # get customer information
    # with information will be used to create the ticket if customer is not defined in the
    # database, customer ticket information need to be empty strings
    my %ContactData = $Kernel::OM->Get('Kernel::System::Contact')->ContactGet(
        ID => $Ticket->{ContactID},
    );

    # get user object
    my $UserObject = $Kernel::OM->Get('Kernel::System::User');

    my $OwnerID;
    if ( $Ticket->{Owner} && !$Ticket->{OwnerID} ) {
        my %OwnerData = $UserObject->GetUserData(
            User => $Ticket->{Owner},
        );
        $OwnerID = $OwnerData{UserID};
    }
    elsif ( defined $Ticket->{OwnerID} ) {
        $OwnerID = $Ticket->{OwnerID};
    }

    my $ResponsibleID;
    if ( $Ticket->{Responsible} && !$Ticket->{ResponsibleID} ) {
        my %ResponsibleData = $UserObject->GetUserData(
            User => $Ticket->{Responsible},
        );
        $ResponsibleID = $ResponsibleData{UserID};
    }
    elsif ( defined $Ticket->{ResponsibleID} ) {
        $ResponsibleID = $Ticket->{ResponsibleID};
    }

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    if ( !defined $Article->{NoAgentNotify} ) {

        # check if new owner is given (then send no agent notify)
        $Article->{NoAgentNotify} = 0;
        if ($OwnerID) {
            $Article->{NoAgentNotify} = 1;
        }
    }

    # set Article From
    my $From;
    if ( $Article->{From} ) {
        $From = $Article->{From};
    }
    # use data from contact (if contact is in database)
    elsif ( IsHashRefWithData( \%ContactData ) ) {
        $From = '"' . $ContactData{Firstname} . ' ' . $ContactData{Lastname} . '"'
            . ' <' . $ContactData{Email} . '>';
    }
    # otherwise use customer user as sent from the request (it should be an email)
    else {
        $From = $Ticket->{ContactID};
    }

    # set Article To
    my $To;
    if ( $Article->{To} ) { 
        $To = $Article->{To}
    }
    else {
        if ( $Ticket->{Queue} ) {
            $To = $Ticket->{Queue};
        }
        else {
            $To = $Kernel::OM->Get('Kernel::System::Queue')->QueueLookup(
                QueueID => $Ticket->{QueueID},
            );
        }
    }

    # prepare attachments
    if ( IsArrayRefWithData($Article->{Attachments}) ) {

        foreach my $Attachment ( @{$Article->{Attachments}} ) {
            $Attachment->{Content} = MIME::Base64::decode_base64( $Attachment->{Content} );
            $Attachment->{Disposition} = 'attachment';
        }
    }

    # create article
    my $ArticleID = $TicketObject->ArticleCreate(
        NoAgentNotify    => $Article->{NoAgentNotify}  || 0,
        TicketID         => $Ticket->{TicketID},
        ChannelID        => $Article->{ChannelID}      || '',
        Channel          => $Article->{Channel}        || '',
        CustomerVisible  => $Article->{CustomerVisible}, # no fallback, core handles it
        SenderTypeID     => $Article->{SenderTypeID}   || '',
        SenderType       => $Article->{SenderType}     || '',
        From             => $From,
        To               => $To,
        Cc               => $Article->{Cc}             || '',
        Bcc              => $Article->{Bcc}            || '',
        Subject          => $Article->{Subject},
        Body             => $Article->{Body},
        IncomingTime     => $Article->{IncomingTime}   || '',
        MimeType         => $Article->{MimeType}       || '',
        Charset          => $Article->{Charset}        || '',
        ContentType      => $Article->{ContentType}    || '',
        UserID           => $Param{UserID},
        HistoryType      => $Article->{HistoryType},
        HistoryComment   => $Article->{HistoryComment} || '%%',
        AutoResponseType => $Article->{AutoResponseType},
        OrigHeader       => {
            From    => $From,
            To      => $To,
            Subject => $Article->{Subject},
            Body    => $Article->{Body},

        },
        Attachment     => $Article->{Attachments},
    );

    if ( !$ArticleID ) {
        my $Error = $Kernel::OM->Get('Kernel::System::Log')->GetLogEntry(
            Type => 'error',
            What => 'Message',
        );

        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => $Error,
        );
    }

    # time accounting
    if ( $Article->{TimeUnit} ) {
        $TicketObject->TicketAccountTime(
            TicketID  => $Ticket->{TicketID},
            ArticleID => $ArticleID,
            TimeUnit  => $Article->{TimeUnit},
            UserID    => $Param{UserID},
        );
    }

    # set dynamic fields
    if ( IsArrayRefWithData($Article->{DynamicFields}) ) {

        DYNAMICFIELD:
        foreach my $DynamicField ( @{$Article->{DynamicFields}} ) {
            my $Result = $Self->SetDynamicFieldValue(
                %{$DynamicField},
                TicketID  => $Ticket->{TicketID},
                ArticleID => $ArticleID,
                UserID    => $Param{UserID},
            );

            if ( !$Result->{Success} ) {
                return $Self->_Error(
                    Code    => 'Operation.InternalError',
                    Message => "Dynamic Field $DynamicField->{Name} could not be set, please contact the system administrator",
                );
            }
        }
    }

    return $Self->_Success(
        Code         => 'Object.Created',
        ArticleID    => 0 + $ArticleID,
    );
}

1;

=end Internal:





=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
