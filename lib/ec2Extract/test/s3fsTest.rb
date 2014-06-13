require 'rubygems'
require 'log4r'

require '../S3FS'
require_relative '../credentials'

class ConsoleFormatter < Log4r::Formatter
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

toplog = Log4r::Logger.new 'toplog'
Log4r::StderrOutputter.new('err_console', :level=>Log4r::DEBUG, :formatter=>ConsoleFormatter)
toplog.add 'err_console'
$log = toplog
	
begin
	AWS.config(:access_key_id => AMAZON_ACCESS_KEY_ID, :secret_access_key => AMAZON_SECRET_ACCESS_KEY)
	fs = S3FS.new(:bucket => "miq-extract")
	fs.findEach(".") do |fp|
		puts fp
	end
rescue => err
	puts err.to_s
	puts err.backtrace.join("\n")
end
