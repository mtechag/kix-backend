# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Ticket::Event::NotificationToOutOfOfficeSubstitute;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Config',
    'HTMLUtils',
    'Log',
    'Email',
    'Time',
    'User',
);

=item new()

create an object.

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # create needed objects
    $Self->{ConfigObject}    = $Kernel::OM->Get('Config');
    $Self->{HTMLUtilsObject} = $Kernel::OM->Get('HTMLUtils');
    $Self->{LogObject}       = $Kernel::OM->Get('Log');
    $Self->{SendmailObject}  = $Kernel::OM->Get('Email');
    $Self->{TimeObject}      = $Kernel::OM->Get('Time');
    $Self->{UserObject}      = $Kernel::OM->Get('User');

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    foreach (qw(TicketID Notification)) {
        if ( !$Param{Data}->{$_} ) {
            $Self->{LogObject}
                ->Log(
                Priority => 'error',
                Message  => "NotificationToOutOfOfficeSubstitute: Need $_!"
                );
            return;
        }
    }
    my %Notification = %{ $Param{Data}->{Notification} };

    # check if recipient data is availible
    if ( !$Param{Data}->{RecipientMail} && !$Param{Data}->{RecipientID} ) {
        $Self->{LogObject}->Log(
            Priority => 'error',
            Message  => "NotificationToOutOfOfficeSubstitute: Need RecipientMail or RecipientID!"
        );
        return;
    }
    my %User;
    if ( $Param{Data}->{RecipientID} ) {
        %User = $Self->{UserObject}->GetUserData(
            UserID => $Param{Data}->{RecipientID},
            Valid  => 1,
        );
    }
    else {
        my %UserList = $Self->{UserObject}->UserSearch(
            PostMasterSearch => $Param{Data}->{RecipientMail},
            Valid            => 1,
        );
        for my $Agent ( keys %UserList ) {
            %User = $Self->{UserObject}->GetUserData(
                UserID => $Agent,
                Valid  => 1,
            );
            last;
        }
    }

    # check if user's out of office-time is configured
    return if !%User || !$User{Preferences}->{OutOfOffice} || !$User{Preferences}->{OutOfOfficeSubstitute};

    # check if user is out of office right now
    my $CurrTime = $Self->{TimeObject}->SystemTime();
    my $StartTime
        = "$User{Preferences}->{OutOfOfficeStartYear}-$User{Preferences}->{OutOfOfficeStartMonth}-$User{Preferences}->{OutOfOfficeStartDay} 00:00:00";
    $StartTime = $Self->{TimeObject}->TimeStamp2SystemTime( String => $StartTime );
    my $EndTime
        = "$User{Preferences}->{OutOfOfficeEndYear}-$User{Preferences}->{OutOfOfficeEndMonth}-$User{Preferences}->{OutOfOfficeEndDay} 23:59:59";
    $EndTime = $Self->{TimeObject}->TimeStamp2SystemTime( String => $EndTime );
    return if ( $StartTime > $CurrTime || $EndTime < $CurrTime );

    # get substitute data
    my %SubstituteUser = $Self->{UserObject}->GetUserData(
        UserID => $User{Preferences}->{OutOfOfficeSubstitute},
        Valid  => 1,
    );
    return if !%SubstituteUser || !$SubstituteUser{UserEmail};

    # prepare notification body
    if ( $User{Preferences}->{OutOfOfficeSubstituteNote} ) {
        if ( $Notification{ContentType} && $Notification{ContentType} eq 'text/html' ) {
            $Notification{Body} = $Self->{HTMLUtilsObject}->DocumentStrip(
                String => $Notification{Body},
            );
            $Notification{Body} = $User{Preferences}->{OutOfOfficeSubstituteNote}
                . "<br/>**********************************************************************<br/><br/>"
                . $Notification{Body};
            $Notification{Body} = $Self->{HTMLUtilsObject}->DocumentComplete(
                String  => $Notification{Body},
                Charset => 'utf-8',
            );
        }
        else {
            $Notification{Body} = $User{Preferences}->{OutOfOfficeSubstituteNote}
                . "\n**********************************************************************\n\n"
                . $Notification{Body};
        }
    }

    $Self->{LogObject}->Log(
        Priority => 'notice',
        Message =>
            "Sent substitute email to '$SubstituteUser{UserEmail}' for agent '$User{UserLogin}'",
    );

    # send notification to substitute
    $Self->{SendmailObject}->Send(
        From => $Self->{ConfigObject}->Get('NotificationSenderName') . ' <'
            . $Self->{ConfigObject}->Get('NotificationSenderEmail') . '>',
        To         => $SubstituteUser{UserEmail},
        Subject    => $Notification{Subject},
        MimeType   => $Notification{ContentType} || 'text/plain',
        Charset    => 'utf-8',
        Body       => $Notification{Body},
        Loop       => 1,
        Attachment => $Param{Data}->{Attachments} || [],
    );

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
