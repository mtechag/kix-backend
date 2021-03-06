# --
# Modified version of the work: Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

use Kernel::System::VariableCheck qw(:all);

# get needed objects
my $ConfigObject           = $Kernel::OM->Get('Config');
my $TransitionActionObject = $Kernel::OM->Get('ProcessManagement::TransitionAction');

# define needed variables
my $RandomID = $Kernel::OM->Get('UnitTest::Helper')->GetRandomID();

# TransitionActionGet() tests
my @Tests = (
    {
        Name              => 'No Parameters',
        TransitionActions => {
            'TA1' . $RandomID => {
                Name   => 'Queue Move',
                Module => 'ProcessManagement::TransitionAction::TicketQueueSet',
                Config => {
                    Queue => 'Misc',
                },
            },
        },
        Config  => {},
        Success => 0,
    },
    {
        Name              => 'No TransitionActionEntityID',
        TransitionActions => {
            'TA1' . $RandomID => {
                Name   => 'Queue Move',
                Module => 'ProcessManagement::TransitionAction::TicketQueueSet',
                Config => {
                    Queue => 'Misc',
                },
            },
        },
        Config => {
            Other => 1,
        },
        Success => 0,
    },
    {
        Name              => 'Wrong TransitionActionEntityID',
        TransitionActions => {
            'TA1' . $RandomID => {
                Name   => 'Queue Move',
                Module => 'ProcessManagement::TransitionAction::TicketQueueSet',
                Config => {
                    Queue => 'Misc',
                },
            },
        },
        Config => {
            TransitionActionEntityID => 'Notexisiting' . $RandomID,
        },
        Success => 0,
    },
    {
        Name              => 'No TransitionActions Configuration',
        TransitionActions => {},
        Config            => {
            TransitionActionEntityID => 'TA1' . $RandomID,
        },
        Success => 0,
    },
    {
        Name              => 'Wrong Module',
        TransitionActions => {
            'TA1' . $RandomID => {
                Name   => 'Queue Move',
                Module => 'ProcessManagement::TransitionAction::NotExistingModule',
                Config => {
                    Queue => 'Misc',
                },
            },
        },
        Config => {
            TransitionActionEntityID => 'TA1' . $RandomID,
        },
        Success => 0,
    },
    {
        Name              => 'Correct ASCII',
        TransitionActions => {
            'TA1' . $RandomID => {
                Name   => 'Queue Move',
                Module => 'ProcessManagement::TransitionAction::TicketQueueSet',
                Config => {
                    Queue => 'Misc',
                },
            },
        },
        Config => {
            TransitionActionEntityID => 'TA1' . $RandomID,
        },
        Success => 1,
    },
    {
        Name              => 'Correct UTF8',
        TransitionActions => {
            'TA1' . $RandomID => {
                Name =>
                    'äöüßÄÖÜ€исáéíúóúÁÉÍÓÚñÑ-カスタ-用迎使用-Язык',
                Module => 'ProcessManagement::TransitionAction::TicketQueueSet',
                Config => {
                    Queue => 'Junk',
                },
            },
        },
        Config => {
            TransitionActionEntityID => 'TA1' . $RandomID,
        },
        Success => 1,
    },
);

for my $Test (@Tests) {

    # set transition action config
    $ConfigObject->Set(
        Key   => 'Process::TransitionAction',
        Value => $Test->{TransitionActions},
    );

    # get transition action described in test
    my $TransitionAction = $TransitionActionObject->TransitionActionGet( %{ $Test->{Config} } );

    if ( $Test->{Success} ) {
        $Self->IsNot(
            $TransitionAction,
            undef,
            "TransitionActionGet() Test:'$Test->{Name}' | should not be undef"
        );
        $Self->Is(
            ref $TransitionAction,
            'HASH',
            "TransitionActionGet() Test:'$Test->{Name}' | should be a HASH"
        );
        $Self->IsDeeply(
            $TransitionAction,
            $Test->{TransitionActions}->{ $Test->{Config}->{TransitionActionEntityID} },
            "TransitionActionGet() Test:'$Test->{Name}' | comparison"
        );
    }
    else {
        $Self->Is(
            $TransitionAction,
            undef,
            "TransitionActionGet() Test:'$Test->{Name}' | should be undef"
        );
    }
}

