# --
# Modified version of the work: Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package scripts::test::sample::GenericAgent::TestConfigurationModule;

use strict;
use warnings;
use utf8;

use vars qw(@ISA @EXPORT %Jobs);
use Exporter;
@ISA     = qw(Exporter);
@EXPORT  = qw(%Jobs);

%Jobs = (

   'set priority very high' => {

        # get all tickets with these properties
        Title => 'UnitTestSafeToDelete',
        New => {

            # new priority
            PriorityID => 5,
        },
    },

   'set state open' => {

        # get all tickets with these properties
        Title => 'UnitTestSafeToDelete',
        New => {

            # new state
            State => 'open',
        },
    },
);
1;




=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
