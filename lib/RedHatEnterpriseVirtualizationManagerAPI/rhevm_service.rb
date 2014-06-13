require 'util/miq-extensions'
require_relative 'rhevm_exception'
require 'nokogiri'

class RhevmService
  DEFAULT_OPTIONS  = {}
  REQUIRED_OPTIONS = [:server, :username, :password]
  DEFAULT_PORT_3_0 = 8443
  DEFAULT_PORT_3_1 =  443
  DEFAULT_PORT     = DEFAULT_PORT_3_1
  DEFAULT_SCHEME   = 'https'.freeze
  SESSION_ID_KEY   = 'JSESSIONID'.freeze

  attr_accessor :session_id

  def self.name_to_class(name)
    require File.join(File.dirname(__FILE__), "./rhevm_#{name}")
    Kernel.const_get("Rhevm#{name.camelize}")
  end

  def xml_to_object(klass, xml)
    klass.create_from_xml(self, xml)
  end

  def initialize(options={})
    @options = DEFAULT_OPTIONS.merge(options)
    parse_domain_name
    REQUIRED_OPTIONS.each { |key| raise "No #{key.to_s} specified" unless @options.has_key?(key) }
    @password = @options.delete(:password)
    @session_id = @options[:session_id]
  end

  def inspect # just like the default inspect, but WITHOUT @password
    "#<#{self.class.name}:0x#{(self.object_id << 1).to_s(16).rjust(14,'0')} @options=#{@options.inspect}>"
  end

  def api(reload = false)
    @api   = nil if reload
    @api ||= xml_to_object(RhevmApi, resource_get)
  end

  def product_info
    @product_info ||= api[:product_info]
  end

  def name
    @name ||= product_info[:name]
  end

  def vendor
    @vendor ||= product_info[:vendor]
  end

  def version
    @version ||= product_info[:version]
  end

  def version_string
    @version_string ||= "#{version[:major]}.#{version[:minor]}.#{version[:revision]}.#{version[:build]}"
  end

  def version_3_0?
    version_string.starts_with?("3.0")
  end

  def summary
    api(true)[:summary] # This is volatile information
  end

  def special_objects
    @special_objects ||= api[:special_objects]
  end

  def blank_template
    @blank_template ||= begin
      href = special_objects[:"templates/blank"]
      href.blank? ? nil : RhevmTemplate.find_by_href(self, href)
    end
  end

  def root_tag
    @root_tag ||= begin
      href = special_objects[:"tags/root"]
      href.blank? ? nil : RhevmTag.find_by_href(self, href)
    end
  end

  def iso_storage_domain
    @iso_storage_domain ||= RhevmStorageDomain.iso_storage_domain(self)
  end

  def iso_images
    iso_storage_domain.nil? ? [] : iso_storage_domain.iso_images
  end

  def disconnect
  end

  def get_resource_by_ems_ref(uri_suffix, element_name = nil)
    xml     = resource_get(uri_suffix)
    doc     = Nokogiri::XML(xml)
    element_name ||= doc.root.name
    klass   = self.class.name_to_class(element_name)
    xml_to_object(klass, doc.root)
  end

  def standard_collection(uri_suffix, element_name = nil, paginate=false, sort_by=:name)
    if paginate
      doc = paginate_resource_get(uri_suffix, sort_by)
    else
      xml = resource_get(uri_suffix)
      doc = Nokogiri::XML(xml)
    end
    element_name ||= uri_suffix.singularize
    klass   = self.class.name_to_class(element_name)

    xml_path = uri_suffix == 'api' ? element_name : "#{element_name.pluralize}/#{element_name}"
    objects = doc.xpath("//#{xml_path}")
    objects.collect { |obj| xml_to_object(klass, obj) }
  end

  def status(link)
    response = resource_get(link)

    node = RhevmObject.xml_to_nokogiri(response)
    node.xpath('status/state').text
  end

  def api_uri(path = nil)
    uri = "#{base_uri}/api"
    unless path.nil?
      parts = path.to_s.split('/')
      parts.shift if parts.first == ''    # Remove leading slash
      parts.shift if parts.first == 'api' # We already have /api in our URI
      uri += "/#{parts.join('/')}" unless parts.empty?
    end
    uri
  end

  def paginate_resource_get(path = nil, sort_by=:name, direction=:asc)
    log_header = "#{self.class.name}#paginate_resource_get"
    page = 1
    full_xml = nil
    loop do
      uri = "#{path}?search=sortby%20#{sort_by}%20#{direction}%20page%20#{page}"
      partial_xml_str = self.resource_get(uri)
      if full_xml.nil?
        full_xml = Nokogiri::XML(partial_xml_str)
      else
        partial_xml = Nokogiri::XML(partial_xml_str)
        break if partial_xml.root.children.count == 0
        $rhevm_log.debug "#{log_header}: Combining resource elements for <#{path}> from page:<#{page}>" if $rhevm_log && $rhevm_log.debug?
        full_xml.root << partial_xml.root.children
      end
      page += 1
    end
    $rhevm_log.debug "#{log_header}: Combined elements for <#{path}>.  Total elements:<#{full_xml.root.children.count}>" if $rhevm_log && $rhevm_log.debug?
    return full_xml
  end

  def resource_get(path = nil)
    resource_verb(path, :get)
  end

  def resource_put(path, payload, additional_headers={:content_type => :xml, :accept => :xml})
    resource_verb(path, :put, payload, additional_headers)
  end

  def resource_post(path, payload, additional_headers={:content_type => :xml, :accept => :xml})
    resource_verb(path, :post, payload, additional_headers)
  end

  def resource_delete(path)
    resource_verb(path, :delete)
  end

  def create_resource(path = nil)
    require "rest-client"
    RestClient::Resource.new(api_uri(path), resource_options)
  end

  private

  def resource_verb(path, verb, *args)
    log_header = "#{self.class.name}#resource_#{verb}"

    resource = create_resource(path)
    $rhevm_log.info "#{log_header}: Sending URL: <#{resource.url}>" if $rhevm_log
    $rhevm_log.debug "#{log_header}: With args: <#{args.inspect}>" if $rhevm_log.try(:debug?)
    resource.send(verb, *args) do |response, request, result, &block|
      case response.code
      when 200
        parse_normal_response(response, resource)
      when 400, 409
        parse_error_response(response)
      else
        response.return!(request, result, &block)
      end
    end
  rescue RestClient::Unauthorized
    if self.session_id
      self.session_id = nil
      retry
    else
      raise
    end
  rescue RestClient::ResourceNotFound, RhevmApiError
    raise
  rescue Exception => e
    msg = "#{log_header}: class = #{e.class.name}, message=#{e.message}, URI=#{resource.url}"
    if $rhevm_log.nil?
      puts msg
    else
      $rhevm_log.error msg
    end
    raise
  end

  def parse_normal_response(response, resource)
    parse_set_cookie_header(response.headers[:set_cookie])
    if $rhevm_log
      log_header = "#{self.class.name}#parse_normal_response"
      $rhevm_log.info  "#{log_header}: Return from URL: <#{resource.url}> Data length:#{response.length}"
      $rhevm_log.debug "#{log_header}: Return from URL: <#{resource.url}> Data:#{response}" if $rhevm_log.debug?
    end
    response
  end

  def parse_error_response(response)
    doc    = Nokogiri::XML(response)
    action = doc.xpath("action").first
    node   = action || doc
    reason = node.xpath("fault/detail").text
    raise RhevmApiError, reason
  end

  def parse_set_cookie_header(set_cookie_header)
    set_cookie_header = set_cookie_header.first if set_cookie_header.kind_of?(Array)
    set_cookie_header.to_s.split(";").each do |kv|
      k, v = kv.strip.split("=")
      self.session_id = v if k == SESSION_ID_KEY
    end
  end

  def base_uri
    if port.blank?
      "#{scheme}://#{server}"
    else
      "#{scheme}://#{server}:#{port}"
    end
  end

  def resource_options
    headers = merge_headers({ 'Prefer' => 'persistent-auth' })
    options = { :ssl_version => :SSLv3 }

    if self.session_id
      headers[:cookie]     = "#{SESSION_ID_KEY}=#{self.session_id}"
    else
      options[:user]       = fully_qualified_username
      options[:password]   = password
    end

    options[:headers]      = headers
    options[:timeout]      = timeout      if timeout
    options[:open_timeout] = open_timeout if open_timeout
    options
  end

  def merge_headers(hash)
    h = @options[:headers] || {}
    h.merge(hash)
  end

  def authorization_header
    @authorization_header ||= { :authorization => "Basic #{authorization_value}" }
  end

  def authorization_value
    @authorization_value ||= begin
      require "base64"
      Base64.encode64 "#{fully_qualified_username}:#{password}"
    end
  end

  def scheme
    @options[:scheme] || DEFAULT_SCHEME
  end

  def server
    @options[:server]
  end

  def port
    @options[:port] || DEFAULT_PORT
  end

  def fully_qualified_username
    domain.blank? ? username : "#{username}@#{domain}"
  end

  def username
    @options[:username]
  end

  def password
    @password
  end

  def domain
    @options[:domain]
  end

  def timeout
    @options[:timeout]        # NetHTTPSession's read_timeout
  end

  def open_timeout
    @options[:open_timeout]   # NetHTTPSessions's open_timeout
  end

  # Parse domain out of the username string
  def parse_domain_name
    if @options[:domain].blank? && !@options[:username].blank?
      if @options[:username].include?('\\')
        @options[:domain], @options[:username] = username.split('\\')
      elsif @options[:username].include?('/')
        @options[:domain], @options[:username] = username.split('/')
      end
    end
  end

end
