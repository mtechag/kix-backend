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

use File::Basename;
use Time::HiRes ();

use Kernel::System::SupportDataCollector::PluginBase;

# get needed objects
my $CacheObject                = $Kernel::OM->Get('Cache');
my $MainObject                 = $Kernel::OM->Get('Main');
my $SupportDataCollectorObject = $Kernel::OM->Get('SupportDataCollector');
my $HelperObject               = $Kernel::OM->Get('UnitTest::Helper');

# test the support data collect asynchronous function
$HelperObject->ConfigSettingChange(
    Valid => 1,
    Key   => 'SupportDataCollector::DisablePlugins',
    Value => [
        'SupportDataCollector::Plugin::KIX::PackageDeployment',
    ],
);
$HelperObject->ConfigSettingChange(
    Valid => 1,
    Key   => 'SupportDataCollector::IdentifierFilterBlacklist',
    Value => [
        'SupportDataCollector::Plugin::KIX::TimeSettings::UserDefaultTimeZone',
    ],
);

my $TimeStart = [ Time::HiRes::gettimeofday() ];

my %Result = $SupportDataCollectorObject->CollectAsynchronous();

$Self->Is(
    $Result{Success},
    1,
    "Asynchronous data collection status",
);

my $TimeElapsed = Time::HiRes::tv_interval($TimeStart);

# Look for all plug-ins in the FS
my @PluginFiles = $MainObject->DirectoryRead(
    Directory => $Kernel::OM->Get('Config')->Get('Home')
        . "/Kernel/System/SupportDataCollector/PluginAsynchronous",
    Filter    => "*.pm",
    Recursive => 1,
);

# Execute all plug-ins
for my $PluginFile (@PluginFiles) {

    # Convert file name => package name
    $PluginFile =~ s{^.*(Kernel/System.*)[.]pm$}{$1}xmsg;
    $PluginFile =~ s{/+}{::}xmsg;

    if ( !$MainObject->Require($PluginFile) ) {
        return (
            Success      => 0,
            ErrorMessage => "Could not load $PluginFile!",
        );
    }
    my $PluginObject = $PluginFile->new( %{$Self} );

    my $AsynchronousData = $PluginObject->_GetAsynchronousData();

    $Self->True(
        defined $AsynchronousData,
        "$PluginFile - asynchronous data exists.",
    );
}

$Self->True(
    $TimeElapsed < 180,
    "CollectAsynchronous() - Should take less than 120 seconds, it took $TimeElapsed"
);

# test the support data collect function
$CacheObject->CleanUp(
    Type => 'SupportDataCollector',
);

$TimeStart = [ Time::HiRes::gettimeofday() ];

%Result = $SupportDataCollectorObject->Collect(
    WebTimeout => 60,
    Hostname   => $HelperObject->GetTestHTTPHostname(),
);

$TimeElapsed = Time::HiRes::tv_interval($TimeStart);

$Self->Is(
    $Result{Success},
    1,
    "Data collection status",
);

$Self->Is(
    $Result{ErrorMessage},
    undef,
    "There is no error message",
);

$Self->True(
    scalar @{ $Result{Result} || [] } >= 1,
    "Data collection result count",
);

my %SeenIdentifier;

for my $ResultEntry ( @{ $Result{Result} || [] } ) {
    $Self->True(
        (
            $ResultEntry->{Status}
                == $Kernel::System::SupportDataCollector::PluginBase::StatusUnknown
                || $ResultEntry->{Status}
                == $Kernel::System::SupportDataCollector::PluginBase::StatusOK
                || $ResultEntry->{Status}
                == $Kernel::System::SupportDataCollector::PluginBase::StatusWarning
                || $ResultEntry->{Status}
                == $Kernel::System::SupportDataCollector::PluginBase::StatusProblem
                || $ResultEntry->{Status}
                == $Kernel::System::SupportDataCollector::PluginBase::StatusInfo

        ),
        "$ResultEntry->{Identifier} - status ($ResultEntry->{Status}).",
    );

    $Self->Is(
        $SeenIdentifier{ $ResultEntry->{Identifier} }++,
        0,
        "$ResultEntry->{Identifier} - identifier only used once.",
    );
}

# Check if the identifier from the disabled plugions are not present.
for my $DisabledPluginsIdentifier (
    qw(Kernel::System::SupportDataCollector::Plugin::KIX::PackageDeployment Kernel::System::SupportDataCollector::Plugin::KIX::PackageDeployment::Verification Kernel::System::SupportDataCollector::Plugin::KIX::PackageDeployment::FrameworkVersion)
    )
{
    $Self->False(
        $SeenIdentifier{$DisabledPluginsIdentifier},
        "Collect() - SupportDataCollector::DisablePlugins - $DisabledPluginsIdentifier should not be present"
    );
}

# Check if the identifiers from the identifier filter blacklist are not present.
$Self->False(
    $SeenIdentifier{'SupportDataCollector::Plugin::KIX::TimeSettings::UserDefaultTimeZone'},
    "Collect() - SupportDataCollector::IdentifierFilterBlacklist - Kernel::System::SupportDataCollector::Plugin::KIX::TimeSettings::UserDefaultTimeZone should not be present"
);

# cache tests
my $CacheResult = $CacheObject->Get(
    Type => 'SupportDataCollector',
    Key  => 'DataCollect',
);
$Self->IsDeeply(
    $CacheResult,
    \%Result,
    "Collect() - Cache"
);

$Self->True(
    $TimeElapsed < 60,
    "Collect() - Should take less than 60 seconds, it took $TimeElapsed"
);

my $TimeStartCache = [ Time::HiRes::gettimeofday() ];
%Result = $SupportDataCollectorObject->Collect(
    UseCache => 1,
);
my $TimeElapsedCache = Time::HiRes::tv_interval($TimeStartCache);

$CacheResult = $CacheObject->Get(
    Type => 'SupportDataCollector',
    Key  => 'DataCollect',
);
$Self->IsDeeply(
    $CacheResult,
    \%Result,
    "Collect() - Cache",
);

$Self->True(
    $TimeElapsedCache < $TimeElapsed,
    "Collect() - Should take less than $TimeElapsed seconds, it took $TimeElapsedCache",
);

# cleanup cache
$CacheObject->CleanUp();

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
