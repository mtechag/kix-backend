use warnings;

use Cwd;
use lib cwd();
use lib cwd() . '/Kernel/cpan-lib';
use lib cwd() . '/plugins';
use lib cwd() . '/scripts/test/api/Cucumber';

use LWP::UserAgent;
use HTTP::Request;
use JSON::XS qw(encode_json decode_json);
use JSON::Validator;

use Test::More;
use Test::BDD::Cucumber::StepFile;

use Data::Dumper;

use Kernel::System::ObjectManager;

$Kernel::OM = Kernel::System::ObjectManager->new();

# require our helper
require '_Helper.pl';

# require our common library
require '_StepsLib.pl';

# feature specific steps 

When qr/I delete this addressbook$/, sub {
   ( S->{Response}, S->{ResponseContent} ) = _Delete(
      Token => S->{Token},
      URL   => S->{API_URL}.'/addressbook/'.S->{AddressID},
   );
};

When qr/delete all this addressbooks$/, sub {
    for ($i=0;$i<@{S->{AddressIDArray}};$i++){ 
        ( S->{Response}, S->{ResponseContent} ) = _Delete(
            Token => S->{Token},
            URL   => S->{API_URL}.'/addressbook/'.S->{AddressIDArray}->[$i],
        );
    }

    S->{AddressIDArray} = ();

};



	