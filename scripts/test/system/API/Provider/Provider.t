# --
# Copyright (C) 2006-2020 c.a.p.e. IT GmbH, https://www.cape-it.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE-GPL3 for license information (GPL3). If you
# did not receive this file, see https://www.gnu.org/licenses/gpl-3.0.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get config object
my $ConfigObject = $Kernel::OM->Get('Config');

# get helper object
# skip SSL certificate verification
$Kernel::OM->ObjectParamAdd(
    'UnitTest::Helper' => {
        SkipSSLVerify => 1,
    },
);
my $Helper = $Kernel::OM->Get('UnitTest::Helper');

my $RandomID = $Helper->GetRandomID();

my @Tests = (
    {
        Name             => 'HTTP request',
        WebserviceConfig => {
            Debugger => {
                DebugThreshold => 'debug',
            },
            Provider => {
                Transport => {
                    Type   => 'HTTP::Test',
                    Config => {
                        Fail => 0,
                    },
                },
                Operation => {
                    test_operation => {
                        Type           => 'Test::Test',
                        MappingInbound => {
                            Type   => 'Test',
                            Config => {
                                TestOption => 'ToUpper',
                                }
                        },
                        MappingOutbound => {
                            Type => 'Test',
                        },
                    },
                },
            },
        },
        RequestData => {
            A => 'A',
            b => 'b',
        },
        ResponseData => {
            A => 'A',
            b => 'B',
        },
        ResponseSuccess => 1,
    },
    {
        Name             => 'HTTP request umlaut',
        WebserviceConfig => {
            Debugger => {
                DebugThreshold => 'debug',
            },
            Provider => {
                Transport => {
                    Type   => 'HTTP::Test',
                    Config => {
                        Fail => 0,
                    },
                },
                Operation => {
                    test_operation => {
                        Type           => 'Test::Test',
                        MappingInbound => {
                            Type => 'Test',
                        },
                    },
                },
            },
        },
        RequestData => {
            A => 'A',
            b => 'ö',
        },
        ResponseData => {
            A => 'A',
            b => 'ö',
        },
        ResponseSuccess => 1,
    },
    {
        Name             => 'HTTP request Unicode',
        WebserviceConfig => {
            Debugger => {
                DebugThreshold => 'debug',
            },
            Provider => {
                Transport => {
                    Type   => 'HTTP::Test',
                    Config => {
                        Fail => 0,
                    },
                },
                Operation => {
                    test_operation => {
                        Type           => 'Test::Test',
                        MappingInbound => {
                            Type => 'Test',
                        },
                    },
                },
            },
        },
        RequestData => {
            A => 'A',
            b => '使用下列语言',
            c => 'Языковые',
            d => 'd',
        },
        ResponseData => {
            A => 'A',
            b => '使用下列语言',
            c => 'Языковые',
            d => 'd',
        },
        ResponseSuccess => 1,
    },
    {
        Name             => 'HTTP request without data',
        WebserviceConfig => {
            Debugger => {
                DebugThreshold => 'debug',
            },
            Provider => {
                Transport => {
                    Type   => 'HTTP::Test',
                    Config => {
                        Fail => 0,
                    },
                },
                Operation => {
                    test_operation => {
                        Type           => 'Test::Test',
                        MappingInbound => {
                            Type => 'Test',
                        },
                        MappingOutbound => {
                            Type => 'Test',
                        },
                    },
                },
            },
        },
        RequestData     => {},
        ResponseData    => {},
        ResponseSuccess => 0,
    },
);

my $CreateQueryString = sub {
    my ( $Self, %Param ) = @_;

    my $QueryString;

    for my $Key ( sort keys %{ $Param{Data} || {} } ) {
        $QueryString .= '&' if ($QueryString);
        $QueryString .= $Param{Encode} ? URI::Escape::uri_escape_utf8($Key) : $Key;
        if ( $Param{Data}->{$Key} ) {
            $QueryString
                .= "="
                . (
                $Param{Encode}
                ? URI::Escape::uri_escape_utf8( $Param{Data}->{$Key} )
                : $Param{Data}->{$Key}
                );
        }
    }

    $Kernel::OM->Get('Encode')->EncodeOutput( \$QueryString );
    return $QueryString;
};

