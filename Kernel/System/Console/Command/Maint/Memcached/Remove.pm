# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Maint::Memcached::Remove;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::Cache',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Removes objects in memcached.');

    $Self->AddArgument(
        Name        => 'type',
        Description => 'cache type',
        Required    => 1,
        ValueRegex  => qr/(.*)/smx,
    );
    $Self->AddArgument(
        Name        => 'key',
        Description => 'cache key',
        Required    => 1,
        ValueRegex  => qr/(.*)/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $Type = $Self->GetArgument('type');
    my $Key  = $Self->GetArgument('key');

    $Self->Print(
        "<yellow>removing...</yellow>\n"
    );

    my $Result = $Kernel::OM->Get('Kernel::System::Cache')->Delete(
        Key  => $Key,
        Type => $Type,
        Raw  => 1,
    );

    if ($Result) {
        print "\"$Type::$Key\" removed.\n";
    }
    else {
        print "\"$Type::$Key\" not found!\n";
    }

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
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
