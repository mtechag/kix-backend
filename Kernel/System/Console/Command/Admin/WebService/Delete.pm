# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Console::Command::Admin::WebService::Delete;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Kernel::System::API::Webservice',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Delete an existing web service.');
    $Self->AddOption(
        Name        => 'webservice-id',
        Description => "The ID of an existing web service.",
        Required    => 1,
        HasValue    => 1,
        ValueRegex  => qr/\A\d+\z/smx,
    );

    return;
}

sub PreRun {
    my ( $Self, %Param ) = @_;

    my $WebServiceList = $Kernel::OM->Get('Kernel::System::API::Webservice')->WebserviceList();

    my $WebServiceID = $Self->GetOption('webservice-id');
    if ( !$WebServiceList->{$WebServiceID} ) {
        die "A web service with the ID $WebServiceID does not exists in this system.\n";
    }

    return;
}

sub Run {
    my ( $Self, %Param ) = @_;

    $Self->Print("<yellow>Deleting web service...</yellow>\n");

    # get current web service
    my $WebServiceID = $Self->GetOption('webservice-id');

    my $WebService =
        $Kernel::OM->Get('Kernel::System::API::Webservice')->WebserviceGet(
        ID => $WebServiceID,
        );

    if ( !$WebService ) {
        $Self->PrintError("Could not get a web service with the ID $WebServiceID from the database!");
        return $Self->ExitCodeError();
    }

    # web service delete
    my $Success = $Kernel::OM->Get('Kernel::System::API::Webservice')->WebserviceDelete(
        ID     => $WebServiceID,
        UserID => 1,
    );
    if ( !$Success ) {
        $Self->PrintError('Could not delete web service!');
        return $Self->ExitCodeError();
    }

    $Self->Print("<green>Done.</green>\n");
    return $Self->ExitCodeOk();
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
