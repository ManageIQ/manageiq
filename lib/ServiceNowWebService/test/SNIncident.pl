#!/usr/bin/perl
#!/usr/bin/perl -w
#use SOAP::Lite ( +trace => all, maptype => {} );
use SOAP::Lite;
use XML::Writer;
use XML::Writer::String;

#
# Get parameters passed by EVM Provision notification
#
$MIQMSG{id}                = $ARGV[0];
$MIQMSG{category}          = $ARGV[1];
$MIQMSG{notify}            = $ARGV[2];
$MIQMSG{severity}          = $ARGV[3];
$MIQMSG{short_description} = $ARGV[4];
$MIQMSG{description}       = $ARGV[5];

sub SOAP::Transport::HTTP::Client::get_basic_credentials {
   return 'itil' => 'itil';
}

my $soap = SOAP::Lite
    -> proxy('https://manageiqdev.service-now.com/ecc_queue.do?SOAP');

my $method = SOAP::Data->name('insert')
    ->attr({xmlns => 'http://www.service-now.com/'});

my @name = 'Catalog Request ' . $MIQMSG{category} . ' Item: ' . $MIQMSG{notify};
# get all incidents with category Network
my @params = ( SOAP::Data->name(agent => 'Rich') );
push(@params,  SOAP::Data->name(queue  => 'input') );
push(@params,  SOAP::Data->name(topic  => 'Open Incident') );
push(@params,  SOAP::Data->name(name   => 'admin') );
push(@params,  SOAP::Data->name(source => '70.91.104.157') );

my $s = XML::Writer::String->new();
my $writer = new XML::Writer(OUTPUT => $s);

#$writer->xmlDecl();
$writer->startTag('notification');

write_element('id');
write_element('category');
write_element('notify');
write_element('severity');
write_element('short_description');
write_element('description');
$writer->endTag('notification');

$writer->end;

sub write_element {
    my $label = shift;
    my $value = $MIQMSG{$label};
    $writer->startTag($label);
    if($value) {
        $writer->characters($value);
    }
    $writer->endTag($label);
}

push(@params, SOAP::Data->name(payload => $s->value()) );

print $soap->call($method => @params)->result;
