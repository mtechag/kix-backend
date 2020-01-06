# --
# Modified version of the work: Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
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

# get needed objects
my $DynamicFieldObject = $Kernel::OM->Get('Kernel::System::DynamicField');
my $TicketObject       = $Kernel::OM->Get('Kernel::System::Ticket');
my $BackendObject      = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

# get helper object
$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

my @DynamicFields = map { $Helper->GetRandomID() } 1 .. 2;
my @Config;

for my $DynamicField (@DynamicFields) {
    my $ID = $DynamicFieldObject->DynamicFieldAdd(
        Name       => $DynamicField,
        Label      => 'test',
        FieldOrder => 123,
        FieldType  => 'Text',
        ObjectType => 'Ticket',
        Reorder    => 0,
        ValidID    => 1,
        UserID     => 1,
        Config     => { Test => 1 },
    );
    $Self->True( $ID, "Dynamic Field $DynamicField created" );

    push @Config, $DynamicFieldObject->DynamicFieldGet(
        ID => $ID,
    );
}

my $MainTicketID = $TicketObject->TicketCreate(
    Title        => 'Main Ticket',
    Queue        => 'Junk',
    Lock         => 'unlock',
    Priority     => '3 normal',
    CustomerNo   => '123456',
    Contact => 'customer@example.com',
    UserID       => 1,
    State        => 'new',
    OwnerID      => 1,
);

$Self->True( $MainTicketID, 'Could create main ticket' );

my $Success = $BackendObject->ValueSet(
    DynamicFieldConfig => $Config[0],
    ObjectID           => $MainTicketID,
    Value              => 'main 0',
    UserID             => 1,
);

$Self->True( $Success, 'Set dynamic field on main ticket' );

my $MergeTicketID = $TicketObject->TicketCreate(
    Title        => 'Merge Ticket',
    Queue        => 'Junk',
    Lock         => 'unlock',
    Priority     => '3 normal',
    CustomerNo   => '123456',
    Contact => 'customer@example.com',
    UserID       => 1,
    State        => 'new',
    OwnerID      => 1,
);

$Self->True( $MergeTicketID, 'Could create merge ticket' );

$BackendObject->ValueSet(
    DynamicFieldConfig => $Config[0],
    ObjectID           => $MergeTicketID,
    Value              => 'merge 0',
    UserID             => 1,
);

$BackendObject->ValueSet(
    DynamicFieldConfig => $Config[1],
    ObjectID           => $MergeTicketID,
    Value              => 'merge 1',
    UserID             => 1,
);

my %MergeTicket = $TicketObject->TicketGet(
    TicketID      => $MergeTicketID,
    UserID        => 1,
    DynamicFields => 1,
);

$TicketObject->TicketMergeDynamicFields(
    MainTicketID  => $MainTicketID,
    MergeTicketID => $MergeTicketID,
    UserID        => 1,
    DynamicFields => \@DynamicFields,
);

my %MainTicket = $TicketObject->TicketGet(
    TicketID      => $MainTicketID,
    UserID        => 1,
    DynamicFields => 1,
);

$Self->Is(
    $MainTicket{ 'DynamicField_' . $DynamicFields[0] },
    'main 0',
    'TicketMergeDynamicFields left existing DF in main ticket intact',
);

$Self->Is(
    $MainTicket{ 'DynamicField_' . $DynamicFields[1] },
    'merge 1',
    'TicketMergeDynamicFields copied DF from merge ticket',
);

# cleanup is done by RestoreDatabase.

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut