require 'yaml'
require 'aws-sdk'

require_relative 'MiqEvmBucket'

class Ec2ExtractHeartbeat
	
	attr_reader :heartbeat_thread, :heartbeat_interval
	
	def initialize(args={})
		@extractor_id		= args[:extractor_id]
		@s3					= args[:s3]  || AWS::S3.new
		@evm_bucket			= MiqEvmBucket.get(args)
		@heartbeat_prefix	= args[:heartbeat_prefix]
		@heartbeat_interval	= args[:heartbeat_interval]
		@heartbeat_obj_key	= File.join(@heartbeat_prefix, @extractor_id) if @extractor_id
		@heartbeat_thread	= nil
		@do_heartbeat		= true
		
		if $log.debug?
			$log.debug "#{self.class.name}: extractor_id       = #{@extractor_id}"
			$log.debug "#{self.class.name}: evm_bucket         = #{@evm_bucket.name}"
			$log.debug "#{self.class.name}: heartbeat_prefix   = #{@heartbeat_prefix}"
			$log.debug "#{self.class.name}: heartbeat_interval = #{@heartbeat_interval}"
		end
	end
	
	def start_heartbeat_loop
		return unless @heartbeat_thread.nil?
		$log.info "#{self.class.name}.#{__method__}: starting heartbeat loop (#{self.object_id})"
		@heartbeat_thread = Thread.new do
			while @do_heartbeat
				begin
					self.heartbeat
				rescue Exception => err
					$log.warn "#{self.class.name}.#{__method__}: #{err.to_s}"
					$log.warn err.backtrace.join("\n")
				end
				sleep @heartbeat_interval
			end
			$log.info "#{self.class.name}.#{__method__}: exiting heartbeat loop"
			@heartbeat_thread = nil
		end
	end
	
	def stop_heartbeat_loop
		return if @heartbeat_thread.nil?
		@do_heartbeat = false
		while @heartbeat_thread && @heartbeat_thread.alive?
			@heartbeat_thread.run
		end
	end
	
	def heartbeat
		ts = Time.now.utc
		$log.debug { "#{self.class.name}.#{__method__}: #{@extractor_id} --> #{ts.to_s}" }
		@evm_bucket.objects[@heartbeat_obj_key].write(YAML.dump(ts))
	end
	
	def get_heartbeat(extractor_id)
		heartbeat_obj_key = File.join(@heartbeat_prefix, extractor_id)
		hbobj = @evm_bucket.objects[heartbeat_obj_key]
		return nil unless hbobj.exists?
		return hbobj.last_modified.utc
	end
	
end
