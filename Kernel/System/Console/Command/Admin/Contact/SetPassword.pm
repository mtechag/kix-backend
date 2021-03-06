# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Console::Command::Admin::Contact::SetPassword;

use strict;
use warnings;

use base qw(Kernel::System::Console::BaseCommand);

our @ObjectDependencies = (
    'Config',
    'Contact',
);

sub Configure {
    my ( $Self, %Param ) = @_;

    $Self->Description('Updates the password for a contact.');
    $Self->AddArgument(
        Name        => 'login',
        Description => "Specify the login of the contact to be updated.",
        Required    => 1,
        ValueRegex  => qr/.*/smx,
    );
    $Self->AddArgument(
        Name        => 'password',
        Description => "Set a new password for the user (a password will be generated otherwise).",
        Required    => 0,
        ValueRegex  => qr/.*/smx,
    );
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $Login = $Self->GetArgument('login');

    $Self->Print("<yellow>Setting password for contact '$Login'...</yellow>\n");

    my $ContactObject = $Kernel::OM->Get('Contact');

    # get contact
    my %ContactList = $ContactObject->ContactSearch(
        Login => $Login,
    );

    if ( !%ContactList ) {
        $Self->PrintError("No contact found with login '$Login'!\n");
        return $Self->ExitCodeError();
    }

    # if no password has been provided, generate one
    my $Password = $Self->GetArgument('password');
    if ( !$Password ) {
        $Password = $ContactObject->GenerateRandomPassword( Size => 12 );
        $Self->Print("<yellow>Generated password '$Password'.</yellow>\n");
    }

    my $Result = $ContactObject->SetPassword(
        ID       => (keys %ContactList)[0],
        Password => $Password,
        UserID   => 1,
    );

    if ( !$Result ) {
        $Self->PrintError("Failed to set password!\n");
        return $Self->ExitCodeError();
    }

    $Self->Print("<green>Successfully set password for contact '$Login'.</green>\n");
    return $Self->ExitCodeOk();
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
