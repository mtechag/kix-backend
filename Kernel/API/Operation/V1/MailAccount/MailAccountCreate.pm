# --
# Kernel/API/Operation/MailAccount/MailAccountCreate.pm - API MailAccount Create operation backend
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

package Kernel::API::Operation::V1::MailAccount::MailAccountCreate;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(IsArrayRefWithData IsHashRefWithData IsString IsStringWithData);

use base qw(
    Kernel::API::Operation::V1::Common
);

our $ObjectManagerDisabled = 1;

=head1 NAME

Kernel::API::Operation::V1::MailAccount::MailAccountCreate - API MailAccount MailAccountCreate Operation backend

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

=item Run()

perform MailAccountCreate Operation. This will return the created MailAccountID.

    my $Result = $OperationObject->Run(
        Data => {
            MailAccount  => {
                Login         => 'mail',
                Password      => 'SomePassword',
                Host          => 'pop3.example.com',
                Type          => 'POP3',
                IMAPFolder    => 'Some Folder',     # optional, only valid for IMAP-type accounts
                ValidID       => 1,
                Trusted       => 0,
                DispatchingBy => 'Queue',           # Queue|From
                Comment       => '...',             # optional
                QueueID       => 12,
            },
        },
    );

    $Result = {
        Success         => 1,                       # 0 or 1
        Code            => '',                      # 
        Message         => '',                      # in case of error
        Data            => {                        # result data payload after Operation
            MailAccountID  => '',                         # ID of the created MailAccount
        },
    };

=cut

sub Run {
    my ( $Self, %Param ) = @_;

    # init webMailAccount
    my $Result = $Self->Init(
        WebserviceID => $Self->{WebserviceID},
    );

    if ( !$Result->{Success} ) {
        $Self->_Error(
            Code    => 'WebService.InvalidConfiguration',
            Message => $Result->{Message},
        );
    }

    # prepare data
    $Result = $Self->PrepareData(
        Data       => $Param{Data},
        Parameters => {
            'MailAccount' => {
                Type     => 'HASH',
                Required => 1
            },
            'MailAccount::Password' => {
                Required => 1
            },
            'MailAccount::Host' => {
                Required => 1
            },
            'MailAccount::Type' => {
                Required => 1
            },                                                
        }
    );

    # check result
    if ( !$Result->{Success} ) {
        return $Self->_Error(
            Code    => 'Operation.PrepareDataError',
            Message => $Result->{Message},
        );
    }

    # isolate MailAccount parameter
    my $MailAccount = $Param{Data}->{MailAccount};

    # remove leading and trailing spaces
    for my $Attribute ( sort keys %{$MailAccount} ) {
        if ( ref $Attribute ne 'HASH' && ref $Attribute ne 'ARRAY' ) {

            #remove leading spaces
            $MailAccount->{$Attribute} =~ s{\A\s+}{};

            #remove trailing spaces
            $MailAccount->{$Attribute} =~ s{\s+\z}{};
        }
    }   
     	
    # check if MailAccount exists
    my %List = $Kernel::OM->Get('Kernel::System::MailAccount')->MailAccountList();

    foreach my $ID ( keys %List ) {                   
        my %MailAccountData = $Kernel::OM->Get('Kernel::System::MailAccount')->MailAccountGet(
            ID    => $ID,
        );

        if ( $MailAccountData{Login} eq $MailAccount->{Login} ) {
            return $Self->_Error(
                Code    => 'Object.AlreadyExists',
                Message => "Can not create MailAccount. MailAccount with same login '$MailAccount->{Login}' already exists.",
            );
        }
    }        

    # create MailAccount
    my $MailAccountID = $Kernel::OM->Get('Kernel::System::MailAccount')->MailAccountAdd(
        Login         => $MailAccount->{Login},
        Password      => $MailAccount->{Password},
        Host          => $MailAccount->{Host},
        Type          => $MailAccount->{Type},
        IMAPFolder    => $MailAccount->{IMAPFolder},
        ValidID       => $MailAccount->{ValidID} || 1,
        Trusted       => $MailAccount->{Trusted} || 0,
        DispatchingBy => $MailAccount->{DispatchingBy} || 'Queue',
        QueueID       => $MailAccount->{QueueID} || '',
        Comment       => $MailAccount->{Comment} || '',
        UserID   => $Self->{Authorization}->{UserID},              
    );

    if ( !$MailAccountID ) {
        return $Self->_Error(
            Code    => 'Object.UnableToCreate',
            Message => 'Could not create MailAccount, please contact the system administrator',
        );
    }
    
    # return result    
    return $Self->_Success(
        Code   => 'Object.Created',
        MailAccountID => $MailAccountID,
    );    
}


1;
