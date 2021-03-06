# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::ImportExport::ObjectBackend::Service2Contact;

use strict;
use warnings;

our @ObjectDependencies = (
    'Service',
    'Contact',
    'ImportExport',
    'Log',
);

=head1 NAME

Kernel::System::ImportExport::ObjectBackend::Contact - import/export backend for Contact

=head1 SYNOPSIS

All functions to import and export Contact entries

=over 4

=cut

=item new()

create an object

    use Kernel::Config;
    use Kernel::System::DB;
    use Kernel::System::Log;
    use Kernel::System::Main;
    use Kernel::System::ImportExport::ObjectBackend::Contact;

    my $ConfigObject = Kernel::Config->new();
    my $LogObject = Kernel::System::Log->new(
        ConfigObject => $ConfigObject,
    );
    my $MainObject = Kernel::System::Main->new(
        ConfigObject => $ConfigObject,
        LogObject    => $LogObject,
    );
    my $DBObject = Kernel::System::DB->new(
        ConfigObject => $ConfigObject,
        LogObject    => $LogObject,
        MainObject   => $MainObject,
    );
    my $BackendObject = Kernel::System::ImportExport::ObjectBackend::Contact->new(
        ConfigObject       => $ConfigObject,
        LogObject          => $LogObject,
        DBObject           => $DBObject,
        MainObject         => $MainObject,
        ImportExportObject => $ImportExportObject,
    );

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item ObjectAttributesGet()

get the object attributes of an object as array/hash reference

    my $Attributes = $ObjectBackend->ObjectAttributesGet(
        UserID => 1,
    );

=cut

sub ObjectAttributesGet {
    my ( $Self, %Param ) = @_;

    # check needed object
    if ( !$Param{UserID} ) {
        $Kernel::OM->Get('Log')
            ->Log( Priority => 'error', Message => 'Need UserID!' );
        return;
    }

    my $Attributes = [];

    return $Attributes;
}

=item MappingObjectAttributesGet()

get the mapping attributes of an object as array/hash reference

    my $Attributes = $ObjectBackend->MappingObjectAttributesGet(
        TemplateID => 123,
        UserID     => 1,
    );

=cut

