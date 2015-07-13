$:.push("#{File.dirname(__FILE__)}/../metadata/VmConfig")

require 'rubygems'
require 'log4r'
require 'log4r/outputter/iooutputter'
require "log4r/staticlogger"

require 'GetNativeCfg'

module Log4r
	
	class MiqPayloadOutputter < IOOutputter
		
		attr_reader :filename, :partialLog
		
		HEADER_SIZE		= 16
		HEADER_MAGIC	= "MIQ_LOG_"
		
		def self.genHeader(size, pos=0)
			return [ HEADER_MAGIC, size, pos ].pack("a8LL")
		end
		
		def initialize(_name, hash={})
			super(_name, nil, hash)
			
			@partialLog = false
			@out = nil
			
			if (_filename = (hash[:filename] or hash['filename']))
				if _filename.class != String
					raise TypeError, "Argument 'filename' must be a String", caller
				end

			    # file validation
				if FileTest.exist?( _filename )
					if not FileTest.file?( _filename )
						raise StandardError, "'#{_filename}' is not a regular file", caller
					elsif not FileTest.writable?( _filename )
						raise StandardError, "'#{_filename}' is not writable!", caller
					end
				else # ensure directory is writable
					dir = File.dirname( _filename )
					if not FileTest.writable?( dir )
						raise StandardError, "'#{dir}' is not writable!"
					end
				end

				@filename = _filename
				@out = File.new(@filename, "r+") 
				Logger.log_internal {
					"MiqPayloadOutputter '#{@name}' writing to #{@filename}"
				}
			else
				cfg = GetNativeCfg.new
				cfg.getDiskFileHash.each_value do |df|
					_out = File.new(df, "r")
					_magic, _size, _pos = _out.read(HEADER_SIZE).unpack("a8LL")
					_out.close
					next if _magic != HEADER_MAGIC
					@out = File.new(df, "r+")
					@filename = df
				end
				raise StandardError, "Could not find log device", caller if !@out
			end
			
			@out.seek(0, IO::SEEK_SET)
			magic, @size, @pos = @out.read(HEADER_SIZE).unpack("a8LL")
			
			raise StandardError, "'#{@filename}' bad magic number #{magic}", caller if magic != HEADER_MAGIC
		end
		
		private
		
		def write(data)
			if @pos + data.length >= @size
				@pos = 0
				@partialLog = true
			end
			@out.seek(@pos + HEADER_SIZE, IO::SEEK_SET)
			super
			@pos += data.length
			@out.seek(0, IO::SEEK_SET)
			@out.write(MiqPayloadOutputter.genHeader(@size, @pos))
			@out.flush
		end
		
	end # class MiqPayloadOutputter
	
end # module Log4r

if __FILE__ == $0
	
	class ConsoleFormatter < Log4r::Formatter
		@@prog = File.basename(__FILE__, ".*")
		def format(event)
			"#{Log4r::LNAMES[event.level]} [#{datetime}] -- #{@@prog}: " +
			(event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
		end

		private

		def datetime
			time = Time.now.utc
			time.strftime("%Y-%m-%dT%H:%M:%S.") << "%06d " % time.usec
		end

	end
	$log = Log4r::Logger.new 'toplog'
	$log.level = Log4r::DEBUG
	lo = Log4r::MiqPayloadOutputter.new('payload', :formatter=>ConsoleFormatter, :filename => "test/test.log" )
	# lo = Log4r::MiqPayloadOutputter.new('payload', :formatter=>ConsoleFormatter)
	$log.add 'payload'
	
	puts "Log file: #{lo.filename}"
	puts
	
	$log.debug "test line 1"
	$log.debug "test line 2"
	$log.debug "test line 3"
	
	# tf = File.open("test/test.log", "r")
	tf = File.open(lo.filename, "r")
	magic, size, pos = tf.read(Log4r::MiqPayloadOutputter::HEADER_SIZE).unpack("a8LL")
	
	puts "MAGIC: #{magic}"
	puts "SIZE: #{size}"
	puts "POS: #{pos}"
	
	puts tf.read(pos)
	
end
