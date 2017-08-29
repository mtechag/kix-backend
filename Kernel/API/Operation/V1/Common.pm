# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::Common;

use strict;
use warnings;
use Hash::Flatten;
use Data::Sorting qw(:arrays);

use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::Common - Base class for all Operations

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item Init()

initialize the operation by checking the webservice configuration

    my $Return = $CommonObject->Init(
        WebserviceID => 1,
    );

    $Return = {
        Success => 1,                       # or 0 in case of failure,
        Message => 'Error Message',
    }

=cut

sub Init {
    my ( $Self, %Param ) = @_;

    # check needed
    if ( !$Param{WebserviceID} ) {
        return $Self->_Error(
            Code    => 'Webservice.InternalError',
            Message => "Got no WebserviceID!",
        );
    }

    # get webservice configuration
    my $Webservice = $Kernel::OM->Get('Kernel::System::API::Webservice')->WebserviceGet(
        ID => $Param{WebserviceID},
    );

    if ( !IsHashRefWithData($Webservice) ) {
        return $Self->_Error(
            Code    => 'Webservice.InternalError',
            Message =>
                'Could not determine Web service configuration'
                . ' in Kernel::API::Operation::V1::Common::Init()',
        );
    }

    return {
        Success => 1,
    };
}

=item PrepareData()

prepare data, check given parameters and parse them according to type

    my $Return = $CommonObject->PrepareData(
        Data   => {
            ...
        },
        Parameters => {
            <Parameter> => {                                            # if Parameter is a attribute of a hashref, just separate it by ::, i.e. "User::UserFirstname"
                Type                => 'ARRAY',                         # optional, use this to parse a comma separated string into an array
                Required            => 1,                               # optional
                RequiredIfNot       => [ '<AltParameter>', ... ]        # optional, specify the alternate parameters to be checked, if one of them has a value
                RequiresValueIfUsed => 1                                # optional
                Default             => ...                              # optional
                OneOf               => [...]                            # optional
            }
        }
    );

    $Return = {
        Success => 1,                       # or 0 in case of failure,
        Message => 'Error Message',
    }

=cut

