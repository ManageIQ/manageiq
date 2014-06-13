$:.push(File.dirname(__FILE__))

require 'rubygems'
require 'log4r'
require 'log4r/configurator'

#
# We must do this before anything accesses log4r.
#
module Log4r
	Configurator.custom_levels(:DEBUG, :INFO, :WARN, :ERROR, :FATAL, :COPY)
end

require 'Ec2Extractor'

class LogFormatter < Log4r::Formatter
	@@prog = File.basename(__FILE__, ".*")
	def format(event)
		"#{Log4r::LNAMES[event.level]} [#{datetime}] -- #{@@prog}: " +
		(event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
	end
	
	private
	
	def datetime
		time = Time.now.utc
		time.strftime("%Y-%m-%dT%H:%M:%S.") << "%06d" % time.usec
	end
end

class CopyFormatter < Log4r::Formatter
	def format(event)
		event.data.chomp + "\n"
	end
end

logFile	= File.join(Dir.tmpdir, "miq.log")
lfIo = File.new(logFile, "w+")

$log = Log4r::Logger.new 'toplog'
$log.level = Log4r::INFO

lfo = Log4r::IOOutputter.new('log_file', lfIo, :formatter=>LogFormatter)
lfo.only_at(Log4r::DEBUG, Log4r::INFO, Log4r::WARN, Log4r::ERROR, Log4r::FATAL)
$log.add 'log_file'

lco = Log4r::IOOutputter.new('log_copy', lfIo, :formatter=>CopyFormatter)
lco.only_at(Log4r::COPY)
$log.add 'log_copy'

eso = Log4r::StderrOutputter.new('err_console', :formatter=>LogFormatter)
eso.only_at(Log4r::DEBUG, Log4r::INFO, Log4r::WARN, Log4r::ERROR, Log4r::FATAL)
$log.add 'err_console'

eco = Log4r::StderrOutputter.new('err_copy', :formatter=>CopyFormatter)
eco.only_at(Log4r::COPY)
$log.add 'err_copy'

$stderr.sync = true

ec2e = nil

begin
	ec2e = Ec2Extractor.new(logFile)
	ec2e.extract
rescue => err
	$log.fatal err.to_s
	$log.fatal err.backtrace.join("\n")
	$log.fatal "Exiting on error"
ensure
	ec2e.done if ec2e
end
