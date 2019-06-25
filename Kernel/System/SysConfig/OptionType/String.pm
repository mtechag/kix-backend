# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::SysConfig::OptionType::String;

use strict;
use warnings;

use base qw(
    Kernel::System::SysConfig::OptionType::Base
);

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::System::Log',
);

=head1 NAME

Kernel::System::SysConfig::OptionType::String - String type lib

=head1 SYNOPSIS

All functions for SysConfig option type String.

=head1 PUBLIC INTERFACE

=over 4

=item ValidateSetting()

Validates the given setting and returns the prepared Setting as well as the default value.

    my $Success = $OptionTypeObject->ValidateSetting(
        Setting => {...},
    );

=cut

sub ValidateSetting {
    my ( $Self, %Param ) = @_;
    my %Setting;
    my $DefaultValue;
    
    if ( IsHashRefWithData($Param{Setting}) ) {
        %Setting = (
            Regex => $Param{Setting}->{Regex}
        );
        $DefaultValue = $Param{Setting}->{content};
    }
    else {
        $DefaultValue = $Param{Setting};
    }

    return (\%Setting, $DefaultValue);
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
