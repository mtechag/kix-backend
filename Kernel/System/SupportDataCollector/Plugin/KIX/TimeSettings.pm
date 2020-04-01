# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::SupportDataCollector::Plugin::KIX::TimeSettings;
## nofilter(TidyAll::Plugin::KIX::Perl::Time)

use strict;
use warnings;

use POSIX;
use Time::Local;

use base qw(Kernel::System::SupportDataCollector::PluginBase);

use Kernel::Language qw(Translatable);

our @ObjectDependencies = (
    'Config',
    'Time',
);

sub GetDisplayPath {
    return Translatable('KIX') . '/' . Translatable('Time Settings');
}

sub Run {
    my $Self = shift;

    my $Dummy          = localtime();       ## no critic
    my $ServerTimeZone = POSIX::tzname();

    $Self->AddResultInformation(
        Identifier => 'ServerTimeZone',
        Label      => Translatable('Server time zone'),
        Value      => $ServerTimeZone,
    );

    # Check if local time and UTC time are different
    my $ServerTimeDiff = $Kernel::OM->Get('Time')->ServerLocalTimeOffsetSeconds();

    # calculate offset - should be '+0200', '-0600', '+0545' or '+0000'
    my $Direction   = $ServerTimeDiff < 0 ? '-' : '+';
    my $DiffHours   = abs int( $ServerTimeDiff / 3600 );
    my $DiffMinutes = abs int( ( $ServerTimeDiff % 3600 ) / 60 );

    $Self->AddResultInformation(
        Identifier => 'ServerTimeOffset',
        Label      => Translatable('Computed server time offset'),
        Value      => sprintf( '%s%02d%02d', $Direction, $DiffHours, $DiffMinutes ),
    );

    my $KIXTimeZone = $Kernel::OM->Get('Config')->Get('TimeZone');

    if ( $ServerTimeDiff && $KIXTimeZone && $KIXTimeZone ne '+0' ) {
        $Self->AddResultProblem(
            Identifier => 'KIXTimeZone',
            Label      => Translatable('KIX TimeZone setting (global time offset)'),
            Value      => $KIXTimeZone,
            Message    => Translatable('TimeZone may only be activated for systems running in UTC.'),
        );
    }
    else {
        $Self->AddResultOk(
            Identifier => 'KIXTimeZone',
            Label      => Translatable('KIX TimeZone setting (global time offset)'),
            Value      => $KIXTimeZone,
        );
    }

    my $KIXTimeZoneUser = $Kernel::OM->Get('Config')->Get('TimeZoneUser');

    if ( $KIXTimeZoneUser && ( $ServerTimeDiff || ( $KIXTimeZone && $KIXTimeZone ne '+0' ) ) ) {
        $Self->AddResultProblem(
            Identifier => 'KIXTimeZoneUser',
            Label      => Translatable('KIX TimeZoneUser setting (per-user time zone support)'),
            Value      => $KIXTimeZoneUser,
            Message    => Translatable(
                'TimeZoneUser may only be activated for systems running in UTC that don\'t have an KIX TimeZone set.'
            ),
        );
    }
    else {
        $Self->AddResultOk(
            Identifier => 'KIXTimeZoneUser',
            Label      => Translatable('KIX TimeZoneUser setting (per-user time zone support)'),
            Value      => $KIXTimeZoneUser,
        );
    }

    for my $Counter ( 1 .. 9 ) {
        my $CalendarTimeZone = $Kernel::OM->Get('Config')->Get( 'TimeZone::Calendar' . $Counter );
        if ( $ServerTimeDiff && $CalendarTimeZone && $CalendarTimeZone ne '+0' ) {
            $Self->AddResultProblem(
                Identifier => "KIXTimeZone::Calendar$Counter",
                Label      => Translatable('KIX TimeZone setting for calendar ') . $Counter,
                Value      => $CalendarTimeZone,
                Message    => Translatable('TimeZone may only be activated for systems running in UTC.'),
            );
        }
        else {
            $Self->AddResultOk(
                Identifier => "KIXTimeZone::Calendar$Counter",
                Label      => Translatable('KIX TimeZone setting for calendar ') . $Counter,
                Value      => $CalendarTimeZone,
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
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
