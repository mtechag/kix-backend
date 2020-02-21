# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::ImportExport::TemplateRunCreate;

use strict;
use warnings;

use MIME::Base64;
use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::ImportExport::TemplateRunCreate - API ImportExport Template Run Create Operation backend

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
    for my $Needed (qw(DebuggerObject WebserviceID)) {
        if ( !$Param{$Needed} ) {
            return $Self->_Error(
                Code    => 'Operation.InternalError',
                Message => "Got no $Needed!"
            );
        }

        $Self->{$Needed} = $Param{$Needed};
    }

    # get config for this screen
    $Self->{Config} = $Kernel::OM->Get('Kernel::Config')->Get('API::Operation::V1::ImportExport::TemplateRunCreate');

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
        'TemplateID' => {
            Required => 1
        },
        'ImportExportTemplateRun' => {
            Type => 'HASH',
            Required => 1
        },
        'ImportExportTemplateRun::Type' => {
            Type => 'STRING',
            Required => 1
        }
    }
}

=item Run()

perform TemplateRunCreate Operation. This function will return the ID of the scheduler task ID.

    my $Result = $OperationObject->Run(
        Data => {
            TemplateID => 123,
            ImportExportTemplateRun  => {
                Type               => 'import',            the type ('import'|'export')
                ImportFileContent  => 'file-content'       # (optional) - required if Type is 'import', base64 encoded file content
            }
        },
    );

    $Result = {
        Success      => 1,                       # 0 or 1
        Code         => '',                      # in case of an error
        Message      => '',                      # in case of an error
        Data         => {
            TaskID        => 123                # ID of the scheduler task             - with type 'import',
            ExportContent => 'some csv string'  # base64 encoded string of the export  - with type 'export'
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # isolate and trim TemplateRun parameter
    my $TemplateRun = $Self->_Trim(
        Data => $Param{Data}->{ImportExportTemplateRun}
    );

    # check if Template exists
    my $TemplateDataRef = $Kernel::OM->Get('Kernel::System::ImportExport')->TemplateGet(
        TemplateID => $Param{Data}->{TemplateID},
        UserID     => $Self->{Authorization}->{UserID},
    );

    if ( !IsHashRefWithData( $TemplateDataRef ) ) {
        return $Self->_Error(
            Code => 'Object.NotFound',
        );
    }

    if ( $TemplateRun->{Type} =~ m/^import$/i ) {
        my $TaskID;

        if (!$TemplateRun->{ImportFileContent}) {
            return $Self->_Error(
                Code    => 'Object.ExecFailed',
                Message => "No value for ImportFileContent given!",
            );
        }

        $TaskID = $Kernel::OM->Get('Kernel::System::ImportExport')->ImportTaskCreate(
            TemplateID    => $Param{Data}->{TemplateID},
            SourceContent => $TemplateRun->{ImportFileContent},
            UserID        => $Self->{Authorization}->{UserID}
        );

        if ( !$TaskID ) {
            my $LogMessage = $Kernel::OM->Get('Kernel::System::Log')->GetLogEntry(
                Type => 'error', 
                What => 'Message',
            );
            return $Self->_Error(
                Code    => 'Object.ExecFailed',
                Message => "An error occured during import execution task creation (error: $LogMessage)",
            );
        }

        # return result
        return $Self->_Success(
            Code   => 'Object.Created',
            TaskID => $TaskID
        );
    }

    elsif ( $TemplateRun->{Type} =~ m/^export$/i ) {
        my $Result = $Kernel::OM->Get('Kernel::System::ImportExport')->Export(
            TemplateID => $Param{Data}->{TemplateID},
            UserID     => 1,
        );

        if ( !$Result ) {
            my $LogMessage = $Kernel::OM->Get('Kernel::System::Log')->GetLogEntry(
                Type => 'error', 
                What => 'Message',
            );
            return $Self->_Error(
                Code    => 'Object.ExecFailed',
                Message => "An error occured during export execution (error: $LogMessage).",
            );
        }

        my $FileContent = join("\n", @{ $Result->{DestinationContent} });

        if (utf8::is_utf8($FileContent)) {
            $FileContent = Encode::encode_utf8($FileContent);
        }

        $FileContent = encode_base64( $FileContent );

        # return result
        return $Self->_Success(
            Code   => 'Object.Created',
            ExportContent => $FileContent
        );
    } else {
        return $Self->_Error(
            Code    => 'Object.ExecFailed',
            Message => "Type has to be 'import' or 'export'.",
        );
    }
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
