# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::Contact::ContactGet;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Contact::ContactGet - API Contact Get Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation::V1::Contact::ContactGet->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw(DebuggerObject WebserviceID)) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => 'Operation.InternalError',
                Message => "Got no $Needed!"
            );
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    # get config for this screen
    $Self->{Config} = $Kernel::OM->Get('Config')->Get('API::Operation::V1::Contact::ContactGet');

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
        'ContactID' => {
            DataType => 'NUMERIC',
            Type     => 'ARRAY',
            Required => 1
        }                
    }
}

=item Run()

perform ContactGet Operation. This function is able to return
one or more ticket entries in one call.

    my $Result = $OperationObject->Run(
        Data => {
            ContactID => 123       # comma separated in case of multiple or arrayref (depending on transport)
        },
    );

    $Result = {
        Success      => 1,                                # 0 or 1
        Code         => '...'
        Message      => '',                               # In case of an error
        Data         => {
            Contact => [
                {
                    ...
                },
                {
                    ...
                },
            ]
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    my @ContactList;
  
    # start loop
    foreach my $ContactID ( @{$Param{Data}->{ContactID}} ) {

        # get the Contact data
        my %ContactData = $Kernel::OM->Get('Contact')->ContactGet(
            ID => $ContactID,
        );

        if ( !IsHashRefWithData( \%ContactData ) ) {

            return $Self->_Error(
                Code => 'Object.NotFound',
            );
        }

        # filter valid attributes
        if ( IsHashRefWithData($Self->{Config}->{AttributeWhitelist}) ) {
            foreach my $Attr (sort keys %ContactData) {
                delete $ContactData{$Attr} if !$Self->{Config}->{AttributeWhitelist}->{$Attr};
            }
        }

        # filter valid attributes
        if ( IsHashRefWithData($Self->{Config}->{AttributeBlacklist}) ) {
            foreach my $Attr (sort keys %ContactData) {
                delete $ContactData{$Attr} if $Self->{Config}->{AttributeBlacklist}->{$Attr};
            }
        }

        # include TicketStats if requested
        if ( $Param{Data}->{include}->{TicketStats} ) {
            # execute ticket searches
            my %TicketStats;
            # new tickets
            $TicketStats{NewCount} = $Kernel::OM->Get('Ticket')->TicketSearch(
                Search => {
                    AND => [
                        {
                            Field    => 'ContactID',
                            Operator => 'EQ',
                            Value    => $ContactID,
                        },
                        {
                            Field    => 'StateType',
                            Operator => 'EQ',
                            Value    => 'new',
                        },
                    ]
                },
                UserID => $Self->{Authorization}->{UserID},
                Result => 'COUNT',
            );
            # open tickets
            $TicketStats{OpenCount} = $Kernel::OM->Get('Ticket')->TicketSearch(
                Search => {
                    AND => [
                        {
                            Field    => 'ContactID',
                            Operator => 'EQ',
                            Value    => $ContactID,
                        },
                        {
                            Field    => 'StateType',
                            Operator => 'EQ',
                            Value    => 'open',
                        },
                    ]
                },
                UserID => $Self->{Authorization}->{UserID},
                Result => 'COUNT',
            );
            # pending tickets
            $TicketStats{PendingReminderCount} = $Kernel::OM->Get('Ticket')->TicketSearch(
                Search => {
                    AND => [
                        {
                            Field    => 'ContactID',
                            Operator => 'EQ',
                            Value    => $ContactID,
                        },
                        {
                            Field    => 'StateType',
                            Operator => 'EQ',
                            Value    => 'pending reminder',
                        },
                    ]
                },
                UserID => $Self->{Authorization}->{UserID},
                Result => 'COUNT',
            );
            # escalated tickets
            $TicketStats{EscalatedCount} = $Kernel::OM->Get('Ticket')->TicketSearch(
                Search => {
                    AND => [
                        {
                            Field    => 'ContactID',
                            Operator => 'EQ',
                            Value    => $ContactID,
                        },
                        {
                            Field    => 'EscalationTime',
                            Operator => 'LT',
                            DataType => 'NUMERIC',
                            Value    => $Kernel::OM->Get('Time')->CurrentTimestamp(),
                        },
                    ]
                },
                UserID => $Self->{Authorization}->{UserID},
                Result => 'COUNT',
            );
            $ContactData{TicketStats} = \%TicketStats;

            # inform API caching about a new dependency
            $Self->AddCacheDependency(Type => 'Ticket');
            $Self->AddCacheDependency(Type => 'User');
        }

        # include assigned user if requested (and existing)

        #FIXME: workaround KIX2018-3308####################
        $Self->AddCacheDependency(Type => 'User');
        my $UserData;
        if ($ContactData{AssignedUserID}) {
            $UserData = $Self->ExecOperation(
                OperationType => 'V1::User::UserGet',
                Data          => {
                    UserID => $ContactData{AssignedUserID},
                }
            );
        }
        $ContactData{Login} = ($UserData && $UserData->{Success}) ? $UserData->{Data}->{User}->{UserLogin} : undef;
        #######################

        #comment back in when 3308 is resolved properly
        if ($Param{Data}->{include}->{User}) {
            # $Self->AddCacheDependency( Type => 'User' );
            # $ContactData{User} = undef;
            # if ($ContactData{AssignedUserID}) {
            #     my $UserData = $Self->ExecOperation(
            #         OperationType => 'V1::User::UserGet',
            #         Data          => {
            #             UserID => $ContactData{AssignedUserID},
            #         }
            #     );
                $ContactData{User} = ($UserData->{Success}) ? $UserData->{Data}->{User} : undef;
            # }
        }

        # include assigned config items if requested
        if ( $Param{Data}->{include}->{AssignedConfigItems} ) {

            # add user data for
            my %CIContact = %ContactData;
            if (!$CIContact{User} && $CIContact{AssignedUserID}) {
                my $UserData = $Self->ExecOperation(
                    OperationType => 'V1::User::UserGet',
                    Data          => {
                        UserID => $CIContact{AssignedUserID},
                    }
                );
                $CIContact{User} = ($UserData->{Success}) ? $UserData->{Data}->{User} : undef;
                $Self->AddCacheDependency(Type => 'User');
            }

            my $ItemIDs = $Kernel::OM->Get('ITSMConfigItem')->GetAssignedConfigItemsForObject(
                ObjectType => 'Contact',
                Object     => \%CIContact
            );

            # filter for customer assigned config items if necessary
            my @ConfigItemIDList = $Self->_FilterCustomerUserVisibleConfigItems(
                ConfigItemIDList => $ItemIDs
            );

            $ContactData{AssignedConfigItems} = \@ConfigItemIDList;

            $Self->AddCacheDependency(Type => 'ITSMConfigurationManagement');
        }

        # delete the UserID in %ContactData, because it's some backwards compatibility fix (KIX2018-2515) masking the
        # the contact ID as the user ID and should not be delivered through the API to the client.
        delete($ContactData{UserID});

        #always delete the User ID of the assigned User. If user information is requested, the assigned User Object is
        # included.
        #delete($ContactData{AssignedUserID});

        # add
        push(@ContactList, \%ContactData);
    }

    if ( scalar(@ContactList) == 1 ) {
        return $Self->_Success(
            Contact => $ContactList[0],
        );    
    }

    return $Self->_Success(
        Contact => \@ContactList,
    );
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
