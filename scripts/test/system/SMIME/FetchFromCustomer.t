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
use File::Path qw(mkpath rmtree);

my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
my $MainObject   = $Kernel::OM->Get('Kernel::System::Main');

$ConfigObject->Set(
    Key   => 'CheckEmailAddresses',
    Value => 0,
);

# copy all
# discard main + config

my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

my $HomeDir = $ConfigObject->Get('Home');

# create directory for certificates and private keys
my $CertPath    = $ConfigObject->Get('Home') . "/var/tmp/certs";
my $PrivatePath = $ConfigObject->Get('Home') . "/var/tmp/private";
mkpath( [$CertPath],    0, 0770 );    ## no critic
mkpath( [$PrivatePath], 0, 0770 );    ## no critic

# set SMIME paths
$ConfigObject->Set(
    Key   => 'SMIME::CertPath',
    Value => $CertPath,
);
$ConfigObject->Set(
    Key   => 'SMIME::PrivatePath',
    Value => $PrivatePath,
);

my $OpenSSLBin = $ConfigObject->Get('SMIME::Bin');

# set config
$ConfigObject->Set(
    Key   => 'SMIME',
    Value => 1,
);
$ConfigObject->Set(
    Key   => 'SMIME::FetchFromCustomer',
    Value => 1,
);

# check if openssl is located there
if ( !-e $OpenSSLBin ) {

    # maybe it's a mac with macport
    if ( -e '/opt/local/bin/openssl' ) {
        $ConfigObject->Set(
            Key   => 'SMIME::Bin',
            Value => '/opt/local/bin/openssl',
        );
    }
}

my $SMIMEObject = $Kernel::OM->Get('Kernel::System::Crypt::SMIME');

if ( !$SMIMEObject ) {
    print STDERR "NOTICE: No SMIME support!\n";

    if ( !-e $OpenSSLBin ) {
        $Self->False(
            1,
            "No such $OpenSSLBin!",
        );
    }
    elsif ( !-x $OpenSSLBin ) {
        $Self->False(
            1,
            "$OpenSSLBin not executable!",
        );
    }
    elsif ( !-e $CertPath ) {
        $Self->False(
            1,
            "No such $CertPath!",
        );
    }
    elsif ( !-d $CertPath ) {
        $Self->False(
            1,
            "No such $CertPath directory!",
        );
    }
    elsif ( !-w $CertPath ) {
        $Self->False(
            1,
            "$CertPath not writable!",
        );
    }
    elsif ( !-e $PrivatePath ) {
        $Self->False(
            1,
            "No such $PrivatePath!",
        );
    }
    elsif ( !-d $Self->{PrivatePath} ) {
        $Self->False(
            1,
            "No such $PrivatePath directory!",
        );
    }
    elsif ( !-w $PrivatePath ) {
        $Self->False(
            1,
            "$PrivatePath not writable!",
        );
    }
    return 1;
}

# get helper object
$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');
my $Random = $Helper->GetRandomID();

# get existing certificates
my @CertList  = $SMIMEObject->CertificateList();
my $CertCount = 0;
for my $Cert ( sort @CertList ) {
    $CertCount++;
}

