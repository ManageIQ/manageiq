class Endpoint < ApplicationRecord
  belongs_to :resource, :polymorphic => true

  default_value_for :verify_ssl, OpenSSL::SSL::VERIFY_PEER
  validates :verify_ssl, :inclusion => {:in => [OpenSSL::SSL::VERIFY_NONE, OpenSSL::SSL::VERIFY_PEER]}

  before_validation do |endpoint|
    # on upgrade verify_ssl would be nil for endpoints that did not have a Provider class
    # only needed for darga branch, since euwe this is fixed in a migration
    # this is for https://bugzilla.redhat.com/show_bug.cgi?id=1360226
    endpoint.verify_ssl = OpenSSL::SSL::VERIFY_PEER if endpoint.verify_ssl.nil?
  end

  def verify_ssl=(val)
    val = resolve_verify_ssl_value(val)
    super
  end

  def verify_ssl?
    verify_ssl != OpenSSL::SSL::VERIFY_NONE
  end

  private

  def resolve_verify_ssl_value(val)
    case val
    when true  then OpenSSL::SSL::VERIFY_PEER
    when false then OpenSSL::SSL::VERIFY_NONE
    else            val
    end
  end
end