sub PrepareData {
    my ( $Self, %Param ) = @_;
    my $Result = {
        Success => 1
    };

    # check needed stuff
    for my $Needed (qw(Data)) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => 'PrepareData.MissingParameter',
                Message => "$Needed parameter is missing!",
            );
        }
    }

    # prepare field filter
    if ( exists($Param{Data}->{filter}) ) {
        my $Result = $Self->_ValidateFilter(
            Filter => $Param{Data}->{filter},
        );
        if ( IsHashRefWithData($Result) ) {
            # error occured
            return $Result;
        }
    }

    # prepare field selector
    if ( exists($Param{Data}->{fields}) ) {
        foreach my $FieldSelector ( split(/,/, $Param{Data}->{fields}) ) {
            my ($Object, $Field) = split(/\./, $FieldSelector, 2);
            if ( !IsArrayRefWithData($Self->{Fields}->{$Object}) ) {
                $Self->{Fields}->{$Object} = [];
            }
            push @{$Self->{Fields}->{$Object}}, $Field;
        }
    }

    # prepare limiter
    if ( exists($Param{Data}->{limit}) ) {
        foreach my $Limiter ( split(/,/, $Param{Data}->{limit}) ) {
            my ($Object, $Limit) = split(/\:/, $Limiter, 2);
            if ( $Limit && $Limit =~ /\d+/ ) {
               $Self->{Limit}->{$Object} = $Limit;
            }
            else {
                $Self->{Limit}->{__COMMON} = $Object;
            }
        }
    }

    # prepare offset
    if ( exists($Param{Data}->{offset}) ) {
        foreach my $Offset ( split(/,/, $Param{Data}->{offset}) ) {
            my ($Object, $Index) = split(/\:/, $Offset, 2);
            if ( $Index && $Index =~ /\d+/ ) {
               $Self->{Offset}->{$Object} = $Index;
            }
            else {
                $Self->{Offset}->{__COMMON} = $Object;
            }
        }
    }

    # prepare sorter
    if ( exists($Param{Data}->{sort}) ) {
        foreach my $Sorter ( split(/,/, $Param{Data}->{sort}) ) {
            my ($Object, $FieldSort) = split(/\./, $Sorter, 2);
            my ($Field, $Type) = split(/\:/, $FieldSort);
            my $Direction = 'ascending';
            $Type = uc($Type || 'TEXTUAL');

            # check if sort type is valid
            if ( $Type && $Type !~ /(NUMERIC|TEXTUAL|NATURAL|DATE|DATETIME)/g ) {
                return $Self->_Error(
                    Code    => 'PrepareData.InvalidSort',
                    Message => "Unknown type $Type in $Sorter!",
                );                
            }
            
            # should we sort ascending or descending
            if ( $Field =~ /^-(.*?)$/g ) {
                $Field = $1;
                $Direction = 'descending';
            }
            
            if ( !IsArrayRefWithData($Self->{Sorter}->{$Object}) ) {
                $Self->{Sort}->{$Object} = [];
            }
            push @{$Self->{Sort}->{$Object}}, { 
                Field => $Field, 
                Direction => $Direction, 
                Type  => ($Type || 'cmp')
            };
        }
    }

    my %Data = %{$Param{Data}};

    # if needed flatten hash structure for easier access to sub structures
    if ( ref($Param{Parameters}) eq 'HASH' ) {
        
        if ( grep(/::/, keys %{$Param{Parameters}}) ) {
            my $FlatData = Hash::Flatten::flatten(
                $Param{Data},
                {
                    HashDelimiter => '::',
                }
            );
            %Data = (
                %Data,
                %{$FlatData},
            );
        }

        foreach my $Parameter ( sort keys %{$Param{Parameters}} ) {

            # check requirement
            if ( $Param{Parameters}->{$Parameter}->{Required} && !exists($Data{$Parameter}) ) {
                $Result->{Success} = 0;
                $Result->{Message} = "Required parameter $Parameter is missing!",
                last;
            }
            elsif ( $Param{Parameters}->{$Parameter}->{RequiredIfNot} && ref($Param{Parameters}->{$Parameter}->{RequiredIfNot}) eq 'ARRAY' ) {
                my $AltParameterHasValue = 0;
                foreach my $AltParameter ( @{$Param{Parameters}->{$Parameter}->{RequiredIfNot}} ) {
                    if ( exists($Data{$AltParameter}) && defined($Data{$AltParameter}) ) {
                        $AltParameterHasValue = 1;
                        last;
                    }
                }
                if ( !exists($Data{$Parameter}) && !$AltParameterHasValue ) {
                    $Result->{Success} = 0;
                    $Result->{Message} = "Required parameter $Parameter or ".( join(" or ", @{$Param{Parameters}->{$Parameter}->{RequiredIfNot}}) )." is missing!",
                    last;
                }
            }

            # parse into arrayref if parameter value is scalar and ARRAY type is needed
            if ( $Param{Parameters}->{$Parameter}->{Type} && $Param{Parameters}->{$Parameter}->{Type} eq 'ARRAY' && $Data{$Parameter} && ref($Data{$Parameter}) ne 'ARRAY' ) {
                $Self->_SetParameter(
                    Data      => $Param{Data},
                    Attribute => $Parameter,
                Value     => [ split('\s*,\s*', $Data{$Parameter}) ],
                );
            }

            # set default value
            if ( !$Data{$Parameter} && exists($Param{Parameters}->{$Parameter}->{Default}) ) {
                $Self->_SetParameter(
                    Data      => $Param{Data},
                    Attribute => $Parameter,
                    Value     => $Param{Parameters}->{$Parameter}->{Default},
                );
            }

            # check valid values
            if ( exists($Param{Parameters}->{$Parameter}->{OneOf}) && ref($Param{Parameters}->{$Parameter}->{OneOf}) eq 'ARRAY' ) {
                if ( !grep(/^$Data{$Parameter}$/g, @{$Param{Parameters}->{$Parameter}->{OneOf}}) ) {
                    $Result->{Success} = 0;
                    $Result->{Message} = "Parameter $Parameter is not one of '".(join(',', @{$Param{Parameters}->{$Parameter}->{OneOf}}))."'!",
                    last;
                }
            }

            # check if we have an optional parameter that needs a value
            if ( $Param{Parameters}->{$Parameter}->{RequiresValueIfUsed} && exists($Data{$Parameter}) && !defined($Data{$Parameter}) ) {
                $Result->{Success} = 0;
                $Result->{Message} = "Optional parameter $Parameter is used without a value!",
                last;
            }
        }
    }
    
    return $Result; 
}