# first stage
my $TableName             = 'UT_' . $Random;
my @UnitTestContacts = (
    {
        FirstName       => 'Hans',
        LastName        => 'Hansen',
        Login           => 'unittest1',
        Email           => 'unittest@example.org',
        Status          => 1,
        CertificateType => 'PEM',
        Certifiacate    => '-----BEGIN CERTIFICATE-----
MIIEXjCCA0agAwIBAgIJAPIBQyBe/HbpMA0GCSqGSIb3DQEBBQUAMHwxCzAJBgNV
BAYTAkRFMQ8wDQYDVQQIEwZCYXllcm4xEjAQBgNVBAcTCVN0cmF1YmluZzEQMA4G
A1UEChMHT1RSUyBBRzERMA8GA1UEAxMIdW5pdHRlc3QxIzAhBgkqhkiG9w0BCQEW
FHVuaXR0ZXN0QGV4YW1wbGUub3JnMB4XDTEyMDUwODEzMTEzMloXDTI2MDExNTEz
MTEzMlowfDELMAkGA1UEBhMCREUxDzANBgNVBAgTBkJheWVybjESMBAGA1UEBxMJ
U3RyYXViaW5nMRAwDgYDVQQKEwdPVFJTIEFHMREwDwYDVQQDEwh1bml0dGVzdDEj
MCEGCSqGSIb3DQEJARYUdW5pdHRlc3RAZXhhbXBsZS5vcmcwggEiMA0GCSqGSIb3
DQEBAQUAA4IBDwAwggEKAoIBAQC2hq1peYGlo4d5Lz8wEGLvUg9pZq4hQhmVwatj
v0q5dNJQ6HZPmzQTZLCEL6Wcn/7MsCQ6v4Avryjf3OPCMV/HTWuoHwmrXzM6Dtr/
3cuUF5L0wOV6wEE+IF6J1OYdObDxRPrz5wZP2XEx3B5yMETksN6qF+g8CwaXwbtl
sR2ZfGo+qxSP+rPs9gy54Xvg2rrgh/SIvKKcFNWX3gJPGg66b0Ne+gOx68u7XREH
y71yzIsCAq52vqBnKySnXIIDG8Lem4LNwlMW993snTK/nE/yhYQkqjcdLpb3EXCq
sxZ+2fpaLFJcU7js5yUDQzncPawy04QNHTrPtC22fJgXFCAZAgMBAAGjgeIwgd8w
HQYDVR0OBBYEFBZG1kwr7OFhLzYO9PEsPJT5OxbaMIGvBgNVHSMEgacwgaSAFBZG
1kwr7OFhLzYO9PEsPJT5OxbaoYGApH4wfDELMAkGA1UEBhMCREUxDzANBgNVBAgT
BkJheWVybjESMBAGA1UEBxMJU3RyYXViaW5nMRAwDgYDVQQKEwdPVFJTIEFHMREw
DwYDVQQDEwh1bml0dGVzdDEjMCEGCSqGSIb3DQEJARYUdW5pdHRlc3RAZXhhbXBs
ZS5vcmeCCQDyAUMgXvx26TAMBgNVHRMEBTADAQH/MA0GCSqGSIb3DQEBBQUAA4IB
AQBE2M1dcTkQyPJUXzchMGIWD5nkUDs0iHqIPNfeTWcTW3iuzZHA6rj4Lw7RFOs+
seYl14DywnYFUM5UZz4ko9t+uqECp4LK6qdkYomjSw+E8Zs5se8QlRYhDEjEDqwR
c0xg0lgybQoceMJ7ub+V/yp/EIyfKbaJBtYIDucQ6yB1EECVm1hfKKLg+gUk4rLY
WgEFDKCVadkItr5yLLMp9CGKWpiv7sW/5f2YVTEZGCcbp2hQRCMPpQYCtvbdfyh5
lZbOYUaP6zWPsKjftcev2Q5ik1L7N9eCynBF3a2U0TPVkfFyzuO58k96vUhKltOb
nj2wbQO4KjM12YLUuvahk5se
-----END CERTIFICATE-----
',
    },
    {
        FirstName       => 'Klaus',
        LastName        => 'Klausen',
        Login           => 'unittest2',
        Email           => 'smimeuser1@test.com',
        Status          => 1,
        CertificateType => 'P7B',
        Certifiacate    => '-----BEGIN CERTIFICATE-----
MIIFjTCCA3UCCQDt3sB/CPz9rjANBgkqhkiG9w0BAQUFADB7MQswCQYDVQQGEwJN
WDEQMA4GA1UECBMHSmFsaXNjbzEQMA4GA1UEChMHT1RSUyBBRzERMA8GA1UECxMI
T1RSUyBMYWIxETAPBgNVBAMTCE9UUlMgTGFiMSIwIAYJKoZIhvcNAQkBFhNvdHJz
bGFiQGV4YW1wbGUuY29tMB4XDTEyMDUxNTAyNTIwNloXDTIyMDUxMzAyNTIwNlow
gZUxCzAJBgNVBAYTAk1YMRAwDgYDVQQIEwdKYWxpc2NvMRQwEgYDVQQHEwtHdWFk
YWxhamFyYTEQMA4GA1UEChMHT1RSUyBBRzERMA8GA1UECxMIT1RSUyBMYWIxFTAT
BgNVBAMTDFNNSU1FIFVzZXIgMTEiMCAGCSqGSIb3DQEJARYTc21pbWV1c2VyMUB0
ZXN0LmNvbTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAJ/cr+sMwWW3
SWLazwZ9O/dScatebBsQ3zEof/f6rO7zSppCPg/iA69VRZ9/wDJLe815bA9UBFXg
M+u/gI0Mnm8JPpPxXc+qqiTyWiNF25Tmxh3BWrFEcrx/3IRQ41G+3mbXWe5NcuWZ
unFbA8OGXW33BqQoV6SZjCxow/uz+YIkNXyNcHYRI87OrvCDhoc7qn7J6RFcDoyb
Sc8Tc5RasFiNvzE2vjodqKmQt1tpjucv15cBtSDTOwANtYYbcFgcUBqUZbeG2MbJ
e8791yXw5ZhoOOahroeszzlwk9r/d8x20iMeKm8O8nGq8+EDDPAZPhyzRfFgQexf
lu34PDGxr8eDniS31ohgMyLx4Kjsl4k5mKk3oxVbc69Y1cRbTbkVOw6gzc+Iyabb
Kuf+xcZQs/QH0IhKLX8yztW72KQJ0Bu0SS9750gkn2Zg2tEwTRnhvoqfLgcqI9Eb
vhYPP5vD17bqFYWizFyWCW7hyb9d41SZREzIT+hCSvRNvQY1HCTRk66pMU62ywjM
1XZmxjiZctQuTlPqHvGU3zF5A2wL4IfnsFGosaQ45nN03tWNfTlpZqHWMEZgmTEq
NGSjVZZUS8CLPq/YXREcWsXZKTFlY5bMhdPZF/PAgKQzPgC+NIkM2dbQGwK9d8P9
tOdHM/Qw6x/56P97uWfMOmKIL0pIygtPAgMBAAEwDQYJKoZIhvcNAQEFBQADggIB
AC32NGijuckU3gSks1pRi2hFzLEmlPcKCyBIjQlylOzUI93v3Bz0DAVcZGb0xw1I
KhNRL+PSF2X7eZi970CrGk5C1JquyS/khLR1kCqEFJshwCTm8ONMpFwXcMPgbRNQ
TNcS+OQTFAS2OV8mqAYLSmYL5e8OgxEUG765ORLU+2QHarMtky4VN1bBzpjCYvzU
UZY1Y3LILjARtJGE5Bl/9/QZTNsUcDKzaxbPT9/SF2JJhM7TkHBcrkm6q+vF3V98
PxdIj/cRPF8cvm9PGQA5JdnoIERGp4+RV8iuVBUPes4qfjQ8rQ1UHtqgscmVtu40
vM22tg7IfjZkj/YUbihj7q+D3GaG9G5qZJA6rIm0A4UKka7xBtIWqqVFDTGGkvAi
hX5OcSIvRiv+l9vBeYs/g4lM1yRLrlD7Zxyj3VdhBm4tJOzWzTp7T12AM9vxtGO7
T6C6nqSZCjGrZ24p0iQky9BrW49xXbGWu8PhxNwxA7ah9keARaTIyiNYgbT9Ey41
5oALXeUDVEVKLZpbkbsSaZ/NEQezMOSkeJxN8zhz9XAizykub3qoN1th0gyuX6SB
cguOn8Sg1O8jzlrZQOT5F6r2BGi4gn/rxIMAOoImAoYyjHZVK0psyGBekh4HYHDl
wpStC0yiqNRd1/r/wkihHv57xSScBPkpdu2Q9RBY36dJ
-----END CERTIFICATE-----
',
    }
);

