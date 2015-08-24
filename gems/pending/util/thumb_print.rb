require 'net/http'
require 'openssl'

class ThumbPrint
  attr_reader   :thumb_print, :der_thumb_print, :x509_cert, :host, :http
  attr_accessor :cert

  def initialize(host)
    $log.info "ThumbPrint.initialize(#{host})" if $log
    @host = host
    @cert = nil
    uri
    http_request
  end

  def http_request
    @http             = Net::HTTP.new(@uri.host, @uri.port)
    @http.use_ssl     = true
    @http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end

  def to_sha1
    @cert = to_cert if @cert.nil?
    $log.info "ThumbPrint.to_sha1 for host #{@host}" if $log
    raise "Invalid Certificate" if @cert.nil?
    @x509_cert       = OpenSSL::X509::Certificate.new(@cert)
    @der_thumb_print = OpenSSL::Digest::SHA1.new(@x509_cert.to_der).to_s
    @thumb_print     = @der_thumb_print.scan(/../).collect(&:upcase).join(":")
    $log.info "ThumbPrint.to_sha1 for host #{@host} is #{@thumb_print}" if $log
    @thumb_print
  end
end
