
require 'pp'
require '../Ec2Payload'
require '../credentials'

S3_AMAZON_ACCESS_KEY_ID		= AMAZON_ACCESS_KEY_ID
S3_AMAZON_SECRET_ACCESS_KEY	= AMAZON_SECRET_ACCESS_KEY

payload = {
	:account_info => {
		:account_id			=> AMAZON_ACCOUNT,
		:access_key_id		=> AMAZON_ACCESS_KEY_ID,
		:secret_access_key	=> AMAZON_SECRET_ACCESS_KEY,
		:private_key		=> PRIVATE_KEY,
		:key_pair_info		=> {
			'rpo'			=> RPO_PK,
			'miq'			=> MIQ_PK,
		}
	},
	:images => [
		"ami-fc3fd895",
		"ami-fa3fd893",
		"ami-8cdb3ce5",
		"ami-8520c7ec",
		"ami-6e2fc807"
	],
	:instances => [
		"i-2762ee4e",
		"i-e862ee81"
	]
}

s3access = {
	:access_key_id		=> S3_AMAZON_ACCESS_KEY_ID,
	:secret_access_key	=> S3_AMAZON_SECRET_ACCESS_KEY,
	:miq_bucket_in		=> "miq-extract",
	:miq_bucket_out		=> "miq-extract",
	:payload			=> "miq-payload-0001"
}

payloadStr = Ec2Payload.encode(payload)

puts
puts payloadStr

yamlStr = Ec2Payload.decode(payloadStr)

puts
pp yamlStr
