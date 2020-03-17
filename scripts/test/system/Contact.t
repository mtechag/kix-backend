# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

use Kernel::System::VariableCheck qw(:all);

# get needed objects
my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');
my $CacheObject        = $Kernel::OM->Get('Kernel::System::Cache');
my $ContactObject      = $Kernel::OM->Get('Kernel::System::Contact');
my $OrganisationObject = $Kernel::OM->Get('Kernel::System::Organisation');
my $DBObject           = $Kernel::OM->Get('Kernel::System::DB');

# get helper object
$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

# add three users
$ConfigObject->Set(
    Key   => 'CheckEmailAddresses',
    Value => 0,
);

my $DatabaseCaseSensitive      = $DBObject->{Backend}->{'DB::CaseSensitive'};
my $SearchCaseSensitiveDefault = $ConfigObject->{Contact}->{Params}->{SearchCaseSensitive};

# create organisation for tests
my $OrgRand        = 'Example-Organisation-Company' . $Helper->GetRandomID();
my $OrganisationID = $OrganisationObject->OrganisationAdd(
    Number  => $OrgRand,
    Name    => $OrgRand . ' Inc',
    Street  => 'Some Street',
    Zip     => '12345',
    City    => 'Some city',
    Country => 'USA',
    Url     => 'http://example.com',
    Comment => 'some comment',
    ValidID => 1,
    UserID  => 1,
);
my $OrganisationIDForUpdate = $OrganisationObject->OrganisationAdd(
    Number  => $OrgRand . '_ForUpdate',
    Name    => $OrgRand . ' Inc_ForUpdate',
    Street  => 'Some Street',
    Zip     => '12345',
    City    => 'Some city',
    Country => 'USA',
    Url     => 'http://example.com',
    Comment => 'some comment',
    ValidID => 1,
    UserID  => 1,
);