# Create Table
{
    my $XMLLoginTable = '<Table Name="' . $TableName . '">
        <Column Name="id" Required="true" PrimaryKey="true" AutoIncrement="true" Type="INTEGER"/>
        <Column Name="login" Required="true" Size="200" Type="VARCHAR"/>
        <Column Name="email" Required="true" Size="150" Type="VARCHAR"/>
        <Column Name="customer_id" Required="true" Size="150" Type="VARCHAR"/>
        <Column Name="pw" Required="false" Size="64" Type="VARCHAR"/>
        <Column Name="title" Required="false" Size="50" Type="VARCHAR"/>
        <Column Name="first_name" Required="true" Size="100" Type="VARCHAR"/>
        <Column Name="last_name" Required="true" Size="100" Type="VARCHAR"/>
        <Column Name="userSMIMECertificate" Required="false" Type="LONGBLOB"/>
        <Column Name="valid_id" Required="true" Type="SMALLINT"/>
        <Column Name="create_time" Required="true" Type="DATE"/>
        <Column Name="create_by" Required="true" Type="INTEGER"/>
        <Column Name="change_time" Required="true" Type="DATE"/>
        <Column Name="change_by" Required="true" Type="INTEGER"/>
    </Table>';
    my @XMLARRAY = $Kernel::OM->Get('Kernel::System::XML')->XMLParse( String => $XMLLoginTable );
    my @SQL = $DBObject->SQLProcessor( Database => \@XMLARRAY );
    my @SQLPost = $DBObject->SQLProcessorPost( Database => \@XMLARRAY );

    for my $SQL ( @SQL, @SQLPost ) {
        $Self->True(
            $DBObject->Do( SQL => $SQL ),
            "Login-table $TableName created",
        );
    }
}

