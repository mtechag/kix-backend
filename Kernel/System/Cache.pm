# --
# Modified version of the work: Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::Cache;

use strict;
use warnings;

use Storable qw();
use Time::HiRes qw(time);

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Log',
);

=head1 NAME

Kernel::System::Cache - Key/value based data cache for KIX

=head1 SYNOPSIS

This is a simple data cache. It can store key/value data both
in memory and in a configured cache backend for persistent caching.

This can be controlled via the config settings C<Cache::InMemory> and
C<Cache::InBackend>. The backend can also be selected with the config setting
C<Cache::Module> and defaults to file system based storage for permanent caching.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not use it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $CacheObject = $Kernel::OM->Get('Kernel::System::Cache');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # 0=off; 1=set+get_cache; 2=+delete+get_request;
    $Self->{Debug} = $Param{Debug} || 0;

    # cache backend
    my $CacheModule = $Kernel::OM->Get('Kernel::Config')->Get('Cache::Module')
        || 'Kernel::System::Cache::FileStorable';

    # Store backend in $Self for fastest access.
    $Self->{CacheObject}    = $Kernel::OM->Get($CacheModule);
    $Self->{CacheInMemory}  = $Kernel::OM->Get('Kernel::Config')->Get('Cache::InMemory') // 1;
    $Self->{CacheInBackend} = $Kernel::OM->Get('Kernel::Config')->Get('Cache::InBackend') // 1;

    return $Self;
}

=item Configure()

change cache configuration settings at runtime. You can use this to disable the cache in
environments where it is not desired, such as in long running scripts.

please, to turn CacheInMemory off in persistent environments.

    $CacheObject->Configure(
        CacheInMemory  => 1,    # optional
        CacheInBackend => 1,    # optional
    );

=cut

sub Configure {
    my ( $Self, %Param ) = @_;

    SETTING:
    for my $Setting (qw(CacheInMemory CacheInBackend)) {
        next SETTING if !exists $Param{$Setting};
        $Self->{$Setting} = $Param{$Setting} ? 1 : 0;
    }

    return;
}

=item Set()

store a value in the cache.

    $CacheObject->Set(
        Type     => 'ObjectName',      # only [a-zA-Z0-9_] chars usable
        Depends  => [],                # optional, invalidate this cache key if one of these cachetypes will be cleared or keys deleted
        Key      => 'SomeKey',
        Value    => 'Some Value',
        TTL      => 60 * 60 * 24 * 20, # seconds, this means 20 days
    );

The Type here refers to the group of entries that should be cached and cleaned up together,
usually this will represent the KIX object that is supposed to be cached, like 'Ticket'.

The Key identifies the entry (together with the type) for retrieval and deletion of this value.

The TTL controls when the cache will expire. Please note that the in-memory cache is not persistent
and thus has no TTL/expiry mechanism.

Please note that if you store complex data, you have to make sure that the data is not modified
in other parts of the code as the in-memory cache only refers to it. Otherwise also the cache would
contain the modifications. If you cannot avoid this, you can disable the in-memory cache for this
value:

    $CacheObject->Set(
        Type  => 'ObjectName',
        Key   => 'SomeKey',
        Value => { ... complex data ... },

        TTL            => 60 * 60 * 24 * 1,  # optional, default 20 days
        CacheInMemory  => 0,                 # optional, defaults to 1
        CacheInBackend => 1,                 # optional, defaults to 1
    );

=cut

