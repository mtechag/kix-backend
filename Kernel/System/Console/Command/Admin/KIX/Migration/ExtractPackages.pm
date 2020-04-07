# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Admin::KIX::Migration::ExtractPackages;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Main',
    'Package',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Extract packages to prepare migration.');
    $Self->AddOption(
        Name        => 'dir',
        Description => 'Define the target directory were the files should be created.',
        HasValue    => 1,
        Required    => 1,
        ValueRegex  => qr/.*/smx,
    );

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my %Options;
    $Options{Directory} = $Self->GetOption('dir');

    my @RepositoryList = $Kernel::OM->Get('Package')->RepositoryList();

    # get dependencies
    my %PackageDeps = ();
    for my $Package (@RepositoryList) {
        if ($Package->{PackageRequired}) {
            if (ref $PackageDeps{$Package->{Name}->{Content}} ne 'ARRAY') {
                $PackageDeps{$Package->{Name}->{Content}} = [];
            }
            foreach my $Deps (@{$Package->{PackageRequired}}) {
                push(@{$PackageDeps{$Package->{Name}->{Content}}}, $Deps->{Content});
            }
        }
        else {
            $PackageDeps{$Package->{Name}->{Content}} = undef;
        }
    }

    my @PackageListRaw;
    foreach my $PackageName (sort keys %PackageDeps) {
        $Self->_BuildPackageList(
            Index => 1,
            PackageDeps => \%PackageDeps,
            PackageName => $PackageName,
            PackageList => \@PackageListRaw,
        );
    }

    my %PackageList;
    foreach my $Package (sort {$b->{Index} cmp $a->{Index}} @PackageListRaw) {
        if (!$PackageList{$Package->{Name}} || $PackageList{$Package->{Name}} < $Package->{Index}) {
            $PackageList{$Package->{Name}} = $Package->{Index};
        }
    }

    for my $Package (sort @RepositoryList) {
        my $PackageContent = $Kernel::OM->Get('Package')->RepositoryGet(
            Name    => $Package->{Name}->{Content},
            Version => $Package->{Version}->{Content},
        );
        if (!$PackageContent) {
            return $Self->ExitCodeError();
        }

        print ".";

        my $Result = $Kernel::OM->Get('Main')->FileWrite(
            Directory => $Options{Directory} || '.',
            Filename  => "$PackageList{$Package->{Name}->{Content}}-$Package->{Name}->{Content}-$Package->{Version}->{Content}.kpm",
            Content   => \$PackageContent,
        );
        if (!$Result) {
            return $Self->ExitCodeError();
        }
    }

    print "\n";

    return $Self->ExitCodeOk();
}

sub _BuildPackageList {
    my ($Self, %Param) = @_;

    if ($Param{PackageDeps}->{$Param{PackageName}}) {
        push(@{$Param{PackageList}}, {Index => $Param{Index}, Name => $Param{PackageName}});
        foreach my $PackageName (@{$Param{PackageDeps}->{$Param{PackageName}}}) {
            $Self->_BuildPackageList(
                %Param,
                Index => $Param{Index}+1,
                PackageName => $PackageName,
            );
        }
    }
    else {
        push(@{$Param{PackageList}}, {Index => $Param{Index}, Name => $Param{PackageName}});
    }

    return 1;
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