# Fill Table
my $SQL = "INSERT INTO $TableName
                (login, email, customer_id, pw, title, first_name, last_name, userSMIMECertificate, valid_id, create_time,
                create_by, change_time, change_by)
            VALUES
                (?,?,?,?,?,?,?,?,1,current_timestamp,1,current_timestamp,1)";
my $Pwd = $MainObject->GenerateRandomString(
    Length => 8,
);
foreach my $Contact (@UnitTestContacts) {
    my $Return = $DBObject->Do(
        SQL  => $SQL,
        Bind => [
            \$Contact->{Login}, \$Contact->{Email}, \'unittest_customer_id',
            \$Pwd,
            \'Mr', \$Contact->{FirstName}, \$Contact->{LastName}, \$Contact->{Certifiacate}
        ],
    );
    $DBObject->Prepare(
        SQL  => "SELECT id, email from $TableName where login = ?",
        Bind => [ \$Contact->{Login} ],
    );
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $Self->Is(
            $Row[1],
            $Contact->{Email},
            "Contact $Row[0] with $Contact->{CertificateType} added into ContactTable ",
        );
    }
}

# Add Table as Contact Table in Config
my $NewConfig;
my $FileLocation;

$ConfigObject->Set(
    Key   => "Contact::AuthModule10",
    Value => 'Kernel::System::ContactAuth::DB',
);
$ConfigObject->Set(
    Key   => "Contact::AuthModule::DB::Table10",
    Value => $TableName,
);
$ConfigObject->Set(
    Key   => "Contact::AuthModule::DB::CustomerKey10",
    Value => 'login',
);
$ConfigObject->Set(
    Key   => "Contact::AuthModule::DB::CustomerPassword10",
    Value => 'pw',
);
$ConfigObject->Set(
    Key   => "Contact::AuthModule::DB::CryptType10",
    Value => 'plain',
);
my %ContactConfig = (
    Name   => 'Database Backend',
    Module => 'Kernel::System::Contact::DB',
    Params => {
        Table => $TableName,
    },
    ReadOnly => 1,

    # customer unique id
    CustomerKey => 'login',

    # customer #
    CustomerID                         => 'customer_id',
    ContactListFields             => [ 'first_name', 'last_name', 'email' ],
    ContactSearchFields           => [ 'login', 'first_name', 'last_name', 'customer_id' ],
    ContactSearchPrefix           => '*',
    ContactSearchSuffix           => '*',
    ContactSearchListLimit        => 250,
    ContactPostMasterSearchFields => ['email'],
    ContactNameFields     => [ 'title', 'first_name', 'last_name' ],
    ContactEmailUniqCheck => 1,

    # show now own tickets in customer panel, CompanyTickets
    ContactExcludePrimaryCustomerID => 0,

    # admin can't change customer preferences
    AdminSetPreferences => 0,

    # cache time to live in sec. - cache any ldap queries
    CacheTTL => 120,
    Map      => [

        # note: Login, Email and CustomerID are mandatory!
        # if you need additional attributes from AD, just map them here.
        # var, frontend, storage, shown (1=always,2=lite), required, storage-type, http-link, readonly
        [ 'Salutation',       'Title or salutation', 'title',                1, 0, 'var', '', 0 ],
        [ 'Firstname',        'Firstname',           'first_name',           1, 1, 'var', '', 0 ],
        [ 'Lastname',         'Lastname',            'last_name',            1, 1, 'var', '', 0 ],
        [ 'Login',            'Username',            'login',                1, 1, 'var', '', 0 ],
        [ 'Password',         'Password',            'pw',                   0, 0, 'var', '', 0 ],
        [ 'Email',            'Email',               'email',                1, 1, 'var', '', 0 ],
        [ 'CustomerID',       'CustomerID',          'customer_id',          0, 1, 'var', '', 0 ],
        [ 'SMIMECertificate', 'SMIMECertificate',    'userSMIMECertificate', 0, 1, 'var', '', 0 ],
    ],
);
my $Return = $ConfigObject->Set(
    Key   => "Contact10",
    Value => \%ContactConfig,
);

