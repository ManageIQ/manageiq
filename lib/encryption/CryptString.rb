require 'openssl'

class CryptString
    def initialize(str=nil, enc_alg=nil, key=nil, iv=nil)
        @enc_alg = enc_alg
        @key     = key
        @iv      = iv
    end

    def encrypt64(str)
      cip = OpenSSL::Cipher::Cipher.new(@enc_alg)
      cip.encrypt
      cip.key = @key
      cip.iv  = @iv

      es = cip.update(str)
      es << cip.final
      [es].pack('m')
    end
    alias_method :encrypt, :encrypt64

    def decrypt64(str)
        cip = OpenSSL::Cipher::Cipher.new(@enc_alg)
        cip.decrypt
        cip.key = @key
        cip.iv  = @iv
        
        rs = cip.update(str.unpack('m').join)
        rs << cip.final
        
        return rs
    end
    alias_method :decrypt, :decrypt64
end # class CryptString
