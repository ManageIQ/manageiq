require 'util/thumb_print'

class VcenterThumbPrint < ThumbPrint
  def uri
    url = "https://#{@host}"
    @uri = URI(url)
  end

  def to_cert
    @http.start
    $log.info "VcenterThumbPrint.ssl_connection: Host is #{@host}, URL is #{@url}" if $log
    cert = @http.peer_cert
    @http.finish
    cert
  end
end
