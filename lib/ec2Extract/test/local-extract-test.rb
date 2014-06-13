require 'rubygems'
require 'net/ssh'
require 'net/sftp'
require 'log4r'

INST = "ec2-67-202-2-188.compute-1.amazonaws.com"

EXTRACTOR	= "../local-extractor/build_linux/local-extractor"
PKEY		= "/Users/rpo/Library/rpo-ec2-kp"
TARGET		= File.join("/tmp", File.basename(EXTRACTOR))

class ConsoleFormatter < Log4r::Formatter
	def format(event)
		(event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
	end
end

toplog = Log4r::Logger.new 'toplog'
Log4r::StderrOutputter.new('err_console', :level=>Log4r::DEBUG, :formatter=>ConsoleFormatter)
toplog.add 'err_console'
$log = toplog if $log.nil?
$stdout.sync = true
$stderr.sync = true

begin
	Net::SFTP.start(INST, "root", :keys=>[PKEY]) do |s|
        $log.info "- Copying file #{EXTRACTOR} to #{TARGET}." if $log
        s.upload!(EXTRACTOR, TARGET)
        $log.info "- Copying of #{EXTRACTOR} to #{TARGET}, complete." if $log
    end

	stdout = ""
	Net::SSH.start(INST, "root", :keys=>[PKEY]) do |s|
		s.exec!("chmod 755 #{TARGET}")
		$log.info s.exec!("ls -l #{TARGET}")
		
	    s.exec!(TARGET) do |channel, stream, data|
			stdout << data if stream == :stdout
			$log.info data if stream == :stderr
	    end
	end
	
	category = nil
	data = ""
	stdout.each do |l|
		if /^----- MIQ START -----: (\w*)$/ =~ l
			raise "Unexpected #{$1} start while #{category} still active" if category
			category = $1
			next
		end
		if /^----- MIQ END -----: (\w*)$/ =~ l
			raise "Unexpected end of category #{$1} encountered" if !category
			raise "End of category #{$1} encountered while #{category} active" if category != $1
			puts "*** #{category} start"
			puts data
			puts "*** #{category} end"
			category = nil
			data = ""
			next
		end
		
		raise "No active category" if !category
		data << l
	end
	
rescue => err
	puts err.to_s
	puts err.backtrace.join("\n")
end
