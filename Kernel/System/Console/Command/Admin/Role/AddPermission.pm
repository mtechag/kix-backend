# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Admin::Role::AddPermission;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Role',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Create a new role permission.');
    $Self->AddOption(
        Name        => 'role-name',
        Description => 'Name of the role.',
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'type',
        Description => 'The type of the new permission.',
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'target',
        Description => 'The target of the new permission.',
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'value',
        Description => 'The value of the new permission (CREATE,READ,UPDATE,DELETE,DENY). You can combine different values by using a comma, i.e. READ,UPDATE.',
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddOption(
        Name        => 'required',
        Description => 'Set this permission as required. This only has effect when multiple attribute value permissions are defined for one object',
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/(yes|no)/smx,
    );
    $Self->AddOption(
        Name        => 'comment',
        Description => 'Comment for the new permission.',
        Required    => 0,
        HasValue    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub PreRun {

    my ( $Self, %Param ) = @_;

    $Self->{PermissionType} = $Self->GetOption('type');
    $Self->{RoleName} = $Self->GetOption('role-name');

    # check permission type
    $Self->{PermissionTypeID} = $Kernel::OM->Get('Role')->PermissionTypeLookup( Name => $Self->{PermissionType} );
    if ( !$Self->{PermissionTypeID} ) {
        die "Permission type $Self->{PermissionType} does not exist.\n";
    }

    # check role
    $Self->{RoleID} = $Kernel::OM->Get('Role')->RoleLookup( Role => $Self->{RoleName} );
    if ( !$Self->{RoleID} ) {
        die "Role $Self->{RoleName} does not exist.\n";
    }

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Adding a new permission to role $Self->{RoleName}...</yellow>\n");

    my %PossiblePermissions = %{Kernel::System::Role::Permission->PERMISSION};
    $PossiblePermissions{CRUD} = Kernel::System::Role::Permission->PERMISSION_CRUD;

    my $Value = 0;
    foreach my $Permission ( split(/\s*\,\s*/, $Self->GetOption('value')) ) {
        $Value += $PossiblePermissions{$Permission};
    }

    my $IsRequired = $Self->GetOption('required') || 'no';

    my $PermissionID = $Kernel::OM->Get('Role')->PermissionAdd(
        RoleID     => $Self->{RoleID},
        TypeID     => $Self->{PermissionTypeID},
        Target     => $Self->GetOption('target') || '',
        Value      => $Value,
        IsRequired => ($IsRequired eq 'yes'),
        Comment    => $Self->GetOption('comment') || '',
        UserID     => 1,
    );

    if ($PermissionID) {
        $Self->Print("<green>Done</green>\n");
        return $Self->ExitCodeOk();
    }

    $Self->PrintError("Can't add permission");
    return $Self->ExitCodeError();
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
