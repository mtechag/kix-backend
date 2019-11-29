# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Automation::ExecPlan::TimeBased;

use strict;
use warnings;

use Date::Pcalc qw(:all);

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::System::Automation::ExecPlan::Common
);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Cache',
    'Kernel::System::DB',
    'Kernel::System::Log',
    'Kernel::System::User',
    'Kernel::System::Valid',
);

=head1 NAME

Kernel::System::Automation::ExecPlan::TimeBased - execution plan type for automation lib

=head1 SYNOPSIS

Provides a simple time based execution of jobs.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Describe()

Describe this execution plan module.

=cut

sub Describe {
    my ( $Self, %Param ) = @_;

    $Self->Description('Allows a time based execution of automation jobs. At least one weekday and time must be configured.');
    $Self->AddOption(
        Name        => 'Weekday',
        Label       => 'Weekday',
        Description => 'An array of weekdays (Mon,Tue,Wed,Thu,Fri,Sat,Sun) when the job should be executed.',
        Required    => 1,
    );
    $Self->AddOption(
        Name        => 'Time',
        Label       => 'Time',
        Description => 'An array of times when the job should be executed on every configured weekday.',
        Required    => 1,
    );

    return;
}

=item ValidateConfig()

Validates the parameters of the config.

Example:
    my $Valid = $Self->ValidateConfig(
        Config => {}                # required
    );

=cut

sub Validate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Config} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Got no Config!',
        );
        return;
    }

    # do some basic checks
    return if !$Self->SUPER::Validate(%Param);

    # check the weekdays

    return 1;
}

=item Run()

Check if the criteria are met, based on the given date+time. Returns 1 if the job can be executed and 0 if not.

Example:
    my $CanExecute = $Object->Run(
        Time              => '2019-10-25 13:55:26',
        Config            => {},
        LastExecutionTime => '2019-10-25 13:55:05'
    );

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # just return in case it's not a time based check
    return 0 if !$Param{Time};

    # check needed stuff
    for (qw(Config)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }    

    return 0 if !IsHashRefWithData($Param{Config}) || !IsArrayRefWithData($Param{Config}->{Weekday}) || !IsArrayRefWithData($Param{Config}->{Time});

    # convert given time to system time and split
    my $CheckSystemTime = $Kernel::OM->Get('Kernel::System::Time')->TimeStamp2SystemTime(
        String => $Param{Time}
    );
    my ($Sec, $Min, $Hour, $Day, $Month, $Year, $WeekDay) = $Kernel::OM->Get('Kernel::System::Time')->SystemTime2Date(
        SystemTime => $CheckSystemTime
    );

    # check weekday
    my @DayMap = qw/Sun Mon Tue Wed Thu Fri Sat/;
    my $CanExecute = 0;
    foreach my $RelevantDay ( @{$Param{Config}->{Weekday}} ) {
        next if $RelevantDay ne $DayMap[$WeekDay];
        $CanExecute = 1;
        last;
    }

    return 0 if !$CanExecute;

    # check time
    my ( $CurrSec, $CurrMin, $CurrHour, $CurrDay, $CurrMonth, $CurrYear ) = $Kernel::OM->Get('Kernel::System::Time')->SystemTime2Date(
        SystemTime => $Kernel::OM->Get('Kernel::System::Time')->SystemTime()
    );
    my $LastRunSystemTime = 0;
    if ( $Param{LastExecutionTime} ) {
        $LastRunSystemTime = $Kernel::OM->Get('Kernel::System::Time')->TimeStamp2SystemTime(
            String => $Param{LastExecutionTime}
        );
    }

    $CanExecute = 0;
    foreach my $Time ( @{$Param{Config}->{Time}} ) {
        # calculate time of next run 
        my $NextRunSystemTime = $Kernel::OM->Get('Kernel::System::Time')->TimeStamp2SystemTime(
            String => "$CurrYear-$CurrMonth-$CurrDay ".$Time.':00'
        );
        # ignore if next run time is not after the last job run
        next if $NextRunSystemTime > $CheckSystemTime;

        # ignore if next run time is not after the last job run
        next if $NextRunSystemTime <= $LastRunSystemTime;

        # ignore if the job could be executed but it was already executed
        next if $NextRunSystemTime <= $CheckSystemTime && $LastRunSystemTime >= $CheckSystemTime;

        $CanExecute = 1;
        last;
    }

    return $CanExecute;
}

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
