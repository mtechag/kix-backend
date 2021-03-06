# --
# Modified version of the work: Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::SupportDataCollector::PluginAsynchronous;

use strict;
use warnings;

our @ObjectDependencies = (
    'JSON',
    'SystemData',
);

use base qw(Kernel::System::SupportDataCollector::PluginBase);

sub _GetAsynchronousData {
    my ( $Self, %Param ) = @_;

    my $Identifier = Scalar::Util::blessed($Self);

    my $AsynchronousDataString = $Kernel::OM->Get('SystemData')->SystemDataGet(
        Key => $Identifier,
    );

    return if !defined $AsynchronousDataString;

    # get asynchronous data as array ref
    my $AsynchronousData = $Kernel::OM->Get('JSON')->Decode(
        Data => $AsynchronousDataString,
    ) || [];

    return $AsynchronousData;
}

sub _StoreAsynchronousData {
    my ( $Self, %Param ) = @_;

    return 1 if !$Param{Data};

    my $Identifier = Scalar::Util::blessed($Self);

    my $CurrentAsynchronousData = $Self->_GetAsynchronousData();

    my $AsynchronousDataString = $Kernel::OM->Get('JSON')->Encode(
        Data => $Param{Data},
    );

    # get system data object
    my $SystemDataObject = $Kernel::OM->Get('SystemData');

    if ( !defined $CurrentAsynchronousData ) {

        $SystemDataObject->SystemDataAdd(
            Key    => $Identifier,
            Value  => $AsynchronousDataString,
            UserID => 1,
        );
    }
    else {

        $SystemDataObject->SystemDataUpdate(
            Key    => $Identifier,
            Value  => $AsynchronousDataString,
            UserID => 1,
        );
    }

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
