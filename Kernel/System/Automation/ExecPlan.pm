# --
# Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::System::Automation::ExecPlan;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::Cache',
    'Kernel::System::DB',
    'Kernel::System::Log',
    'Kernel::System::User',
    'Kernel::System::Valid',
);

=head1 NAME

Kernel::System::Automation::ExecPlan - execution plan extension for automation lib

=head1 SYNOPSIS

All Execution Plan functions.

=head1 PUBLIC INTERFACE

=over 4

=cut

=item ExecPlanTypeGet()

get a description of the given ExecPlan type

    my %ExecPlanType = $AutomationObject->ExecPlanTypeGet(
        Name => '...',
    );

=cut

sub ExecPlanTypeGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Name} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Got no Name!',
        );
        return;
    }

    # load type backend module
    my $BackendObject = $Self->_LoadExecPlanTypeBackend(
        %Param
    );
    return if !$BackendObject;

    return $BackendObject->DefinitionGet();
}

=item ExecPlanLookup()

get id for ExecPlan name

    my $ExecPlanID = $AutomationObject->ExecPlanLookup(
        Name => '...',
    );

get name for ExecPlan id

    my $ExecPlanName = $AutomationObject->ExecPlanLookup(
        ID => '...',
    );

=cut

sub ExecPlanLookup {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{Name} && !$Param{ID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Got no Name or ID!',
        );
        return;
    }

    # get ExecPLan list
    my %ExecPlanList = $Self->ExecPlanList(
        Valid => 0,
    );

    return $ExecPlanList{ $Param{ID} } if $Param{ID};

    # create reverse list
    my %ExecPlanListReverse = reverse %ExecPlanList;

    return $ExecPlanListReverse{ $Param{Name} };
}

=item ExecPlanGet()

returns a hash with the ExecPlan data

    my %ExecPlanData = $AutomationObject->ExecPlanGet(
        ID => 2,
    );

This returns something like:

    %ExecPlanData = (
        'ID'         => 2,
        'Type'       => '...'
        'Name'       => 'Test'
        'Parameters' => {
            Weekdays => [0,2],                  # 0 = Sunday, 1 = Monday, ...
            Time => '10:00:00',
            Events => [ 'TicketCreate', ...]
        },
        'Comment'    => '...',
        'ValidID'    => '1',
        'CreateTime' => '2010-04-07 15:41:15',
        'CreateBy'   => 1,
        'ChangeTime' => '2010-04-07 15:41:15',
        'ChangeBy'   => 1
    );

=cut

sub ExecPlanGet {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    if ( !$Param{ID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => 'Need ID!'
        );
        return;
    }

    # check cache
    my $CacheKey = 'ExecPlanGet::' . $Param{ID};
    my $Cache    = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;
    
    return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare( 
        SQL   => "SELECT id, name, type, parameters, comments, valid_id, create_time, create_by, change_time, change_by FROM exec_plan WHERE id = ?",
        Bind => [ \$Param{ID} ],
    );

    my %Result;
    
    # fetch the result
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        %Result = (
            ID         => $Row[0],
            Name       => $Row[1],
            Type       => $Row[2],
            Parameters => $Row[3],
            Comment    => $Row[4],
            ValidID    => $Row[5],
            CreateTime => $Row[6],
            CreateBy   => $Row[7],
            ChangeTime => $Row[8],
            ChangeBy   => $Row[9],
        );

        if ( $Result{Parameters} ) {
            # decode JSON
            $Result{Parameters} = $Kernel::OM->Get('Kernel::System::JSON')->Decode(
                Data => $Result{Parameters}
            );
        }
    }
    
    # no data found...
    if ( !%Result ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "ExecPlan with ID $Param{ID} not found!",
        );
        return;
    }
    
    # set cache
    $Kernel::OM->Get('Kernel::System::Cache')->Set(
        Type  => $Self->{CacheType},
        TTL   => $Self->{CacheTTL},
        Key   => $CacheKey,
        Value => \%Result,
    ); 

    return %Result;
}

=item ExecPlanAdd()

adds a new ExecPlan

    my $ID = $AutomationObject->ExecPlanAdd(
        Name       => 'test',
        Type       => 'test',
        Parameters => {                             # optional
            Weekdays => [0,2],                          # optional 0 = Sunday, 1 = Monday, ...
            Time => '10:00:00',                         # optional
            Events => [ 'TicketCreate', ...]            # optional
        },
        Comment    => '...',                        # optional
        ValidID    => 1,                            # optional
        UserID     => 123,
    );

=cut