=item _Success()

helper function to return a successful result.

    my $Return = $CommonObject->_Success(
        ...
    );

=cut

sub _Success {
    my ( $Self, %Param ) = @_;

    # honor a filter, if we have one
    if ( IsHashRefWithData($Self->{Filter}) ) {
        $Self->_ApplyFilter(
            Data => \%Param,
        );
    }

    # honor a sorter, if we have one
    if ( IsHashRefWithData($Self->{Sort}) ) {
        $Self->_ApplySort(
            Data => \%Param,
        );
    }
    
    # honor a field selector, if we have one
    if ( IsHashRefWithData($Self->{Fields}) ) {
        $Self->_ApplyFieldSelector(
            Data => \%Param,
        );
    }

    # honor an offset, if we have one
    if ( IsHashRefWithData($Self->{Offset}) ) {
        $Self->_ApplyOffset(
            Data => \%Param,
        );
    }

    # honor a limiter, if we have one
    if ( IsHashRefWithData($Self->{Limit}) ) {
        $Self->_ApplyLimit(
            Data => \%Param,
        );
    }

    # prepare result
    my $Code    = $Param{Code};
    my $Message = $Param{Message};
    delete $Param{Code};
    delete $Param{Message};

    # return structure
    return {
        Success      => 1,
        Code         => $Code,
        Message      => $Message,
        Data         => {
            %Param
        },
    };
}

=item _Error()

helper function to return an error message.

    my $Return = $CommonObject->_Error(
        Code    => Ticket.AccessDenied,
        Message => 'You don't have rights to access this ticket',
    );

=cut

sub _Error {
    my ( $Self, %Param ) = @_;

    $Self->{DebuggerObject}->Error(
        Summary => $Param{Code},
        Data    => $Param{Message},
    );

    # return structure
    return {
        Success => 0,
        Code    => $Param{Code},
        Message => $Param{Message},
        Data    => {
        },
    };
}

=item ExecOperation()

helper function to execute another operation to work with its result.

    my $Return = $CommonObject->ExecOperation(
        Operation => '...'                              # required
        Data      => {

        }
    );

=cut

sub ExecOperation {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(Operation Data)) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => 'ExecOperation.MissingParameter',
                Message => "$Needed parameter is missing!",
            );
        }
    }

    my $Operation = 'Kernel::API::Operation::'.$Param{Operation};

    if ( !$Kernel::OM->Get('Kernel::System::Main')->Require($Operation) ) {
        return $Self->_Error(
            Code    => 'ExecOperation.OperationNotFound',
            Message => "$Operation not found!",
        );
    }
    my $OperationObject = $Operation->new( %{$Self} );

    return $OperationObject->Run(
        Data => $Param{Data},
    );
}


# BEGIN INTERNAL

