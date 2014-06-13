
require 'rubygems'
require 'log4r'
require "#{File.dirname(__FILE__)}/../S3FS"
require_relative '../credentials'

# DIR = "TS:2009-04-15T01:16:59.884696"
DIR = "TS:2009-04-04T03:47:04.034498"

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

$stdout.sync = true

errorMap = [
	/The requested instance type's architecture (\S*) does not match the architecture in the manifest for .*/,
	/Subscription to ProductCode \S* required./,
	/Skipping windows image: .*/,
	/Image \S* is not an AMI, skipping./,
	/Could not download image: .*/,
	/Registered machine image manifest for \S* and manifest in S3 differ.*/,
	/HTTP 404 \(Not Found\) response for URL .*/,
	/HTTP 403 \(Forbidden\) response for URL .*/,
	/Not authorized for images: .*/,
	/Instance \S* does not exist/,
	/fingerprint \S* does not match for .*/
]

s3access = {
	:bucket				=> "miq-extract",
}

AWS.config(:access_key_id => AMAZON_ACCESS_KEY_ID, :secret_access_key => AMAZON_SECRET_ACCESS_KEY)

fs = S3FS.new(s3access)

fs.chdir(DIR)

scans = completed = errors = successful = both = 0
errorFiles = []
fs.dirEntries.each do |de|
	next if !fs.fileDirectory?(de)
	scans += 1
	completed	+= 1 if fs.fileExists?(File.join(de, "END"))
	successful	+= 1 if fs.fileExists?(File.join(de, "system.xml"))
	
	ef = File.join(de, "ERROR")
	if fs.fileExists?(ef)
		errorFiles << ef
		errors += 1
	end
	# puts "\t" + de   if !fs.fileExists?(File.join(de, "system.xml")) && !fs.fileExists?(File.join(de, "ERROR"))
end

puts
puts "AMIs scanned: #{scans}"
puts "COMPLETED:    #{completed}"
puts "SUCCESSFUL:   #{successful}"
puts "ERRORS:       #{errors}"
	
puts
puts "Processing errors..."
errorSum = Hash.new { |h, k| h[k] = 0 }
errorFiles.each do |ef|
	fs.fileOpen(ef, "r") do |efo|
		err = efo.read
		errorMap.each do |re|
			if re =~ err
				err = re.inspect
				break
			end
		end
		errorSum[err] += 1
	end
end
puts "done."
puts
errorSum.to_a.sort { |x, y| y.last <=> x.last }.each { |a| puts "#{a[1]}:\t#{a[0]}"}
