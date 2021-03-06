# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Ticket::Event::AutoCreateLinkedPerson;

use strict;
use warnings;

our @ObjectDependencies = (
    'Config',
    'Contact',
    'Link',
    'Log',
    'SystemAddress',
    'State',
    'Ticket',
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
    $Self->{ConfigObject}        = $Kernel::OM->Get('Config');
    $Self->{ContactObject}  = $Kernel::OM->Get('Contact');
    $Self->{LinkObject}          = $Kernel::OM->Get('LinkObject');
    $Self->{LogObject}           = $Kernel::OM->Get('Log');
    $Self->{SystemAddressObject} = $Kernel::OM->Get('SystemAddress');
    $Self->{StateObject}         = $Kernel::OM->Get('State');
    $Self->{TicketObject}        = $Kernel::OM->Get('Ticket');
    $Self->{UserObject}          = $Kernel::OM->Get('User');

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check required params...
    for my $CurrKey (qw(Event Data)) {
        if ( !$Param{$CurrKey} ) {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Need $CurrKey!"
            );
            return;
        }
    }

    my %Data      = %{ $Param{Data} };
    my $ConfigRef = $Self->{ConfigObject}->Get('AutoCreateLinkedPerson');
    my @Blacklist = @{ $ConfigRef->{Blacklist} };

    my $Blacklisted;

    if ( $Param{Event} eq 'ArticleCreate' ) {

        # check required params...
        for my $CurrKey (qw(TicketID ArticleID)) {
            if ( !$Data{$CurrKey} ) {
                $Self->{LogObject}->Log(
                    Priority => 'error',
                    Message  => "Need $CurrKey!"
                );
                return;
            }
        }

        my %Ticket = $Self->{TicketObject}->TicketGet(
            TicketID => $Data{TicketID},
            UserID   => 1,
        );
        my %Article = $Self->{TicketObject}->ArticleGet(
            ArticleID => $Data{ArticleID},
        );

        if ( $Article{Channel} eq 'email' ) {

            # extract all receipients mail addresses...
            my @SplitAddresses;
            foreach (qw(From To Cc)) {
                next if ( !$Article{$_} );
                push(
                    @SplitAddresses,
                    grep {/.+@.+/}
                        split( /[<>,"\s\/\\()\[\]\{\}]/, $Article{$_} )
                );
            }

            # lookup each mail address and add corresponding link...
            MAILADDRESS:
            for my $CurrEmailAddress (@SplitAddresses) {

                # check if mail address is blacklisted
                $Blacklisted = 0;
                for my $Item (@Blacklist) {
                    next if $CurrEmailAddress !~ m/$Item/;
                    $Blacklisted = 1;
                    last;
                }
                next if $Blacklisted;

                # check for systemaddresses...
                next
                    if (
                    $Self->{SystemAddressObject}
                    ->SystemAddressIsLocalAddress( Address => $CurrEmailAddress )
                    );

                #---------------------------------------------------------------
                # check in agent backend for this mail address...
                my %UserListAgent = $Self->{UserObject}->UserSearch(
                    PostMasterSearch => $CurrEmailAddress,
                    ValidID          => 1,
                );
                for my $CurrUserID ( keys(%UserListAgent) ) {
                    next if ( $CurrUserID == 1 );
                    my %User = $Self->{UserObject}->GetUserData(
                        UserID => $CurrUserID,
                        Valid  => 1,
                    );
                    next if !$User{UserLogin};
                    $Blacklisted = 0;
                    for my $Item (@Blacklist) {
                        next if $User{UserLogin} !~ m/$Item/;
                        $Blacklisted = 1;
                        last;
                    }
                    next if $Blacklisted;

                    my $Type = "Agent";

                    my $Success = $Self->{LinkObject}->LinkAdd(
                        SourceObject => 'Person',
                        SourceKey    => $User{UserLogin},
                        TargetObject => 'Ticket',
                        TargetKey    => $Data{TicketID},
                        Type         => $Type,
                        UserID       => $Param{UserID},
                    );

                    $Self->{TicketObject}->HistoryAdd(
                        Name         => 'added involved person ' . $CurrUserID,
                        HistoryType  => 'TicketLinkAdd',
                        TicketID     => $Ticket{TicketID},
                        CreateUserID => 1,
                    );

                    # avoid adding agent as customer user - next mail address...
                    next MAILADDRESS;
                }

                #---------------------------------------------------------------
                # check in customer backend for this mail address...
                my %UserListCustomer = $Self->{ContactObject}->CustomerSearch(
                    PostMasterSearch => $CurrEmailAddress,
                );
                for my $CurrUserID ( keys(%UserListCustomer) ) {

                    my %ContactData =
                        $Self->{ContactObject}->ContactGet( ID => $CurrUserID, );

                    # set type customer if users CustomerID equals tickets CustomerID...
                    my $Type = "3rdParty";

                    my $LinkList = $Self->{LinkObject}->LinkList(
                        Object  => 'Ticket',
                        Key     => $Data{TicketID},
                        Object2 => 'Person',
                        State   => 'Valid',
                        UserID  => $Param{UserID},
                    );

                    # next if customer already linked
                    next
                        if defined $LinkList->{Person}->{Customer}->{Source}
                            ->{ $ContactData{UserLogin} }
                            && $LinkList->{Person}->{Customer}->{Source}
                            ->{ $ContactData{UserLogin} };
                    next
                        if defined $LinkList->{Person}->{'3rdParty'}->{Source}
                            ->{ $ContactData{UserLogin} }
                            && $LinkList->{Person}->{'3rdParty'}->{Source}
                            ->{ $ContactData{UserLogin} };

                    if (
                        $ContactData{UserCustomerID}
                        && $Ticket{CustomerID}
                        && $Ticket{CustomerID} eq $ContactData{UserCustomerID}
                        )
                    {
                        $Type = "Customer";
                    }

                    $Blacklisted = 0;
                    for my $Item (@Blacklist) {
                        next if $UserListCustomer{$CurrUserID} !~ m/$Item/;
                        $Blacklisted = 1;
                        last;
                    }
                    next if $Blacklisted;

                    # add links to database
                    my $Success = $Self->{LinkObject}->LinkAdd(
                        SourceObject => 'Person',
                        SourceKey    => $ContactData{UserLogin},
                        TargetObject => 'Ticket',
                        TargetKey    => $Data{TicketID},
                        Type         => $Type,
                        UserID       => $Param{UserID},
                    );

                    $Self->{TicketObject}->HistoryAdd(
                        Name         => 'added involved person ' . $UserListCustomer{$CurrUserID},
                        HistoryType  => 'TicketLinkAdd',
                        TicketID     => $Ticket{TicketID},
                        CreateUserID => 1,
                    );

                    # avoid multiple links caused by multiple users for one mailaddress...
                    next MAILADDRESS;
                }

            }
        }

        #-----------------------------------------------------------------------
        # add current agent
        return if ( $Article{SenderTypeID} != 1 );
        return 1 if ( !$Param{UserID} || $Param{UserID} == 1 );

        my %User = $Self->{UserObject}->GetUserData(
            UserID => $Param{UserID},
            Valid  => 1,
        );
        return 1 if ( !$User{UserLogin} );
        $Blacklisted = 0;
        for my $Item (@Blacklist) {
            next if $User{UserLogin} !~ m/$Item/ && $User{Email} !~ m/$Item/; #todo email moved to contact
            $Blacklisted = 1;
            last;
        }
        next if $Blacklisted;

        my $Success = $Self->{LinkObject}->LinkAdd(
            SourceObject => 'Person',
            SourceKey    => $User{UserLogin},
            TargetObject => 'Ticket',
            TargetKey    => $Data{TicketID},
            Type         => 'Agent',
            UserID       => $Param{UserID},
        );

        $Self->{TicketObject}->HistoryAdd(
            Name         => 'added involved person ' . $User{UserLogin},
            HistoryType  => 'TicketLinkAdd',
            TicketID     => $Ticket{TicketID},
            CreateUserID => 1,
        );

    }

    #---------------------------------------------------------------------------
    # EVENT TicketOwnerUpdate / TicketResponsibleUpdate...
    elsif (
        $Param{Event} eq 'TicketOwnerUpdate'
        || $Param{Event} eq 'TicketResponsibleUpdate'
        )
    {

        my %Ticket = $Self->{TicketObject}->TicketGet(
            TicketID => $Data{TicketID},
            UserID   => 1,
        );

        my $User =
            ( $Param{Event} eq 'TicketOwnerUpdate' )
            ? $Ticket{OwnerID}
            : $Ticket{ResponsibleID};
        return 1 if ( $User == 1 );

        my %User = $Self->{UserObject}->GetUserData(
            UserID => $User,
            Valid  => 1,
        );
        return 1 if ( !$User{UserLogin} );
        $Blacklisted = 0;
        for my $Item (@Blacklist) {
            next if $User{UserLogin} !~ m/$Item/ && $User{UserEmail} !~ m/$Item/; #todo email moved to contact
            $Blacklisted = 1;
            last;
        }
        return 1 if $Blacklisted;

        my $Success = $Self->{LinkObject}->LinkAdd(
            SourceObject => 'Person',
            SourceKey    => $User{UserLogin},
            TargetObject => 'Ticket',
            TargetKey    => $Data{TicketID},
            Type         => 'Agent',
            UserID       => $Param{UserID},
        );

        $Self->{TicketObject}->HistoryAdd(
            Name         => 'added involved person ' . $User{UserLogin},
            HistoryType  => 'TicketLinkAdd',
            TicketID     => $Ticket{TicketID},
            CreateUserID => 1,
        );
    }

    elsif ( $Param{Event} eq 'TicketCustomerUpdate' )
    {

        my %Ticket = $Self->{TicketObject}->TicketGet(
            TicketID => $Data{TicketID},
            UserID   => 1,
        );
        my %ContactData =
            $Self->{ContactObject}->ContactGet( ID => $Ticket{ContactID} );

        $Blacklisted = 0;
        for my $Item (@Blacklist) {
            next if $Ticket{ContactID} !~ m/$Item/ && $ContactData{Email} !~ m/$Item/;
            $Blacklisted = 1;
            last;
        }
        return 1 if $Blacklisted;

        my $Success = $Self->{LinkObject}->LinkAdd(
            SourceObject => 'Person',
            SourceKey    => $Ticket{ContactID},
            TargetObject => 'Ticket',
            TargetKey    => $Data{TicketID},
            Type         => 'Customer',
            UserID       => $Param{UserID},
        );

        $Self->{TicketObject}->HistoryAdd(
            Name         => 'added involved person ' . $Ticket{ContactID},
            HistoryType  => 'TicketLinkAdd',
            TicketID     => $Ticket{TicketID},
            CreateUserID => 1,
        );
    }

    elsif ( $Param{Event} eq 'TicketMerge' ) {
        return if !$Data{MainTicketID};

        # get ticket data and ticket state
        my %Ticket = $Self->{TicketObject}->TicketGet(
            TicketID => $Data{TicketID},
            UserID   => 1,
        );
        my %State = $Self->{StateObject}->StateGet( ID => $Ticket{StateID} );

        # if ticket is merged, linked persons will be added to target
        if ( $State{TypeName} eq 'merged' ) {

            my $LinkList = $Self->{LinkObject}->LinkList(
                Object  => 'Ticket',
                Key     => $Data{TicketID},
                Object2 => 'Person',
                State   => 'Valid',
                UserID  => 1,
            );

            for my $LinkType ( keys %{ $LinkList->{Person} } ) {
                for my $Person ( keys %{ $LinkList->{Person}->{$LinkType}->{Source} } ) {

                    $Blacklisted = 0;
                    for my $Item (@Blacklist) {
                        next if $Person !~ m/$Item/;
                        $Blacklisted = 1;
                        last;
                    }
                    next if $Blacklisted;

                    my $Success = $Self->{LinkObject}->LinkAdd(
                        SourceObject => 'Person',
                        SourceKey    => $Person,
                        TargetObject => 'Ticket',
                        TargetKey    => $Data{MainTicketID},
                        Type         => $LinkType,
                        UserID       => $Param{UserID},
                    );

                    $Self->{TicketObject}->HistoryAdd(
                        Name         => 'added involved person ',
                        HistoryType  => 'TicketLinkAdd',
                        TicketID     => $Data{MainTicketID},
                        CreateUserID => 1,
                    );
                }
            }
        }
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
