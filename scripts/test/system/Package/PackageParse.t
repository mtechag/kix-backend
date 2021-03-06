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

use Kernel::System::VariableCheck qw(:all);

# get package object
my $PackageObject = $Kernel::OM->Get('Package');

# get KIX Version
my $KIXVersion = $Kernel::OM->Get('Config')->Get('Version');

# leave only major and minor level versions
$KIXVersion =~ s{ (\d+ \. \d+) .+ }{$1}msx;

# add x as patch level version
$KIXVersion .= '.x';

my @Tests = (
    {
        Name   => 'Wrong package content',
        String => 'Not a valid structure
for a package file.',
        Success => 0,
    },
    {
        Name   => 'Invalid package content',
        String => '
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01//EN"
    "http://www.w3.org/TR/html4/strict.dtd">
<html>
  <head>
    <title>Page title</title>
  </head>
  <body>
    <div class="Main">
        <p>This is a invalid content.</p>
        <p>It can pass the XML parse.</p>
        <p>But is not possible to retrieve an structure from it.</p>
    </div>
  </body>
</html>
',
        Success => 0,
    },
    {
        Name   => 'Normal package content',
        String => '<?xml version="1.0" encoding="utf-8" ?>
    <kix_package version="1.0">
      <Name>TestPackage</Name>
      <Version>1.0.1</Version>
      <Vendor>c.a.p.e. IT GmbH</Vendor>
      <URL>http://www.cape-it.de/</URL>
      <License>GNU GENERAL PUBLIC LICENSE Version 2, June 1991</License>
      <ChangeLog>2013-08-14 New package (some test &lt; &gt; &amp;).</ChangeLog>
      <Description Lang="en">A test package (some test &lt; &gt; &amp;).</Description>
      <Description Lang="de">Ein Test Paket (some test &lt; &gt; &amp;).</Description>
      <ModuleRequired Version="1.112">Encode</ModuleRequired>
      <Framework>' . $KIXVersion . '</Framework>
      <BuildDate>2005-11-10 21:17:16</BuildDate>
      <BuildHost>yourhost.example.com</BuildHost>
      <Filelist>
        <File Location="Test" Permission="644" Encode="Base64">aGVsbG8K</File>
        <File Location="var/Test" Permission="644" Encode="Base64">aGVsbG8K</File>
        <File Location="bin/otrs.CheckDB.pl" Permission="755" Encode="Base64">aGVsbG8K</File>
      </Filelist>
    </kix_package>
',
        Success => 1,
    },
);

for my $Test (@Tests) {

    my $ResultStructure = 1;
    my %Structure = $PackageObject->PackageParse( String => $Test->{String} );
    $ResultStructure = 0 if !IsHashRefWithData( \%Structure );

    $Self->Is(
        $ResultStructure,
        $Test->{Success},
        "PackageParse() - $Test->{Name}",
    );

    if ( $Test->{Success} ) {

        $Self->Is(
            $Structure{Name}->{Content},
            'TestPackage',
            "PackageParse() - $Test->{Name} | Name",
        );

        $Self->Is(
            $Structure{Version}->{Content},
            '1.0.1',
            "PackageParse() - $Test->{Name} | Version",
        );

        $Self->Is(
            $Structure{Vendor}->{Content},
            'c.a.p.e. IT GmbH',
            "PackageParse() - $Test->{Name} | Vendor",
        );
    }
}

# cleanup cache
$Kernel::OM->Get('Cache')->CleanUp();

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