# TransitionActionList() tests
@Tests = (
    {
        Name              => 'No Params',
        TransitionActions => {
            'TA1' . $RandomID => {
                Name   => 'Queue Move',
                Module => 'ProcessManagement::TransitionAction::TicketQueueSet',
                Config => {
                    Queue => 'Misc',
                },
            },
        },
        Config  => {},
        Success => 0,
    },
    {
        Name              => 'No TransitionActionEntityID',
        TransitionActions => {
            'TA1' . $RandomID => {
                Name   => 'Queue Move',
                Module => 'ProcessManagement::TransitionAction::TicketQueueSet',
                Config => {
                    Queue => 'Misc',
                },
            },
        },
        Config => {
            Other => 1,
        },
        Success => 0,
    },
    {
        Name              => 'Wrong TransitionActionEntityID format',
        TransitionActions => {
            'TA1' . $RandomID => {
                Name   => 'Queue Move',
                Module => 'ProcessManagement::TransitionAction::TicketQueueSet',
                Config => {
                    Queue => 'Misc',
                },
            },
        },
        Config => {
            TransitionActionEntityID => 'TA1' . $RandomID,
        },
        Success => 0,
    },
    {
        Name              => 'Wrong TransitionActionEntityID',
        TransitionActions => {
            'TA1' . $RandomID => {
                Name   => 'Queue Move',
                Module => 'ProcessManagement::TransitionAction::TicketQueueSet',
                Config => {
                    Queue => 'Misc',
                },
            },
        },
        Config => {
            TransitionActionEntityID => [ 'NotExistent' . $RandomID ],
        },
        Success => 0,
    },
    {
        Name              => 'Wrong TransitionAction Module',
        TransitionActions => {
            'TA1' . $RandomID => {
                Name   => 'Queue Move',
                Module => 'ProcessManagement::TransitionAction::NotExisiting',
                Config => {
                    Queue => 'Misc',
                },
            },
        },
        Config => {
            TransitionActionEntityID => [ 'TA1' . $RandomID ],
        },
        Success => 0,
    },
    {
        Name              => 'Correct Single',
        TransitionActions => {
            'TA1' . $RandomID => {
                Name   => 'Queue Move',
                Module => 'ProcessManagement::TransitionAction::TicketQueueSet',
                Config => {
                    Queue => 'Misc',
                },
            },
            'TA2' . $RandomID => {
                Name   => 'Customer Set',
                Module => 'ProcessManagement::TransitionAction::TicketCustomerSet',
                Config => {
                    Param1 => 1,
                },
            },
            'TA3' . $RandomID => {
                Name => 'Article Create',
                Module =>
                    'ProcessManagement::TransitionAction::TicketArticleCreate',
                Config => {
                    Param1 => 1,
                },
            },
        },
        Config => {
            TransitionActionEntityID => [ 'TA1' . $RandomID ],
        },
        Success => 1,
    },
    {
        Name              => 'Correct Multiple 2TA',
        TransitionActions => {
            'TA1' . $RandomID => {
                Name   => 'Queue Move',
                Module => 'ProcessManagement::TransitionAction::TicketQueueSet',
                Config => {
                    Queue => 'Misc',
                },
            },
            'TA2' . $RandomID => {
                Name   => 'Customer Set',
                Module => 'ProcessManagement::TransitionAction::TicketCustomerSet',
                Config => {
                    Param1 => 1,
                },
            },
            'TA3' . $RandomID => {
                Name => 'Article Create',
                Module =>
                    'ProcessManagement::TransitionAction::TicketArticleCreate',
                Config => {
                    Param1 => 1,
                },
            },
        },
        Config => {
            TransitionActionEntityID => [
                'TA2' . $RandomID,
                'TA1' . $RandomID,
            ],
        },
        Success => 1,
    },
    {
        Name              => 'Correct Multiple 3TA',
        TransitionActions => {
            'TA1' . $RandomID => {
                Name   => 'Queue Move',
                Module => 'ProcessManagement::TransitionAction::TicketQueueSet',
                Config => {
                    Queue => 'Misc',
                },
            },
            'TA2' . $RandomID => {
                Name   => 'Customer Set',
                Module => 'ProcessManagement::TransitionAction::TicketCustomerSet',
                Config => {
                    Param1 => 1,
                },
            },
            'TA3' . $RandomID => {
                Name => 'Article Create',
                Module =>
                    'ProcessManagement::TransitionAction::TicketArticleCreate',
                Config => {
                    Param1 => 1,
                },
            },
        },
        Config => {
            TransitionActionEntityID => [
                'TA1' . $RandomID,
                'TA2' . $RandomID,
                'TA3' . $RandomID,
            ],
        },
        Success => 1,
    },
);

for my $Test (@Tests) {

    # set activity config
    $ConfigObject->Set(
        Key   => 'Process::TransitionAction',
        Value => $Test->{TransitionActions},
    );

    # list get transition actions
    my $TransitionActionList = $TransitionActionObject->TransitionActionList( %{ $Test->{Config} } );

    if ( $Test->{Success} ) {
        $Self->IsNot(
            $TransitionActionList,
            undef,
            "TransitionActionList() Test:'$Test->{Name}' | should not be undef"
        );
        $Self->Is(
            ref $TransitionActionList,
            'ARRAY',
            "TransitionActionList() Test:'$Test->{Name}' | should be an ARRAY"
        );

        my @ExpectedTransitionActions;

        ENTITYID:
        for my $TransitionActionEntityID ( @{ $Test->{Config}->{TransitionActionEntityID} } ) {
            next ENTITYID if !$TransitionActionEntityID;

            # get the transition action form test config
            my %TransitionAction = %{ $Test->{TransitionActions}->{$TransitionActionEntityID} };

            # add the entity ID
            $TransitionAction{TransitionActionEntityID} = $TransitionActionEntityID;
            push @ExpectedTransitionActions, \%TransitionAction;
        }

        $Self->IsDeeply(
            $TransitionActionList,
            \@ExpectedTransitionActions,
            "TransitionActionList() Test:'$Test->{Name}' | comparison"
        );
    }
    else {
        $Self->Is(
            $TransitionActionList,
            undef,
            "TransitionActionList() Test:'$Test->{Name}' | should be undef"
        );
    }
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
