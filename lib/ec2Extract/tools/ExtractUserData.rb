require "../credentials"

module ExtractUserData
	def self.user_data
		{
			:account_info => {
				:account_id			=> AMAZON_ACCOUNT,
				:access_key_id		=> AMAZON_ACCESS_KEY_ID,
				:secret_access_key	=> AMAZON_SECRET_ACCESS_KEY,
				:private_key		=> PRIVATE_KEY,
				:key_pair_info		=> {
					'rpo'			=> RPO_PK,
					'miq'			=> MIQ_PK
				}
			},
			:log_level			=> 'DEBUG',
			:request_queue		=> 'evm_extract_request',
			:reply_queue		=> 'evm_extract_reply',
			:evm_bucket			=> 'miq-evm',
			:reply_prefix		=> 'extract/queue-reply/',
			:log_prefix			=> 'extract/logs/',
			:heartbeat_prefix	=> 'extract/heartbeat/',
			:image_prefix		=> 'extract/images/',
			:heartbeat_interval	=> 120
		}
	end
end
