# --
# Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::ITSMConfigItem::XML::Type::Attachment;

use strict;
use warnings;

use MIME::Base64;

our @ObjectDependencies = (
    'Kernel::System::ITSMConfigItem',
    'Kernel::System::Log'
);

=head1 NAME

Kernel::System::ITSMConfigItem::XML::Type::Attachment - xml backend module

=head1 SYNOPSIS

All xml functions of Attachment objects

=over 4

=cut

=item new()

create a object

    use Kernel::System::ObjectManager;
    local $Kernel::OM = Kernel::System::ObjectManager->new();
    my $BackendObject = $Kernel::OM->Get('Kernel::System::ITSMConfigItem::XML::Type::Attachment');

=cut

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {};
    bless( $Self, $Type );

    return $Self;
}

=item ValueLookup()

get the xml data of a version

    my $Value = $BackendObject->ValueLookup(
        Item => $ItemRef,
        Value => 1.1.1.1,
    );

=cut

sub ValueLookup {
    my ( $Self, %Param ) = @_;
    my $Value = '';

    # check needed stuff
    foreach (qw(Item)) {
        if ( !$Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "$Param{Item}->{Input}->{Type} :: Need $_!"
            );
            return;
        }
    }
    if ( ( defined $Param{Value} ) ) {
        my $retVal = $Param{Value};

        return $retVal;
    }

    return '';

}

=item InternalValuePrepare()

prepare "external" value to "internal"

    my $AttachmentDirID = $BackendObject->InternalValuePrepare(
        Value => {
            Filename    => '...',
            ContentType => '...'
            Content     => '...'            # base64 coded
        }
    );

=cut

sub InternalValuePrepare {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    foreach (qw(Filename ContentType Content)) {
        if ( !$Param{Value}->{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    my $Content = decode_base64($Param{Value}->{Content});

    # store the attachment in the default storage backend....
    my $AttDirID = $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->AttachmentStorageAdd(
        DataRef         => \$Content,
        Filename        => $Param{Value}->{Filename},
        UserID          => 1,
        Preferences     => {
            Datatype => $Param{Value}->{ContentType},
        }
    );

    return $AttDirID;
}

=item ExternalValuePrepare()

convert "internal" value to "external"

    my $Attachment = $BackendObject->ExternalValuePrepare(
        Value => 123
    );

=cut

sub ExternalValuePrepare {
    my ( $Self, %Param ) = @_;

    return if !defined $Param{Value};

    my $Attachment = $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->AttachmentStorageGet(
        ID => $Param{Value},
    );

    return {
        Filename    => $Attachment->{Filename},
        ContentType => $Attachment->{Preferences}->{Datatype},
        Content     => ${$Attachment->{ContentRef}},
    };
}

=item StatsAttributeCreate()

create a attribute array for the stats framework

    my $Attribute = $BackendObject->StatsAttributeCreate(
        Key => 'Key::Subkey',
        Name => 'Name',
        Item => $ItemRef,
    );

=cut

sub StatsAttributeCreate {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Argument (qw(Key Name Item)) {
        if ( !$Param{$Argument} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Argument!"
            );
            return;
        }
    }

    # create arrtibute
    my $Attribute = [
        {
            Name             => $Param{Name},
            UseAsXvalue      => 0,
            UseAsValueSeries => 0,
            UseAsRestriction => 0,
            Element          => $Param{Key},
            Block            => 'InputField',
        },
    ];

    return $Attribute;
}

=item ExportSearchValuePrepare()

prepare search value for export

    my $ArrayRef = $BackendObject->ExportSearchValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ExportSearchValuePrepare {
    my ( $Self, %Param ) = @_;

    return if !defined $Param{Value};
    return $Param{Value};
}

=item ExportValuePrepare()

prepare value for export

    my $Value = $BackendObject->ExportValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ExportValuePrepare {
    my ( $Self, %Param ) = @_;

    return if !defined $Param{Value};

    my $RetVal       = "";
    my $SizeNote     = "";
    my $RealFileSize = 0;
    my $MD5Note      = "";
    my $RealMD5Sum   = "";

    # get saved properties (attachment directory info)
    my %AttDirData = $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->AttachmentStorageGetDirectory(
        ID => $Param{Value},
    );

    if (
        $AttDirData{Preferences}->{FileSizeBytes}
        &&
        $AttDirData{Preferences}->{MD5Sum}
        )
    {

        my %RealProperties =
            $Kernel::OM->Get('Kernel::System::ITSMConfigItem')->AttachmentStorageGetRealProperties(
            %AttDirData,
            );

        $RetVal       = "(size " . $AttDirData{Preferences}->{FileSizeBytes} . ")";
        $RealMD5Sum   = $RealProperties{RealMD5Sum};
        $RealFileSize = $RealProperties{RealFileSize};

        if ( $RealFileSize != $AttDirData{Preferences}->{FileSizeBytes} ) {
            $SizeNote = " Invalid content - file size on disk has been changed";

            if ( $RealFileSize > ( 1024 * 1024 ) ) {
                $RealFileSize = sprintf "%.1f MBytes", ( $RealFileSize / ( 1024 * 1024 ) );
            }
            elsif ( $RealFileSize > 1024 ) {
                $RealFileSize = sprintf "%.1f KBytes", ( ( $RealFileSize / 1024 ) );
            }
            else {
                $RealFileSize = $RealFileSize . ' Bytes';
            }

            $RetVal = "(real size " . $RealFileSize . $SizeNote . ")";
        }
        elsif ( $RealMD5Sum ne $AttDirData{Preferences}->{MD5Sum} ) {
            $MD5Note = " Invalid md5sum - The file might have been changed.";
            $RetVal =~ s/\)/$MD5Note\)/g;
        }

    }
    $RetVal = $AttDirData{FileName};

    #return file information...
    return $RetVal;
}

=item ImportSearchValuePrepare()

prepare search value for import

    my $ArrayRef = $BackendObject->ImportSearchValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ImportSearchValuePrepare {
    my ( $Self, %Param ) = @_;

    return if !defined $Param{Value};

    # this attribute is not intended for import yet...
    $Param{Value} = "";

    return $Param{Value};
}

=item ImportValuePrepare()

prepare value for import

    my $Value = $BackendObject->ImportValuePrepare(
        Value => 11, # (optional)
    );

=cut

sub ImportValuePrepare {
    my ( $Self, %Param ) = @_;

    return if !defined $Param{Value};

    # this attribute is not intended for import yet...
    $Param{Value} = "";

    return $Param{Value};
}

=item ValidateValue()

validate given value for this particular attribute type

    my $Value = $BackendObject->ValidateValue(
        Value => {
            Filename    => '...'
            ContentType => '...'
            Content     => '...'
        }
    );

=cut

sub ValidateValue {
    my ( $Self, %Param ) = @_;

    my $Value = $Param{Value};

    my $Valid = $Value->{Filename} && $Value->{ContentType} && $Value->{Content};

    if (!$Valid) {
        return 'not a valid attachment'
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