sub _ValidateFilter {
    my ( $Self, %Param ) = @_;

    if ( !IsHashRefWithData(\%Param) || !$Param{Filter} ) {
        # nothing to do
        return;
    }    

    my %OperationTypeMapping = (
        'EQ'         => { 'NUMERIC' => 1, 'STRING'  => 1, 'DATE' => 1, 'DATETIME' => 1 },
        'NE'         => { 'NUMERIC' => 1, 'STRING'  => 1, 'DATE' => 1, 'DATETIME' => 1 },
        'LT'         => { 'NUMERIC' => 1, 'DATE' => 1, 'DATETIME' => 1 },
        'GT'         => { 'NUMERIC' => 1, 'DATE' => 1, 'DATETIME' => 1 },
        'LTE'        => { 'NUMERIC' => 1, 'DATE' => 1, 'DATETIME' => 1 },
        'GTE'        => { 'NUMERIC' => 1, 'DATE' => 1, 'DATETIME' => 1 },
        'IN'         => { 'NUMERIC' => 1, 'STRING'  => 1, 'DATE' => 1, 'DATETIME' => 1 },
        'CONTAINS'   => { 'STRING'  => 1 },
        'STARTSWITH' => { 'STRING'  => 1 },
        'ENDSWITH'   => { 'STRING'  => 1 },
    );
    my $ValidOperations = join('|', keys %OperationTypeMapping);
    my %ValidTypes;
    foreach my $Tmp ( values %OperationTypeMapping ) {
        foreach my $Type ( keys %{$Tmp} ) { 
            $ValidTypes{$Type} = 1;
        } 
    }

    my $FilterDef = $Kernel::OM->Get('Kernel::System::JSON')->Decode(
        Data => $Param{Filter}
    );
    foreach my $Object ( keys %{$FilterDef} ) {
        # do we have a object definition ?
        if ( !IsArrayRefWithData($FilterDef->{$Object}) ) {
            return $Self->_Error(
                Code    => 'PrepareData.InvalidFilter',
                Message => "Invalid filter for object $Object!",
            );                
        }     
        # iterate filters
        foreach my $Filter ( @{$FilterDef->{$Object}} ) {           
            $Filter->{Operation} = uc($Filter->{Operation} || '');
            $Filter->{Type} = uc($Filter->{Type} || 'STRING');

            # check if filter field is valid
            if ( !$Filter->{Field} ) {
                return $Self->_Error(
                    Code    => 'PrepareData.InvalidFilter',
                    Message => "No field in $Object.$Filter->{Field}!",
                );
            }
            # check if filter operation is valid
            if ( $Filter->{Operation} !~ /^($ValidOperations)$/g ) {
                return $Self->_Error(
                    Code    => 'PrepareData.InvalidFilter',
                    Message => "Unknown filter operation $Filter->{Operation} in $Object.$Filter->{Field}!",
                );
            }
            # check if type is valid
            if ( !$ValidTypes{$Filter->{Type}} ) {
                return $Self->_Error(
                    Code    => 'PrepareData.InvalidFilter',
                    Message => "Unknown type $Filter->{Type} in $Object.$Filter->{Field}!",
                );                
            }
            # check if combination of filter operation and type is valid
            if ( !$OperationTypeMapping{$Filter->{Operation}}->{$Filter->{Type}} ) {
                return $Self->_Error(
                    Code    => 'PrepareData.InvalidFilter',
                    Message => "Type $Filter->{Type} not valid for operation $Filter->{Operation} in $Object.$Filter->{Field}!",
                );                                
            }

            # prepare value if it is a DATE type
            if ( $Filter->{Type} eq 'DATE' ) {
                if ( $Filter->{Value} !~ /\d{4}-\d{2}-\d{2}/ && $Filter->{Value} !~ /\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}/ ) {
                    return $Self->_Error(
                        Code    => 'PrepareData.InvalidFilter',
                        Message => "Invalid date value $Filter->{Value} in $Object.$Filter->{Field}!",
                    );
                }
                my ($DatePart, $TimePart) = split(/T/, $Filter->{Value});

                # convert Value to unixtime to later compares
                $Filter->{Value} = $Kernel::OM->Get('Kernel::System::Time')->TimeStamp2SystemTime(
                    String => $DatePart.' 12:00:00',
                );
            }

            if ( $Filter->{Type} eq 'DATETIME' ) {
                if ( $Filter->{Value} !~ /\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}/ ) {
                    return $Self->_Error(
                        Code    => 'PrepareData.InvalidFilter',
                        Message => "Invalid datetime value $Filter->{Value} in $Object.$Filter->{Field}!",
                    );
                }
                my ($DatePart, $TimePart) = split(/T/, $Filter->{Value});
                $TimePart =~ s/-/:/g;

                # convert Value to unixtime to later compares
                $Filter->{Value} = $Kernel::OM->Get('Kernel::System::Time')->TimeStamp2SystemTime(
                    String => $DatePart.' '.$TimePart,
                );
            }
        }
        
        # filter is ok
        $Self->{Filter} = $FilterDef;
    }

    return 1;
}