# get remote host with some precautions for certain unit test systems
my $Host = $Helper->GetTestHTTPHostname();

# create URL
my $ScriptAlias   = $ConfigObject->Get('ScriptAlias');
my $ApacheBaseURL = "http://$Host/${ScriptAlias}/nph-API.pl/";
my $PlackBaseURL;
if ( $ConfigObject->Get('UnitTestPlackServerPort') ) {
    $PlackBaseURL = "http://localhost:"
        . $ConfigObject->Get('UnitTestPlackServerPort')
        . '/nph-API.pl/';
}

# get objects
my $WebserviceObject = $Kernel::OM->Get('API::Webservice');
my $ProviderObject   = $Kernel::OM->Get('API::Provider');

for my $Test (@Tests) {

    # add config
    my $WebserviceID = $WebserviceObject->WebserviceAdd(
        Config  => $Test->{WebserviceConfig},
        Name    => "$Test->{Name} $RandomID",
        ValidID => 1,
        UserID  => 1,
    );

    $Self->True(
        $WebserviceID,
        "$Test->{Name} WebserviceAdd()",
    );

    my $WebserviceNameEncoded = URI::Escape::uri_escape_utf8("$Test->{Name} $RandomID");

    #
    # Test with IO redirection, no real HTTP request
    #
    for my $RequestMethod (qw(get post)) {

        for my $WebserviceAccess (
            "WebserviceID/$WebserviceID",
            "Webservice/$WebserviceNameEncoded"
            )
        {

            my $RequestData  = '';
            my $ResponseData = '';

            {
                local %ENV;

                if ( $RequestMethod eq 'post' ) {

                    # prepare CGI environment variables
                    $ENV{REQUEST_URI}    = "http://localhost/otrs/nph-API.pl/$WebserviceAccess";
                    $ENV{REQUEST_METHOD} = 'POST';
                    $RequestData         = $CreateQueryString->(
                        $Self,
                        Data   => $Test->{RequestData},
                        Encode => 0,
                    );
                    use bytes;
                    $ENV{CONTENT_LENGTH} = length($RequestData);
                }
                else {    # GET

                    # prepare CGI environment variables
                    $ENV{REQUEST_URI} = "http://localhost/otrs/nph-API.pl/$WebserviceAccess?"
                        . $CreateQueryString->(
                        $Self,
                        Data   => $Test->{RequestData},
                        Encode => 1,
                        );
                    $ENV{QUERY_STRING} = $CreateQueryString->(
                        $Self,
                        Data   => $Test->{RequestData},
                        Encode => 1,
                    );
                    $ENV{REQUEST_METHOD} = 'GET';
                }

                $ENV{CONTENT_TYPE} = 'application/x-www-form-urlencoded; charset=utf-8;';

                # redirect STDIN from String so that the transport layer will use this data
                local *STDIN;
                open STDIN, '<:utf8', \$RequestData;    ## no critic

                # redirect STDOUT from String so that the transport layer will write there
                local *STDOUT;
                open STDOUT, '>:utf8', \$ResponseData;    ## no critic

                # reset CGI object from previous runs
                CGI::initialize_globals();
                $Kernel::OM->ObjectsDiscard( Objects => ['WebRequest'] );

                $ProviderObject->Run();
            }

            if ( $Test->{ResponseSuccess} ) {

                for my $Key ( sort keys %{ $Test->{ResponseData} || {} } ) {
                    my $QueryStringPart = URI::Escape::uri_escape_utf8($Key);
                    if ( $Test->{ResponseData}->{$Key} ) {
                        $QueryStringPart
                            .= '=' . URI::Escape::uri_escape_utf8( $Test->{ResponseData}->{$Key} );
                    }

                    $Self->True(
                        index( $ResponseData, $QueryStringPart ) > -1,
                        "$Test->{Name} $WebserviceAccess Run() HTTP $RequestMethod result data contains $QueryStringPart",
                    );
                }

                $Self->True(
                    index( $ResponseData, 'HTTP/1.0 200 OK' ) > -1,
                    "$Test->{Name} $WebserviceAccess Run() HTTP $RequestMethod result success status",
                );
            }
            else {

                # If an early error occurred, GI cannot generate a valid HTTP error response yet,
                #   because the transport object was not yet initialized. In these cases, apache will
                #   generate this response, but here we do not use apache.
                if ( !$Test->{EarlyError} ) {
                    $Self->True(
                        index( $ResponseData, 'HTTP/1.0 500 ' ) > -1,
                        "$Test->{Name} $WebserviceAccess Run() HTTP $RequestMethod result error status",
                    );
                }
            }
        }
    }

    #
    # Test real HTTP request
    #
    for my $RequestMethod (qw(get post)) {

        my @BaseURLs = ($ApacheBaseURL);
        if ($PlackBaseURL) {
            push @BaseURLs, $PlackBaseURL;
        }

        for my $BaseURL (@BaseURLs) {

            for my $WebserviceAccess (
                "WebserviceID/$WebserviceID",
                "Webservice/$WebserviceNameEncoded"
                )
            {

                my $URL = $BaseURL . $WebserviceAccess;
                my $Response;
                my $ResponseData;
                my $QueryString = $CreateQueryString->(
                    $Self,
                    Data   => $Test->{RequestData},
                    Encode => 1,
                );

                if ( $RequestMethod eq 'get' ) {
                    $URL .= "?$QueryString";
                    $Response = LWP::UserAgent->new()->$RequestMethod($URL);
                }
                else {    # POST
                    $Response = LWP::UserAgent->new()->$RequestMethod( $URL, Content => $QueryString );
                }
                chomp( $ResponseData = $Response->decoded_content() );

                if ( $Test->{ResponseSuccess} ) {
                    for my $Key ( sort keys %{ $Test->{ResponseData} || {} } ) {
                        my $QueryStringPart = URI::Escape::uri_escape_utf8($Key);
                        if ( $Test->{ResponseData}->{$Key} ) {
                            $QueryStringPart
                                .= '='
                                . URI::Escape::uri_escape_utf8( $Test->{ResponseData}->{$Key} );
                        }

                        $Self->True(
                            index( $ResponseData, $QueryStringPart ) > -1,
                            "$Test->{Name} $WebserviceAccess real HTTP $RequestMethod request (needs configured and running webserver) result data contains $QueryStringPart ($URL)",
                        );
                    }

                    $Self->Is(
                        $Response->code(),
                        200,
                        "$Test->{Name} $WebserviceAccess real HTTP $RequestMethod request (needs configured and running webserver) result success status ($URL)",
                    );
                }
                else {
                    $Self->Is(
                        $Response->code(),
                        500,
                        "$Test->{Name} $WebserviceAccess real HTTP $RequestMethod request (needs configured and running webserver) result error status ($URL)",
                    );
                }
            }
        }
    }

    # delete webservice
    my $Success = $WebserviceObject->WebserviceDelete(
        ID     => $WebserviceID,
        UserID => 1,
    );

    $Self->True(
        $Success,
        "$Test->{Name} WebserviceDelete()",
    );
}

#
# Test non existing webservice
#
for my $RequestMethod (qw(get post)) {

    my $URL = $ApacheBaseURL . 'undefined';
    my $ResponseData;

    my $Response = LWP::UserAgent->new()->$RequestMethod($URL);
    chomp( $ResponseData = $Response->decoded_content() );

    $Self->Is(
        $Response->code(),
        500,
        "Non existing Webservice real HTTP $RequestMethod request result error status ($URL)",
    );
}

# cleanup cache
$Kernel::OM->Get('Cache')->CleanUp();

1;



=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE-GPL3 for license information (GPL3). If you did not receive this file, see

<https://www.gnu.org/licenses/gpl-3.0.txt>.

=cut