sub MappingObjectAttributesGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(TemplateID UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # get object data
    my $ObjectData = $Kernel::OM->Get('ImportExport')->ObjectDataGet(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    my $ElementList = [
        {
            Key   => 'ContactLogin',
            # rkaiser - T#2017020290001194 - changed customer user to contact
            Value => 'Contact login',
        },
        {
            Key   => 'ServiceName',
            Value => 'Service Name',
        },
        {
            Key   => 'ServiceID',
            Value => 'Service ID',
        },
        {
            Key   => 'AssignmentActive',
            Value => 'Validity of service assignment for CU',
        },

    ];

    my $Attributes = [
        {
            Key   => 'Key',
            Name  => 'Key',
            Input => {
                Type         => 'Selection',
                Data         => $ElementList,
                Required     => 1,
                Translation  => 0,
                PossibleNone => 1,
            },
        },

        # currently, there are no additional attributes
        #        {
        #            Key   => 'Identifier',
        #            Name  => 'Identifier',
        #            Input => { Type => 'Checkbox', },
        #        },
    ];

    return $Attributes;
}

=item SearchAttributesGet()

get the search object attributes of an object as array/hash reference

    my $AttributeList = $ObjectBackend->SearchAttributesGet(
        TemplateID => 123,
        UserID     => 1,
    );

=cut

sub SearchAttributesGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(TemplateID UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    my $AttributeList = [
        {
            Key   => 'ContactLogin',
            # rkaiser - T#2017020290001194 - changed customer user to contact
            Name  => 'Contact login',
            Input => {
                Type      => 'Text',
                Size      => 80,
                MaxLength => 255,
            },
        },
        {
            Key   => 'ServiceName',
            Name  => 'Service Name',
            Input => {
                Type      => 'Text',
                Size      => 80,
                MaxLength => 255,
            },
        },
    ];

    return $AttributeList;
}

=item ExportDataGet()

get export data as 2D-array-hash reference

    my $ExportData = $ObjectBackend->ExportDataGet(
        TemplateID => 123,
        UserID     => 1,
    );

=cut

sub ExportDataGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(TemplateID UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return;
        }
    }

    # get object data
    my $ObjectData = $Kernel::OM->Get('ImportExport')->ObjectDataGet(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    # check object data
    if ( !$ObjectData || ref $ObjectData ne 'HASH' ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No object data found for the template id $Param{TemplateID}",
        );
        return;
    }

    # get the mapping list
    my $MappingList = $Kernel::OM->Get('ImportExport')->MappingList(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    # check the mapping list
    if ( !$MappingList || ref $MappingList ne 'ARRAY' || !@{$MappingList} ) {

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No valid mapping list found for the template id $Param{TemplateID}",
        );
        return;
    }

    # create the mapping object list
    my @MappingObjectList;
    for my $MappingID ( @{$MappingList} ) {

        # get mapping object data
        my $MappingObjectData =
            $Kernel::OM->Get('ImportExport')->MappingObjectDataGet(
            MappingID => $MappingID,
            UserID    => $Param{UserID},
            );

        # check mapping object data
        if ( !$MappingObjectData || ref $MappingObjectData ne 'HASH' ) {

            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "No valid mapping list found for the template id $Param{TemplateID}",
            );
            return;
        }

        push( @MappingObjectList, $MappingObjectData );
    }

    # get search data
    my $SearchData = $Kernel::OM->Get('ImportExport')->SearchDataGet(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    if ( $SearchData && ref($SearchData) ne 'HASH' ) {
        $SearchData = 0;
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message =>
                "Service2Contact: search data is not a hash ref - ignoring search limitation.",
        );
    }

    if ( $SearchData && $SearchData->{ServiceName} && $SearchData->{ServiceName} =~ /\*/ ) {
        $SearchData->{ServiceName} =~ s/\*/.*/g;
    }
    if (
        $SearchData
        && $SearchData->{ContactLogin}
        && $SearchData->{ContactLogin} =~ /\*/
        )
    {
        $SearchData->{ContactLogin} =~ s/\*/.*/g;
    }

    #search all services...
    my %ServiceData = $Kernel::OM->Get('Service')->ServiceList(
        Valid  => 0,
        UserID => 1,
    );

    # export data...
    my @ExportData;

    for my $ServiceID ( keys(%ServiceData) ) {

        #check for ServiceName export filter...
        if ( $SearchData && $SearchData->{ServiceName} ) {
            if ( $SearchData->{ServiceName} =~ /\*/ ) {
                next if ( $ServiceData{$ServiceID} !~ /$SearchData->{ServiceName}/ );
            }
            else {
                next if ( $ServiceData{$ServiceID} ne $SearchData->{ServiceName} );
            }
        }

        #search all customers set for current service...
        my %CustomerServiceHash = $Kernel::OM->Get('Service')->ContactServiceMemberList(
            ServiceID       => $ServiceID,
            Result          => 'HASH',
            DefaultServices => 0,
        );

        for my $CurrentCUL ( keys(%CustomerServiceHash) ) {
            my @CurrRow = qw{};

            #check for ContactLogin export filter...
            if ( $SearchData && $SearchData->{ContactLogin} ) {
                if ( $SearchData->{ContactLogin} =~ /\*/ ) {
                    next if ( $CurrentCUL !~ /$SearchData->{ContactLogin}/ );
                }
                else {
                    next if ( $CurrentCUL ne $SearchData->{ServiceName} );
                }
            }

            for my $MappingObject (@MappingObjectList) {
                my $Key = $MappingObject->{Key};

                if ( $MappingObject->{Key} && $MappingObject->{Key} eq 'ContactLogin' ) {
                    push( @CurrRow, $CurrentCUL );
                }
                elsif ( $MappingObject->{Key} && $MappingObject->{Key} eq 'ServiceName' ) {
                    push( @CurrRow, $ServiceData{$ServiceID} || '' );
                }
                elsif ( $MappingObject->{Key} && $MappingObject->{Key} eq 'ServiceID' ) {
                    push( @CurrRow, $ServiceID || '' );
                }
                elsif ( $MappingObject->{Key} && $MappingObject->{Key} eq 'AssignmentActive' ) {
                    push( @CurrRow, 'valid' );
                }
                else {
                    push( @CurrRow, '-' );
                }
            }

            push @ExportData, \@CurrRow;

        }

    }

    return \@ExportData;
}

=item ImportDataSave()

import one row of the import data

    my $ConfigItemID = $ObjectBackend->ImportDataSave(
        TemplateID    => 123,
        ImportDataRow => $ArrayRef,
        UserID        => 1,
    );

=cut

