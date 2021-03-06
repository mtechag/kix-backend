# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ProcessManagement::TransitionAction::TicketArticleSend;

use strict;
use warnings;
use utf8;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::ProcessManagement::TransitionAction::Base);

our @ObjectDependencies = (
    'Log',
    'Ticket',
    'User',
);

=head1 NAME

# BPMX-capeIT
#Kernel::System::ProcessManagement::TransitionAction::TicketArticleCreate - A module to create an article
Kernel::System::ProcessManagement::TransitionAction::TicketArticleSend - A module to create an article to send
# EO BPMX-capeIT

=head1 SYNOPSIS
# BPMX-capeIT
#All TicketArticleCreate functions.
All TicketArticleSend functions.
# EO BPMX-capeIT
=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
# BPMX-capeIT
#    my $TicketArticleCreateObject = $Kernel::OM->Get('ProcessManagement::TransitionAction::TicketArticleCreate');
    my $TicketArticleCreateObject = $Kernel::OM->Get('ProcessManagement::TransitionAction::TicketArticleSend');
# EO BPMX-capeIT
=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item Run()

    Run Data
# BPMX-capeIT
#    my $TicketArticleCreateResult = $TicketArticleCreateActionObject->Run(
    my $TicketArticleSendResult = $TicketArticleSendActionObject->Run(
# EO BPMX-capeIT
        UserID                   => 123,
        Ticket                   => \%Ticket,   # required
        ProcessEntityID          => 'P123',
        ActivityEntityID         => 'A123',
        TransitionEntityID       => 'T123',
        TransitionActionEntityID => 'TA123',
        Config                   => {
            # required:
            Channel          => 'email',                                # ...
            CustomerVisible  => 0|1,                                    # optional
            SenderType       => 'agent',                                # agent|system|customer
            ContentType      => 'text/plain; charset=ISO-8859-15',      # or optional Charset & MimeType
            Subject          => 'some short description',               # required
            Body             => 'the message text',                     # required
            HistoryType      => 'OwnerUpdate',                          # EmailCustomer|Move|AddNote|PriorityUpdate|WebRequestCustomer|...
            HistoryComment   => 'Some free text!',

            # optional:
            From             => 'Some Agent <email@example.com>',       # not required but useful
            To               => 'Some Customer A <customer-a@example.com>', # not required but useful
            Cc               => 'Some Customer B <customer-b@example.com>', # not required but useful
            ReplyTo          => 'Some Customer B <customer-b@example.com>', # not required
            MessageID        => '<asdasdasd.123@example.com>',          # not required but useful
            InReplyTo        => '<asdasdasd.12@example.com>',           # not required but useful
            References       => '<asdasdasd.1@example.com> <asdasdasd.12@example.com>', # not required but useful
            NoAgentNotify    => 0,                                      # if you don't want to send agent notifications
            AutoResponseType => 'auto reply'                            # auto reject|auto follow up|auto reply/new ticket|auto remove

            ForceNotificationToUserID   => [ 1, 43, 56 ],               # if you want to force somebody
            ExcludeNotificationToUserID => [ 43,56 ],                   # if you want full exclude somebody from notfications,
                                                                        # will also be removed in To: line of article,
                                                                        # higher prio as ForceNotificationToUserID
            ExcludeMuteNotificationToUserID => [ 43,56 ],               # the same as ExcludeNotificationToUserID but only the
                                                                        # sending gets muted, agent will still shown in To:
                                                                        # line of article

            TimeUnit => 123                                             # optional, to set the acouting time
            UserID   => 123,                                            # optional, to override the UserID from the logged user
        }
    );
    Ticket contains the result of TicketGet including DynamicFields
    Config is the Config Hash stored in a Process::TransitionAction's  Config key
    Returns:

# BPMX-capeIT
#    $TicketArticleCreateResult = 1; # 0
    $TicketArticleSendResult = 1; # 0
# EO BPMX-capeIT
    );

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # define a common message to output in case of any error
    my $CommonMessage = "Process: $Param{ProcessEntityID} Activity: $Param{ActivityEntityID}"
        . " Transition: $Param{TransitionEntityID}"
        . " TransitionAction: $Param{TransitionActionEntityID} - ";

    # check for missing or wrong params
    my $Success = $Self->_CheckParams(
        %Param,
        CommonMessage => $CommonMessage,
    );
    return if !$Success;

    # override UserID if specified as a parameter in the TA config
    $Param{UserID} = $Self->_OverrideUserID(%Param);

    # use ticket attributes if needed
    $Self->_ReplaceTicketAttributes(%Param);

    # convert scalar items into array references
    for my $Attribute (
        qw(ForceNotificationToUserID ExcludeNotificationToUserID
        ExcludeMuteNotificationToUserID
        )
        )
    {
        if ( IsStringWithData( $Param{Config}->{$Attribute} ) ) {
            $Param{Config}->{$Attribute} = $Self->_ConvertScalar2ArrayRef(
                Data => $Param{Config}->{$Attribute},
            );
        }
    }

    # check Channel
    # BPMX-capeIT
    #    TODO Test => consultation tto => ReleaseTicket => skpm
    #    if ( $Param{Config}->{Channel} =~ m{\A email }msxi ) {
    if ( !( $Param{Config}->{Channel} =~ m{\A email }msxi ) ) {

        # EO BPMX-capeIT
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => $CommonMessage
                . "Channel $Param{Config}->{Channel} is not supported",
        );
        return;
    }

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Ticket');

    # If "From" is not set
    if ( !$Param{Config}->{From} ) {

        # Get current user data
        my %Contact = $Kernel::OM->Get('Contact')->ContactGet(
            UserID => $Param{UserID},
        );

        $Param{Config}->{From} = $Contact{Fullname} . ' <' . $Contact{Email} . '>';
    }

    my $ArticleID = $TicketObject->ArticleCreate(
        %{ $Param{Config} },
        TicketID => $Param{Ticket}->{TicketID},
        UserID   => $Param{UserID},
    );

    if ( !$ArticleID ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => $CommonMessage
                . "Couldn't create article for Ticket: "
                . $Param{Ticket}->{TicketID} . '!',
        );
        return;
    }

    # set time units
    if ( $Param{Config}->{TimeUnit} ) {
        $TicketObject->TicketAccountTime(
            TicketID  => $Param{Ticket}->{TicketID},
            ArticleID => $ArticleID,
            TimeUnit  => $Param{Config}->{TimeUnit},
            UserID    => $Param{UserID},
        );
    }

    return 1;
}

1;





=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
