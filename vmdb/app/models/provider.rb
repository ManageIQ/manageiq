class Provider < ActiveRecord::Base
  include AuthenticationMixin

  belongs_to :zone

  def verify_ssl=(val)
    val = case val
          when true then OpenSSL::SSL::VERIFY_PEER
          when false then OpenSSL::SSL::VERIFY_NONE
          else val
          end
    syper(val)
  end

  def verify_ssl?
    verify_ssl != OpenSSL::SSL::VERIFY_NONE
  end
end