my $AuthObject = $Kernel::OM->Get('Kernel::System::ContactAuth');

# login check
$DBObject->Prepare(
    SQL => "SELECT id, login, pw, email from $TableName",
);
my %Customers;
while ( my @Row = $DBObject->FetchrowArray() ) {
    $Customers{ $Row[1] } = $Row[2];
}

for my $Customer ( sort keys %Customers ) {
    my $AuthResult = $AuthObject->Auth(
        User => $Customer,
        Pw   => $Customers{$Customer},
    );

    $Self->Is(
        $AuthResult,
        $Customer,
        "Contact $Customer login OK",
    );
}

# check against existing certificates
@CertList = $SMIMEObject->CertificateList();
my $OldOKCount = 0;
for my $Cert ( sort @CertList ) {
    $OldOKCount++;
}
$Self->Is(
    $OldOKCount,
    $CertCount,
    "NewCertificates not yet imported",
);

# get Contact-List
my $ContactObject = $Kernel::OM->Get('Kernel::System::Contact');
my %List               = $ContactObject->CustomerSearch(
    CustomerID => 'unittest_customer_id',
    Valid      => 1,
);

CUSTOMERUSER:
for my $Contact ( sort keys %List ) {
    my %UserContact = $ContactObject->ContactGet(
        ID => $Contact,
    );
    next CUSTOMERUSER if !$UserContact{UserSMIMECertificate};

    # 1st try with CertificateSearch
    # add
    my @CertificateFilename = $SMIMEObject->CertificateSearch(
        Search => $UserContact{Email},
    );

    $Self->True(
        $CertificateFilename[0]{Filename},
        "Certificate for $UserContact{Email} was imported",
    );

    # check
    my $Certificate = $SMIMEObject->CertificateGet(
        Filename => $CertificateFilename[0]{Filename},
    );

    # remove
    my %Remove = $SMIMEObject->CertificateRemove(
        Filename => $CertificateFilename[0]{Filename},
    );
    $Self->False(
        $Remove{Success},
        "$Remove{Message}",
    );

    #2nd try - fetching from customer
    my @Files = $SMIMEObject->FetchFromCustomer(
        Search => $UserContact{Email},
    );

    my @CertificateFilename2nd = $SMIMEObject->CertificateSearch(
        Search  => $UserContact{Email},
        DontAdd => 1,
    );

    $Self->True(
        $CertificateFilename2nd[0],
        "Certificate for $UserContact{Email} found",
    );

    # remove
    my %Remove2nd = $SMIMEObject->CertificateRemove(
        Filename => $CertificateFilename2nd[0]{Filename},
    );
    $Self->False(
        $Remove2nd{Success},
        "$Remove2nd{Message}",
    );

}

# TODO - second stage
# create a real LDAP server to test against

$DBObject->Do( SQL => 'Drop table ' . $TableName );

# delete needed test directories
for my $Directory ( $CertPath, $PrivatePath ) {
    my $Success = rmtree( [$Directory] );
    $Self->True(
        $Success,
        "Directory deleted - '$Directory'",
    );
}

# cleanup is done by RestoreDatabase.

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