my $ContactID = '';
for my $Key ( 1 .. 3, 'ä', 'カス', '_', '&' ) {

    # create non existing customer user login
    my $ContactRandom = 'unittest-' . $Key . $Helper->GetRandomID();

    my $ContactID = $ContactObject->ContactAdd(
        Firstname             => 'Firstname Test' . $Key,
        Lastname              => 'Lastname Test' . $Key,
        PrimaryOrganisationID => $OrganisationID,
        OrganisationIDs       => [
            $OrganisationID
        ],
        Email    => $ContactRandom . '-Email@example.com',
        ValidID  => 1,
        UserID   => 1,
    );

    $Self->True(
        $ContactID,
        "ContactAdd() - $ContactID",
    );

    my %Contact = $ContactObject->ContactGet(
        ID => $ContactID,
    );

    $Self->Is(
        $Contact{Firstname},
        "Firstname Test$Key",
        "ContactGet() - Firstname",
    );
    $Self->Is(
        $Contact{Lastname},
        "Lastname Test$Key",
        "ContactGet() - Lastname",
    );
    $Self->Is(
        $Contact{Email},
        $ContactRandom . '-Email@example.com',
        "ContactGet() - Email",
    );
    $Self->Is(
        $Contact{PrimaryOrganisationID},
        $OrganisationID,
        "ContactGet() - PrimaryOrganisationID",
    );

    $Self->Is(
        scalar( @{ $Contact{OrganisationIDs} } ),
        1,
        "ContactGet() - length OrganisationIDs",
    );
    $Self->Is(
        $Contact{ValidID},
        1,
        "ContactGet() - ValidID",
    );

    my $Update = $ContactObject->ContactUpdate(
        ID                    => $ContactID,
        Firstname             => 'Firstname Test Update' . $Key,
        Lastname              => 'Lastname Test Update' . $Key,
        PrimaryOrganisationID => $OrganisationIDForUpdate,
        OrganisationIDs       => [
            $OrganisationIDForUpdate
        ],
        ValidID => 1,
        UserID  => 1,
    );
    $Self->True(
        $Update,
        "ContactUpdate() - $ContactID",
    );

    %Contact = $ContactObject->ContactGet(
        ID => $ContactID,
    );

    $Self->Is(
        $Contact{Firstname},
        "Firstname Test Update$Key",
        "ContactGet() - Firstname",
    );
    $Self->Is(
        $Contact{Lastname},
        "Lastname Test Update$Key",
        "ContactGet() - Lastname",
    );
    $Self->Is(
        $Contact{Email},
        $ContactRandom . '-Update@example.com',
        "ContactGet() - Email",
    );
    $Self->Is(
        $Contact{PrimaryOrganisationID},
        $OrganisationIDForUpdate,
        "ContactGet() - OrganisationID",
    );
    $Self->Is(
        $Contact{ValidID},
        1,
        "ContactGet() - ValidID",
    );

    # search by OrganisationID
    my %List = $ContactObject->ContactSearch(
        OrganisationID => $OrganisationIDForUpdate,
        ValidID        => 1,
    );
    $Self->True(
        $List{$ContactID},
        "ContactSearch() - PrimaryOrganisationID=\'$OrganisationIDForUpdate\' - $ContactID is found",
    );

    # START CaseSensitive
    $ConfigObject->{Contact}->{Params}->{SearchCaseSensitive} = 1;

    $Kernel::OM->ObjectsDiscard( Objects => ['Kernel::System::Contact'] );
    $ContactObject = $Kernel::OM->Get('Kernel::System::Contact');

    $CacheObject->CleanUp();

    # Customer Search
    %List = $ContactObject->ContactSearch(
        Search  => lc( $ContactRandom . '-Customer-Update-Id' ),
        ValidID => 1,
    );

    if ($DatabaseCaseSensitive) {

        $Self->False(
            $List{$ContactID},
            "ContactSearch() - ContactID - $ContactID (SearchCaseSensitive = 1)",
        );
    }
    else {
        $Self->True(
            $List{$ContactID},
            "ContactSearch() - OrganisationID - $ContactID (SearchCaseSensitive = 1)",
        );
    }

    %List = $ContactObject->ContactSearch(
        PostMasterSearch => $ContactRandom . '-Update@example.com',
        ValidID          => 1,
    );
    $Self->True(
        $List{$ContactID},
        "ContactSearch() - PostMasterSearch - $ContactID",
    );
    %List = $ContactObject->ContactSearch(
        PostMasterSearch => lc( $ContactRandom . '-Update@example.com' ),
        ValidID          => 1,
    );
    $Self->True(
        $List{$ContactID},
        "ContactSearch() - PostMasterSearch lc() - $ContactID",
    );
    %List = $ContactObject->ContactSearch(
        PostMasterSearch => uc( $ContactRandom . '-Update@example.com' ),
        ValidID          => 1,
    );
    $Self->True(
        $List{$ContactID},
        "ContactSearch() - PostMasterSearch uc() - $ContactID",
    );

    %List = $ContactObject->ContactSearch(
        Login   => $ContactRandom,
        ValidID => 1,
    );
    $Self->True(
        $List{$ContactID},
        "ContactSearch() - Login - $ContactID",
    );
    %List = $ContactObject->ContactSearch(
        Login   => lc($ContactRandom),
        ValidID => 1,
    );
    $Self->True(
        $List{$ContactID},
        "ContactSearch() - Login - lc - $ContactID",
    );
    %List = $ContactObject->ContactSearch(
        Login   => uc($ContactRandom),
        ValidID => 1,
    );
    $Self->True(
        $List{$ContactID},
        "ContactSearch() - Login - uc - $ContactID",
    );

    %List = $ContactObject->ContactSearch(
        Search  => $ContactRandom,
        ValidID => 1,
    );
    $Self->True(
        $List{$ContactID},
        "ContactSearch() - Search '\$ContactID' - $ContactID",
    );

    %List = $ContactObject->ContactSearch(
        Search  => "$ContactRandom+firstname",
        ValidID => 1,
    );
    $Self->True(
        $List{$ContactID},
        "ContactSearch() - Search '\$ContactRandom+firstname' - $ContactID",
    );

    %List = $ContactObject->ContactSearch(
        Search  => "$ContactRandom+firstname_with_not_match",
        ValidID => 1,
    );
    $Self->True(
        !$List{$ContactID},
        "ContactSearch() - Search '\$ContactRandom+firstname_with_not_match' - $ContactID",
    );

    %List = $ContactObject->ContactSearch(
        Search  => "$ContactRandom*",
        ValidID => 1,
    );
    $Self->True(
        $List{$ContactID},
        "ContactSearch() - Search '\$ContactRandom*' - $ContactID",
    );

    %List = $ContactObject->ContactSearch(
        Search  => "*$ContactRandom",
        ValidID => 1,
    );
    $Self->True(
        $List{$ContactID},
        "ContactSearch() - Search '*\$ContactRandom' - $ContactID",
    );

    %List = $ContactObject->ContactSearch(
        Search  => "*$ContactRandom*",
        ValidID => 1,
    );
    $Self->True(
        $List{$ContactID},
        "ContactSearch() - Search '*\$ContactRandom*' - $ContactID",
    );

    # lc()
    %List = $ContactObject->ContactSearch(
        Search  => lc("$ContactRandom"),
        ValidID => 1,
    );
    $Self->True(
        $List{$ContactID},
        "ContactSearch() - Search lc('') - $ContactID",
    );

    %List = $ContactObject->ContactSearch(
        Search  => lc("$ContactRandom*"),
        ValidID => 1,
    );
    $Self->True(
        $List{$ContactID},
        "ContactSearch() - Search lc('\$ContactRandom*') - $ContactID",
    );

    %List = $ContactObject->ContactSearch(
        Search  => lc("*$ContactRandom"),
        ValidID => 1,
    );
    $Self->True(
        $List{$ContactID},
        "ContactSearch() - Search lc('*\$ContactRandom') - $ContactID",
    );

    %List = $ContactObject->ContactSearch(
        Search  => lc("*$ContactRandom*"),
        ValidID => 1,
    );
    $Self->True(
        $List{$ContactID},
        "ContactSearch() - Search lc('*\$ContactRandom*') - $ContactID",
    );

    # uc()
    %List = $ContactObject->ContactSearch(
        Search  => uc("$ContactRandom"),
        ValidID => 1,
    );
    $Self->True(
        $List{$ContactID},
        "ContactSearch() - Search uc('\$ContactRandom') - $ContactID",
    );

    %List = $ContactObject->ContactSearch(
        Search  => uc("$ContactRandom*"),
        ValidID => 1,
    );
    $Self->True(
        $List{$ContactID},
        "ContactSearch() - Search uc('\$ContactRandom*') - $ContactID",
    );

    %List = $ContactObject->ContactSearch(
        Search  => uc("*$ContactRandom"),
        ValidID => 1,
    );
    $Self->True(
        $List{$ContactID},
        "ContactSearch() - Search uc('*\$ContactRandom') - $ContactID",
    );

    %List = $ContactObject->ContactSearch(
        Search  => uc("*$ContactRandom*"),
        ValidID => 1,
    );
    $Self->True(
        $List{$ContactID},
        "ContactSearch() - Search uc('*\$ContactRandom*') - $ContactID",
    );

    %List = $ContactObject->ContactSearch(
        Search  => uc("*$ContactRandom*"),
        ValidID => 1,
    );
    $Self->True(
        $List{$ContactID},
        "ContactSearch() - Search uc('*\$ContactRandom*') - $ContactID",
    );

    # check token support
    my $Token = $ContactObject->TokenGenerate(
        ContactID => $ContactID,
    );
    $Self->True(
        $Token,
        "TokenGenerate() - $ContactID - $Token",
    );

    my $TokenValid = $ContactObject->TokenCheck(
        Token     => $Token,
        ContactID => $ContactID,
    );

    $Self->True(
        $TokenValid,
        "TokenCheck() - $ContactID - $Token",
    );

    $TokenValid = $ContactObject->TokenCheck(
        Token     => $Token,
        ContactID => $ContactID,
    );

    $Self->True(
        !$TokenValid,
        "TokenCheck() - $ContactID - $Token",
    );

    $TokenValid = $ContactObject->TokenCheck(
        Token     => $Token . '123',
        ContactID => $ContactID,
    );

    $Self->True(
        !$TokenValid,
        "TokenCheck() - $ContactID - $Token" . "123",
    );

    # testing preferences

    my $SetPreferences = $ContactObject->SetPreferences(
        Key       => 'UserLanguage',
        Value     => 'fr',
        ContactID => $ContactID,
    );

    $Self->True(
        $SetPreferences,
        "SetPreferences - $ContactID",
    );

    my %Preferences = $ContactObject->GetPreferences(
        ContactID => $ContactID,
    );

    $Self->True(
        %Preferences || '',
        "GetPreferences - $ContactID",
    );

    $Self->Is(
        $Preferences{UserLanguage},
        "fr",
        "GetPreferences $ContactID - fr",
    );

    my %ContactList = $ContactObject->SearchPreferences(
        Key   => 'UserLanguage',
        Value => 'fr',
    );

    $Self->True(
        %ContactList || '',
        "SearchPreferences - $ContactID",
    );

    $Self->Is(
        $ContactList{$ContactID},
        'fr',
        "SearchPreferences() - $ContactID",
    );

    %ContactList = $ContactObject->SearchPreferences(
        Key   => 'UserLanguage',
        Value => 'de',
    );

    $Self->False(
        $ContactList{$ContactID},
        "SearchPreferences() - $ContactID",
    );

    # search for any value
    %ContactList = $ContactObject->SearchPreferences(
        Key => 'UserLanguage',
    );

    $Self->True(
        %ContactList || '',
        "SearchPreferences - $ContactID",
    );

    $Self->Is(
        $ContactList{$ContactID},
        'fr',
        "SearchPreferences() - $ContactID",
    );

    #update existing prefs
    my $UpdatePreferences = $ContactObject->SetPreferences(
        Key       => 'UserLanguage',
        Value     => 'da',
        ContactID => $ContactID,
    );

    $Self->True(
        $UpdatePreferences,
        "UpdatePreferences - $ContactID",
    );

    %Preferences = $ContactObject->GetPreferences(
        ContactID => $ContactID,
    );

    $Self->True(
        %Preferences || '',
        "GetPreferences - $ContactID",
    );

    $Self->Is(
        $Preferences{UserLanguage},
        "da",
        "UpdatePreferences $ContactID - da",
    );

    #update customer user
    my $Update = $ContactObject->ContactUpdate(
        ID                    => $ContactID,
        Firstname             => 'Firstname Update' . $ContactID,
        Lastname              => 'Lastname Update' . $ContactID,
        Email                 => $ContactID . 'new@example.com',
        PrimaryOrganisationID => $OrganisationID,
        OrganisationIDs       => [
            $OrganisationID
        ],
        ValidID => 1,
        UserID  => 1,
    );
    $Self->True(
        $Update,
        "ContactUpdate - $ContactID",
    );

    %Preferences = $ContactObject->GetPreferences(
        ContactID => $ContactID,
    );

    $Self->True(
        %Preferences || '',
        "GetPreferences for updated user - Updated NewLogin$ContactID",
    );

    $Self->Is(
        $Preferences{UserLanguage},
        "da",
        "GetPreferences for updated user $ContactID - da",
    );

    if ( $Key eq '1' ) {

        # delete the first contact
        my $Success = $ContactObject->ContactDelete(
            ID => $ContactID,
        );

        $Self->True(
            $Success,
            "ContactDelete() - $ContactID",
        );
    }
}

# cleanup is done by RestoreDatabase

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
