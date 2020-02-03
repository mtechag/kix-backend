# --
# Modified version of the work: Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-AGPL for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::DynamicField::Driver::CheckList;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

use base qw(Kernel::System::DynamicField::Driver::BaseText);

our @ObjectDependencies = (
    'Kernel::Config',
    'Kernel::System::DynamicFieldValue',
    'Kernel::System::Main',
);

=head1 NAME

Kernel::System::DynamicField::Driver::CheckList

=head1 SYNOPSIS

DynamicFields CheckList Driver delegate

=head1 PUBLIC INTERFACE

This module implements the public interface of L<Kernel::System::DynamicField::Backend>.
Please look there for a detailed reference of the functions.

=over 4

=item new()

usually, you want to create an instance of this
by using Kernel::System::DynamicField::Backend->new();

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    # set the maximum length for the text-area fields to still be a searchable field in some
    # databases
    $Self->{MaxLength} = 3800;

    # set field behaviors
    $Self->{Behaviors} = {
        'IsACLReducible'               => 0,
        'IsNotificationEventCondition' => 0,
        'IsSortable'                   => 0,
        'IsFiltrable'                  => 0,
        'IsStatsCondition'             => 1,
        'IsCustomerInterfaceCapable'   => 1,
    };

    # get the Dynamic Field Backend custom extensions
    my $DynamicFieldDriverExtensions
        = $Kernel::OM->Get('Kernel::Config')->Get('DynamicFields::Extension::Driver::CheckList');

    EXTENSION:
    for my $ExtensionKey ( sort keys %{$DynamicFieldDriverExtensions} ) {

        # skip invalid extensions
        next EXTENSION if !IsHashRefWithData( $DynamicFieldDriverExtensions->{$ExtensionKey} );

        # create a extension config shortcut
        my $Extension = $DynamicFieldDriverExtensions->{$ExtensionKey};

        # check if extension has a new module
        if ( $Extension->{Module} ) {

            # check if module can be loaded
            if (
                !$Kernel::OM->Get('Kernel::System::Main')->RequireBaseClass( $Extension->{Module} )
                )
            {
                die "Can't load dynamic fields backend module"
                    . " $Extension->{Module}! $@";
            }
        }

        # check if extension contains more behaviors
        if ( IsHashRefWithData( $Extension->{Behaviors} ) ) {

            %{ $Self->{Behaviors} } = (
                %{ $Self->{Behaviors} },
                %{ $Extension->{Behaviors} }
            );
        }
    }

    return $Self;
}

sub DisplayValueRender {
    my ( $Self, %Param ) = @_;

    # set HTMLOutput as default if not specified
    if ( !defined $Param{HTMLOutput} ) {
        $Param{HTMLOutput} = 1;
    }

    my $LineBreak = "\n";
    if ($Param{HTMLOutput}) {
        $LineBreak = "<br />";
    }

    # set Value and Title variables
    my $Value = $Param{DynamicFieldConfig}->{Label} . $LineBreak;
    my $Title = '';

    # check value
    my @Values;
    if ( ref $Param{Value} eq 'ARRAY' ) {
        @Values = @{ $Param{Value} };
    }
    else {
        @Values = ( $Param{Value} );
    }

    for my $ChecklistItemString ( @Values) {
        next if !$ChecklistItemString;

        my $ChecklistItems = $Kernel::OM->Get('Kernel::System::JSON')->Decode(
            Data => $ChecklistItemString,
        );
        my $Items = $Self->_GetChecklistRows(Items => $ChecklistItems);

        if (IsArrayRefWithData($Items)) {
            for my $Item (@{$Items}) {
                $Value .= "- $Item->{Title}: $Item->{Value}$LineBreak";
            }
        }
        $Value .= $LineBreak;
    }

    # create return structure
    my $Data = {
        Value => $Value,
        Title => $Title
    };

    return $Data;
}

sub HTMLDisplayValueRender {
    my ( $Self, %Param ) = @_;

    # set Value and Title variables
    my $Value = '<h3>' . $Param{DynamicFieldConfig}->{Label} . '</h3>';
    my $Title = '';

    # check value
    my @Values;
    if ( ref $Param{Value} eq 'ARRAY' ) {
        @Values = @{ $Param{Value} };
    }
    else {
        @Values = ( $Param{Value} );
    }

    for my $ChecklistItemString ( @Values) {
        next if !$ChecklistItemString;

        my $ChecklistItems = $Kernel::OM->Get('Kernel::System::JSON')->Decode(
            Data => $ChecklistItemString,
        );
        my $Items = $Self->_GetChecklistRows(Items => $ChecklistItems);

        if (IsArrayRefWithData($Items)) {
            $Value .= '<table style="border:none; width:90%">'
                . '<thead><tr>'
                    . '<th style="padding:10px 15px;">Action</th>'
                    . '<th style="padding:10px 15px;">State</th>'
                . '<tr></thead>'
                . '<tbody>';

            for my $Item (@{$Items}) {
                $Value .= '<tr>'
                    . '<td style="padding:10px 15px;">' . $Item->{Title} . '</td>'
                    . '<td style="padding:10px 15px;">' . $Item->{Value} . '</td>'
                    . '</tr>';
            }

            $Value .= '</tbody></table>';
        }
    }

    # create return structure
    my $Data = {
        Value => $Value,
        Title => $Title
    };

    return $Data;
}

sub ShortDisplayValueRender {
    my ( $Self, %Param ) = @_;

    # set Value and Title variables
    my $Value = '';
    my $Title = '';

    # check value
    my @Values;
    if ( ref $Param{Value} eq 'ARRAY' ) {
        @Values = @{ $Param{Value} };
    }
    else {
        @Values = ( $Param{Value} );
    }

    for my $ChecklistItemString ( @Values) {
        next if !$ChecklistItemString;

        my $ChecklistItems = $Kernel::OM->Get('Kernel::System::JSON')->Decode(
            Data => $ChecklistItemString,
        );

        my $Items = $Self->_GetChecklistRows(Items => $ChecklistItems);

        if (IsArrayRefWithData($Items)) {
            my $Done = 0;
            my $All = 0;
            for my $Item ( @{ $Items } ) {
                if ($Item && $Item->{IsCheckList}) {
                    $All++;
                    if ($Item->{Value} eq 'OK' || $Item->{Value} eq 'NOK' || $Item->{Value} eq 'n.a.') {
                        $Done++;
                    }
                }
            }
            $Value .= ($Value ? ', ' : '') . "$Done/$All";
        }
    }

    # create return structure
    my $Data = {
        Value => $Value,
        Title => $Title
    };

    return $Data;
}

sub _GetChecklistRows {
    my ( $Self, %Param ) = @_;

    my @Rows;

    if ( IsArrayRefWithData($Param{Items}) ) {
        for my $Item ( @{ $Param{Items} } ) {
            if (IsHashRefWithData($Item)) {
                push(
                    @Rows,
                    {
                        Title       => $Item->{title} || '',
                        Value       => $Item->{value} || '',
                        IsCheckList => $Item->{input} eq 'ChecklistState' ? 1 : 0
                    }
                );

                if ( IsArrayRefWithData($Item->{sub}) ) {
                    my $SubRows = $Self->_GetChecklistRows(Items => $Item->{sub});
                    push(@Rows, @{$SubRows});
                }
            }
        }
    }

    return \@Rows;
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
