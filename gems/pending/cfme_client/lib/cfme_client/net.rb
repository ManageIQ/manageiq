class CfmeClient
  #
  # HTTP helper procs
  #
  def resource_method(method, path = "", payload = nil, parameters = {})
    update_options(parameters)
    if [:get, :delete].include?(method)
      call_api(path, method, nil, parameters)
    else
      call_api(path, method, payload, parameters)
    end
  end

  def call_api(path, verb, payload = nil, parameters = {})
    faraday = faraday_client(api_uri(path))

    if @config[:debug]
      puts "URL: <#{faraday.url_prefix}>"
      puts "Method: <#{verb}>"
      puts "Parameters: <#{parameters}>" unless parameters.empty?
    end

    begin
      response = faraday_call(faraday, path, verb, payload, parameters)
    rescue => e
      @code    = network_error?(e.message) ? 0 : 500
      @status  = API_STATUS[@code]
      @message = e.message
      @result  = {:error => {:kind => @status, :message => @message, :klass => e.class.name}}
      return false
    end

    parse_response(response)
  end

  def parse_response(response)
    success  = response.status < 300
    @result  = json_parse(response.body)
    @code    = response.status
    @status  = API_STATUS[@code] || (success ? 200 : 500)
    @message = response_error_message(success, @result)
    success
  end

  def faraday_client(url)
    Faraday.new(:url => url, :ssl => {:verify => false}) do |faraday|
      faraday.request(:url_encoded)
      faraday.response(:logger) if @config[:debug]
      faraday.use FaradayMiddleware::FollowRedirects, :limit => 3, :standards_compliant => true
      faraday.adapter(Faraday.default_adapter)
      faraday.basic_auth(@options[:user], @options[:password]) unless @options[:headers].key?(:x_auth_token)
    end
  end

  def faraday_call(faraday, path, verb, payload = nil, parameters = {})
    faraday.send(verb) do |req|
      req.url api_uri(path)
      req.options.open_timeout    = @config[:open_timeout]
      req.headers[:content_type]  = @config[:content_type]
      req.headers[:accept]        = @config[:accept]
      req.headers['X-Auth-Token'] = @options[:headers][:x_auth_token] if @options[:headers].key?(:x_auth_token)
      req.params.merge!(parameters)
      req.body = payload if payload
    end
  end

  def json_parse(body)
    body ? JSON.parse(body) : {}
  rescue
    {}
  end

  def response_error_message(success, result)
    success ? "" : result.try(:fetch_path, "error", "message")
  end

  def network_error?(message)
    msg = message.dup.downcase
    msg.match("connection refused|execution expired|getaddrinfo: nodename")
  end

  def api_uri(path)
    uripath = @config[:prefix].dup
    uripath << "/v#{@config[:version]}" unless @config[:version].blank?
    unless path.blank?
      uripath << "/" if path[0] != '/'
      uripath << path
    end
    urioptions = {:scheme => @config[:scheme], :host => @config[:host], :path => uripath}
    urioptions.merge!(:port => @config[:port].to_i) unless @config[:port].blank?
    URI::Generic.build(urioptions).to_s
  end
end
