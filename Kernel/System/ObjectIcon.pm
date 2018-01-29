# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ObjectIcon;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);
use vars qw(@ISA);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::CacheInternal',
    'Kernel::System::DB',
    'Kernel::System::Log',
);

=head1 NAME

Kernel::System::ObjectIcon

=head1 SYNOPSIS

Add address book functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create a ObjectIcon object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $ObjectIconObject = $Kernel::OM->Get('Kernel::System::ObjectIcon');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{CacheType} = 'ObjectIcon';
    $Self->{CacheTTL}  = 60 * 60 * 24 * 30;   # 30 days
    
    return $Self;
}

=item ObjectIconGet()

Get an objecticon.

    my $Result = $ObjectIconObject->ObjectIconGet(
        ID      => 123,
    );

=cut

sub ObjectIconGet {
    my ( $Self, %Param ) = @_;
    
    my %Result;

    # check required params...
    if ( !$Param{ID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log( 
            Priority => 'error', 
            Message  => 'Need ClientID!' 
        );
        return;
    }
   
    # check cache
    my $CacheKey = 'ObjectIconGet::' . $Param{ID};
    my $Cache    = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;
    
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    return if !$DBObject->Prepare( 
        SQL   => "SELECT id, object, object_id, content_type, content, create_by, create_time, change_by, change_time 
                  FROM object_icon WHERE id = ?",
        Bind => [ \$Param{ID} ],
    );

    my %Data;
    
    # fetch the result
    while ( my @Data = $DBObject->FetchrowArray() ) {
        %Data = (
            ID          => $Data[0],
            Object      => $Data[1],
            ObjectID    => $Data[2],
            ContentType => $Data[3],
            Content     => $Data[4],
            CreateBy    => $Data[5],
            CreateTime  => $Data[6],
            ChangeBy    => $Data[7],
            ChangeTime  => $Data[8],
        );
    }
    
    # no data found...
    if ( !%Data ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "No ObjectIcon with ID $Param{ID} found!",
        );
        return;
    }
    
    # set cache
    $Kernel::OM->Get('Kernel::System::Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%Data,
    ); 
       
    return %Data;   

}


=item ObjectIconAdd()

Adds a new objecticon

    my $Result = $ObjectIconObject->ObjectIconAdd(
        Object          => 'TicketState'
        ObjectID        => '12',
        ContentType     => 'image/png',           
        Content         => '...',
        UserID          => 1,
    );

=cut

sub ObjectIconAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Object ObjectID ContentType Content UserID)) {
        if ( !defined( $Param{$_} ) ) {
            $Self->{LogObject}->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # do the db insert...
    my $DBInsert = $DBObject->Do(
        SQL  => "INSERT INTO object_icon (object, object_id, content_type, content, create_by, create_time, change_by, change_time) 
                 VALUES (?, ?, ?, ?, ?, current_timestamp, ?, current_timestamp)",
        Bind => [
            \$Param{Object},
            \$Param{ObjectID},
            \$Param{ContentType},
            \$Param{Content},
            \$Param{UserID},
            \$Param{UserID},
        ],
    );

    #handle the insert result...
    if ($DBInsert) {

        # delete cache
        $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
            Type => $Self->{CacheType}
        );

        return if !$DBObject->Prepare(
            SQL => 'SELECT id FROM object_icon WHERE object = ? AND object_id = ?',
            Bind => [
                \$Param{Object}, \$Param{ObjectID}
            ],
            Limit => 1,
        );

        # fetch results
        my $ID;
        while ( my @Row = $DBObject->FetchrowArray() ) {
            $ID = $Row[0];
        }

        return $ID;
    }
    else {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "DB insert failed!",
        );
    }

    return;
}

=item ObjectIconUpdate()

Update an objecticon

    my $Result = $ObjectIconObject->ObjectIconUpdate(
        ID              => 123
        Object          => 'TicketState'
        ObjectID        => '12',
        ContentType     => 'image/png',           
        Content         => '...',
        UserID          => 1,
    );

=cut

sub ObjectIconUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ID Object ObjectID ContentType Content UserID)) {
        if ( !defined( $Param{$_} ) ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log( Priority => 'error', Message => "Need $_!" );
            return;
        }
    }

    # do the db insert...
    my $DBUpdate = $Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL  => "UPDATE object_icon SET object = ?, object_id = ?, content_type = ?, content = ?, change_by = ? WHERE id = ?",
        Bind => [
            \$Param{Object},
            \$Param{ObjectID},
            \$Param{ContentType},
            \$Param{Content},
            \$Param{UserID},
            \$Param{ID},
        ],
    );

    #handle the insert result...
    if ($DBUpdate) {

        # delete cache
        $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
            Type => $Self->{CacheType}
        );

        return $Param{ID};
    }
    else {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "DB update failed!",
        );
    }

    return;
}

=item ObjectIconList()

Returns a ArrayRef with all objecticons

    my $IDs = $ObjectIconObject->ObjectIconList(
        Object   => '...',          # optional
        ObjectID => '...'           # optional
    );

=cut

sub ObjectIconList {
    my ( $Self, %Param ) = @_;
    my %Result;
    my @SQLWhere;
    my @BindVars;

    # check cache
    my $CacheKey = 'ObjectIconList::'.($Param{Object}||'').'::'.($Param{ObjectID}||'');
    my $CacheResult = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey
    );
    
    return $CacheResult if (IsArrayRefWithData($CacheResult));
  
    if ($Param{Object}) {
        push(@SQLWhere, 'object = ?');
        push(@BindVars, \$Param{Object});
    }

    if ($Param{ObjectID}) {
        push(@SQLWhere, 'object_id = ?');
        push(@BindVars, \$Param{ObjectID});
    }

    my $SQL = "SELECT id FROM object_icon";

    if (@SQLWhere) {
        $SQL .= ' WHERE '.join(' AND ', @SQLWhere);
    }
   
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    return if !$DBObject->Prepare( 
        SQL   => $SQL,
        Bind  => \@BindVars,
    );

    my @Result;
    while ( my @Data = $DBObject->FetchrowArray() ) {
        push(@Result, $Data[0]);
    }

    # set cache
    $Kernel::OM->Get('Kernel::System::Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \@Result,
    );

    return \@Result;
}

=item ObjectIconDelete()

Delete an objecticon.

    my $Result = $ObjectIconObject->ObjectIconDelete(
        ID      => 123,
    );

=cut

sub ObjectIconDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    return if !$DBObject->Prepare(
        SQL  => 'DELETE FROM object_icon WHERE id = ?',
        Bind => [ \$Param{ID} ],
    );

    # delete cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp(
        Type => $Self->{CacheType}
    );

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
