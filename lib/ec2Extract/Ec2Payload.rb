
require 'yaml'
require 'openssl'

module Ec2Payload
	
	EXPECTED_KEY_LENGTH	= 64
	EXPECTED_IV_LENGTH	= 24
	LP_SPLIT = (EXPECTED_KEY_LENGTH + EXPECTED_IV_LENGTH) / 2
	PAIRAPD = 2
	PAIRBPD = 3
	
	GLOBAL_KEY = "\222dL\256\177\311X)\177\332\214*3\367\252\002\023\034\305\243\274\252\312X\276\b\273\261\331(\216\310".force_encoding("ASCII-8BIT")
	
	def self.userData
		ud = `curl http://169.254.169.254/latest/user-data 2> /dev/null`
		raise "No user data provided" if !ud || ud.empty? || ud =~ /.*404 - Not Found.*/
		return(decode(ud))
	end
	
	def self.encode(pl)
		cip1 = OpenSSL::Cipher::Cipher.new("aes-256-cbc")

		globalKey		= GLOBAL_KEY
		globalKeyIv		= cip1.random_iv
		globalKeyIvB64	= [globalKeyIv].pack('m').tr("\n", "")
		raise "Unexpected global IV length: #{globalKeyIvB64.length}" if globalKeyIvB64.length != EXPECTED_IV_LENGTH

		localKey		= cip1.random_key
		localKeyIv		= cip1.random_iv
		localKeyIvB64	= [localKeyIv].pack('m').tr("\n", "")
		raise "Unexpected local IV length: #{localKeyIvB64.length}" if localKeyIvB64.length != EXPECTED_IV_LENGTH

		cip1.encrypt
		cip1.key	= globalKey
		cip1.iv		= "\000" * cip1.iv_len
		eeLocalKey	= ([cip1.update(localKey) + cip1.final].pack('m')).tr("\n", "")
		raise "Unexpected Key length: #{eeLocalKey.length}" if eeLocalKey.length != EXPECTED_KEY_LENGTH

		localPair	= eeLocalKey + localKeyIvB64
		localPaira	= localPair[0, LP_SPLIT]
		localPairb	= localPair[LP_SPLIT, localPair.length - LP_SPLIT]

		cip1.encrypt
		cip1.key	= localKey
		cip1.iv		= localKeyIv
		cStr		= ([cip1.update(YAML.dump(pl)) + cip1.final].pack('m')).tr("\n", "")

		lpap = cStr.length / PAIRAPD
		cStr[lpap, 0] = localPaira

		lpbp = cStr.length / PAIRBPD
		cStr[lpbp, 0] = localPairb

		cip1.encrypt
		cip1.key	= globalKey
		cip1.iv		= globalKeyIv
		cStr2		= ([cip1.update(cStr) + cip1.final].pack('m')).tr("\n", "")
		cStr2		<< globalKeyIvB64

		outStr = ""
		cStr2.scan(/.{1,60}/) { outStr << $& + "\n" }

		return outStr
	end
	
	def self.decode(epl)
		globalKey	= GLOBAL_KEY
		
		cStr2 = epl.tr("\n", "")

		globalKeyIvB64 = cStr2[-EXPECTED_IV_LENGTH, EXPECTED_IV_LENGTH]
		cStr2[-EXPECTED_IV_LENGTH, EXPECTED_IV_LENGTH] = ""

		cip2 = OpenSSL::Cipher::Cipher.new("aes-256-cbc")

		cip2.decrypt
		cip2.key	= globalKey
		cip2.iv		= globalKeyIvB64.unpack('m').join
		cStr		= cip2.update(cStr2.unpack('m').join) + cip2.final

		lpbp = (cStr.length - LP_SPLIT) / PAIRBPD
		localPairb  = cStr[lpbp, LP_SPLIT]
		cStr[lpbp, LP_SPLIT] = ""

		lpap = (cStr.length - LP_SPLIT) / PAIRAPD
		localPaira  = cStr[lpap, LP_SPLIT]
		cStr[lpap, LP_SPLIT] = ""

		localPair		= localPaira + localPairb
		eeLocalKey		= localPair[0, EXPECTED_KEY_LENGTH]
		localKeyIvB64	= localPair[EXPECTED_KEY_LENGTH, EXPECTED_IV_LENGTH]

		cip2.decrypt
		cip2.key	= globalKey
		cip2.iv		= "\000" * cip2.iv_len
		localKey	= cip2.update(eeLocalKey.unpack('m').join) + cip2.final
		localKeyIv	= localKeyIvB64.unpack('m').join

		cip2.decrypt
		cip2.key = localKey
		cip2.iv  = localKeyIv

		outStr = cip2.update(cStr.unpack('m').join) + cip2.final

		return YAML.load(outStr)
	end
	
end # module Ec2Payload
