# --
# Modified version of the work: Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Auth::Sync::LDAP;

use strict;
use warnings;

use Net::LDAP;
use Net::LDAP::Util qw(escape_filter_value);

our @ObjectDependencies = (
    'Config',
    'Encode',
    'Log',
    'User',
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # Debug 0=off 1=on
    $Self->{Debug} = 0;

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Config');

    # get ldap preferences
    if ( !$ConfigObject->Get( 'AuthSyncModule::LDAP::Host' . $Param{Count} ) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need AuthSyncModule::LDAP::Host$Param{Count} in Kernel/Config.pm",
        );
        return;
    }
    if ( !defined $ConfigObject->Get( 'AuthSyncModule::LDAP::BaseDN' . $Param{Count} ) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need AuthSyncModule::LDAP::BaseDN$Param{Count} in Kernel/Config.pm",
        );
        return;
    }
    if ( !$ConfigObject->Get( 'AuthSyncModule::LDAP::UID' . $Param{Count} ) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Need AuthSyncModule::LDAP::UID$Param{Count} in Kernel/Config.pm",
        );
        return;
    }
    $Self->{Count}        = $Param{Count} || '';
    $Self->{Die}          = $ConfigObject->Get( 'AuthSyncModule::LDAP::Die' . $Param{Count} );
    $Self->{Host}         = $ConfigObject->Get( 'AuthSyncModule::LDAP::Host' . $Param{Count} );
    $Self->{BaseDN}       = $ConfigObject->Get( 'AuthSyncModule::LDAP::BaseDN' . $Param{Count} );
    $Self->{UID}          = $ConfigObject->Get( 'AuthSyncModule::LDAP::UID' . $Param{Count} );
    $Self->{SearchUserDN} = $ConfigObject->Get( 'AuthSyncModule::LDAP::SearchUserDN' . $Param{Count} ) || '';
    $Self->{SearchUserPw} = $ConfigObject->Get( 'AuthSyncModule::LDAP::SearchUserPw' . $Param{Count} ) || '';
    $Self->{GroupDN}      = $ConfigObject->Get( 'AuthSyncModule::LDAP::GroupDN' . $Param{Count} )
        || '';
    $Self->{AccessAttr} = $ConfigObject->Get( 'AuthSyncModule::LDAP::AccessAttr' . $Param{Count} )
        || 'memberUid';
    $Self->{UserAttr} = $ConfigObject->Get( 'AuthSyncModule::LDAP::UserAttr' . $Param{Count} )
        || 'DN';
    $Self->{DestCharset} = $ConfigObject->Get( 'AuthSyncModule::LDAP::Charset' . $Param{Count} )
        || 'utf-8';

    # ldap filter always used
    $Self->{AlwaysFilter} = $ConfigObject->Get( 'AuthSyncModule::LDAP::AlwaysFilter' . $Param{Count} ) || '';

    # Net::LDAP new params
    if ( $ConfigObject->Get( 'AuthSyncModule::LDAP::Params' . $Param{Count} ) ) {
        $Self->{Params} = $ConfigObject->Get( 'AuthSyncModule::LDAP::Params' . $Param{Count} );
    }
    else {
        $Self->{Params} = {};
    }

    return $Self;
}

