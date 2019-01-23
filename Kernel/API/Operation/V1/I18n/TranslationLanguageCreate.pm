# --
# Kernel/API/Operation/Translation/TranslationLanguageCreate.pm - API LanguageTranslation Create operation backend
# Copyright (C) 2006-2016 c.a.p.e. IT GmbH, http://www.cape-it.de
#
# written/edited by:
# * Rene(dot)Boehm(at)cape(dash)it(dot)de
# 
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::API::Operation::V1::I18n::TranslationLanguageCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsString IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::I18n::TranslationLanguageCreate - API Translation TranslationLanguage Create Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    my $Self = {};
    bless( $Self, $Type );

    # check needed objects
    for my $Needed (qw( DebuggerObject WebserviceID )) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => 'Operation.InternalError',
                Message => "Got no $Needed!"
            );
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    return $Self;
}

=item ParameterDefinition()

define parameter preparation and check for this operation

    my $Result = $OperationObject->ParameterDefinition(
        Data => {
            ...
        },
    );

    $Result = {
        ...
    };

=cut

sub ParameterDefinition {
    my ( $Self, %Param ) = @_;

    return {
        'TranslationID' => {
            Required => 1
        },
        'TranslationLanguage' => {
            Type     => 'HASH',
            Required => 1
        },
        'TranslationLanguage::Language' => {
            Required => 1
        },
        'TranslationLanguage::Value' => {
            Required => 1
        },
    }
}

=item Run()

perform TranslationLanguageCreate Operation. This will return success.

    my $Result = $OperationObject->Run(
        Data => {
            TranslationID      => 12,
            TranslationLanguage  => {
                Language => '...',
                Value    => '...'
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      # 
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            Language => '...'
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim Language parameter
    my $Language = $Self->_Trim(
        Data => $Param{Data}->{TranslationLanguage},
    );

    # check if pattern already exists
    my %PatternData = $Kernel::OM->Get('Kernel::System::Translation')->PatternGet(
        ID => $Param{Data}->{TranslationID},
    );
    if ( !%PatternData ) {
        return $Self->_Error(
            Code    => 'Object.NotFound',
            Message => "Cannot add language. No translation with ID '$Param{Data}->{TranslationID}' found.",
        );
    }

    # check if translation already exists for this pattern
    my %TranslationData = $Kernel::OM->Get('Kernel::System::Translation')->TranslationLanguageGet(
        PatternID => $Param{Data}->{TranslationID},
        Language  => $Language->{Language}
    );
    if ( %TranslationData ) {
        return $Self->_Error(
            Code    => 'Conflict',
            Message => "Cannot add language. Language already exists for this translation.",
        );
    }

    # add language
    my $Success = $Kernel::OM->Get('Kernel::System::Translation')->TranslationLanguageAdd(
        PatternID => $Param{Data}->{TranslationID},
        Language  => $Language->{Language},
        Value     => $Language->{Value},
        UserID    => $Self->{Authorization}->{UserID}
    );

    if ( !$Success ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not add language, please contact the system administrator',
        );
    }
    
    # return result    
    return $Self->_Success(
        Code     => 'Object.Created',
        Language => $Language->{Language}
    );    
}


1;
