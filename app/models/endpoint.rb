require 'openssl'

class Endpoint < ApplicationRecord
  belongs_to :resource, :polymorphic => true

  default_value_for :verify_ssl, OpenSSL::SSL::VERIFY_PEER
  validates :verify_ssl, :inclusion => {:in => [OpenSSL::SSL::VERIFY_NONE, OpenSSL::SSL::VERIFY_PEER]}
  validates :port, :numericality => {:only_integer => true, :allow_nil => true, :greater_than => 0}
  validates :url, :uniqueness => true, :if => :url
  validate :validate_certificate_authority

  after_create  :endpoint_created
  after_destroy :endpoint_destroyed

  def endpoint_created
    resource.endpoint_created(role) if resource.respond_to?(:endpoint_created)
  end

  def endpoint_destroyed
    resource.endpoint_destroyed(role) if resource.respond_to?(:endpoint_destroyed)
  end

  def verify_ssl=(val)
    val = resolve_verify_ssl_value(val)
    super
  end

  def verify_ssl?
    verify_ssl != OpenSSL::SSL::VERIFY_NONE
  end

  # From endpoint, falling back to Settings, then to system CA bundle
  def ssl_cert_store
    certs = parse_certificate_authority
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

  def to_s
    (url || generate_uri).to_s
  end

  private

  def generate_uri
    return unless resource.kind_of?(ExtManagementSystem)
    host = hostname || ipaddress || resource.hostname
    path = ["", resource.try(:api_version) || api_version, ""].compact.join("/")
    query = {:verify_ssl => verify_ssl?, :security_protocol => security_protocol }.delete_blanks.to_query
    URI::Generic.new(resource.emstype, nil, host, port, nil, path, nil, query, nil)
  end

  def resolve_verify_ssl_value(val)
    case val
    when true  then OpenSSL::SSL::VERIFY_PEER
    when false then OpenSSL::SSL::VERIFY_NONE
    else            val
    end
  end

  # Returns a list, to support concatenated PEM certs.
  def parse_certificate_authority
    return [] if certificate_authority.blank?
    certificate_authority.split(/(?=-----BEGIN)/).reject(&:blank?).collect do |pem_fragment|
      OpenSSL::X509::Certificate.new(pem_fragment)
    end
  end

  def validate_certificate_authority
    parse_certificate_authority
  rescue OpenSSL::OpenSSLError => err
    errors.add(:certificate_authority, err.to_s)
  end
end
