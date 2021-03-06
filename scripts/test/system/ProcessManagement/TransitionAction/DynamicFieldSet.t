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

# get helper object
$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

# define variables
my $UserID     = 1;
my $ModuleName = 'DynamicFieldSet';
my $RandomID   = $Helper->GetRandomID();
my $DFName1    = 'Test1' . $RandomID;
my $DFName2    = 'Test2' . $RandomID;

# set user details
my $TestUserLogin = $Helper->TestUserCreate();
my $TestUserID    = $Kernel::OM->Get('User')->UserLookup(
    UserLogin => $TestUserLogin,
);

# ----------------------------------------
# Create the dynamic fields for testing
# ----------------------------------------

my @NewDynamicFieldConfig = (
    {
        Name       => $DFName1,
        Label      => $DFName1,
        FieldType  => 'Dropdown',
        ObjectType => 'Ticket',
        Config     => {
            TranslatableValues => '0',
            PossibleValues     => {
                1 => 'A',
                2 => 'B',
                3 => 'C',
            },
        },
    },
    {
        Name       => $DFName2,
        Label      => $DFName2,
        FieldType  => 'Checkbox',
        ObjectType => 'Ticket',
        Config     => {
            DefaultValue => '',
        },
    },

);

my @AddedDynamicFields;
for my $DynamicFieldConfig (@NewDynamicFieldConfig) {

    # add the new dynamic field
    my $ID = $Kernel::OM->Get('DynamicField')->DynamicFieldAdd(
        %{$DynamicFieldConfig},
        FieldOrder => 99999,
        ValidID    => 1,
        UserID     => 1,
    );

    push @AddedDynamicFields, $ID;

    # sanity check
    $Self->True(
        $ID,
        "DynamicFieldAdd() - DynamicField: $ID for DynamicFieldSet"
            . " checks with True",
    );
}

# get ticket object
my $TicketObject = $Kernel::OM->Get('Ticket');

# ----------------------------------------
# Create a test ticket
# ----------------------------------------
my $TicketID = $TicketObject->TicketCreate(
    Title         => 'test',
    QueueID       => 1,
    Lock          => 'unlock',
    Priority      => '3 normal',
    StateID       => 1,
    TypeID        => 1,
    OwnerID       => 1,
    ResponsibleID => 1,
    UserID        => $UserID,
);

# sanity checks
$Self->True(
    $TicketID,
    "TicketCreate() - $TicketID",
);

my %Ticket = $TicketObject->TicketGet(
    TicketID => $TicketID,
    UserID   => $UserID,
);
$Self->True(
    IsHashRefWithData( \%Ticket ),
    "TicketGet() - Get Ticket with ID $TicketID.",
);

# Run() tests
my @Tests = (
    {
        Name    => 'No Params',
        Config  => undef,
        Success => 0,
    },
    {
        Name   => 'No UserID',
        Config => {
            UserID => undef,
            Ticket => \%Ticket,
            Config => {
                $DFName1 => 1,
            },
        },
        Success => 0,
    },
    {
        Name   => 'No Ticket',
        Config => {
            UserID => $UserID,
            Ticket => undef,
            Config => {
                $DFName1 => 1,
            },
        },
        Success => 0,
    },
    {
        Name   => 'No Config',
        Config => {
            UserID => $UserID,
            Ticket => \%Ticket,
            Config => {},
        },
        Success => 0,
    },
    {
        Name   => 'Wrong Config',
        Config => {
            UserID => $UserID,
            Ticket => \%Ticket,
            Config => {
                NoAgentNotify => 0,
            },
        },
        Success => 0,
    },
    {
        Name   => 'Wrong Ticket Format',
        Config => {
            UserID => $UserID,
            Ticket => 1,
            Config => {
                $DFName1 => '1',
            },
        },
        Success => 0,
    },
    {
        Name   => 'Wrong Config Format',
        Config => {
            UserID => $UserID,
            Ticket => \%Ticket,
            Config => 1,
        },
        Success => 0,
    },
    {
        Name   => 'Correct ASCII Dropdown',
        Config => {
            UserID => $UserID,
            Ticket => \%Ticket,
            Config => {
                $DFName1 => 'TestString',
            },
        },
        Success => 1,
    },
    {
        Name   => 'Correct ASCII Checkbox',
        Config => {
            UserID => $UserID,
            Ticket => \%Ticket,
            Config => {
                $DFName2 => 1,
            },
        },
        Success => 1,
    },
    {
        Name   => 'Correct ASCII Dropdown && Checkbox',
        Config => {
            UserID => $UserID,
            Ticket => \%Ticket,
            Config => {
                $DFName1 => 1,
                $DFName2 => 0,
            },
        },
        Success => 1,
    },
    {
        Name   => 'Correct UTF8 Dropdown',
        Config => {
            UserID => $UserID,
            Ticket => \%Ticket,
            Config => {
                $DFName1 =>
                    'äöüßÄÖÜ€исáéíúóúÁÉÍÓÚñÑ-カスタ-用迎使用-Язык',
            },
        },
        Success => 1,
    },
    {
        Name   => 'Correct Ticket->Queue Dropdown',
        Config => {
            UserID => $UserID,
            Ticket => \%Ticket,
            Config => {
                $DFName1 => '<KIX_TICKET_Queue>',
            },
        },
        Success => 1,
    },
    {
        Name   => 'Correct Ticket->Queue + Ticket->QueueID Dropdown',
        Config => {
            UserID => $UserID,
            Ticket => \%Ticket,
            Config => {
                $DFName1 => '<KIX_TICKET_Queue> <KIX_TICKET_QueueID>',
            },
        },
        Success => 1,
    },
    {
        Name   => 'Correct Ticket->NotExisting Dropdown',
        Config => {
            UserID => $UserID,
            Ticket => \%Ticket,
            Config => {
                $DFName1 => '<KIX_TICKET_NotExisting>',
            },
        },
        NoValue => 1,
        Success => 1,
    },
    {
        Name   => 'Correct Using Different UserID',
        Config => {
            UserID => $UserID,
            Ticket => \%Ticket,
            Config => {
                $DFName1 => 'Test',
                UserID   => $TestUserID,
            },
        },
        Success => 1,
    },
);

