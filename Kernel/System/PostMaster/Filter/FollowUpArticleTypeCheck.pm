# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::PostMaster::Filter::FollowUpChannelCheck;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::System::Contact',
    'Kernel::System::Log',
    'Kernel::System::Ticket',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # get parser object
    $Self->{ParserObject} = $Param{ParserObject} || die "Got no ParserObject!";

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    return 1 if !$Param{TicketID};

    # check needed stuff
    for (qw(JobConfig GetParam)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # Only run if we have a follow-up article with SenderType 'customer'.
    #   It could be that follow-ups have a different SenderType like 'system' for
    #   automatic notifications. In these cases there is no need to hide them.
    #   See also bug#10182 for details.
    if (
#rbo - T2016121190001552 - renamed X-OTRS headers
        !$Param{GetParam}->{'X-KIX-FollowUp-SenderType'}
        || $Param{GetParam}->{'X-KIX-FollowUp-SenderType'} ne 'customer'
        )
    {
        return 1;
    }

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # Get all articles.
    my @ArticleIndex = $TicketObject->ArticleGet(
        TicketID      => $Param{TicketID},
        DynamicFields => 0,
    );
    return if !@ArticleIndex;

    # Check if it is a known customer, otherwise use email address from ContactID field of the ticket.
    my %CustomerData = $Kernel::OM->Get('Kernel::System::Contact')->ContactGet(
        User => $ArticleIndex[0]->{ContactID},
    );
    my $CustomerEmailAddress = $CustomerData{UserEmail} || $ArticleIndex[0]->{ContactID};

    # Email sender address
    my $SenderAddress = $Param{GetParam}->{'X-Sender'};

    # Email Reply-To address for forwarded emails
    my $ReplyToAddress;
    if ( $Param{GetParam}->{ReplyTo} ) {
        $ReplyToAddress = $Self->{ParserObject}->GetEmailAddress(
            Email => $Param{GetParam}->{ReplyTo},
        );
    }

    # check if current sender is customer (do nothing)
    if ( $CustomerEmailAddress && $SenderAddress ) {
        return 1 if lc $CustomerEmailAddress eq lc $SenderAddress;
    }

    my @References = $Self->{ParserObject}->GetReferences();

    # check if current sender got an internal forward
    my $InternalForward;
    ARTICLE:
    for my $Article ( reverse @ArticleIndex ) {

        # just check agent sent article
        next ARTICLE if $Article->{SenderType} ne 'agent';

        # just check email internal
        next ARTICLE if $Article->{Channel} ne 'email' || !$Article->{CustomerVisible};

        # check recipients
        next ARTICLE if !$Article->{To};

        # check based on recipient addresses of the article
        my @ToEmailAddresses = $Self->{ParserObject}->SplitAddressLine(
            Line => $Article->{To},
        );
        my @CcEmailAddresses = $Self->{ParserObject}->SplitAddressLine(
            Line => $Article->{Cc},
        );
        my @EmailAdresses = ( @ToEmailAddresses, @CcEmailAddresses );

        EMAIL:
        for my $Email (@EmailAdresses) {
            my $Recipient = $Self->{ParserObject}->GetEmailAddress(
                Email => $Email,
            );
            if ( lc $Recipient eq lc $SenderAddress ) {
                $InternalForward = 1;
                last ARTICLE;
            }
            if ( $ReplyToAddress && lc $Recipient eq lc $ReplyToAddress ) {
                $InternalForward = 1;
                last ARTICLE;
            }
        }

        # check based on Message-ID of the article
        for my $Reference (@References) {
            if ( $Article->{MessageID} && $Article->{MessageID} eq $Reference ) {
                $InternalForward = 1;
                last ARTICLE;
            }
        }
    }

    return 1 if !$InternalForward;

#rbo - T2016121190001552 - renamed X-OTRS headers
    # get latest customer article (current arrival)
    $Param{GetParam}->{'X-KIX-FollowUp-Channel'} = $Param{JobConfig}->{Channel} || 'email';
    $Param{GetParam}->{'X-KIX-FollowUp-CustomerVisible'} = $Param{JobConfig}->{VisibleForCustomer} || 'email';

    # set article type to email-internal
    $Param{GetParam}->{'X-KIX-FollowUp-SenderType'} = $Param{JobConfig}->{SenderType} || 'customer';

    return 1;
}

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
