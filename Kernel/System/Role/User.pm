# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Role::User;

use strict;
use warnings;

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Cache',
    'Kernel::System::DB',
    'Kernel::System::Log',
    'Kernel::System::User',
    'Kernel::System::Valid',
);

=head1 NAME

Kernel::System::Role::User - user functions for roles lib

=head1 SYNOPSIS

All role functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item RoleUserAdd()

add a user to the role

    my $Success = $RoleObject->RoleUserAdd(
        RoleID => 6,
        AssignUserID => 12,
        UserID => 123,
    );

=cut

sub RoleUserAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(AssignUserID RoleID UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }
    
    # insert new relation
    return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => 'INSERT INTO role_user '
            . '(user_id, role_id, create_time, create_by, change_time, change_by) '
            . 'VALUES (?, ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [ \$Param{AssignUserID}, \$Param{RoleID}, \$Param{UserID}, \$Param{UserID} ],
    );

    # delete cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp();

    # push client callback event
    $Kernel::OM->Get('Kernel::System::ClientRegistration')->NotifyClients(
        Event     => 'CREATE',
        Namespace => 'Role.User',
        ObjectID  => $Param{RoleID}.'::'.$Param{AssignUserID},
    );

    return 1;
}

=item RoleUserList()

returns a list with all users of a role

    my @UserList = $RoleObject->RoleUserList(
        RoleID => $RoleID,
    );

    @UserList = (
        1,
        2,
        3
    );

=cut

sub RoleUserList {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(RoleID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # create cache key
    my $CacheKey = 'RoleUserList::' . $Param{RoleID};

    # read cache
    my $Cache = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return @{$Cache} if $Cache;

    return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare( 
        SQL  => 'SELECT user_id FROM role_user WHERE role_id = ?',
        Bind => [ \$Param{RoleID} ]
    );

    my @Result;
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        push(@Result, $Row[0]);
    }

    # set cache
    $Kernel::OM->Get('Kernel::System::Cache')->Set(
        Type  => $Self->{CacheType},
        Key   => $CacheKey,
        Value => \@Result,
        TTL   => $Self->{CacheTTL},
    );

    return @Result;
}

=item RoleUserDelete()

remove a user from the role

    my $Success = $RoleObject->RoleUserDelete(
        RoleID => 6,
        UserID => 12,
    );

=cut

sub RoleUserDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(RoleID UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # delete existing RoleUser relation
    return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL  => 'DELETE FROM role_user WHERE user_id = ? AND role_id = ?',
        Bind => [ \$Param{UserID}, \$Param{RoleID} ],
    );

    # delete cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp();

    # push client callback event
    $Kernel::OM->Get('Kernel::System::ClientRegistration')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'Role.User',
        ObjectID  => $Param{RoleID}.'::'.$Param{UserID},
    );

    return 1;
}


1;

=end Internal:





=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