sub ExecPlanAdd {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Name Type UserID)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }

    if ( !defined $Param{ValidID} ) {
        $Param{ValidID} = 1;
    }

    # check if this is a duplicate after the change
    my $ID = $Self->ExecPlanLookup( 
        Name => $Param{Name},
    );
    if ( $ID ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "An ExecPlan with the same name already exists.",
        );
        return;
    }

    # validate Parameters
    my $BackendObject = $Self->_LoadExecPlanTypeBackend(
        Name      => $Param{Type},
    );
    return if !$BackendObject;

    my $IsValid = $BackendObject->ValidateConfig(
        Config => $Param{Parameters}
    );

    if ( !$IsValid ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "ExecPlan config is invalid!"
        );
        return;
    }

    # prepare Parameters as JSON
    my $Parameters;
    if ( $Param{Parameters} ) {
        $Parameters = $Kernel::OM->Get('Kernel::System::JSON')->Encode(
            Data => $Param{Parameters}
        );
    }

    # get database object
    my $DBObject = $Kernel::OM->Get('Kernel::System::DB');

    # insert
    return if !$DBObject->Do(
        SQL => 'INSERT INTO exec_plan (name, type, parameters, comments, valid_id, create_time, create_by, change_time, change_by) '
             . 'VALUES (?, ?, ?, ?, ?, current_timestamp, ?, current_timestamp, ?)',
        Bind => [
            \$Param{Name}, \$Param{Type}, \$Parameters, \$Param{Comment}, \$Param{ValidID}, \$Param{UserID}, \$Param{UserID}
        ],
    );

    # get new id
    return if !$DBObject->Prepare(
        SQL  => 'SELECT id FROM exec_plan WHERE name = ?',
        Bind => [ 
            \$Param{Name}, 
        ],
    );

    # fetch the result
    while ( my @Row = $DBObject->FetchrowArray() ) {
        $ID = $Row[0];
    }

    # delete whole cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp();

    # push client callback event
    $Kernel::OM->Get('Kernel::System::ClientRegistration')->NotifyClients(
        Event     => 'CREATE',
        Namespace => 'ExecPlan',
        ObjectID  => $ID,
    );

    return $ID;
}

=item ExecPlanUpdate()

updates an ExecPlan

    my $Success = $AutomationObject->ExecPlanUpdate(
        ID         => 123,        
        Name       => 'test'
        Type       => 'test',
        Parameters => {                             # optional
            Weekdays => [0,2],                          # optional 0 = Sunday, 1 = Monday, ...
            Time => '10:00:00',                         # optional
            Events => [ 'TicketCreate', ...]            # optional
        },
        Comment    => '...',                        # optional
        ValidID    => 1,                            # optional
        UserID     => 123,
    );

=cut

sub ExecPlanUpdate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ID UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!",
            );
            return;
        }
    }

    # get current data
    my %Data = $Self->ExecPlanGet(
        ID => $Param{ID},
    );

    # check if this is a duplicate after the change
    my $ID = $Self->ExecPlanLookup( 
        Name => $Param{Name} || $Data{Name},
    );
    if ( $ID && $ID != $Param{ID} ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "A ExecPlan with the same name already exists.",
        );
        return;
    }

    # validate parameters if given
    if ( $Param{Parameters} ) {
        # validate Parameters
        my $BackendObject = $Self->_LoadExecPlanTypeBackend(
            Name => $Param{Type} || $Data{Type},
        );
        return if !$BackendObject;

        my $IsValid = $BackendObject->ValidateConfig(
            Config => $Param{Parameters}
        );

        if ( !$IsValid ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "ExecPlan config is invalid!"
            );
            return;
        }
    }

    # set default value
    $Param{Comment} ||= '';

    # check if update is required
    my $ChangeRequired;
    KEY:
    for my $Key ( qw(Name Type Parameters Comment ValidID) ) {

        next KEY if defined $Data{$Key} && $Data{$Key} eq $Param{$Key};

        $ChangeRequired = 1;

        last KEY;
    }

    return 1 if !$ChangeRequired;

    $Param{Type} ||= $Data{Type};

    # prepare Parameters as JSON
    my $Parameters;
    if ( $Param{Parameters} ) {
        $Parameters = $Kernel::OM->Get('Kernel::System::JSON')->Encode(
            Data => $Param{Parameters}
        );
    }

    # update ExecPlan in database
    return if !$Kernel::OM->Get('Kernel::System::DB')->Do(
        SQL => 'UPDATE exec_plan SET name = ?, type = ?, parameters = ?, comments = ?, valid_id = ?, change_time = current_timestamp, change_by = ? WHERE id = ?',
        Bind => [
            \$Param{Name}, \$Param{Type}, \$Parameters, \$Param{Comment}, \$Param{ValidID}, \$Param{UserID}, \$Param{ID}
        ],
    );

    # delete whole cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp();

    # push client callback event
    $Kernel::OM->Get('Kernel::System::ClientRegistration')->NotifyClients(
        Event     => 'UPDATE',
        Namespace => 'ExecPlan',
        ObjectID  => $Param{ID},
    );

    return 1;
}

