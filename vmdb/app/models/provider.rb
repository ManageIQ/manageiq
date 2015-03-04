class Provider < ActiveRecord::Base
  include NewWithTypeStiMixin
  include AuthenticationMixin
  include EmsRefresh::Manager

  belongs_to :zone

  def verify_ssl=(val)
    val = case val
          when true then OpenSSL::SSL::VERIFY_PEER
          when false then OpenSSL::SSL::VERIFY_NONE
          else val
          end
    super
  end

  def verify_ssl?
    verify_ssl != OpenSSL::SSL::VERIFY_NONE
  end

  def my_zone
    zone.try(:name).presence || MiqServer.my_zone
  end
  alias_method :zone_name, :my_zone
end
