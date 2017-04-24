require 'openssl'

class Endpoint < ApplicationRecord
  belongs_to :resource, :polymorphic => true

  default_value_for :verify_ssl, OpenSSL::SSL::VERIFY_PEER
  validates :verify_ssl, :inclusion => {:in => [OpenSSL::SSL::VERIFY_NONE, OpenSSL::SSL::VERIFY_PEER]}
  validates :port, :numericality => {:only_integer => true, :allow_nil => true, :greater_than => 0}
  validates :url, :uniqueness => true, :if => :url
  validate :validate_certificate_authority

  def verify_ssl=(val)
    val = resolve_verify_ssl_value(val)
    super
  end

  def verify_ssl?
    verify_ssl != OpenSSL::SSL::VERIFY_NONE
  end

  # From endpoint, falling back to Settings, then to system CA bundle
  def ssl_cert_store
    certs = parse_certificate_authorities
    if certs.present?
      store = OpenSSL::X509::Store.new
      certs.each do |cert|
        store.add_cert(cert)
      end
      return store
    end

    file = Settings.ssl.ssl_ca_file
    path = Settings.ssl.ssl_ca_path
    if file.present? || path.present?
      store = OpenSSL::X509::Store.new
      store.add_file(file) if file.present?
      store.add_path(path) if path.present?
      return store
    end

    nil # use system defaults
  end

  # Split concatenated PEM certs to a list
  def certificate_authorities
    return [] if certificate_authority.blank?
    certificate_authority.split(/^(?=-----BEGIN)/).reject(&:blank?)
  end

  def parse_certificate_authorities
    certificate_authorities.collect do |pem_fragment|
      OpenSSL::X509::Certificate.new(pem_fragment)
    end
  end

  private

  def resolve_verify_ssl_value(val)
    case val
    when true  then OpenSSL::SSL::VERIFY_PEER
    when false then OpenSSL::SSL::VERIFY_NONE
    else            val
    end
  end

  def validate_certificate_authority
    parse_certificate_authorities
  rescue OpenSSL::OpenSSLError => err
    errors.add(:certificate_authority, err.to_s)
  end
end
