# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Requester;

use strict;
use warnings;

use Kernel::API::Debugger;
use Kernel::API::Invoker;
use Kernel::API::Mapping;
use Kernel::API::Transport;
use Kernel::System::VariableCheck qw(IsHashRefWithData);

our @ObjectDependencies = (
    'API::Webservice',
    'Log',
);

=head1 NAME

Kernel::API::Requester - API handler for sending web service requests to remote providers

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

create an object. Do not create it directly, instead use:

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $RequesterObject = $Kernel::OM->Get('API::Requester');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item Run()

receives the current incoming web service request, handles it,
and returns an appropriate answer based on the configured requested
web service.

    my $Result = $RequesterObject->Run(
        WebserviceID => 1,                      # ID of the configured remote web service to use OR
        Invoker      => 'some_operation',       # Name of the Invoker to be used for sending the request
        Asynchronous => 1,                      # Optional, 1 or 0, defaults to 0
        Data         => {                       # Data payload for the Invoker request (remote webservice)
           #...
        },
    );

    $Result = {
        Success      => 1,   # 0 or 1
        ErrorMessage => '',  # if an error occurred
        Data         => {    # Data payload of Invoker result (web service response)
            #...
        },
    };

in case of an error if the request has been made asynchronously it can be re-schedule in future if
the invoker returns the appropriate information

    $Result = {
        Success      => 0,   # 0 or 1
        ErrorMessage => 'some error message',
        Data         => {
            ReSchedule    => 1,
            ExecutionTime => '2015-01-01 00:00:00',     # optional
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    for my $Needed (qw(WebserviceID Invoker Data)) {
        if ( !$Param{$Needed} ) {
            $Kernel::OM->Get('Log')->Log(
                Priority => 'error',
                Message  => "Got no $Needed!",
            );

            return {
                Success      => 0,
                ErrorMessage => "Got no $Needed!",
            };
        }
    }

    #
    # Locate desired webservice and load its configuration data.
    #

    my $WebserviceID = $Param{WebserviceID};

    my $Webservice = $Kernel::OM->Get('API::Webservice')->WebserviceGet(
        ID => $WebserviceID,
    );

    if ( !IsHashRefWithData($Webservice) ) {
        $Kernel::OM->Get('Log')->Log(
            Priority => 'error',
            Message =>
                "Could not load web service configuration for web service $Param{WebserviceID}",
        );

        return {
            Success => 0,
            ErrorMessage =>
                "Could not load web service configuration for web service $Param{WebserviceID}",
        };
    }

    my $RequesterConfig = $Webservice->{Config}->{Requester};

    #
    # Create a debugger instance which will log the details of this
    #   communication entry.
    #

    my $DebuggerObject = Kernel::API::Debugger->new(
        DebuggerConfig    => $Webservice->{Config}->{Debugger},
        WebserviceID      => $WebserviceID,
        CommunicationType => 'Requester',
    );

    if ( ref $DebuggerObject ne 'API::Debugger' ) {

        return {
            Success      => 0,
            ErrorMessage => "Could not initialize debugger",
        };
    }

    $DebuggerObject->Debug(
        Summary => 'Communication sequence started',
        Data    => $Param{Data},
    );

    #
    # Create Invoker object and prepare the request on it.
    #

    $DebuggerObject->Debug(
        Summary => "Using invoker '$Param{Invoker}'",
    );

    my $InvokerObject = Kernel::API::Invoker->new(
        DebuggerObject => $DebuggerObject,
        Invoker        => $Param{Invoker},
        InvokerType    => $RequesterConfig->{Invoker}->{ $Param{Invoker} }->{Type},
        WebserviceID   => $WebserviceID,
    );

    # bail out if invoker init failed
    if ( ref $InvokerObject ne 'API::Invoker' ) {

        return $DebuggerObject->Error(
            Summary => 'InvokerObject could not be initialized',
            Data    => $InvokerObject,
        );
    }

    my $FunctionResult = $InvokerObject->PrepareRequest(
        Data => $Param{Data},
    );

    if ( !$FunctionResult->{Success} ) {

        return $DebuggerObject->Error(
            Summary => 'InvokerObject returned an error, canceling Request',
            Data    => $FunctionResult->{ErrorMessage},
        );
    }

    # not always a success on the invoker prepare request means that invoker need to do something
    # there are cases in which the requester does not need to do anything, for this cases
    # StopCommunication can be sent. in this cases the request will be successful with out sending
    # the request actually
    elsif ( $FunctionResult->{StopCommunication} && $FunctionResult->{StopCommunication} eq 1 ) {

        return {
            Success => 1,
        };
    }

    #
    # Map the outgoing data.
    #

    my $DataOut = $FunctionResult->{Data};

    $DebuggerObject->Debug(
        Summary => "Outgoing data before mapping",
        Data    => $DataOut,
    );

    # decide if mapping needs to be used or not
    if (
        IsHashRefWithData(
            $RequesterConfig->{Invoker}->{ $Param{Invoker} }->{MappingOutbound}
        )
        )
    {
        my $MappingOutObject = Kernel::API::Mapping->new(
            DebuggerObject => $DebuggerObject,
            Invoker        => $Param{Invoker},
            InvokerType    => $RequesterConfig->{Invoker}->{ $Param{Invoker} }->{Type},
            MappingConfig =>
                $RequesterConfig->{Invoker}->{ $Param{Invoker} }->{MappingOutbound},
        );

        # if mapping init failed, bail out
        if ( ref $MappingOutObject ne 'API::Mapping' ) {
            $DebuggerObject->Error(
                Summary => 'MappingOut could not be initialized',
                Data    => $MappingOutObject,
            );

            return $DebuggerObject->Error(
                Summary => $FunctionResult->{ErrorMessage},
            );
        }

        $FunctionResult = $MappingOutObject->Map(
            Data => $DataOut,
        );

        if ( !$FunctionResult->{Success} ) {

            return $DebuggerObject->Error(
                Summary => $FunctionResult->{ErrorMessage},
            );
        }

        $DataOut = $FunctionResult->{Data};

        $DebuggerObject->Debug(
            Summary => "Outgoing data after mapping",
            Data    => $DataOut,
        );
    }

    my $TransportObject = Kernel::API::Transport->new(
        DebuggerObject  => $DebuggerObject,
        TransportConfig => $RequesterConfig->{Transport},
    );

    # bail out if transport init failed
    if ( ref $TransportObject ne 'API::Transport' ) {

        return $DebuggerObject->Error(
            Summary => 'TransportObject could not be initialized',
            Data    => $TransportObject,
        );
    }

    # read request content
    $FunctionResult = $TransportObject->RequesterPerformRequest(
        Operation => $Param{Invoker},
        Data      => $DataOut,
    );

    my $IsAsynchronousCall = $Param{Asynchronous} ? 1 : 0;

    if ( !$FunctionResult->{Success} ) {
        my $ErrorReturn = $DebuggerObject->Error(
            Summary => $FunctionResult->{ErrorMessage},
        );

        # Send error to Invoker
        my $Response = $InvokerObject->HandleResponse(
            ResponseSuccess      => 0,
            ResponseErrorMessage => $FunctionResult->{ErrorMessage},
            
            # KIXPro-capeIT  
            ResponseOriginal => $Param{Data} || '',
            # EO KIXPro-capeIT        
        );

        if ($IsAsynchronousCall) {

            RESPONSEKEY:
            for my $ResponseKey ( sort keys %{$Response} ) {

                # skip Success and ErrorMessage as they are set already
                next RESPONSEKEY if $ResponseKey eq 'Success';
                next RESPONSEKEY if $ResponseKey eq 'ErrorMessage';

                # add any other key from the invoker HandleResponse() in Data
                $ErrorReturn->{$ResponseKey} = $Response->{$ResponseKey}
            }
        }

        return $ErrorReturn;
    }

    my $DataIn = $FunctionResult->{Data};
    my $SizeExeeded = $FunctionResult->{SizeExeeded} || 0;

    if ($SizeExeeded) {
        $DebuggerObject->Debug(
            Summary => "Incoming data before mapping was too large for logging",
            Data => 'See SysConfig option API::Operation::ResponseLoggingMaxSize to change the maximum.',
        );
    }
    else {
        $DebuggerObject->Debug(
            Summary => "Incoming data before mapping",
            Data    => $DataIn,
        );
    }

    # decide if mapping needs to be used or not
    if (
        IsHashRefWithData(
            $RequesterConfig->{Invoker}->{ $Param{Invoker} }->{MappingInbound}
        )
        )
    {
        my $MappingInObject = Kernel::API::Mapping->new(
            DebuggerObject => $DebuggerObject,
            Invoker        => $Param{Invoker},
            InvokerType    => $RequesterConfig->{Invoker}->{ $Param{Invoker} }->{Type},
            MappingConfig =>
                $RequesterConfig->{Invoker}->{ $Param{Invoker} }->{MappingInbound},
        );

        # if mapping init failed, bail out
        if ( ref $MappingInObject ne 'API::Mapping' ) {
            $DebuggerObject->Error(
                Summary => 'MappingOut could not be initialized',
                Data    => $MappingInObject,
            );

            return $DebuggerObject->Error(
                Summary => $FunctionResult->{ErrorMessage},
            );
        }

        $FunctionResult = $MappingInObject->Map(
            Data => $DataIn,
        );

        if ( !$FunctionResult->{Success} ) {

            return $DebuggerObject->Error(
                Summary => $FunctionResult->{ErrorMessage},
            );
        }

        $DataIn = $FunctionResult->{Data};

        if ($SizeExeeded) {
            $DebuggerObject->Debug(
                Summary => "Incoming data after mapping was too large for logging",
                Data =>
                    'See SysConfig option API::Operation::ResponseLoggingMaxSize to change the maximum.',
            );
        }
        else {
            $DebuggerObject->Debug(
                Summary => "Incoming data after mapping",
                Data    => $DataIn,
            );
        }
    }

    #
    # Handle response data in Invoker
    #

    $FunctionResult = $InvokerObject->HandleResponse(
        ResponseSuccess => 1,
        Data            => $DataIn,
    );

    if ( !$FunctionResult->{Success} ) {

        my $ErrorReturn = $DebuggerObject->Error(
            Summary => 'Error handling response data in Invoker',
            Data    => $FunctionResult->{ErrorMessage},
        );

        if ($IsAsynchronousCall) {

            RESPONSEKEY:
            for my $ResponseKey ( sort keys %{$FunctionResult} ) {

                # skip Success and ErrorMessage as they are set already
                next RESPONSEKEY if $ResponseKey eq 'Success';
                next RESPONSEKEY if $ResponseKey eq 'ErrorMessage';

                # add any other key from the invoker HandleResponse() in Data
                $ErrorReturn->{$ResponseKey} = $FunctionResult->{$ResponseKey}
            }
        }

        return $ErrorReturn;
    }

    $DataIn = $FunctionResult->{Data};

    return {
        Success => 1,
        Data    => $DataIn,
    };
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