sub Set {
    my ( $Self, %Param ) = @_;

    for my $Needed (qw(Type Key Value)) {
        if ( !defined $Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    # set default TTL to 20 days
    $Param{TTL} //= 60 * 60 * 24 * 20;

    # Enforce cache type restriction to make sure it works properly on all file systems.
    if ( $Param{Type} !~ m{ \A [a-zA-Z0-9_]+ \z}smx ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message =>
                "Cache Type '$Param{Type}' contains invalid characters, use [a-zA-Z0-9_] only!",
        );
        return;
    }

    # debug
    if ( $Self->{Debug} > 0 ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'notice',
            Message  => "Set Key:$Param{Key} TTL:$Param{TTL}!",
        );
    }

    # store TypeDependencies information
    if (ref $Param{Depends} eq 'ARRAY') {
        if ( !$Self->{TypeDependencies} ) {
            # load information from backend
            $Self->{TypeDependencies} = $Self->{CacheObject}->Get(
                Type => 'Cache',
                Key  => 'TypeDependencies',
            );
        }
        my $Changed = 0;
        foreach my $Type (@{$Param{Depends}}) {
            # ignore same type as dependency
            next if $Type eq $Param{Type};

            if ( !exists $Self->{TypeDependencies}->{$Type} || !exists $Self->{TypeDependencies}->{$Type}->{$Param{Type}} ) {
                $Changed = 1;
                $Self->_Debug('', "adding dependent cache type \"$Param{Type}\" to cache type \"$Type\".");
                $Self->{TypeDependencies}->{$Type}->{$Param{Type}} = 1;
            }
        }

        if ( $Changed && $Self->{CacheInBackend} && $Param{CacheInBackend} // 1 && $Self->{TypeDependencies} ) {
            # update cache dependencies in backend only if something has changed
            use Data::Dumper;
            $Self->_Debug('', "updating gobal cache dependency information: ".Dumper($Self->{TypeDependencies}));
            $Self->{CacheObject}->Set(
                Type => 'Cache',
                Key  => 'TypeDependencies',
                Value => $Self->{TypeDependencies},
                TTL   => 60 * 60 * 24 * 20,         # 20 days
            );
        }
    }

    # Set in-memory cache.
    if ( $Self->{CacheInMemory} && ( $Param{CacheInMemory} // 1 ) ) {
        $Self->_Debug('', "set in-memory cache key \"$Param{Key}\"");
        $Self->{Cache}->{ $Param{Type} }->{ $Param{Key} } = $Param{Value};
    }

    # If in-memory caching is not active, make sure the in-memory
    #   cache is not in an inconsistent state.
    else {
        delete $Self->{Cache}->{ $Param{Type} }->{ $Param{Key} };
    }

    # update stats
    $Self->_UpdateCacheStats(
        Operation => 'Set',
        %Param,
    );

    # Set persistent cache.
    if ( $Self->{CacheInBackend} && ( $Param{CacheInBackend} // 1 ) ) {
        return $Self->{CacheObject}->Set(%Param);
    }

    # If persistent caching is not active, make sure the persistent
    #   cache is not in an inconsistent state.
    else {
        return $Self->{CacheObject}->Delete(%Param);
    }

    return 1;
}

=item Get()

fetch a value from the cache.

    my $Value = $CacheObject->Get(
        Type => 'ObjectName',       # only [a-zA-Z0-9_] chars usable
        Key  => 'SomeKey',
    );

Please note that if you store complex data, you have to make sure that the data is not modified
in other parts of the code as the in-memory cache only refers to it. Otherwise also the cache would
contain the modifications. If you cannot avoid this, you can disable the in-memory cache for this
value:

    my $Value = $CacheObject->Get(
        Type => 'ObjectName',
        Key  => 'SomeKey',

        CacheInMemory => 0,     # optional, defaults to 1
        CacheInBackend => 1,    # optional, defaults to 1
    );


=cut

sub Get {
    my ( $Self, %Param ) = @_;

    for my $Needed (qw(Type Key)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    # check in-memory cache
    if ( $Self->{CacheInMemory} && ( $Param{CacheInMemory} // 1 ) ) {
        if ( exists $Self->{Cache}->{ $Param{Type} }->{ $Param{Key} } ) {
            $Self->_UpdateCacheStats(
                Operation => 'Get',
                Result    => 'HIT',
                %Param,
            );
            return $Self->{Cache}->{ $Param{Type} }->{ $Param{Key} };
        }
    }

    if ( !$Self->{CacheInBackend} || !( $Param{CacheInBackend} // 1 ) ) {
        $Self->_UpdateCacheStats(
            Operation => 'Get',
            Result    => 'MISS',
            %Param,
        );
        return;
    }

    # check persistent cache
    my $Value = $Self->{CacheObject}->Get(%Param);

    # set in-memory cache
    if ( defined $Value ) {
        $Self->_UpdateCacheStats(
            Operation => 'Get',
            Result    => 'HIT',
            %Param,
        );
        if ( $Self->{CacheInMemory} && ( $Param{CacheInMemory} // 1 ) ) {
            $Self->{Cache}->{ $Param{Type} }->{ $Param{Key} } = $Value;
        }
    }
    else {
        $Self->_UpdateCacheStats(
            Operation => 'Get',
            Result    => 'MISS',
            %Param,
        );
    }

    return $Value;
}

=item Delete()

deletes a single value from the cache.

    $CacheObject->Delete(
        Type => 'ObjectName',       # only [a-zA-Z0-9_] chars usable
        Key  => 'SomeKey',
    );

Please note that despite the cache configuration, Delete and CleanUp will always
be executed both in memory and in the backend to avoid inconsistent cache states.

=cut

sub Delete {
    my ( $Self, %Param ) = @_;

    for my $Needed (qw(Type Key)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    $Param{Indent} = $Param{Indent} || '';

    # Delete and cleanup operations should also be done if the cache is disabled
    #   to avoid inconsistent states.

    # delete from in-memory cache
    delete $Self->{Cache}->{ $Param{Type} }->{ $Param{Key} };

    # delete from persistent cache
    return if !$Self->{CacheObject}->Delete(%Param);

    # check and delete depending caches
    $Self->_HandleDependingCacheTypes(
        Type   => $Param{Type},
        Indent => $Param{Indent}.'    '
    );

    $Self->_UpdateCacheStats(
        Operation => 'Delete',
        %Param,
    );

    return 1;
}

=item CleanUp()

delete parts of the cache or the full cache data.

To delete the whole cache:

    $CacheObject->CleanUp();

To delete the data of only one cache type:

    $CacheObject->CleanUp(
        Type => 'ObjectName',   # only [a-zA-Z0-9_] chars usable
    );

To delete all data except of some types:

    $CacheObject->CleanUp(
        KeepTypes => ['Object1', 'Object2'],
    );

To delete only expired cache data:

    $CacheObject->CleanUp(
        Expired => 1,   # optional, defaults to 0
    );

Type/KeepTypes and Expired can be combined to only delete expired data of a single type
or of all types except the types to keep.

Please note that despite the cache configuration, Delete and CleanUp will always
be executed both in memory and in the backend to avoid inconsistent cache states.

=cut

sub CleanUp {
    my ( $Self, %Param ) = @_;

    $Param{Indent} = $Param{Indent} || '';

    if ( $Param{KeepTypes} ) {
        $Self->_Debug($Param{Indent}, "cleaning up everything except: ".join(', ', @{$Param{KeepTypes}}));
    }

    # cleanup in-memory cache
    # We don't have TTL/expiry information here, so just always delete to be sure.
    if ( $Param{Type} ) {
        delete $Self->{Cache}->{ $Param{Type} };

        # check and delete depending caches
        $Self->_HandleDependingCacheTypes(
            Type   => $Param{Type},
            Indent => $Param{Indent}.'    '
        );

        $Self->_UpdateCacheStats(
            Operation => 'CleanUp',
            %Param,
        );
    }
    elsif ( $Param{KeepTypes} ) {
        my %KeepTypeLookup;
        @KeepTypeLookup{ ( @{ $Param{KeepTypes} || [] } ) } = undef;
        TYPE:
        for my $Type ( sort keys %{ $Self->{Cache} || {} } ) {
            next TYPE if exists $KeepTypeLookup{$Type};

            delete $Self->{Cache}->{$Type};

            # check and delete depending caches
            $Self->_HandleDependingCacheTypes(
                Type   => $Type,
                Indent => $Param{Indent}.'    '
            );

            $Self->_UpdateCacheStats(
                Operation => 'CleanUp',
                Type      => $Type
            );
        }
    }
    else {
        my @AdditionalKeepTypes;
        my $AlwaysKeepTypes = $Kernel::OM->Get('Kernel::Config')->Get('Cache::AlwaysKeepTypesOnCompleteCleanUp');
        if ( IsHashRefWithData($AlwaysKeepTypes) ) {
            # extend relevant param with the list of activated types
            @AdditionalKeepTypes = grep { defined $_ } map { $AlwaysKeepTypes->{$_} ? $_ : undef } keys %{$AlwaysKeepTypes};
            if ( @AdditionalKeepTypes ) {
                $Param{KeepTypes} = \(@{$Param{KeepTypes} || []}, @AdditionalKeepTypes);
            }
        }

        delete $Self->{Cache};
        delete $Self->{TypeDependencies};

        # delete persistent cache
        if ( $Self->{CacheInBackend} ) {
            $Self->{CacheObject}->Delete(
                Type => 'Cache',
                Key  => 'TypeDependencies',
            );
        }

        # some debug output
        if ( !$Param{KeepTypes} ) {
            $Self->_Debug($Param{Indent}, "cleaning up everything");
        }
        else {
            $Self->_Debug($Param{Indent}, "cleaning up everything except: ".join(', ', @{$Param{KeepTypes}}));
        }

        $Self->_UpdateCacheStats(
            Operation => 'CleanUp',
            %Param,
        );        
    }

    # cleanup persistent cache
    return $Self->{CacheObject}->CleanUp(%Param);
}

=item GetCacheStats()

return the cache statistics

    my $HashRef = $CacheObject->GetCacheStats();

=cut

sub GetCacheStats {
    my ( $Self, %Param ) = @_;
    my $Result;

    my @Files = $Kernel::OM->Get('Kernel::System::Main')->DirectoryRead(
        Directory => $Kernel::OM->Get('Kernel::Config')->Get('Home').'/var/tmp',
        Filter    => 'CacheStats.*',
    );
    foreach my $File (@Files) {
        my $Content = $Kernel::OM->Get('Kernel::System::Main')->FileRead(
            Location => $File,
        );
        if ($Content && $$Content) {
            my $CacheStats = eval { Storable::thaw( ${$Content} ) };
            foreach my $Type (keys %{$CacheStats}) {
                if (!exists $Result->{$Type}) {
                    $Result->{$Type}->{AccessCount}  = 0;
                    $Result->{$Type}->{HitCount}     = 0;
                    $Result->{$Type}->{CleanupCount} = 0;
                    $Result->{$Type}->{DeleteCount}  = 0;
                }
                $Result->{$Type}->{AccessCount}  += $CacheStats->{$Type}->{AccessCount} || 0;
                $Result->{$Type}->{HitCount}     += $CacheStats->{$Type}->{HitCount} || 0;
                $Result->{$Type}->{KeyCount}     += $CacheStats->{$Type}->{KeyCount} || 0;
                $Result->{$Type}->{CleanupCount} += $CacheStats->{$Type}->{CleanupCount} || 0;
                $Result->{$Type}->{DeleteCount}  += $CacheStats->{$Type}->{DeleteCount} || 0;
            }
        }
    }

    return $Result;
}

=item DeleteCacheStats()

delete the cache statistics

    my $Result = $CacheObject->DeleteCacheStats();

=cut

sub DeleteCacheStats {
    my ( $Self, %Param ) = @_;

    my @Files = $Kernel::OM->Get('Kernel::System::Main')->DirectoryRead(
        Directory => $Kernel::OM->Get('Kernel::Config')->Get('Home').'/var/tmp',
        Filter    => 'CacheStats.*',
    );
    foreach my $File (@Files) {
        my $Result = $Kernel::OM->Get('Kernel::System::Main')->FileDelete(
            Location => $File,
        );
        if (!$Result) {
            return;
        }
    }

    return 1;
}

=item _HandleDependingCacheTypes()

deletes relevant keys of depending cache types

    $CacheObject->_HandleDependingCacheTypes(
        Type => '...'
    );

=cut

sub _HandleDependingCacheTypes {
    my ( $Self, %Param ) = @_;

    $Param{Indent} = $Param{Indent} || '';

    if ( !$Self->{TypeDependencies} ) {
        # load information from backend
        $Self->{TypeDependencies} = $Self->{CacheObject}->Get(
            Type => 'Cache',
            Key  => 'TypeDependencies',
        );
    }

    if ( $Self->{TypeDependencies} && IsHashRefWithData($Self->{TypeDependencies}->{$Param{Type}}) ) {        
        $Self->_Debug($Param{Indent}, "type \"$Param{Type}\" of deleted key affects other cache types: ".join(', ', keys %{$Self->{TypeDependencies}->{$Param{Type}}}));

        foreach my $DependentType ( keys %{$Self->{TypeDependencies}->{$Param{Type}}} ) {
            $Self->_Debug($Param{Indent}, "    cleaning up depending cache type \"$DependentType\"");
            delete $Self->{TypeDependencies}->{$Param{Type}}->{$DependentType};

            # delete whole type if all keys are deleted
            if ( !IsHashRefWithData($Self->{TypeDependencies}->{$Param{Type}}) ) {
                $Self->_Debug($Param{Indent}, "        no dependencies left for type $Param{Type}, deleting entry");
                delete $Self->{TypeDependencies}->{$Param{Type}};
            }

            if ( !IsHashRefWithData($Self->{TypeDependencies}) ) {
                $Self->{TypeDependencies} = undef;
            }

            $Self->CleanUp(
                Type => $DependentType,
            );
        }
    }

    return 1;
}

=item _UpdateCacheStats()

update the cache statistics

    $CacheObject->_UpdateCacheStats(
        Type => '...'
    );

=cut

sub _UpdateCacheStats {
    my ( $Self, %Param ) = @_;

    # do nothing if cache stats are not enabled
    return if !$Kernel::OM->Get('Kernel::Config')->Get('Cache::Stats');

    # read stats from disk if empty
    my $Filename = $Kernel::OM->Get('Kernel::Config')->Get('Home').'/var/tmp/CacheStats.'.$$;
    if ( !$Self->{CacheStats} && -f $Filename ) {
        my $Content = $Kernel::OM->Get('Kernel::System::Main')->FileRead(
            Location        => $Filename,
            DisableWarnings => 1,
        );
        if ($Content && $$Content) {
            $Self->{CacheStats} = eval { Storable::thaw( ${$Content} ) };
        }
    }

    # add to stats
    if ( $Param{Operation} eq 'Set' ) {
        $Self->{CacheStats}->{$Param{Type}}->{KeyCount}++;
    }
    elsif ( $Param{Operation} eq 'Get' ) {
        $Self->{CacheStats}->{$Param{Type}}->{AccessCount}++;
        if ($Param{Result} eq 'HIT') {
            $Self->{CacheStats}->{$Param{Type}}->{HitCount}++
        }
    }
    elsif ( $Param{Operation} eq 'Delete' ) {
        if ($Self->{CacheStats}->{$Param{Type}}->{KeyCount}) {
            $Self->{CacheStats}->{$Param{Type}}->{KeyCount}--;
        }
        $Self->{CacheStats}->{$Param{Type}}->{DeleteCount}++;
    }
    elsif ( $Param{Operation} eq 'CleanUp' ) {
        if ( $Param{Type} ) {
            $Self->{CacheStats}->{$Param{Type}}->{KeyCount} = 0;
            $Self->{CacheStats}->{$Param{Type}}->{CleanupCount}++;
        }
        else {
            # clear stats of each type and incease cleanup counter
            foreach my $Type ( keys %{$Self->{CacheStats}} ) {
                foreach my $Key ( keys %{$Self->{CacheStats}->{$Type}} ) {
                    next if $Key eq 'CleanupCount';
                    $Self->{CacheStats}->{$Type}->{$Key} = 0;
                }
                $Self->{CacheStats}->{$Type}->{CleanupCount}++;
            }
        }
    }

    # store to disk
    my $Content = '';
    if ( $Self->{CacheStats} ) {
        $Content = Storable::nfreeze($Self->{CacheStats});
    }

    $Kernel::OM->Get('Kernel::System::Main')->FileWrite(
        Directory => $Kernel::OM->Get('Kernel::Config')->Get('Home').'/var/tmp',
        Filename  => 'CacheStats.'.$$,
        Content   => \$Content,
    );

    return 1;
}

sub _Debug {
    my ( $Self, $Indent, $Message ) = @_;

    return if ( !$Kernel::OM->Get('Kernel::Config')->Get('Cache::Debug') );
    return if !$Message;

    $Indent ||= '';

    printf STDERR "(%5i) %-15s %s%s\n", $$, "[Cache]", $Indent, $Message;
}


=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-AGPL for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
