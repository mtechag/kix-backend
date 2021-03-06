# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;

use vars qw($Self);

use Kernel::System::PostMaster;

# add or update dynamic fields if needed
my $DynamicFieldObject = $Kernel::OM->Get('DynamicField');

my @DynamicfieldIDs;
my @DynamicFieldUpdate;
my %NeededDynamicfields = (
    SysMonXAlias  => 1,
    SysMonXAddress  => 1,
    SysMonXHost  => 1,
    SysMonXService  => 1,
    SysMonXState  => 1,
    ArticleFreeText1 => 1,
);

# list available dynamic fields
my $DynamicFields = $DynamicFieldObject->DynamicFieldList(
    Valid      => 0,
    ResultType => 'HASH',
);
$DynamicFields = ( ref $DynamicFields eq 'HASH' ? $DynamicFields : {} );
$DynamicFields = { reverse %{$DynamicFields} };

for my $FieldName ( sort keys %NeededDynamicfields ) {
    if ( !$DynamicFields->{$FieldName} ) {

        # create a dynamic field
        my $FieldID = $DynamicFieldObject->DynamicFieldAdd(
            Name       => $FieldName,
            Label      => $FieldName . "_test",
            FieldOrder => 9991,
            FieldType  => 'Text',
            ObjectType => 'Ticket',
            Config     => {
                DefaultValue => 'a value',
            },
            ValidID => 1,
            UserID  => 1,
        );

        # verify dynamic field creation
        $Self->True(
            $FieldID,
            "DynamicFieldAdd() successful for Field $FieldName",
        );

        push @DynamicfieldIDs, $FieldID;
    }
    else {
        my $DynamicField
            = $DynamicFieldObject->DynamicFieldGet( ID => $DynamicFields->{$FieldName} );

        if ( $DynamicField->{ValidID} > 1 ) {
            push @DynamicFieldUpdate, $DynamicField;
            $DynamicField->{ValidID} = 1;
            my $SuccessUpdate = $DynamicFieldObject->DynamicFieldUpdate(
                %{$DynamicField},
                Reorder => 0,
                UserID  => 1,
                ValidID => 1,
            );

            # verify dynamic field creation
            $Self->True(
                $SuccessUpdate,
                "DynamicFieldUpdate() successful update for Field $DynamicField->{Name}",
            );
        }
    }
}

# get needed objects
my $MainObject   = $Kernel::OM->Get('Main');
my $ConfigObject = $Kernel::OM->Get('Config');

my $FileArray = $MainObject->FileRead(
    Location => $ConfigObject->Get('Home') . '/scripts/test/system/sample/SystemMonitoring1X.box',
    Result => 'ARRAY',    # optional - SCALAR|ARRAY
);

my $PostMasterObject = Kernel::System::PostMaster->new(
    %{$Self},
    Email => $FileArray,
);

my @Return = $PostMasterObject->Run();
@Return = @{ $Return[0] || [] };

$Self->Is(
    $Return[0] || 0,
    1,
    "Run() - NewTicket",
);
$Self->True(
    $Return[1] || 0,
    "Run() - NewTicket/TicketID",
);

my $TicketObject = Kernel::System::Ticket->new( %{$Self} );
my %Ticket       = $TicketObject->TicketGet(
    TicketID      => $Return[1],
    DynamicFields => 1,
);

$Self->Is(
    $Ticket{DynamicField_SysMonXHost},
    'ANDROMEDA',
    "Host check",
);

$Self->Is(
    $Ticket{DynamicField_SysMonXService},
    'Host',
    "Service check",
);
$Self->Is(
    $Ticket{DynamicField_SysMonXAddress},
    '127.1.1.1',
    "Address check",
);

$Self->Is(
    $Ticket{State},
    'new',
    "Run() - Ticket State",
);

$FileArray = $MainObject->FileRead(
    Location => $ConfigObject->Get('Home') . '/scripts/test/system/sample/SystemMonitoring1X_UP.box',
    Result => 'ARRAY',    # optional - SCALAR|ARRAY
);

$PostMasterObject = Kernel::System::PostMaster->new(
    %{$Self},
    Email => $FileArray,
);

@Return = $PostMasterObject->Run();
@Return = @{ $Return[0] || [] };

$Self->Is(
    $Return[0] || 0,
    2,
    "Run() - NewTicket",
);
$Self->True(
    $Return[1] == $Ticket{TicketID},
    "Run() - NewTicket/TicketID",
);
# get ticket object
$TicketObject = $Kernel::OM->Get('Ticket');
%Ticket       = $TicketObject->TicketGet(
    TicketID => $Return[1],
    DynamicFields => 1,
);

# prepare Article to get Dynamic Field
my @ArticleIDs = $TicketObject->ArticleIndex(
    TicketID => $Return[1],
);

my %Article = $TicketObject->ArticleGet(
    ArticleID     => $ArticleIDs[-1],
    DynamicFields => 1,
    UserID        => 1,
);

$Self->Is(
    $Article{DynamicField_SysMonXState},
    'UP',
    "State check",
);

$Self->Is(
    $Ticket{State},
    'closed',
    "Run() - Ticket State",
);

# delete ticket
my $Delete = $TicketObject->TicketDelete(
    TicketID => $Return[1],
    UserID   => 1,
);
$Self->True(
    $Delete || 0,
    "TicketDelete()",
);

# revert changes to dynamic fields
for my $DynamicField (@DynamicFieldUpdate) {
    my $SuccessUpdate = $DynamicFieldObject->DynamicFieldUpdate(
        Reorder => 0,
        UserID  => 1,
        %{$DynamicField},
    );
    $Self->True(
        $SuccessUpdate,
        "Reverted changes on ValidID for $DynamicField->{Name} field.",
    );
}

for my $DynamicFieldID (@DynamicfieldIDs) {

    # delete the dynamic field
    my $FieldDelete = $DynamicFieldObject->DynamicFieldDelete(
        ID     => $DynamicFieldID,
        UserID => 1,
    );
    $Self->True(
        $FieldDelete,
        "Deleted dynamic field with id $DynamicFieldID.",
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