TEST:
for my $Test (@Tests) {

    # make a deep copy to avoid changing the definition
    my $OrigTest = Storable::dclone($Test);

    my $Success = $Kernel::OM->Get('ProcessManagement::TransitionAction::DynamicFieldSet')->Run(
        %{ $Test->{Config} },
        ProcessEntityID          => 'P1',
        ActivityEntityID         => 'A1',
        TransitionEntityID       => 'T1',
        TransitionActionEntityID => 'TA1',
    );

    if ( !$Test->{Success} ) {
        $Self->False(
            $Success,
            "$ModuleName Run() - Test:'$Test->{Name}' | executed with False"
        );
        next TEST;
    }

    $Self->True(
        $Success,
        "$ModuleName Run() - Test:'$Test->{Name}' | executed with True"
    );

    # get ticket
    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $TicketID,
        DynamicFields => 1,
        UserID        => 1,
    );

    ATTRIBUTE:
    for my $Attribute ( sort keys %{ $Test->{Config}->{Config} } ) {

        if ( $Test->{NoValue} ) {
            $Self->False(
                defined $Ticket{ 'DynamicField_' . $Attribute },
                "$ModuleName - Test:'$Test->{Name}' | Attribute: DynamicField_" . $Attribute
                    . " for TicketID: $TicketID exists with True",
            );
            next TEST;
        }

        $Self->True(
            defined $Ticket{ 'DynamicField_' . $Attribute },
            "$ModuleName - Test:'$Test->{Name}' | Attribute: DynamicField_" . $Attribute
                . " for TicketID: $TicketID exists with True",
        );

        my $ExpectedValue = $Test->{Config}->{Config}->{$Attribute};
        if (
            $OrigTest->{Config}->{Config}->{$Attribute}
            =~ m{\A<KIX_TICKET_([A-Za-z0-9_]+)>\z}msx
            )
        {
            $ExpectedValue = $Ticket{$1} // '';
            $Self->IsNot(
                $Test->{Config}->{Config}->{$Attribute},
                $OrigTest->{Config}->{Config}->{$Attribute},
                "$ModuleName - Test:'$Test->{Name}' | Attribute: DynamicField_$Attribute value: $OrigTest->{Config}->{Config}->{$Attribute} should been replaced",
            );
        }
        elsif (
            $OrigTest->{Config}->{Config}->{$Attribute}
            =~ m{\A<KIX_TICKET_([A-Za-z0-9_]+)> [ ] <KIX_TICKET_([A-Za-z0-9_]+)>\z}msx
            )
        {
            $ExpectedValue = ( $Ticket{$1} // '' ) . ' ' . ( $Ticket{$2} // '' );
            $Self->IsNot(
                $Test->{Config}->{Config}->{$Attribute},
                $OrigTest->{Config}->{Config}->{$Attribute},
                "$ModuleName - Test:'$Test->{Name}' | Attribute: DynamicField_$Attribute value: $OrigTest->{Config}->{Config}->{$Attribute} should been replaced",
            );
        }

        $Self->Is(
            $Ticket{ 'DynamicField_' . $Attribute },
            $ExpectedValue,
            "$ModuleName - Test:'$Test->{Name}' | Attribute: DynamicField_" . $Attribute
                . " for TicketID: $TicketID match expected value",
        );
    }

    if ( $OrigTest->{Config}->{Config}->{UserID} ) {
        $Self->Is(
            $Test->{Config}->{Config}->{UserID},
            undef,
            "$ModuleName - Test:'$Test->{Name}' | Attribute: UserID for TicketID:"
                . " $TicketID should be removed (as it was used)",
        );
    }
}

# cleanup is done by RestoreDatabase

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