sub _ApplyFilter {
    my ( $Self, %Param ) = @_;

    if ( !IsHashRefWithData(\%Param) || !IsHashRefWithData($Param{Data}) ) {
        # nothing to do
        return;
    }    

    OBJECT:
    foreach my $Object ( keys %{$Self->{Filter}} ) {
        if ( ref($Param{Data}->{$Object}) eq 'ARRAY' ) {
            # filter each contained hash
            my @FilteredResult;
            
            OBJECTITEM:
            foreach my $ObjectItem ( @{$Param{Data}->{$Object}} ) {                
                if ( ref($ObjectItem) eq 'HASH' ) {
                    my $Match = 1;

                    FILTER:
                    foreach my $Filter ( @{$Self->{Filter}->{$Object}} ) {
                        my $FieldValue = $ObjectItem->{$Filter->{Field}};
                        my $FilterValue = $Filter->{Value};
                        my $Type = $Filter->{Type};

                        # check if the value references a field in our hash and take its value in this case
                        if ( $FilterValue =~ /^\$(.*?)$/ ) {
                            $FilterValue =  exists($ObjectItem->{$1}) ? $ObjectItem->{$1} : undef;
                        }

                        # prepare date compare
                        if ( $Type eq 'DATE' ) {
                            # convert values to unixtime
                            my ($DatePart, $TimePart) = split(/\s+/, $FieldValue);
                            $FieldValue = $Kernel::OM->Get('Kernel::System::Time')->TimeStamp2SystemTime(
                                String => $DatePart.' 12:00:00',
                            );
                            # handle this as a numeric compare
                            $Type = 'NUMERIC';
                        }
                        # prepare datetime compare
                        elsif ( $Type eq 'DATETIME' ) {
                            # convert values to unixtime
                            $FieldValue = $Kernel::OM->Get('Kernel::System::Time')->TimeStamp2SystemTime(
                                String => $FieldValue,
                            );
                            # handle this as a numeric compare
                            $Type = 'NUMERIC';
                        }

                        # equal (=)
                        if ( $Filter->{Operation} eq 'EQ' ) {
                            if ( $Type eq 'STRING' && $FieldValue ne $FilterValue ) {
                                $Match = 0;
                            }
                            elsif ( $Type eq 'NUMERIC' && $FieldValue != $FilterValue ) {
                                $Match = 0;
                            }                                
                        }
                        # not equal (!=)
                        elsif ( $Filter->{Operation} eq 'NE' ) {                        
                            if ( $Type eq 'STRING' && $FieldValue eq $FilterValue ) {
                                $Match = 0;
                            }
                            elsif ( $Type eq 'NUMERIC' && $FieldValue == $FilterValue ) {
                                $Match = 0;
                            }                                
                        }
                        # less than (<)
                        elsif ( $Filter->{Operation} eq 'LT' ) {                        
                            if ( $Type eq 'NUMERIC' && $FieldValue >= $FilterValue ) {
                                $Match = 0;
                            }                                
                        }
                        # greater than (>)
                        elsif ( $Filter->{Operation} eq 'GT' ) {                        
                            if ( $Type eq 'NUMERIC' && $FieldValue <= $FilterValue ) {
                                $Match = 0;
                            }                                
                        }
                        # less than or equal (<=)
                        elsif ( $Filter->{Operation} eq 'LTE' ) {                        
                            if ( $Type eq 'NUMERIC' && $FieldValue > $FilterValue ) {
                                $Match = 0;
                            }                                
                        }
                        # greater than or equal (>=)
                        elsif ( $Filter->{Operation} eq 'GTE' ) {                        
                            if ( $Type eq 'NUMERIC' && $FieldValue < $FilterValue ) {
                                $Match = 0;
                            }                                
                        }
                        # value is contained in an array or values
                        elsif ( $Filter->{Operation} eq 'IN' ) {
                            if ( !grep(/^$FieldValue$/g, @{$FilterValue}) ) {
                                $Match = 0;
                            }
                        }
                        # the string contains a part
                        elsif ( $Filter->{Operation} eq 'CONTAINS' ) {                        
                            if ( $Type eq 'STRING' && $FieldValue !~ /$FilterValue/ ) {
                                $Match = 0;
                            }
                        }
                        # the string starts with the part
                        elsif ( $Filter->{Operation} eq 'STARTSWITH' ) {                        
                            if ( $Type eq 'STRING' && $FieldValue !~ /^$FilterValue/ ) {
                                $Match = 0;
                            }
                        }
                        # the string ends with the part
                        elsif ( $Filter->{Operation} eq 'ENDSWITH' ) {                        
                            if ( $Type eq 'STRING' && $FieldValue !~ /$FilterValue$/ ) {
                                $Match = 0;
                            }
                        }

                        if ( $Filter->{Not} ) {
                            # negate match result
                            $Match = !$Match;
                        }

                        # abort filters for this object, if we have a non-match
                        last FILTER if !$Match;
                    }

                    # all filter criteria match, add to result
                    if ( $Match ) {
                        push @FilteredResult, $ObjectItem;
                    }
                }
            }
            $Param{Data}->{$Object} = \@FilteredResult;
        }
    } 

    return 1;
}

