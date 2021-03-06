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

# Temporarily disabled to work around a mod_perl bug that occurs on Ubuntu 15.04 and gentoo atm (2016-01-29).
#
# Frontend/Basic.t finds one module to return a 500 internal error (seemingly random).
# The apache error log shows this message:
#
# [perl:error] [pid 908] [client ::1:36519] Use of each() on hash after insertion without resetting hash iterator results in undefined behavior, Perl interpreter: 0x55b01def9a90 at /opt/otrs/Kernel/cpan-lib/Apache2/Reload.pm line 171.
#
# This seems to be caused by Apache2::Reload trying to reload modules which in turn triggers an internal mod_perl bug
#   that we currently don't know.
#
# Avoid this error by not reinstalling the installed packages in the UT scenarios so that mod_perl does not try to reload the packages.

# my $CommandObject = $Kernel::OM->Get('Console::Command::Admin::Package::ReinstallAll');

# my $ExitCode = $CommandObject->Execute();

# $Self->Is(
#     $ExitCode,
#     0,
#     "Admin::Package::ReinstallAll exit code",
# );

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
