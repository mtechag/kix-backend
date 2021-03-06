# --
# Modified version of the work: Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Package::Event::SupportDataSend;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Cache',
    'Log',
    'SystemData',
    'Time',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Data Event Config)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get system data object
    my $SystemDataObject = $Kernel::OM->Get('SystemData');

    my $RegistrationState = $SystemDataObject->SystemDataGet(
        Key => 'Registration::State',
    ) || '';

    # do nothing if system is not register
    return 1 if $RegistrationState ne 'registered';

    my $SupportDataSending = $SystemDataObject->SystemDataGet(
        Key => 'Registration::SupportDataSending',
    ) || 'No';

    # return if Data Sending is not activated
    return 1 if $SupportDataSending ne 'Yes';

    # delete cache
    $Kernel::OM->Get('Cache')->Delete(
        Type => 'SupportDataCollector',
        Key  => 'DataCollect',
    );

    # get time object
    my $TimeObject = $Kernel::OM->Get('Time');

    # calculate next update time for 1 hour
    my $NewUpdateSeconds    = 3600;
    my $NewUpdateSystemTime = $TimeObject->SystemTime() + $NewUpdateSeconds;
    my $NewUpdateTime       = $TimeObject->SystemTime2TimeStamp(
        SystemTime => $NewUpdateSystemTime,
    );

    # get current update time
    my $CurrentUpdateTime = $SystemDataObject->SystemDataGet(
        Key => 'Registration::NextUpdateTime',
    );

    # if there is no update time set it for 1 hour
    if ( !defined $CurrentUpdateTime ) {
        $SystemDataObject->SystemDataAdd(
            Key    => 'Registration::NextUpdateTime',
            Value  => $NewUpdateTime,
            UserID => 1,
        );
        return 1;
    }

    # convert update time to system time for easy compare
    my $CurrentUpdateSystemTime = $TimeObject->TimeStamp2SystemTime(
        String => $CurrentUpdateTime,
    );

    # return success if the next update is schedule in or less than 1 hour
    return 1 if $CurrentUpdateSystemTime <= $NewUpdateSystemTime;

    # otherwise update next update for 1 hour
    $SystemDataObject->SystemDataUpdate(
        Key    => 'Registration::NextUpdateTime',
        Value  => $NewUpdateTime,
        UserID => 1,
    );
    return 1;
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
