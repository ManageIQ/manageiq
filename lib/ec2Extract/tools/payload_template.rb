require "../credentials"

$payload = {
	:account_info	=> {
		:account_id			=> AMAZON_ACCOUNT,
		:access_key_id		=> AMAZON_ACCESS_KEY_ID,
		:secret_access_key	=> AMAZON_SECRET_ACCESS_KEY,
		:private_key		=> PRIVATE_KEY,
		:launch_key_name	=> 'rpo',
		:key_pair_info		=> {
			'rpo'			=> RPO_PK,
			'miq'			=> MIQ_PK,
		}
	},
	:images => [],
	:manifests => [],
	:instances => []
}
