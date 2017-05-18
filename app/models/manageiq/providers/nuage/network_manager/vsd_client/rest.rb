class ManageIQ::Providers::Nuage::NetworkManager::VsdClient::Rest
  include Vmdb::Logging
  def initialize(server, user, password)
    @server = server
    @user = user
    @password = password
    @api_key = ''
    @headers = {'X-Nuage-Organization' => 'csp', "Content-Type" => "application/json; charset=UTF-8"}
  end

  def login
    @login_url = @server + "/me"
    RestClient::Request.execute(:method => :get, :url => @login_url, :user => @user, :password => @password,
    :headers => @headers, :verify_ssl => false) do |response|
      case response.code
      when 200
        data = JSON.parse(response.body)
        extracted_data = data[0]
        @api_key = extracted_data["APIKey"]
        return true, extracted_data["enterpriseID"]
      else
        raise MiqException::MiqInvalidCredentialsError, "Login failed due to a bad username or password."
      end
    end
  end

  class << self
    attr_reader :server
  end

  def append_headers(key, value)
    @headers[key] = value
  end

  def get(url)
    if @api_key == ''
      login
    end
    _log.debug("GET for Nuage VSD url #{url}")
    RestClient::Request.execute(:method => :get, :url => url, :user => @user, :password => @api_key,
     :headers => @headers, :verify_ssl => false) do |response|
      return response
    end
  end

  def delete(url)
    if @api_key == ''
      login
    end
    RestClient::Request.execute(:method => :delete, :url => url, :user => @user, :password => @api_key,
    :headers => @headers, :verify_ssl => false) do |response|
      return response
    end
  end

  def put(url, data)
    if @api_key == ''
      login
    end

    RestClient::Request.execute(:method => :put, :data => data, :url => url, :user => @user, :password => @api_key,
    :headers => @headers, :verify_ssl => false) do |response|
      return response
    end
  end

  def post(url, data)
    if @api_key == ''
      login
    end

    RestClient::Request.execute(:method => :post, :data => data, :url => url, :user => @user, :password => @api_key,
    :headers => @headers, :verify_ssl => false) do |response|
      return response
    end
  end
end
