# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::Config;

use strict;
use warnings;
use utf8;

# Perl 5.10.0 is the required minimum version to use KIX.
use 5.010_000;

# prepend '../plugins' and '../Kernel/cpan-lib' to the module search path @INC
use File::Basename;
use FindBin qw($Bin);
use lib dirname($Bin);
use lib dirname($Bin) . '/../Kernel/cpan-lib';
use lib dirname($Bin) . '/../plugins';

use Exporter qw(import);

our @EXPORT = qw(Translatable);

our @ObjectDependencies = (
    'SysConfig',
);

=head1 NAME

Kernel::Config - the ConfigObject.

=head1 DESCRIPTION

This class implements several internal functions that are used internally in
L<Kernel::Config>. The two externally used functions are documented as part
of L<Kernel::Config>, even though they are actually implemented here.

=head1 PUBLIC INTERFACE

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # 0=off; 1=log if there exists no entry; 2=log all;
    $Self->{Debug} = 0;

    # init the basic configuration to "find" ourself
    $Self->{Config}->{Home} = $ENV{KIX_HOME} || dirname($Bin);

    # load settings from Config.pm
    $Self->{Config} = $Self->LoadLocalConfig($Self->{Config}->{Home}.'/config');

    return $Self;
}

# load values from local config files (stage 1)
sub LoadLocalConfig {
    my ( $Self, $ConfigDir ) = @_;
    my %Config = %{$Self->{Config}};

    if ( opendir(my $DIR, $ConfigDir) ) {
        # filter files and ignore file with .dist extension
        my @Files = grep { -f "$ConfigDir/$_" && $_ !~ /\.dist$/ } readdir($DIR);
        closedir $DIR;

        foreach my $File ( sort @Files ) {
            if ( open( my $HANDLE, '<', $ConfigDir.'/'.$File ) ) {
                my $Content = do { local $/; <$HANDLE> };
                my %Hash = eval "($Content)";
                if ( $@ ) {
                    # some error occured
                    print STDERR "ERROR: config file \"$File\" has errors. Aborting\n";
                    die;
                }
                
                %Config = ( %Config, %Hash );
            }
            else {
                print STDERR "ERROR: Can't read config file \"$File\". Aborting.\n";
                die;
            }
        }
    }
    else {
        print STDERR "ERROR: Can't read config directory $ConfigDir: $!\n";
        die;
    }

    return \%Config;
}

# load values from SysConfig (stage 2)
sub LoadSysConfig {
    my ( $Self ) = @_;

    # return if the ObjectManager is not yet initialized
    return if !$Kernel::OM;

    $Self->{SysConfigLoaded} = 1;

    my $SysConfigObject = $Kernel::OM->Get('SysConfig');

    # load the current config
    my %SysConfig = $SysConfigObject->ValueGetAll( Valid => 1 );

    my %Options = ( %SysConfig, %{$Self->{Config}} );
    my %PreparedOptions;

    foreach my $Option ( sort keys %Options ) {
        if ( $Option =~ /^(.+?)###(.+?)$/ ) {
            $PreparedOptions{$1}->{$2} = $Options{$Option};
        }
        else {
            $PreparedOptions{$Option} = $Options{$Option};
        }
    }
    $Self->{Config} = \%PreparedOptions;

    my $Home = $Self->Get('Home');

    # load basic RELEASE file to check integrity of installation
    if ( open( my $Product, '<', "$Home/RELEASE" ) ) { ## no critic
        while (my $Line = <$Product>) {

            # filtering of comment lines
            if ( $Line !~ /^#/ ) {
                if ( $Line =~ /^PRODUCT\s{0,2}=\s{0,2}(.*)\s{0,2}$/i ) {
                    $Self->{Config}->{Product} = $1;
                }
                elsif ( $Line =~ /^VERSION\s{0,2}=\s{0,2}(.*)\s{0,2}$/i ) {
                    $Self->{Config}->{Version} = $1;
                }
                elsif ( $Line =~ /^BUILDDATE\s{0,2}=\s{0,2}(.*)\s{0,2}$/i ) {
                    $Self->{Config}->{BuildDate} = $1;
                }
                elsif ( $Line =~ /^BUILDHOST\s{0,2}=\s{0,2}(.*)\s{0,2}$/i ) {
                    $Self->{Config}->{BuildHost} = $1;
                }
                elsif ( $Line =~ /^BUILDNUMBER\s{0,2}=\s{0,2}(.*)\s{0,2}$/i ) {
                    $Self->{Config}->{BuildNumber} = $1;
                }
            }
        }
        close($Product);
    }
    else {
        print STDERR "($$) ERROR: $Home/RELEASE does not exist! This file is needed by core components of KIX and the system will not work without this file.\n";
        die;
    }

    return 1;
}

sub Exists {
    my ( $Self, $What ) = @_;

    if ( !defined $Self->{Config}->{$What} && !$Self->{SysConfigLoaded} ) {        
        # Config hash has not been loaded yet, just do it
        $Self->LoadSysConfig();
    }

    return exists $Self->{Config}->{$What}
}

sub Get {
    my ( $Self, $What ) = @_;

    if ( !defined $Self->{Config}->{$What} && !$Self->{SysConfigLoaded} ) {        
        # Config hash has not been loaded yet, just do it
        $Self->LoadSysConfig();
    }


    # debug
    if ( $Self->{Debug} > 1 ) {
        my $Value = defined $Self->{Config}->{$What} ? $Self->{Config}->{$What} : '<undef>';
        print STDERR "($$) Debug: Config.pm ->Get('$What') --> $Value\n";
    }

    # replace config variables in value
    if ( defined $Self->{Config}->{$What} ) {
        $Self->{Config}->{$What} =~ s/\<KIX_CONFIG_(.+?)\>/$Self->{Config}->{$1}/g;
    }

    return $Self->{Config}->{$What};
}

sub Set {
    my ( $Self, %Param ) = @_;

    for (qw(Key)) {
        if ( !defined $Param{$_} ) {
            $Param{$_} = '';
        }
    }

    # debug
    if ( $Self->{Debug} > 1 ) {
        my $Value = defined $Param{Value} ? $Param{Value} : '<undef>';
        print STDERR "($$) Debug: Config.pm ->Set(Key => $Param{Key}, Value => $Value)\n";
    }

    # set runtime config option
    if ( $Param{Key} =~ /^(.+?)###(.+?)$/ ) {
        if ( !defined $Param{Value} ) {
            delete $Self->{Config}->{$1}->{$2};
        }
        else {
            $Self->{Config}->{$1}->{$2} = $Param{Value};
        }
    }
    else {
        if ( !defined $Param{Value} ) {
            delete $Self->{Config}->{ $Param{Key} };
        }
        else {
            $Self->{Config}->{ $Param{Key} } = $Param{Value};
        }
    }
    return 1;
}

## nofilter(TidyAll::Plugin::OTRS::Perl::Translatable)

# This is a no-op to mark a text as translatable in the Perl code.
#   We use our own version here instead of importing Language::Translatable to not add a dependency.

sub Translatable {
    return shift;
}

1;

=head1 TERMS AND CONDITIONS

This software is part of the OTRS project (L<http://otrs.org/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see
the enclosed file COPYING for license information (AGPL). If you
did not receive this file, see L<http://www.gnu.org/licenses/agpl.txt>.

=cut

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
