# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Admin::KIX::CleanupPackageRepository;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Main',
    'Package',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Remove duplicate entries in package_repository due to force install.');

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $Result = $Kernel::OM->Get('DB')->Prepare(
        SQL =>
            'SELECT id FROM package_repository pr1 WHERE id IN (SELECT id FROM package_repository WHERE name = pr1.name AND id < (SELECT MAX(id) FROM package_repository WHERE name = pr1.name))',
    );

    if ($Result) {
        my @IDs;
        while ( my @Row = $Kernel::OM->Get('DB')->FetchrowArray() ) {
            push( @IDs, $Row[0] );
        }

        foreach my $ID (@IDs) {
            $Result = $Kernel::OM->Get('DB')->Prepare(
                SQL  => 'DELETE FROM package_repository WHERE id = ?',
                Bind => [ \$ID ],
            );
            last if !$Result;
        }
    }

    if ( !$Result ) {
        return $Self->ExitCodeError();
    }

    return $Self->ExitCodeOk();
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