sub Sync {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{User} ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'Need User!'
        );
        return;
    }
    $Param{User} = $Self->_ConvertTo( $Param{User}, 'utf-8' );

    my $RemoteAddr = $ENV{REMOTE_ADDR} || 'Got no REMOTE_ADDR env!';

    # remove leading and trailing spaces
    $Param{User} =~ s{ \A \s* ( [^\s]+ ) \s* \z }{$1}xms;

    # just in case for debug!
    if ( $Self->{Debug} > 0 ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message  => "User: '$Param{User}' tried to sync (REMOTE_ADDR: $RemoteAddr)",
        );
    }

    # ldap connect and bind (maybe with SearchUserDN and SearchUserPw)
    my $LDAP = Net::LDAP->new( $Self->{Host}, %{ $Self->{Params} } );
    if ( !$LDAP ) {
        if ( $Self->{Die} ) {
            die "Can't connect to $Self->{Host}: $@";
        }

        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Can't connect to $Self->{Host}: $@",
        );
        return;
    }
    my $Result;
    if ( $Self->{SearchUserDN} && $Self->{SearchUserPw} ) {
        $Result = $LDAP->bind(
            dn       => $Self->{SearchUserDN},
            password => $Self->{SearchUserPw}
        );
    }
    else {
        $Result = $LDAP->bind();
    }
    if ( $Result->code() ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => 'First bind failed! ' . $Result->error(),
        );
        return;
    }

    # user quote
    my $Filter = "($Self->{UID}=" . escape_filter_value( $Param{User} ) . ')';

    # prepare filter
    if ( $Self->{AlwaysFilter} ) {
        $Filter = "(&$Filter$Self->{AlwaysFilter})";
    }

    # perform user search
    $Result = $LDAP->search(
        base   => $Self->{BaseDN},
        filter => $Filter,
    );
    if ( $Result->code() ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message  => "Search failed! ($Self->{BaseDN}) filter='$Filter' " . $Result->error(),
        );
        return;
    }

    # get whole user dn
    my $UserDN;
    for my $Entry ( $Result->all_entries() ) {
        $UserDN = $Entry->dn();
    }

    # log if there is no LDAP user entry
    if ( !$UserDN ) {

        # failed login note
        $Kernel::OM->Get('Log')->Log(
            Priority => 'notice',
            Message  => "User: $Param{User} sync failed, no LDAP entry found!"
                . "BaseDN='$Self->{BaseDN}', Filter='$Filter', (REMOTE_ADDR: $RemoteAddr).",
        );

        # take down session
        $LDAP->unbind();
        return;
    }

    # get needed objects
    my $UserObject   = $Kernel::OM->Get('User');
    my $ConfigObject = $Kernel::OM->Get('Config');

    # get current user id
    my $UserID = $UserObject->UserLookup(
        UserLogin => $Param{User},
        Silent    => 1,
    );

    # system permissions
    my %PermissionsEmpty =
        map { $_ => 0 } @{ $ConfigObject->Get('System::Permission') };

    # get RoleObject
    my $RoleObject = $Kernel::OM->Get('Role');

    # get system roles and create lookup
    my %SystemRoles = $RoleObject->RoleList( Valid => 1 );
    my %SystemRolesByName = reverse %SystemRoles;

    # sync user from ldap
    my $UserSyncMap = $ConfigObject->Get( 'AuthSyncModule::LDAP::UserSyncMap' . $Self->{Count} );
    if ($UserSyncMap) {

        # get whole user dn
        my %SyncUser;
        for my $Entry ( $Result->all_entries() ) {
            for my $Key ( sort keys %{$UserSyncMap} ) {

                # detect old config setting
                if ( $Key =~ m{ \A (?: Firstname | Lastname | Email ) }xms ) {
                    $Key = 'User' . $Key;
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'error',
                        Message  => 'Old config setting detected, please use the new one '
                            . 'from Kernel/Config/Defaults.pm (User* has been added!).',
                    );
                }

                my $AttributeNames = $UserSyncMap->{$Key};
                if ( ref $AttributeNames ne 'ARRAY' ) {
                    $AttributeNames = [$AttributeNames];
                }
                ATTRIBUTE_NAME:
                for my $AttributeName ( @{$AttributeNames} ) {
                    if ( $AttributeName =~ /^_/ ) {
                        $SyncUser{$Key} = substr( $AttributeName, 1 );
                        last ATTRIBUTE_NAME;
                    }
                    elsif ( $Entry->get_value($AttributeName) ) {
                        $SyncUser{$Key} = $Entry->get_value($AttributeName);
                        last ATTRIBUTE_NAME;
                    }
                }

                # e. g. set utf-8 flag
                $SyncUser{$Key} = $Self->_ConvertFrom(
                    $SyncUser{$Key},
                    'utf-8',
                );
            }
            if ( $Entry->get_value('userPassword') ) {
                $SyncUser{UserPw} = $Entry->get_value('userPassword');

                # e. g. set utf-8 flag
                $SyncUser{UserPw} = $Self->_ConvertFrom(
                    $SyncUser{UserPw},
                    'utf-8',
                );
            }
        }

        # add new user
        if ( %SyncUser && !$UserID ) {
            $UserID = $UserObject->UserAdd(
                UserTitle => 'Mr/Mrs',
                UserLogin => $Param{User},
                %SyncUser,
                UserType     => 'User',
                ValidID      => 1,
                ChangeUserID => 1,
            );
            if ( !$UserID ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Can't create user '$Param{User}' ($UserDN) in RDBMS!",
                );

                # take down session
                $LDAP->unbind();
                return;
            }
            else {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'notice',
                    Message  => "Initial data for '$Param{User}' ($UserDN) created in RDBMS.",
                );
            }
        }

        # update user attributes (only if changed)
        elsif (%SyncUser) {

            # get user data
            my %UserData = $UserObject->GetUserData( User => $Param{User} );

            # check for changes
            my $AttributeChange;
            ATTRIBUTE:
            for my $Attribute ( sort keys %SyncUser ) {
                next ATTRIBUTE if $SyncUser{$Attribute} eq $UserData{$Attribute};
                $AttributeChange = 1;
                last ATTRIBUTE;
            }

            if ($AttributeChange) {
                $UserObject->UserUpdate(
                    %UserData,
                    UserID    => $UserID,
                    UserLogin => $Param{User},
                    %SyncUser,
                    UserType     => 'User',
                    ChangeUserID => 1,
                );
            }
        }
    }

    # variable to store role permissions from ldap
    my %RolePermissionsFromLDAP;

    # sync ldap group 2 otrs role permissions
    my $UserSyncRolesDefinition = $ConfigObject->Get(
        'AuthSyncModule::LDAP::UserSyncRolesDefinition' . $Self->{Count}
    );
    if ($UserSyncRolesDefinition) {

        # read and remember roles from ldap
        GROUPDN:
        for my $GroupDN ( sort keys %{$UserSyncRolesDefinition} ) {

            # search if we're allowed to
            my $Filter;
            if ( $Self->{UserAttr} eq 'DN' ) {
                $Filter = "($Self->{AccessAttr}=" . escape_filter_value($UserDN) . ')';
            }
            else {
                $Filter = "($Self->{AccessAttr}=" . escape_filter_value( $Param{User} ) . ')';
            }
            my $Result = $LDAP->search(
                base   => $GroupDN,
                filter => $Filter,
            );
            if ( $Result->code() ) {
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'error',
                    Message  => "Search failed! ($GroupDN) filter='$Filter' " . $Result->error(),
                );
                next GROUPDN;
            }

            # extract it
            my $Valid;
            for my $Entry ( $Result->all_entries() ) {
                $Valid = $Entry->dn();
            }

            # log if there is no LDAP entry
            if ( !$Valid ) {

                # failed login note
                $Kernel::OM->Get('Log')->Log(
                    Priority => 'notice',
                    Message  => "User: $Param{User} not in "
                        . "GroupDN='$GroupDN', Filter='$Filter'! (REMOTE_ADDR: $RemoteAddr).",
                );
                next GROUPDN;
            }

            # remember role permissions
            my %SyncRoles = %{ $UserSyncRolesDefinition->{$GroupDN} };
            SYNCROLE:
            for my $SyncRole ( sort keys %SyncRoles ) {

                # only for valid roles
                if ( !$SystemRolesByName{$SyncRole} ) {
                    $Kernel::OM->Get('Log')->Log(
                        Priority => 'notice',
                        Message =>
                            "Invalid role '$SyncRole' in "
                            . "'AuthSyncModule::LDAP::UserSyncRolesDefinition"
                            . "$Self->{Count}'!",
                    );
                    next SYNCROLE;
                }

                # set/overwrite remembered permissions
                $RolePermissionsFromLDAP{ $SystemRolesByName{$SyncRole} } =
                    $SyncRoles{$SyncRole};
            }
        }
    }

    # sync ldap attribute 2 otrs role permissions
    my $UserSyncAttributeRolesDefinition = $ConfigObject->Get(
        'AuthSyncModule::LDAP::UserSyncAttributeRolesDefinition' . $Self->{Count}
    );
    if ($UserSyncAttributeRolesDefinition) {

        # build filter
        my $Filter = "($Self->{UID}=" . escape_filter_value( $Param{User} ) . ')';

        # perform search
        $Result = $LDAP->search(
            base   => $Self->{BaseDN},
            filter => $Filter,
        );
        if ( $Result->code() ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Search failed! ($Self->{BaseDN}) filter='$Filter' " . $Result->error(),
            );
        }
        else {
            my %SyncConfig = %{$UserSyncAttributeRolesDefinition};
            for my $Attribute ( sort keys %SyncConfig ) {

                my %AttributeValues = %{ $SyncConfig{$Attribute} };
                ATTRIBUTEVALUE:
                for my $AttributeValue ( sort keys %AttributeValues ) {

                    for my $Entry ( $Result->all_entries() ) {

                        # Check if configured value exists in values of role attribute
                        # If yes, add sync roles to the user
                        my $GotValue;
                        my @Values = $Entry->get_value($Attribute);
                        VALUE:
                        for my $Value (@Values) {
                            next VALUE if $Value !~ m{ \A \Q$AttributeValue\E \z }xmsi;
                            $GotValue = 1;
                            last VALUE;
                        }
                        next ATTRIBUTEVALUE if !$GotValue;

                        # remember role permissions
                        my %SyncRoles = %{ $AttributeValues{$AttributeValue} };
                        SYNCROLE:
                        for my $SyncRole ( sort keys %SyncRoles ) {

                            # only for valid roles
                            if ( !$SystemRolesByName{$SyncRole} ) {
                                $Kernel::OM->Get('Log')->Log(
                                    Priority => 'notice',
                                    Message =>
                                        "Invalid role '$SyncRole' in "
                                        . "'AuthSyncModule::LDAP::UserSyncAttributeRolesDefinition"
                                        . "$Self->{Count}'!",
                                );
                                next SYNCROLE;
                            }

                            # set/overwrite remembered permissions
                            $RolePermissionsFromLDAP{ $SystemRolesByName{$SyncRole} } =
                                $SyncRoles{$SyncRole};
                        }
                    }
                }
            }
        }
    }

    # compare role permissions from ldap with current user role permissions and update if necessary
    if (%RolePermissionsFromLDAP) {

        # get current user roles
        my %UserRoles = $UserObject->RoleList(
            UserID => $UserID,
        );

        ROLEID:
        for my $RoleID ( sort keys %SystemRoles ) {

            # if old and new permission for role matches, do nothing
            if (
                ( $UserRoles{$RoleID} && $RolePermissionsFromLDAP{$RoleID} )
                ||
                ( !$UserRoles{$RoleID} && !$RolePermissionsFromLDAP{$RoleID} )
                )
            {
                next ROLEID;
            }

            $Kernel::OM->Get('Log')->Log(
                Priority => 'notice',
                Message  => "User: '$Param{User}' sync ldap role $SystemRoles{$RoleID}!",
            );
            $RoleObject->RoleUserAdd(
                AssignUserID  => $UserID,
                RoleID        => $RoleID,
                UserID        => 1,
#                Active => $RolePermissionsFromLDAP{$RoleID} || 0,
            );
        }
    }

    # take down session
    $LDAP->unbind();

    return $Param{User};
}

sub _ConvertTo {
    my ( $Self, $Text, $Charset ) = @_;

    return if !defined $Text;

    # get encode object
    my $EncodeObject = $Kernel::OM->Get('Encode');

    if ( !$Charset || !$Self->{DestCharset} ) {
        $EncodeObject->EncodeInput( \$Text );
        return $Text;
    }

    # convert from input charset ($Charset) to directory charset ($Self->{DestCharset})
    return $EncodeObject->Convert(
        Text => $Text,
        From => $Charset,
        To   => $Self->{DestCharset},
    );
}

sub _ConvertFrom {
    my ( $Self, $Text, $Charset ) = @_;

    return if !defined $Text;

    # get encode object
    my $EncodeObject = $Kernel::OM->Get('Encode');

    if ( !$Charset || !$Self->{DestCharset} ) {
        $EncodeObject->EncodeInput( \$Text );
        return $Text;
    }

    # convert from directory charset ($Self->{DestCharset}) to input charset ($Charset)
    return $EncodeObject->Convert(
        Text => $Text,
        From => $Self->{DestCharset},
        To   => $Charset,
    );
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
