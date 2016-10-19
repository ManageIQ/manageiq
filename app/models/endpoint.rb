class Endpoint < ApplicationRecord
  belongs_to :resource, :polymorphic => true

  default_value_for :verify_ssl, OpenSSL::SSL::VERIFY_PEER
  validates :verify_ssl, :inclusion => {:in => [OpenSSL::SSL::VERIFY_NONE, OpenSSL::SSL::VERIFY_PEER]}
  validates :port, :numericality => {:only_integer => true, :allow_nil => true, :greater_than => 0}
  validates :url, :uniqueness => true, :if => :url

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
