# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::PostMaster::Filter::PGPInlineDecryptFilter;

use strict;
use warnings;

our @ObjectDependencies = (
    'Log',
    'Crypt::PGP',
);

sub new {
    my $Type  = shift;
    my %Param = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    $Self->{LogObject} = $Kernel::OM->Get('Log');

    if ( !$Self->{CryptObject} ) {
        $Self->{CryptObject} = $Kernel::OM->Get('Crypt::PGP');
    }

    $Self->{Debug} = $Param{Debug} || 0;

    return $Self;
}

sub Run {
    my $Self  = shift;
    my %Param = @_;
    my $inBody;

    # get config options
    my %Config = ();
    if ( $Param{JobConfig} && ref( $Param{JobConfig} ) eq 'HASH' ) {
        %Config = %{ $Param{JobConfig} };
    }

    #------------------------------------------------------------------
    # NOTE: There is a 'bug' in Kernel::System::Crypt::PGP
    # in sub _CryptedWithKey, which is responsible for identifying
    # the keys used to encrypt the message. It parses the gpg output
    # for english output "encrypted with". This DOES NOT work if the
    # environment is set to another language.
    #------------------------------------------------------------------

    #Decrypt body....
    #print STDERR "Decrypting message...\n";
    if ( $Param{GetParam}->{Body} =~ /^-----BEGIN PGP MESSAGE-----/ ) {

        my %DecryptResult = $Self->{CryptObject}->Decrypt( Message => $Param{GetParam}->{Body} );

        if ( $DecryptResult{Successful} ) {
            $Param{GetParam}->{Body} = $DecryptResult{Data};
        }
        else {
            $Self->{LogObject}->Log(
                Priority => 'error',
                Message  => "Decrypt failure: " . $DecryptResult{Message},
            );
        }
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