=item ExecPlanList()

returns a hash of all ExecPlans

    my %ExecPlans = $AutomationObject->ExecPlanList(
        Valid => 1          # optional
    );

the result looks like

    %ExecPlans = (
        1 => 'test',
        2 => 'dummy',
        3 => 'domesthing'
    );

=cut

sub ExecPlanList {
    my ( $Self, %Param ) = @_;

    # set default value
    my $Valid = $Param{Valid} ? 1 : 0;

    # create cache key
    my $CacheKey = 'ExecPlanList::' . $Valid;

    # read cache
    my $Cache = $Kernel::OM->Get('Kernel::System::Cache')->Get(
        Type => $Self->{CacheType},
        Key  => $CacheKey,
    );
    return %{$Cache} if $Cache;

    my $SQL = 'SELECT id, name FROM exec_plan';

    if ( $Param{Valid} ) {
        $SQL .= ' WHERE valid_id = 1'
    }

    return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare( 
        SQL => $SQL
    );

    my %Result;
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        $Result{$Row[0]} = $Row[1];
    }

    # set cache
    $Kernel::OM->Get('Kernel::System::Cache')->Set(
        Type  => $Self->{CacheType},
        Key   => $CacheKey,
        Value => \%Result,
        TTL   => $Self->{CacheTTL},
    );

    return %Result;
}

=item ExecPlanDelete()

deletes an ExecPlan

    my $Success = $AutomationObject->ExecPlanDelete(
        ID => 123,
    );

=cut

sub ExecPlanDelete {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # check if this ExecPlan exists
    my $ID = $Self->ExecPlanLookup( 
        ID => $Param{ID},
    );
    if ( !$ID ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "An ExecPlan with the ID $Param{ID} does not exist.",
        );
        return;
    }

    # delete relations with Jobs
    return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL  => 'DELETE FROM job_exec_plan WHERE exec_plan_id = ?',
        Bind => [ \$Param{ID} ],
    );

    # remove from database
    return if !$Kernel::OM->Get('Kernel::System::DB')->Prepare(
        SQL  => 'DELETE FROM exec_plan WHERE id = ?',
        Bind => [ \$Param{ID} ],
    );
   
    # delete whole cache
    $Kernel::OM->Get('Kernel::System::Cache')->CleanUp();

    # push client callback event
    $Kernel::OM->Get('Kernel::System::ClientRegistration')->NotifyClients(
        Event     => 'DELETE',
        Namespace => 'ExecPlan',
        ObjectID  => $Param{ID},
    );

    return 1;

}

=item ExecPlanCheck()

checks an exec plan if the job can run

    my $CanExecute = $AutomationObject->ExecPlanCheck(
        ID        => 123,       # the ID of the macro action
        JobID     => 123,       # the ID of the job to be executed
        Time      => '...',     # optional, required for time based execplans
        Event     => '...',     # optional, required for event based execplans
        UserID    => 1
    );

=cut

sub ExecPlanCheck {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(ID JobID UserID)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    # get ExecPlan data
    my %ExecPlan = $Self->ExecPlanGet(
        ID => $Param{ID}
    );

    if ( !%ExecPlan ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "No such ExecPlan with ID $Param{ID}!"
        );
        return;        
    }

    # igonore invalid exec plans
    return if $ExecPlan{ValidID} != 1;

    # get Job data
    my %Job = $Self->JobGet(
        ID => $Param{JobID}
    );

    if ( !%Job ) {
        $Kernel::OM->Get('Kernel::System::Log')->Log(
            Priority => 'error',
            Message  => "No such job with ID $Param{JobID}!"
        );
        return;        
    }

    # load type backend module
    my $BackendObject = $Self->_LoadExecPlanTypeBackend(
        Name => $ExecPlan{Type},
    );
    return if !$BackendObject;

    my $BackendResult = $BackendObject->Run(
        %Param,
        Config            => $ExecPlan{Parameters},
        LastExecutionTime => $Job{LastExecutionTime},
    );

    return $BackendResult;
}

sub _LoadExecPlanTypeBackend {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Name)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    $Self->{ExecPlanTypeModules} //= {};

    if ( !$Self->{ExecPlanTypeModules}->{$Param{Name}} ) {
        my $Backend = 'Kernel::System::Automation::ExecPlan::' . $Param{Name};

        if ( !$Kernel::OM->Get('Kernel::System::Main')->Require($Backend) ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Unable to require $Backend!"
            );        
        }

        my $BackendObject = $Backend->new( %{$Self} );
        if ( !$BackendObject ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Unable to create instance of $Backend!"
            );        
        }

        $Self->{ExecPlanTypeModules}->{$Param{Name}} = $BackendObject;
    }

    return $Self->{ExecPlanTypeModules}->{$Param{Name}};
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