sub ImportDataSave {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(TemplateID ImportDataRow UserID)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!",
            );
            return ( undef, 'Failed' );
        }
    }

    # check import data row
    if ( ref $Param{ImportDataRow} ne 'ARRAY' ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'ImportDataRow must be an array reference',
        );
        return ( undef, 'Failed' );
    }

    # get object data
    my $ObjectData = $Kernel::OM->Get('ImportExport')->ObjectDataGet(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    # check object data
    if ( !$ObjectData || ref $ObjectData ne 'HASH' ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No object data found for the template id $Param{TemplateID}",
        );
        return ( undef, 'Failed' );
    }

    # get the mapping list
    my $MappingList = $Kernel::OM->Get('ImportExport')->MappingList(
        TemplateID => $Param{TemplateID},
        UserID     => $Param{UserID},
    );

    # check the mapping list
    if ( !$MappingList || ref $MappingList ne 'ARRAY' || !@{$MappingList} ) {

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "No valid mapping list found for the template id $Param{TemplateID}",
        );
        return ( undef, 'Failed' );
    }

    # create the mapping object list
    my @MappingObjectList;
    my %Identifier;
    my $Counter         = 0;
    my %ImportData      = qw{};
    my $ContactKey = "";

    #--------------------------------------------------------------------------
    #BUILD MAPPING TABLE...
    for my $MappingID ( @{$MappingList} ) {

        # get mapping object data
        my $MappingObjectData =
            $Kernel::OM->Get('ImportExport')->MappingObjectDataGet(
            MappingID => $MappingID,
            UserID    => $Param{UserID},
            );

        # check mapping object data
        if ( !$MappingObjectData || ref $MappingObjectData ne 'HASH' ) {

            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "No valid mapping list found for template id $Param{TemplateID}",
            );
            return ( undef, 'Failed' );
        }

        push( @MappingObjectList, $MappingObjectData );

        $ImportData{ $MappingObjectData->{Key} } =
            $Param{ImportDataRow}->[$Counter];

        $Counter++;

    }

    #--------------------------------------------------------------------------
    #DO THE IMPORT...

    #(1) search service...
    if ( $ImportData{ServiceName} ) {
        my $CurrentSID = $Kernel::OM->Get('Service')->ServiceLookup(
            Name => $ImportData{ServiceName},
        ) || 0;

        if ( !$ImportData{ServiceID} ) {
            $ImportData{ServiceID} = $CurrentSID;
        }
        if ( !$CurrentSID || $ImportData{ServiceID} != $CurrentSID ) {

            #service name does not exist or does not fit to ServiceID - drop line...
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Service2Contact: service <"
                    . $ImportData{ServiceName}
                    . "> does not exist or does not match given ServiceID <"
                    . ( $ImportData{ServiceID} || '' )
                    . ">.",
            );
            return (0, 'Failed');   # if got no ServiceID, then exit
        }
    }

    #(2) search customer user...
    my %ContactData;
    if ( $ImportData{ContactLogin} && $ImportData{ContactLogin} !~ /DEFAULT/ ) {
        my %Contacts = $Kernel::OM->Get('Contact')->ContactSearch(
            Login => $ImportData{ContactLogin},
            Limit => 1,
            Valid => 0
        );
        if ( IsHashRefWithData(\%Contacts)) {
            for my $ContactID ( keys %Contacts) {
                %ContactData = $Kernel::OM->Get('Contact')->ContactGet(
                    ID => $ContactID,
                );
            }
        }
        if ( !%ContactData ) {

            #customer user login does not exist - drop line...
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                # rkaiser - T#2017020290001194 - changed customer user to contact
                Message  => "Service2Contact: contact login <"
                    . "$ImportData{ContactLogin}> does not exist.",
            );
            return (0, 'Failed');   # if got no ContactLogin, then exit
        }
    }

    #(3) normalize AssignmentActive value...
    if ( $ImportData{AssignmentActive} && $ImportData{AssignmentActive} =~ /invalid/ ) {
        $ImportData{AssignmentActive} = 0;
    }
    else {
        $ImportData{AssignmentActive} = 1;
    }

    #(4) dis/enable customer user - service mapping...
    my $Result     = 0;
    my $ReturnCode = "";    # Created | Changed | Failed

    if ( $ImportData{ContactLogin} !~ /DEFAULT/ ) {
        if (%ContactData) {
            $Result = $Kernel::OM->Get('Service')->ContactServiceMemberAdd(
                ContactLogin => $ImportData{ContactLogin},
                ServiceID         => $ImportData{ServiceID},
                Active            => $ImportData{AssignmentActive} || 0,
                UserID            => $Param{UserID},
            );
            if ( !$Result && $ImportData{AssignmentActive}) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => 'ImportDataSave: adding Service2Contact <'
                        . $ImportData{ContactLogin}
                        . "> failed (line $Param{Counter}).",
                );
            }
            else {
                $ReturnCode = "Created";
                $Result = 1;
            }
        }
    }
    else {
        $Result = $Kernel::OM->Get('Service')->ContactServiceMemberAdd(
            ContactLogin => '<DEFAULT>',
            ServiceID         => $ImportData{ServiceID},
            Active            => $ImportData{AssignmentActive} || 0,
            UserID            => $Param{UserID},
        );
        if ( !$Result && $ImportData{AssignmentActive} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => 'ImportDataSave: adding <DEFAULT> Service2Contact <'
                    . "> failed (line $Param{Counter}).",
            );
        }
        else {
            $ReturnCode = "Created";
            $Result = 1;
        }
    }

    #
    #--------------------------------------------------------------------------

    return ( $Result, $ReturnCode );
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
