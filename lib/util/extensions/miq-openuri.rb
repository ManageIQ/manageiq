require 'open-uri'

module OpenURI
  def OpenURI.open_http(buf, target, proxy, options) # :nodoc:
    if proxy
      raise "Non-HTTP proxy URI: #{proxy}" if proxy.class != URI::HTTP
    end

    if target.userinfo
      raise ArgumentError, "userinfo not supported.  [RFC3986]"
    end

    require 'net/http'
    klass = Net::HTTP
    if URI::HTTP === target
      # HTTP or HTTPS
      if proxy
        klass = Net::HTTP::Proxy(proxy.host, proxy.port)
      end
      target_host = target.host
      target_port = target.port
      request_uri = target.request_uri
    else
      # FTP over HTTP proxy
      target_host = proxy.host
      target_port = proxy.port
      request_uri = target.to_s
    end

    http = klass.new(target_host, target_port)
    if target.class == URI::HTTPS
      require 'net/https'
      http.use_ssl = true
      #GMM http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      store = OpenSSL::X509::Store.new
      store.set_default_paths
      http.cert_store = store
    end

    header = {}
    options.each {|k, v| header[k] = v if String === k }

    resp = nil
    http.start {
      if target.class == URI::HTTPS
        # xxx: information hiding violation
        sock = http.instance_variable_get(:@socket)
        if sock.respond_to?(:io)
          sock = sock.io # 1.9
        else
          sock = sock.instance_variable_get(:@socket) # 1.8
        end
        #GMM sock.post_connection_check(target_host)
      end
      req = Net::HTTP::Get.new(request_uri, header)
      if options.include? :http_basic_authentication
        user, pass = options[:http_basic_authentication]
        req.basic_auth user, pass
      end
      http.request(req) {|response|
        resp = response
        if options[:content_length_proc] && Net::HTTPSuccess === resp
          if resp.key?('Content-Length')
            options[:content_length_proc].call(resp['Content-Length'].to_i)
          else
            options[:content_length_proc].call(nil)
          end
        end
        resp.read_body {|str|
          buf << str
          if options[:progress_proc] && Net::HTTPSuccess === resp
            options[:progress_proc].call(buf.size)
          end
        }
      }
    }
    io = buf.io
    io.rewind
    io.status = [resp.code, resp.message]
    resp.each {|name,value| buf.io.meta_add_field name, value }
    case resp
    when Net::HTTPSuccess
    when Net::HTTPMovedPermanently, # 301
         Net::HTTPFound, # 302
         Net::HTTPSeeOther, # 303
         Net::HTTPTemporaryRedirect # 307
      throw :open_uri_redirect, URI.parse(resp['location'])
    else
      raise OpenURI::HTTPError.new(io.status.join(' '), io)
    end
  end
end