sub _ApplyFieldSelector {
    my ( $Self, %Param ) = @_;

    if ( !IsHashRefWithData(\%Param) || !IsHashRefWithData($Param{Data}) ) {
        # nothing to do
        return;
    }    

    foreach my $Object ( keys %{$Self->{Fields}} ) {
        if ( ref($Param{Data}->{$Object}) eq 'HASH' ) {
            # extract filtered fields from hash
            my %NewObject;
            foreach my $Field ( @{$Self->{Fields}->{$Object}} ) {
                $NewObject{$Field} = $Param{Data}->{$Object}->{$Field};
            }
            $Param{Data}->{$Object} = \%NewObject;
        }
        elsif ( ref($Param{Data}->{$Object}) eq 'ARRAY' ) {
            # filter keys in each contained hash
            foreach my $ObjectItem ( @{$Param{Data}->{$Object}} ) {
                if ( ref($ObjectItem) eq 'HASH' ) {
                    my %NewObjectItem;
                    foreach my $Field ( @{$Self->{Fields}->{$Object}} ) {
                        $NewObjectItem{$Field} = $ObjectItem->{$Field};
                    }
                    $ObjectItem = \%NewObjectItem;
                }
            }
        }
    } 

    return 1;
}

sub _ApplyOffset {
    my ( $Self, %Param ) = @_;

    if ( !IsHashRefWithData(\%Param) || !IsHashRefWithData($Param{Data}) ) {
        # nothing to do
        return;
    }    

    foreach my $Object ( keys %{$Self->{Offset}} ) {
        if ( $Object eq '__COMMON' ) {
            foreach my $DataObject ( keys %{$Param{Data}} ) {
                # ignore the object if we have a specific start index for it
                next if exists($Self->{Offset}->{$DataObject});

                if ( ref($Param{Data}->{$DataObject}) eq 'ARRAY' ) {
                    my @ResultArray = splice @{$Param{Data}->{$DataObject}}, $Self->{Offset}->{$Object};
                    $Param{Data}->{$DataObject} = \@ResultArray;
                }
            }
        }
        elsif ( ref($Param{Data}->{$Object}) eq 'ARRAY' ) {
            my @ResultArray = splice @{$Param{Data}->{$Object}}, $Self->{Offset}->{$Object};
            $Param{$Object} = \@ResultArray;
        }
    } 
}

sub _ApplyLimit {
    my ( $Self, %Param ) = @_;

    if ( !IsHashRefWithData(\%Param) || !IsHashRefWithData($Param{Data}) ) {
        # nothing to do
        return;
    }    

    foreach my $Object ( keys %{$Self->{Limit}} ) {
        if ( $Object eq '__COMMON' ) {
            foreach my $DataObject ( keys %{$Param{Data}} ) {
                # ignore the object if we have a specific limiter for it
                next if exists($Self->{Limit}->{$DataObject});

                if ( ref($Param{Data}->{$DataObject}) eq 'ARRAY' ) {
                    my @LimitedArray = splice @{$Param{Data}->{$DataObject}}, 0, $Self->{Limit}->{$Object};
                    $Param{Data}->{$DataObject} = \@LimitedArray;
                }
            }
        }
        elsif ( ref($Param{Data}->{$Object}) eq 'ARRAY' ) {
            my @LimitedArray = splice @{$Param{Data}->{$Object}}, 0, $Self->{Limit}->{$Object};
            $Param{$Object} = \@LimitedArray;
        }
    } 
}

