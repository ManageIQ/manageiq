require 'util/thumb_print'

class ESXThumbPrint < ThumbPrint
  attr_reader :user, :password

  def initialize(host, user, password)
    @user     = user
    @password = password
    super(host)
  end

  def uri
    url  = "https://#{@host}/host/ssl_cert"
    @uri = URI(url)
  end

  def http_request
    super
    @request = Net::HTTP::Get.new(uri.request_uri)
    @request.basic_auth(@user, @password)
    @request
  end

  def to_cert
    raise "Invalid Request" if @request.nil?
    response = @http.request(@request)
    unless response.message == "OK" && response.code == "200"
      raise "Unable to get ESX Host SSL Certificate: Invalid HTTP Response #{response.message} code #{response.code}"
    end
    response.body
  end
end
