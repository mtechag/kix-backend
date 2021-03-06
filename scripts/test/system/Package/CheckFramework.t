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

# get package object
my $ConfigObject  = $Kernel::OM->Get('Config');
my $PackageObject = $Kernel::OM->Get('Package');

# Set Framework Version to 4.0.4
$ConfigObject->Set(
    Key   => 'Version',
    Value => '4.0.4',
);

my @Tests = (

    # Example of the Framework Array
    #
    # $VAR2 = 'Framework';
    # $VAR3 = [
    #           {
    #             'TagType' => 'Start',
    #             'TagLevel' => '2',
    #             'Minimum' => '5.0.10',
    #             'Content' => '5.0.x',
    #             'TagLastLevel' => 'kix_package',
    #             'TagCount' => '24',
    #             'Tag' => 'Framework'
    #           }
    #         ];

    # test with single framework version <Framework>4.0.x</Framework>
    {
        Framework => [
            {
                'Content' => '4.0.x',
            }
        ],
        Result => 1,
    },
    {
        Framework => [
            {
                'Content' => '4.0.3',
            }
        ],
        Result => 0,
    },
    {
        Framework => [
            {
                'Content' => '4.0.4',
            }
        ],
        Result => 1,
    },
    {
        Framework => [
            {
                'Content' => '4.0.5',
            }
        ],
        Result => 0,
    },
    {
        Framework => [
            {
                'Content' => '4.1.x',
            }
        ],
        Result => 0,
    },
    {
        Framework => [
            {
                'Content' => '4.1.3',
            }
        ],
        Result => 0,
    },
    {
        Framework => [
            {
                'Content' => '5.0.4',
            }
        ],
        Result => 0,
    },
    {
        Framework => [
            {
                'Content' => '3.0.5',
            }
        ],
        Result => 0,
    },

    # test minimum framework version (e.g. <Framework Minimum="4.0.4">4.0.x</Framework>)
    {
        Framework => [
            {
                'Content' => '4.0.x',
                'Minimum' => '4.0.4'
            }
        ],
        Result => 1,
    },
    {
        Framework => [
            {
                'Content' => '4.0.x',
                'Minimum' => '4.0.3'
            }
        ],
        Result => 1,
    },
    {
        Framework => [
            {
                'Content' => '4.0.x',
                'Minimum' => '4.0.5'
            }
        ],
        Result => 0,
    },
    {
        Framework => [
            {
                'Content' => '5.0.x',
                'Minimum' => '4.0.4'
            }
        ],
        Result => 0,
    },
    {
        Framework => [
            {
                'Content' => '5.0.x',
                'Minimum' => '4.0.3'
            }
        ],
        Result => 0,
    },
    {
        Framework => [
            {
                'Content' => '3.0.x',
                'Minimum' => '4.0.5'
            }
        ],
        Result => 0,
    },
    {
        Framework => [
            {
                'Content' => '3.0.x',
                'Minimum' => '4.0.3'
            }
        ],
        Result => 0,
    },

    # test maximum framework version (e.g. <Framework Maximum="4.0.4">4.0.x</Framework>)
    {
        Framework => [
            {
                'Content' => '4.0.x',
                'Maximum' => '4.0.4'
            }
        ],
        Result => 1,
    },
    {
        Framework => [
            {
                'Content' => '4.0.x',
                'Maximum' => '4.1.3'
            }
        ],
        Result => 1,
    },
    {
        Framework => [
            {
                'Content' => '4.0.x',
                'Maximum' => '4.0.3'
            }
        ],
        Result => 0,
    },
    {
        Framework => [
            {
                'Content' => '5.0.x',
                'Maximum' => '4.0.4'
            }
        ],
        Result => 0,
    },
    {
        Framework => [
            {
                'Content' => '5.0.x',
                'Maximum' => '4.1.3'
            }
        ],
        Result => 0,
    },
    {
        Framework => [
            {
                'Content' => '3.0.x',
                'Maximum' => '4.0.5'
            }
        ],
        Result => 0,
    },
    {
        Framework => [
            {
                'Content' => '3.0.x',
                'Maximum' => '4.0.3'
            }
        ],
        Result => 0,
    },
    {
        Framework => [
            {
                'Content' => '3.0.x',
                'Maximum' => '4.0.4'
            }
        ],
        Result => 0,
    },

# test combination of minimum and maximum framework versions  (e.g. <Framework Minimum="4.0.3" Maximum="4.0.4">4.0.x</Framework>)
    {
        Framework => [
            {
                'Content' => '4.0.x',
                'Minimum' => '4.0.4',
                'Maximum' => '4.0.4'
            }
        ],
        Result => 1,
    },
    {
        Framework => [
            {
                'Content' => '4.0.x',
                'Minimum' => '4.0.3',
                'Maximum' => '4.0.4'
            }
        ],
        Result => 1,
    },
    {
        Framework => [
            {
                'Content' => '4.0.x',
                'Minimum' => '4.0.4',
                'Maximum' => '4.0.5'
            }
        ],
        Result => 1,
    },
    {
        Framework => [
            {
                'Content' => '4.0.x',
                'Minimum' => '4.0.5',
                'Maximum' => '4.0.6'
            }
        ],
        Result => 0,
    },
    {
        Framework => [
            {
                'Content' => '4.0.x',
                'Minimum' => '4.0.2',
                'Maximum' => '4.0.3'
            }
        ],
        Result => 0,
    },
    {
        Framework => [
            {
                'Content' => '4.0.x',
                'Minimum' => '4.0.5',
                'Maximum' => '4.0.3'
            }
        ],
        Result => 0,
    },
    {
        Framework => [
            {
                'Content' => '5.0.x',
                'Minimum' => '4.0.4',
                'Maximum' => '4.0.4'
            }
        ],
        Result => 0,
    },
    {
        Framework => [
            {
                'Content' => '5.0.x',
                'Minimum' => '4.0.3',
                'Maximum' => '4.0.4'
            }
        ],
        Result => 0,
    },
    {
        Framework => [
            {
                'Content' => '5.0.x',
                'Minimum' => '4.0.4',
                'Maximum' => '4.0.5'
            }
        ],
        Result => 0,
    },
    {
        Framework => [
            {
                'Content' => '3.0.x',
                'Minimum' => '4.0.5',
                'Maximum' => '4.0.6'
            }
        ],
        Result => 0,
    },
    {
        Framework => [
            {
                'Content' => '3.0.x',
                'Minimum' => '4.0.2',
                'Maximum' => '4.0.3'
            }
        ],
        Result => 0,
    },
    {
        Framework => [
            {
                'Content' => '3.0.x',
                'Minimum' => '4.0.5',
                'Maximum' => '4.0.3'
            }
        ],
        Result => 0,
    },
    {
        Framework => [
            {
                'Content' => '3.0.x',
                'Minimum' => '4.0.3',
                'Maximum' => '4.0.5'
            }
        ],
        Result => 0,
    },

    # test with multiple frameworks
    {
        Framework => [
            {
                'Content' => '5.0.x',
            },
            {
                'Content' => '4.x.x',
            },
            {
                'Content' => '3.x.x',
            }
        ],
        Result => 1,
    },
    {
        Framework => [
            {
                'Content' => '4.0.3',
            },
            {
                'Content' => '4.0.4',
            },
            {
                'Content' => '4.0.5',
            }
        ],
        Result => 1,
    },
    {
        Framework => [
            {
                'Content' => '3.0.x',
            },
            {
                'Content' => '4.0.x',
            },
            {
                'Content' => '5.0.x',
            }
        ],
        Result => 1,
    },
    {
        Framework => [
            {
                'Content' => '3.0.x',
            },
            {
                'Content' => '4.0.x',
                'Minimum' => '4.0.5',
            },
            {
                'Content' => '5.0.x',
            }
        ],
        Result => 0,
    },
    {
        Framework => [
            {
                'Content' => '3.0.x',
            },
            {
                'Content' => '4.0.x',
                'Minimum' => '4.0.3',
            },
            {
                'Content' => '5.0.x',
            }
        ],
        Result => 1,
    },
    {
        Framework => [
            {
                'Content' => '3.0.x',
            },
            {
                'Content' => '4.0.x',
                'Minimum' => '4.0.4',
            },
            {
                'Content' => '5.0.x',
            }
        ],
        Result => 1,
    },
    {
        Framework => [
            {
                'Content' => '3.0.x',
            },
            {
                'Content' => '4.0.x',
                'Maximum' => '4.0.4',
            },
            {
                'Content' => '5.0.x',
            }
        ],
        Result => 1,
    },
    {
        Framework => [
            {
                'Content' => '3.0.x',
            },
            {
                'Content' => '4.0.x',
                'Maximum' => '4.0.3',
            },
            {
                'Content' => '5.0.x',
            }
        ],
        Result => 0,
    },
    {
        Framework => [
            {
                'Content' => '3.0.x',
            },
            {
                'Content' => '4.0.x',
                'Maximum' => '4.0.5',
            },
            {
                'Content' => '5.0.x',
            }
        ],
        Result => 1,
    },
    {
        Framework => [
            {
                'Content' => '3.0.x',
            },
            {
                'Content' => '4.0.x',
                'Minimum' => '4.0.4',
                'Maximum' => '4.0.4'
            },
            {
                'Content' => '5.0.x',
            }
        ],
        Result => 1,
    },
    {
        Framework => [
            {
                'Content' => '3.0.x',
            },
            {
                'Content' => '4.0.x',
                'Minimum' => '4.0.3',
                'Maximum' => '4.0.4'
            },
            {
                'Content' => '5.0.x',
            }
        ],
        Result => 1,
    },
    {
        Framework => [
            {
                'Content' => '3.0.x',
            },
            {
                'Content' => '4.0.x',
                'Minimum' => '4.0.4',
                'Maximum' => '4.0.5'
            },
            {
                'Content' => '5.0.x',
            }
        ],
        Result => 1,
    },
    {
        Framework => [
            {
                'Content' => '3.0.x',
            },
            {
                'Content' => '4.0.x',
                'Minimum' => '4.0.5',
                'Maximum' => '4.0.6'
            },
            {
                'Content' => '5.0.x',
            }
        ],
        Result => 0,
    },
    {
        Framework => [
            {
                'Content' => '3.0.x',
            },
            {
                'Content' => '4.0.x',
                'Minimum' => '4.0.3',
                'Maximum' => '4.0.3'
            },
            {
                'Content' => '5.0.x',
            }
        ],
        Result => 0,
    },
    {
        Framework => [
            {
                'Content' => '3.0.x',
            },
            {
                'Content' => '4.0.x',
                'Minimum' => '4.0.2',
                'Maximum' => '4.0.3'
            },
            {
                'Content' => '5.0.x',
            }
        ],
        Result => 0,
    },
    {
        Framework => [
            {
                'Content' => '3.0.x',
                'Minimum' => '4.0.4',
                'Maximum' => '4.0.4'
            },
            {
                'Content' => '5.0.x',
            }
        ],
        Result => 0,
    },
    {
        Framework => [
            {
                'Content' => '3.0.x',
                'Minimum' => '4.0.3',
                'Maximum' => '4.0.4'
            },
            {
                'Content' => '4.0.5',
            },
            {
                'Content' => '5.0.x',
            }
        ],
        Result => 0,
    },
    {
        Framework => [
            {
                'Content' => '3.0.x',
                'Minimum' => '4.0.4',
                'Maximum' => '4.0.5'
            },
            {
                'Content' => '4.0.3',
            },
            {
                'Content' => '5.0.x',
            }
        ],
        Result => 0,
    },
    {
        Framework => [
            {
                'Content' => '3.0.x',
                'Minimum' => '4.0.5',
                'Maximum' => '4.0.6'
            },
            {
                'Content' => '5.0.x',
            }
        ],
        Result => 0,
    },
    {
        Framework => [
            {
                'Content' => '3.0.x',
                'Minimum' => '4.0.3',
                'Maximum' => '4.0.3'
            },
            {
                'Content' => '5.0.x',
            }
        ],
        Result => 0,
    },
    {
        Framework => [
            {
                'Content' => '3.0.x',
                'Minimum' => '4.0.2',
                'Maximum' => '4.0.3'
            },
            {
                'Content' => '5.0.x',
            }
        ],
        Result => 0,
    },
    {
        Framework => [
            {
                'Content' => '3.0.x',
            },
            {
                'Content' => '5.0.x',
                'Minimum' => '4.0.4',
                'Maximum' => '4.0.4'
            }
        ],
        Result => 0,
    },
    {
        Framework => [
            {
                'Content' => '3.0.x',
            },
            {
                'Content' => '4.0.5',
            },
            {
                'Content' => '5.0.x',
                'Minimum' => '4.0.3',
                'Maximum' => '4.0.4'
            }
        ],
        Result => 0,
    },
    {
        Framework => [
            {
                'Content' => '3.0.x',
            },
            {
                'Content' => '4.0.3',
            },
            {
                'Content' => '5.0.x',
                'Minimum' => '4.0.4',
                'Maximum' => '4.0.5'
            }
        ],
        Result => 0,
    },
    {
        Framework => [
            {
                'Content' => '3.0.x',
            },
            {
                'Content' => '5.0.x',
                'Minimum' => '4.0.5',
                'Maximum' => '4.0.6'
            }
        ],
        Result => 0,
    },
    {
        Framework => [
            {
                'Content' => '3.0.x',
            },
            {
                'Content' => '5.0.x',
                'Minimum' => '4.0.3',
                'Maximum' => '4.0.3'
            }
        ],
        Result => 0,
    },
    {
        Framework => [
            {
                'Content' => '3.0.x',
            },
            {
                'Content' => '5.0.x',
                'Minimum' => '4.0.2',
                'Maximum' => '4.0.3'
            }
        ],
        Result => 0,
    },

);

for my $Test (@Tests) {

    my $VersionCheck = $PackageObject->_CheckFramework(
        Framework => $Test->{Framework},
    );

    my $FrameworkVersion = $Test->{Framework}[0]->{Content};
    my $FrameworkMinimum = $Test->{Framework}[0]->{Minimum} || '';
    my $FrameworkMaximum = $Test->{Framework}[0]->{Maximum} || '';

    my $Name = "_CheckFramework() - $FrameworkVersion - Minimum: $FrameworkMinimum - Maximum: $FrameworkMaximum";

    if ( $Test->{Result} ) {
        $Self->True(
            $VersionCheck,
            $Name,
        );
    }
    else {
        $Self->True(
            !$VersionCheck,
            $Name,
        );
    }
}

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
