class Provider < ActiveRecord::Base
  include AuthenticationMixin

  def verify_ssl=(val)
    val = case val
          when true then OpenSSL::SSL::VERIFY_PEER
          when false then OpenSSL::SSL::VERIFY_NONE
          else val
          end
    write_attribute(:verify_ssl, val)
  end

  def verify_ssl?
    verify_ssl != OpenSSL::SSL::VERIFY_NONE
  end
end
