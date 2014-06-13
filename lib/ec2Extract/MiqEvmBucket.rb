module MiqEvmBucket
	
	def self.get(arg_hash)
		evm_bucket_name	= arg_hash[:evm_bucket]
		evm_bucket_name	= evm_bucket_name + arg_hash[:account_info][:account_id] if arg_hash[:account_info]
		reply_prefix	= arg_hash[:reply_prefix]
		s3				= arg_hash[:s3]  || AWS::S3.new
		
		unless (evm_bucket = s3.buckets[evm_bucket_name]).exists?
			$log.info "#{self.name}.#{__method__}: Reply bucket #{evm_bucket_name} does not exist, creating..."
			evm_bucket = s3.buckets.create(evm_bucket_name)
			$log.info "#{self.name}.#{__method__}: Adding rule: #{reply_prefix}, 4"
			evm_bucket.lifecycle_configuration.add_rule(reply_prefix, 4)
			evm_bucket.lifecycle_configuration.update
			$log.info "#{self.name}.#{__method__}: Created reply bucket #{evm_bucket_name}"
		else
			$log.info "#{self.name}.#{__method__}: Found reply bucket #{evm_bucket_name}"
		end
		
		return evm_bucket
	end
	
end
