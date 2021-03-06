# --
# Modified version of the work: Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Automation::MacroAction::Ticket::TicketCreate;

use strict;
use warnings;
use utf8;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::Automation::MacroAction::Ticket::ArticleCreate);

our @ObjectDependencies = (
    'Config',
    'DynamicField',
    'DynamicField::Backend',
    'LinkObject',
    'Log',
    'State',
    'Ticket',
    'Time',
    'User',
);

=head1 NAME

Kernel::System::Automation::MacroAction::Ticket::TicketCreate - A module to create a ticket

=head1 SYNOPSIS

All TicketCreate functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Describe()

Describe this macro action module.

=cut

sub Describe {
    my ( $Self, %Param ) = @_;

    $Self->SUPER::Describe(%Param);
    $Self->Description(Kernel::Language::Translatable('Creates an ticket.'));
    $Self->AddOption(
        Name        => 'Contact',
        Label       => Kernel::Language::Translatable('Contact'),
        Description => Kernel::Language::Translatable('The login of the contact of the new ticket.'),
        Required    => 1,
    );
    $Self->AddOption(
        Name        => 'Lock',
        Label       => Kernel::Language::Translatable('Lock'),
        Description => Kernel::Language::Translatable('The lock state of the new ticket.'),
        Required    => 0,
    );
    $Self->AddOption(
        Name        => 'Organisation',
        Label       => Kernel::Language::Translatable('Organisation'),
        Description => Kernel::Language::Translatable('The number of the organisation of the new ticket. Primary organisation of contact will be used if omitted.'),
        Required    => 0,
    );
    $Self->AddOption(
        Name        => 'Owner',
        Label       => Kernel::Language::Translatable('Owner'),
        Description => Kernel::Language::Translatable('The login of the owner of the new ticket. Current user will be used if omitted.'),
        Required    => 0,
    );
    $Self->AddOption(
        Name        => 'Priority',
        Label       => Kernel::Language::Translatable('Priority'),
        Description => Kernel::Language::Translatable('The name of the priority of the new ticket.'),
        Required    => 1
    );
    $Self->AddOption(
        Name        => 'Responsible',
        Label       => Kernel::Language::Translatable('Responsible'),
        Description => Kernel::Language::Translatable('The login of the responsible of the new ticket. Root user (ID = 1) will be used if omitted.'),
        Required    => 0,
    );
    $Self->AddOption(
        Name        => 'State',
        Label       => Kernel::Language::Translatable('State'),
        Description => Kernel::Language::Translatable('The name of the state of the new ticket.'),
        Required    => 1,
    );
    $Self->AddOption(
        Name        => 'PendingTimeDiff',
        Label       => Kernel::Language::Translatable('Pending Time Difference'),
        Description => Kernel::Language::Translatable('(Optional) The pending time in seconds. Will be added to the actual time when the macro action is executed. Used for pending states only.'),
        Required    => 0,
    );
    $Self->AddOption(
        Name        => 'Title',
        Label       => Kernel::Language::Translatable('Title'),
        Description => Kernel::Language::Translatable('The title of the new ticket and subject of the first article.'),
        Required    => 1,
    );
    $Self->AddOption(
        Name        => 'Team',
        Label       => Kernel::Language::Translatable('Team'),
        Description => Kernel::Language::Translatable('The name of the team of the new ticket.'),
        Required    => 1,
    );
    $Self->AddOption(
        Name        => 'Type',
        Label       => Kernel::Language::Translatable('Type'),
        Description => Kernel::Language::Translatable('The name of the type of the new ticket. Configured default will be used (Ticket::Type::Default) if omitted.'),
        Required    => 0,
    );
    delete $Self->{Definition}->{Options}->{Subject};

    return;
}

=item Run()

Run this module. Returns 1 if everything is ok.

