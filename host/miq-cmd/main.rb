require_relative '../bundler_setup'

$:.push("#{File.dirname(__FILE__)}/../../lib/Verbs")
$:.push("#{File.dirname(__FILE__)}/..")

$:.push("#{File.dirname(__FILE__)}/../../lib")

require 'active_support/all'
require 'rexml/document'
require 'MiqVerbs'

#
# Environment variables set by the Ruby self extractor.
#
$0          = ENV.fetch("MIQ_EXE_NAME", $0)     # name of the command being executed
$miqExePath = ENV.fetch("MIQ_EXE_PATH", nil)    # full path to the executable file
$miqExtDir  = ENV.fetch("MIQ_EXT_DIR", nil)     # directory where the extracted files reside

Log4r::Logger.root.level = Log4r::ERROR

class ConsoleFormatter < Log4r::Formatter
	def format(event)
		(event.data.kind_of?(String) ? event.data : event.data.inspect)
	end
end

toplog = Log4r::Logger.new 'toplog'
Log4r::StderrOutputter.new('err_console', :level=>Log4r::ERROR, :formatter=>ConsoleFormatter)
toplog.add 'err_console'
$log = toplog if $log.nil?

miqp = MiqParser.new
# miqp.miqRet.test = true

miqp.parse
ret = miqp.miqRet

if ret.error
    toplog.error "#{$0} ERROR:\n"
	toplog.error ret.error + "\n"
	toplog.error ret.cmdObj.show_help if ret.show_help
	exit(ret.code) if ret.code
	exit(1)
end

if ret.value
    if ret.encode
        ret.value = ret.value.unpack('m').join
    end
    if ret.xml
        doc = REXML::Document.new(ret.value)
        doc.write($stdout, 4)
        puts
    else
        puts ret.value
    end
end

if ret.file
end

puts("ret.code = #{ret.code}") if ret.verbose

exit(ret.code) if ret.code
exit(0)
