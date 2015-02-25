#
# For testing REST API via Rspec requests
#

require 'bcrypt'
require 'json'

module ApiSpecHelper
  HEADER_ALIASES = {
    "auth_token" => "HTTP_X_AUTH_TOKEN"
  }

  DEF_HEADERS = {
    "Content-Type" => "application/json",
    "Accept"       => "application/json"
  }

  API_STATUS = Rack::Utils::HTTP_STATUS_CODES.merge(0 => "Network Connection Error")

  def parse_response
    @code    = last_response.status
    @result  = (@code != Rack::Utils.status_code(:no_content)) ? JSON.parse(last_response.body) : {}
    @success = @code < 400
    @status  = API_STATUS[@code] || (@success ? Rack::Utils.status_code(:ok) : Rack::Utils.status_code(:bad_request))
    @message = @result.fetch_path("error", "message").to_s
    @success
  end

  def update_headers(headers)
    HEADER_ALIASES.keys.each do |k|
      if headers.key?(k)
        headers[HEADER_ALIASES[k]] = headers[k]
        headers.delete(k)
      end
    end
    headers.merge(DEF_HEADERS)
  end

  def run_get(url, headers = {})
    get url, {}, update_headers(headers)
    parse_response
  end

  def run_post(url, body = {}, headers = {})
    post url, {}, update_headers(headers).merge('RAW_POST_DATA' => body.to_json)
    parse_response
  end

  def run_delete(url, headers = {})
    delete url, {}, update_headers(headers)
    parse_response
  end

  def resources_include_suffix?(resources, key, suffix)
    resources.any? { |r| r.key?(key) && r[key].match("#{suffix}$") }
  end

  def resources_include?(resources, key, value)
    resources.any? { |r| r[key] == value }
  end

  def define_user
    @role  = FactoryGirl.create(:miq_user_role,
                                :name => @cfme[:role_name])

    @group = FactoryGirl.create(:miq_group,
                                :description      => @cfme[:group_name],
                                :miq_user_role_id => @role.id)

    @user  = FactoryGirl.create(:user,
                                :name             => @cfme[:user_name],
                                :userid           => @cfme[:user],
                                :password_digest  => BCrypt::Password.create(@cfme[:password]),
                                :miq_groups       => [@group],
                                :current_group_id => @group.id)
  end

  def init_api_spec_env
    MiqRegion.seed
    MiqDatabase.seed
    Vmdb::Application.config.secret_token = MiqDatabase.first.session_secret_token
    @guid, @server, @zone = EvmSpecHelper.create_guid_miq_server_zone

    @cfme = {
      :user       => "api_user_id",
      :password   => "api_user_password",
      :user_name  => "API User",
      :group_name => "API User Group",
      :role_name  => "API User Role",
      :auth_token => "",
      :entrypoint => "/api"
    }

    collections  = %w(auth vms tags providers hosts data_stores resource_pools clusters
                      policies policy_profiles templates policy_actions events conditions)

    collections.each { |collection| @cfme["#{collection}_url".to_sym] = "#{@cfme[:entrypoint]}/#{collection}" }

    define_user
    define_url_methods
  end

  def define_url_methods
    collections  = %w(vms tags providers hosts data_stores resource_pools clusters
                      policies policy_profiles templates policy_actions events conditions)

    collections.each do |collection|
      self.class.class_eval do
        define_method("#{collection}_url".to_sym) do
          @cfme["#{collection}_url".to_sym]
        end
        define_method("#{collection.singularize}_url".to_sym) do |id|
          "#{@cfme["#{collection}_url".to_sym]}/#{id}"
        end
      end
    end
  end

  def api_basic_authorize(identifier = nil)
    update_user_role(@role, identifier) unless identifier.blank?
    basic_authorize @cfme[:user], @cfme[:password]
  end

  def update_user_role(role, *identifiers)
    return if identifiers.blank?
    product_features = identifiers.collect do |identifier|
      MiqProductFeature.find_or_create_by_identifier(identifier)
    end
    role.update_attributes!(:miq_product_features => product_features)
  end

  def miq_server_guid
    @miq_server_guid ||= MiqUUID.new_guid
  end

  def api_config
    @api_config ||= YAML.load_file(Rails.root.join("config/api.yml"))
  end

  def collection_config
    api_config[:collections]
  end

  def action_identifier(type, action, selection = :resource_actions)
    collection_config.fetch_path(type, selection, :post)
      .detect { |spec| spec[:name] == action.to_s }[:identifier]
  end

  def collection_action_identifier(type, action)
    action_identifier(type, action, :collection_actions)
  end

  def subcollection_action_identifier(type, subtype, action)
    action_identifier(type, action, "#{subtype}_subcollection_actions".to_sym)
  end

  def gen_request(action, data = nil, *hrefs)
    request = {"action" => action.to_s}
    if hrefs.present?
      data ||= {}
      request["resources"] = hrefs.collect { |href| data.dup.merge("href" => href) }
    elsif data.present?
      request[data.kind_of?(Array) ? "resources" : "resource"] = data
    end
    request
  end

  def fetch_value(value)
    value.kind_of?(Symbol) && respond_to?(value) ? public_send(value) : value
  end
end
