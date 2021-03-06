# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

package Kernel::API::Operation::V1::TicketTemplate::TicketTemplateSearch;

use strict;
use warnings;

use MIME::Base64;

use Kernel::System::VariableCheck qw(:all);

use base qw(
    Kernel::API::Operation::V1::Ticket::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

 Kernel::API::Operation::V1::TicketTemplate::TicketTemplateSearch - API Ticket Template Get Operation backend

=head1 SYNOPSIS

=head1 PUBLIC INTERFACE

=over 4

=cut

=item new()

usually, you want to create an instance of this
by using Kernel::API::Operation::V1->new();

=cut

sub new {
    my ($Type, %Param) = @_;

    my $Self = {};
    bless($Self, $Type);

    # check needed objects
    for my $Needed (qw(DebuggerObject WebserviceID)) {
        if (!$Param{$Needed}) {
            return {
                Success      => 0,
                ErrorMessage => "Got no $Needed!",
            };
        }

        $Self->{$Needed} = $Param{$Needed};
    }
    # get config for this screen
    # $Self->{Config} = $Kernel::OM->Get('Config')->Get('API::Operation::V1::TicketTemplate::TicketTemplateSearch');

    return $Self;
}

=item Run()

perform TicketTemplateSearch Operation. This function is able to return
one or more ticket templates in one call.

    my $Result = $OperationObject->Run(
        Data => { },
    );

    $Result = { }

=cut

sub Run {
    my ($Self, %Param) = @_;

    my @TicketTemplateList = $Kernel::OM->Get('TicketTemplate')->TicketTemplateList();

    # get already prepared template data from TicketTemplateGet operation
    if ( IsArrayRefWithData(\@TicketTemplateList) ) {

        my $TicketTemplateGetResult = $Self->ExecOperation(
            OperationType            => 'V1::TicketTemplate::TicketTemplateGet',
            SuppressPermissionErrors => 1,
            Data      => {
                TemplateName => join(',', map { $_->{TemplateID} } @TicketTemplateList),
            }
        );
 
        if ( !IsHashRefWithData($TicketTemplateGetResult) || !$TicketTemplateGetResult->{Success} ) {
            return $TicketTemplateGetResult;
        }

        my @ResultList = IsArrayRef($TicketTemplateGetResult->{Data}->{TicketTemplate}) ? @{$TicketTemplateGetResult->{Data}->{TicketTemplate}} : ( $TicketTemplateGetResult->{Data}->{TicketTemplate} );

        if ( IsArrayRefWithData(\@ResultList) ) {
            return $Self->_Success(
                TicketTemplate => \@ResultList,
            )
        }
    }

    # return result
    return $Self->_Success(
        TicketTemplate => [],
    );
}


