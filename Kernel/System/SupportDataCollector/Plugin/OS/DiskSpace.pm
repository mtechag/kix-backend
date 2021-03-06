# --
# Modified version of the work: Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::SupportDataCollector::Plugin::OS::DiskSpace;

use strict;
use warnings;

use base qw(Kernel::System::SupportDataCollector::PluginBase);

use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Config',
);

sub GetDisplayPath {
    return Translatable('Operating System');
}

sub Run {
    my $Self = shift;

    # This plugin is temporary disabled
    # A new logic is required to calculate the space
    return $Self->GetResults();

    # Check if used OS is a linux system
    if ( $^O !~ /(linux|unix|netbsd|freebsd|darwin)/i ) {
        return $Self->GetResults();
    }

    # find KIX partition
    my $Home = $Kernel::OM->Get('Config')->Get('Home');

    my $Partition = `df -P $Home | tail -1 | cut -d' ' -f 1`;
    chomp $Partition;

    my $Commandline = "df -lx tmpfs -x iso9660 -x udf -x squashfs";

    # current MacOS and FreeBSD does not support the -x flag for df
    if ( $^O =~ /(darwin|freebsd)/i ) {
        $Commandline = "df -l";
    }

    my $In;
    if ( open( $In, "-|", "$Commandline" ) ) {

        my ( @ProblemPartitions, $StatusProblem );

        # TODO change from percent to megabytes used.
        while (<$In>) {
            if ( $_ =~ /^$Partition\s.*/ && $_ =~ /^(.+?)\s.*\s(\d+)%.+?$/ ) {
                my ( $Partition, $UsedPercent ) = $_ =~ /^(.+?)\s.*?\s(\d+)%.+?$/;
                if ( $UsedPercent > 90 ) {
                    push @ProblemPartitions, "$Partition \[$UsedPercent%\]";
                    $StatusProblem = 1;
                }
                elsif ( $UsedPercent > 80 ) {
                    push @ProblemPartitions, "$Partition \[$UsedPercent%\]";
                }
            }
        }
        close($In);
        if (@ProblemPartitions) {
            if ($StatusProblem) {
                $Self->AddResultProblem(
                    Label   => Translatable('Disk Usage'),
                    Value   => join( ', ', @ProblemPartitions ),
                    Message => Translatable('The partition where KIX is located is almost full.'),
                );
            }
            else {
                $Self->AddResultWarning(
                    Label   => Translatable('Disk Usage'),
                    Value   => join( ', ', @ProblemPartitions ),
                    Message => Translatable('The partition where KIX is located is almost full.'),
                );
            }
        }
        else {
            $Self->AddResultOk(
                Label   => Translatable('Disk Usage'),
                Value   => '',
                Message => Translatable('The partition where KIX is located has no disk space problems.'),
            );
        }
    }

    return $Self->GetResults();
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
