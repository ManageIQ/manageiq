$:.push("#{File.dirname(__FILE__)}/../../MiqVm")

require 'rubygems'
require 'log4r'
require 'optparse'
require 'MiqLocalVm'

cmdName = File.basename($0)

LOG_LEVELS	= {
	"DEBUG"	=> Log4r::DEBUG,
	"INFO"	=> Log4r::INFO,
	"WARN"	=> Log4r::WARN,
	"ERROR"	=> Log4r::ERROR,
	"FATAL"	=> Log4r::FATAL
}

logLevel	= Log4r::INFO										# default log level
categories	= ["accounts", "services", "software", "system"]	# all categories by default

#
# Process command line args.
#
OptionParser.new do |opts|
	opts.banner = "Usage: #{cmdName} [options] categories"
	
	opts.on('-l', '--loglevel ARG')	do |ll|
		raise OptionParser::ParseError.new("Unrecognized log level: #{ll}") if !(/DEBUG|INFO|WARN|ERROR|FATAL/i =~ ll)
		logLevel = LOG_LEVELS[ll.upcase]
	end
	opts.on('-e', '--extractor-id ARG')	do |eid|
		$extractor_id = eid
	end

	begin
		cats = opts.parse!(ARGV)
		categories = cats if !cats.empty?
	rescue OptionParser::ParseError => perror
		$stderr.puts cmdName + ": " + perror.to_s
		$stderr.puts
		$stderr.puts opts.to_s
		exit 1
	end
end

class ConsoleFormatter < Log4r::Formatter
	@@prog = File.basename(__FILE__, ".*")
	def format(event)
		"#{Log4r::LNAMES[event.level]} [#{datetime}" +
		($extractor_id.nil? ? "" : " #{$extractor_id}") +
		"] -- #{@@prog}: " +
		(event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
	end
	
	private
	
	def datetime
		time = Time.now.utc
		time.strftime("%Y-%m-%dT%H:%M:%S.") << "%06d" % time.usec
	end
end

toplog = Log4r::Logger.new 'toplog'
Log4r::StderrOutputter.new('err_console', :formatter=>ConsoleFormatter)
toplog.add 'err_console'
$log = toplog if $log.nil?
$log.level = logLevel

vm = nil

begin
	vm = MiqLocalVm.new

	categories.each do |cat|
		xml = vm.extract(cat)
		puts "----- MIQ START -----: #{cat}"
		xml.to_xml.write($stdout, 4)
		puts
		puts "----- MIQ END -----: #{cat}"
	end
ensure
	vm.unmount if vm
end
