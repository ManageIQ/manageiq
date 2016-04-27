class Endpoint < ActiveRecord::Base
  belongs_to :resource, :polymorphic => true

  before_save :delete_ceilometer_endpoint

  default_value_for :verify_ssl, OpenSSL::SSL::VERIFY_PEER
  validates :verify_ssl, :inclusion => {:in => [OpenSSL::SSL::VERIFY_NONE, OpenSSL::SSL::VERIFY_PEER]}

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

  def role_amqp?
    role == "amqp"
  end

  def delete_ceilometer_endpoint
    Endpoint.find_by(:role => "ceilometer", :resource_id => resource_id).try(:destroy) if role_amqp?
  end
end