sub _ApplySort {
    my ( $Self, %Param ) = @_;

    if ( !IsHashRefWithData(\%Param) || !IsHashRefWithData($Param{Data}) ) {
        # nothing to do
        return;
    }    

    foreach my $Object ( keys %{$Self->{Sort}} ) {
        if ( ref($Param{Data}->{$Object}) eq 'ARRAY' ) {
            # sort array by given criteria
            my @SortCriteria;
            my %SpecialSort;
            foreach my $Sort ( @{$Self->{Sort}->{$Object}} ) {
                my $SortField = $Sort->{Field};
                my $Type = $Sort->{Type};

                # special handling for DATE and DATETIME sorts
                if ( $Sort->{Type} eq 'DATE' ) {
                    # handle this as a numeric compare
                    $Type = 'NUMERIC';
                    $SortField = $SortField.'_DateSort';
                    $SpecialSort{'_DateSort'} = 1;

                    # convert field values to unixtime
                    foreach my $ObjectItem ( @{$Param{Data}->{$Object}} ) {
                        my ($DatePart, $TimePart) = split(/\s+/, $ObjectItem->{$Sort->{Field}});
                        $ObjectItem->{$SortField} = $Kernel::OM->Get('Kernel::System::Time')->TimeStamp2SystemTime(
                            String => $DatePart.' 12:00:00',
                        );
                    }
                }
                elsif ( $Sort->{Type} eq 'DATETIME' ) {
                    # handle this as a numeric compare
                    $Type = 'NUMERIC';
                    $SortField = $SortField.'_DateTimeSort';
                    $SpecialSort{'_DateTimeSort'} = 1;

                    # convert field values to unixtime
                    foreach my $ObjectItem ( @{$Param{Data}->{$Object}} ) {
                        $ObjectItem->{$SortField} = $Kernel::OM->Get('Kernel::System::Time')->TimeStamp2SystemTime(
                            String => $ObjectItem->{$Sort->{Field}},
                        );
                    }
                }

                push @SortCriteria, { 
                    order     => $Sort->{Direction}, 
                    compare   => lc($Type), 
                    sortkey   => $SortField,                    
                };
            }

            my @SortedArray = sorted_arrayref($Param{Data}->{$Object}, @SortCriteria);

            # remove special sort attributes
            if ( %SpecialSort ) {
                SPECIALSORTKEY:
                foreach my $SpecialSortKey ( keys %SpecialSort ) {
                    foreach my $ObjectItem ( @SortedArray ) {
                        last SPECIALSORTKEY if !IsHashRefWithData($ObjectItem);

                        my %NewObjectItem;
                        foreach my $ItemAttribute ( keys %{$ObjectItem}) {
                            if ( $ItemAttribute !~ /.*?$SpecialSortKey$/g ) {
                                $NewObjectItem{$ItemAttribute} = $ObjectItem->{$ItemAttribute};
                            }
                        }

                        $ObjectItem = \%NewObjectItem;                    
                    }
                }
            }

            $Param{Data}->{$Object} = \@SortedArray;
        }
    } 
}

sub _SetParameter {
    my ( $Self, %Param ) = @_;
    
    # check needed stuff
    for my $Needed (qw(Data Attribute)) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => '_SetParameter.MissingParameter',
                Message => "$Needed parameter is missing!",
            );
        }
    }
    
    my $Value;
    if ( exists($Param{Value}) ) {
        $Value = $Param{Value};
    };
    
    if ($Param{Attribute} =~ /::/) {
        my ($SubKey, $Rest) = split(/::/, $Param{Attribute});
        $Self->_SetParameter(
            Data      => $Param{Data}->{$SubKey},
            Attribute => $Rest,
            Value     => $Param{Value}
        );    
    }
    else {
        $Param{Data}->{$Param{Attribute}} = $Value;
    }
    
    return 1;
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