Example:
    my $Success = $Object->Run(
        TicketID => 123,
        Config   => {
            # ticket required
            Title         => 'Some Ticket Title',
            Team          => 'Junk',
            Lock          => 'unlock',
            Priority      => '3 normal',
            State         => 'new',
            Contact       => 'someContactLogin',
            Owner         => 'someUserLogin',

            # optional parameter
            Organisation    => 'someOrganisationNumber',   # if omitted, primary organisation of contact is used
            Type            => 'Incident',
            Responsible     => 'someUserLogin',
            PendingTimeDiff => 3600 ,                      # optional (for pending states)

            # article parameter, see ArticleCreate
        },
        UserID   => 123
    );

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # check incoming parameters
    return if !$Self->_CheckParams(%Param);
    return if !$Self->_CheckTicketParams(
        %{$Param{Config}},
        UserID => $Param{UserID}
    );

    # collect ticket params (organisation have to be before contact)
    my %TicketParam;
    for my $Attribute ( qw(Organisation Contact Lock Owner Priority Responsible State Title Team Type) ) {
        if ( defined $Param{Config}->{$Attribute} ) {
            if ( $Attribute eq 'Owner' || $Attribute eq 'Responsible' ) {
                my $UserID = $Kernel::OM->Get('User')->UserLookup(
                    UserLogin => $Param{Config}->{$Attribute},
                );
                $TicketParam{$Attribute . 'ID'} = $UserID;
            } elsif ($Attribute eq 'Organisation') {
                my $OrganisationID = $Kernel::OM->Get('Organisation')->OrganisationLookup(
                    Number => $Param{Config}->{Organisation},
                    Silent => 1
                );
                $TicketParam{'OrganisationID'} = $OrganisationID || $Param{Config}->{Organisation};
            } elsif ($Attribute eq 'Contact') {
                my $ContactID;
                
                if ($Param{Config}->{Contact} =~ /\d+/) {
                    $ContactID = $Kernel::OM->Get('Contact')->ContactLookup(
                        ID  => $Param{Config}->{Contact},
                        Silent => 1
                    );
                } elsif ( index($Param{Config}->{Contact}, '@') != -1 ) {
                    $ContactID = $Kernel::OM->Get('Contact')->ContactLookup(
                        Email  => $Param{Config}->{Contact},
                        Silent => 1
                    );
                }

                if (!$TicketParam{OrganisationID}) {
                    if ($ContactID) {
                        my %Contact = $Kernel::OM->Get('Contact')->ContactGet(
                            ID => $ContactID
                        );
                        $TicketParam{OrganisationID} = $Contact{PrimaryOrganisationID};
                    }
                }

                $TicketParam{'ContactID'} = $ContactID || $Param{Config}->{Contact};

            } else {
                $TicketParam{$Attribute} = $Param{Config}->{$Attribute}
            }
        }
    }

    if (!$TicketParam{OwnerID}) {
        $TicketParam{OwnerID} = $Param{UserID};
    }

    if (!$TicketParam{Lock}) {
        $TicketParam{Lock} = 'unlock';
    }

    my $TicketObject = $Kernel::OM->Get('Ticket');

    $TicketParam{Title} = $Kernel::OM->Get('TemplateGenerator')->ReplacePlaceHolder(
        RichText => 0,
        Text     => $TicketParam{Title},
        TicketID => $Param{TicketID},
        Data     => {
            %TicketParam,
            Queue => $TicketParam{Team}
        },
        UserID   => $Param{UserID},
    );

    # create ticket
    my $TicketID = $TicketObject->TicketCreate(
        %TicketParam,
        Queue => $TicketParam{Team},
        UserID => $Param{UserID}
    );

    if ( !$TicketID ) {
        $Kernel::OM->Get('Automation')->LogError(
            Referrer => $Self,
            Message  => "Couldn't create new ticket!",
            UserID   => $Param{UserID}
        );
        return;
    }

    # get state information
    my %StateData = $Kernel::OM->Get('State')->StateGet(
        Name => $TicketParam{State},
    );

    if ( $StateData{TypeName} =~ /^close/i ) {

        # closed tickets get unlocked
        $TicketObject->TicketLockSet(
            TicketID => $TicketID,
            Lock     => 'unlock',
            UserID   => $Param{UserID},
        );
    } elsif ( $StateData{TypeName} =~ m{\A pending}msxi ) {

        # set pending time
        $TicketObject->TicketPendingTimeSet(
            UserID   => $Param{UserID},
            TicketID => $TicketID,
            Diff     => $Param{Config}->{PendingTimeDiff},
        );
    }

    # remember ticket definition
    my $TicketDef = $Self->{Definition}->{Options};

    # use article definition
    $Self->{Definition}->{Options} = {};
    $Self->SUPER::Describe(%Param);

    # collect article params based on definition
    my %ArticleParam;
    if ( IsHashRefWithData($Self->{Definition}->{Options}) ) {
        for my $Attribute ( %{$Self->{Definition}->{Options}} ) {
            if ( defined $Param{Config}->{$Attribute} ) {
                $ArticleParam{$Attribute} = $Param{Config}->{$Attribute}
            }
        }
    }
    $ArticleParam{Subject} = $TicketParam{Title};
    $ArticleParam{Body} = $Kernel::OM->Get('TemplateGenerator')->ReplacePlaceHolder(
        RichText => 1,
        Text     => $ArticleParam{Body},
        TicketID => $Param{TicketID},
        Data     => {
            %TicketParam,
            Queue => $TicketParam{Team}
        },
        UserID   => $Param{UserID},
    );

    # create article
    my $ArticleBackendResult = $Self->SUPER::Run(
        Config   => \%ArticleParam,
        TicketID => $TicketID,
        UserID   => $Param{UserID}
    );

    # reset definition
    $Self->{Definition}->{Options} = $TicketDef;

    if ( !$ArticleBackendResult ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Couldn't create Article on Ticket: $TicketID!",
        );
        return;
    }

    return 1;
}

=item ValidateConfig()

Validates the parameters of the config.

