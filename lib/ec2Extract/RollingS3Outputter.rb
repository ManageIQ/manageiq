require "log4r/outputter/fileoutputter"
require "log4r/staticlogger"

require_relative 'MiqEvmBucket'

module Log4r
	
	class RollingS3Outputter < FileOutputter
		attr_reader :count, :maxsize

		def initialize(_name, hash={})
			@count		= 0
			@aws_args	= hash[:aws_args]
			
			@evm_bucket_name	= @aws_args[:evm_bucket]
			@evm_bucket_name	= @evm_bucket_name + @aws_args[:account_info][:account_id]
			@s3_log_prefix		= File.join(@aws_args[:log_prefix], @aws_args[:extractor_id])
			@evm_bucket			= MiqEvmBucket.get(@aws_args)
						
			_maxsize = (hash[:maxsize] or hash['maxsize']).to_i
			if _maxsize.class != Fixnum
				raise TypeError, "Argument 'maxsize' must be an Fixnum", caller
			end
			if _maxsize == 0
				raise TypeError, "Argument 'maxsize' must be > 0", caller
			end
			@maxsize = _maxsize
			@datasize = 0
			
			super(_name, hash.merge({:create => true, :trunc => true}))
		end
		
		def flush
			roll
		end

		private

		def write(data)
			# we have to keep track of the file size ourselves - File.size doesn't
			# seem to report the correct size when the size changes rapidly
			@datasize += data.size + 1 # the 1 is for newline
			super
			roll if @datasize > @maxsize
		end
		
		def newS3OblectKey
			log_id = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S")
			seq = "0" * (6 - @count.to_s.length) + @count.to_s
			key = File.join(@s3_log_prefix, "#{log_id}-#{seq}.log")
			@count += 1
			Logger.log_internal {"S3 obj key #{key} created"}
			return key
		end

		def roll
			@out.close
			return if @datasize == 0
			key = newS3OblectKey
			@evm_bucket.objects[key].write(:file => @filename)
			# truncate the file
			@out = File.new(@filename, "w")
			@datasize = 0
		end
	end # class RollingS32Outputter
	
end # module Log4r

if __FILE__ == $0
	require 'rubygems'
	require "log4r"
	require 'aws-sdk'
	require_relative 'tools/ExtractUserData'
		
	class MyFormatter < Log4r::Formatter
		def format(event)
			"#{Log4r::LNAMES[event.level]} [#{datetime}]: " +
			(event.data.kind_of?(String) ? event.data : event.data.inspect) + "\n"
		end

		private

		def datetime
			time = Time.now.utc
			time.strftime("%Y-%m-%dT%H:%M:%S.") << "%06d" % time.usec
		end
	end
	
	userData = ExtractUserData::user_data
	userData[:extractor_id] = 'some-id'
	
	AWS.config({
		:access_key_id     => userData[:account_info][:access_key_id],
		:secret_access_key => userData[:account_info][:secret_access_key]
	})
	
	outputterArgs = {
		:formatter	=> MyFormatter,
		:filename	=> "/tmp/TestSize.log",
		:maxsize	=> 16000,
		:aws_args	=> userData
	}

	s3Log = Log4r::Logger.new 'S3LOG'
	s3o = Log4r::RollingS3Outputter.new('S3LOG', outputterArgs)
	s3Log.outputters = s3o
	s3Log.level = Log4r::DEBUG

	10000.times { |t|
		s3Log.info "blah #{t}"
	}
	s3o.flush

end
