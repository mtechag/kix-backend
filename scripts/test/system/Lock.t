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

# get lock object
my $LockObject = $Kernel::OM->Get('Lock');

# get helper object
$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my @Names = sort $LockObject->LockViewableLock(
    Type => 'Name',
);

$Self->IsDeeply(
    \@Names,
    [ 'unlock' ],
    'LockViewableLock()',
);

my @Tests = (
    {
        Name   => 'Lookup - lock',
        Input  => 'lock',
        Result => 1,
    },
    {
        Name   => 'Lookup - unlock',
        Input  => 'unlock',
        Result => 1,
    },
    {
        Name   => 'Lookup - unlock_not_extsits',
        Input  => 'unlock_not_exists',
        Result => 0,
    },
);

for my $Test (@Tests) {

    my $LockID = $LockObject->LockLookup( Lock => $Test->{Input} );

    if ( $Test->{Result} ) {

        $Self->True( $LockID, $Test->{Name} );

        my $Lock = $LockObject->LockLookup( LockID => $LockID );

        $Self->Is(
            $Test->{Input},
            $Lock,
            $Test->{Name},
        );
    }
    else {
        $Self->False( $LockID, $Test->{Name} );
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