Example:
    my $Valid = $Self->ValidateConfig(
        Config => {}                # required
    );

=cut

sub ValidateConfig {
    my ( $Self, %Param ) = @_;

    return if !$Self->SUPER::ValidateConfig(%Param);

    my %State = $Kernel::OM->Get('State')->StateGet(
        Name => $Param{Config}->{State}
    );

    if (%State) {
        if ( $State{TypeName} =~ m{\A pending}msxi && !IsNumber( $Param{Config}->{PendingTimeDiff} ) ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Validation of parameter \"PendingTimeDiff\" failed!"
            );
            return;
        }
    }

    return 1;
}

sub _CheckTicketParams {
    my ( $Self, %Param ) = @_;

    # if ($Param{Contact}) {
    #     my $ContactID = $Kernel::OM->Get('Contact')->ContactLookup(
    #         Login  => $Param{Contact},
    #         Silent => 1
    #     );

    #     if ( !$ContactID ) {
    #         $Kernel::OM->Get('Automation')->LogError(
    #             Referrer => $Self,
    #             Message  => "Couldn't create new ticket - can't find contact with login \"$Param{Contact}\"!",
    #             UserID   => $Param{UserID}
    #         );
    #         return;
    #     }
    # }

    if ($Param{Lock}) {
        my $LockID = $Kernel::OM->Get('Lock')->LockLookup(
            Lock => $Param{Lock},
        );

        if ( !$LockID ) {
            $Kernel::OM->Get('Automation')->LogError(
                Referrer => $Self,
                Message  => "Couldn't create new ticket - can't find lock state \"$Param{Lock}\"!",
                UserID   => $Param{UserID}
            );
            return;
        }
    }

    # if ($Param{Organisation}) {
    #     my $OrganisationID = $Kernel::OM->Get('Organisation')->OrganisationLookup(
    #         Number => $Param{Organisation},
    #         Silent => 1
    #     );

    #     if ( !$OrganisationID ) {
    #         $Kernel::OM->Get('Automation')->LogError(
    #             Referrer => $Self,
    #             Message  => "Couldn't create new ticket - can't find organisation with number \"$Param{Organisation}\"!",
    #             UserID   => $Param{UserID}
    #         );
    #         return;
    #     }
    # }

    for my $UserType ( qw(Owner Responsible) ) {
        if ($Param{$UserType}) {
            my $UserID = $Kernel::OM->Get('User')->UserLookup(
                UserLogin => $Param{$UserType},
            );

            if ( !$UserID ) {
                $Kernel::OM->Get('Automation')->LogError(
                    Referrer => $Self,
                    Message  => "Couldn't create new ticket - can't find user with login \"$Param{$UserType}\"!",
                    UserID   => $Param{UserID}
                );
                return;
            }
        }
    }

    if ($Param{Priority}) {
        my $PriorityID = $Kernel::OM->Get('Priority')->PriorityLookup(
            Priority => $Param{Priority}
        );

        if ( !$PriorityID ) {
            $Kernel::OM->Get('Automation')->LogError(
                Referrer => $Self,
                Message  => "Couldn't create new ticket - can't find ticket priority \"$Param{Priority}\"!",
                UserID   => $Param{UserID}
            );
            return;
        }
    }

    if ($Param{State}) {
        my %State = $Kernel::OM->Get('State')->StateGet(
            Name => $Param{State}
        );

        if ( !%State ) {
            $Kernel::OM->Get('Automation')->LogError(
                Referrer => $Self,
                Message  => "Couldn't create new ticket - can't find ticket state \"$Param{State}\"!",
                UserID   => $Param{UserID}
            );
            return;
        }

        if ( $State{TypeName} =~ m{\A pending}msxi && !IsNumber( $Param{PendingTimeDiff} ) ) {
            $Kernel::OM->Get('Automation')->LogError(
                Referrer => $Self,
                Message  => "Couldn't create new ticket - \"PendingTimeDiff\" value ($Param{PendingTimeDiff}) is not valid!",
                UserID   => $Param{UserID}
            );
            return;
        }
    }

    if ($Param{Team}) {
        my $QueueID = $Kernel::OM->Get('Queue')->QueueLookup(
            Queue => $Param{Team}
        );

        if ( !$QueueID ) {
            $Kernel::OM->Get('Automation')->LogError(
                Referrer => $Self,
                Message  => "Couldn't create new ticket - can't find ticket team \"$Param{Team}\"!",
                UserID   => $Param{UserID}
            );
            return;
        }
    }

    if ($Param{Type}) {
        my $TypeID = $Kernel::OM->Get('Type')->TypeLookup(
            Type => $Param{Type},
        );

        if ( !$TypeID ) {
            $Kernel::OM->Get('Automation')->LogError(
                Referrer => $Self,
                Message  => "Couldn't create new ticket - can't find ticket type \"$Param{Type}\"!",
                UserID   => $Param{UserID}
            );
            return;
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
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
