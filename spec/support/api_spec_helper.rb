#
# For testing REST API via Rspec requests
#

require 'bcrypt'
require 'json'

module ApiSpecHelper
  HEADER_ALIASES = {
    "auth_token" => "HTTP_X_AUTH_TOKEN",
    "miq_group"  => "HTTP_X_MIQ_GROUP"
  }

  DEF_HEADERS = {
    "Content-Type" => "application/json",
    "Accept"       => "application/json"
  }

  def response_hash
    JSON.parse(response.body)
  end

  def update_headers(headers)
    HEADER_ALIASES.keys.each do |k|
      if headers.key?(k)
        headers[HEADER_ALIASES[k]] = headers[k]
        headers.delete(k)
      end
    end
    headers.merge!("HTTP_AUTHORIZATION" => @http_authorization) if @http_authorization
    headers.merge(DEF_HEADERS)
  end

  def run_get(url, options = {})
    headers = options.delete(:headers) || {}
    get url, :params => options.stringify_keys, :headers => update_headers(headers)
  end

  def run_post(url, body = {}, headers = {})
    post url, :headers => update_headers(headers).merge('RAW_POST_DATA' => body.to_json)
  end

  def run_put(url, body = {}, headers = {})
    put url, :headers => update_headers(headers).merge('RAW_POST_DATA' => body.to_json)
  end

  def run_patch(url, body = {}, headers = {})
    patch url, :headers => update_headers(headers).merge('RAW_POST_DATA' => body.to_json)
  end

  def run_delete(url, headers = {})
    delete url, :headers => update_headers(headers)
  end

  def resources_include_suffix?(resources, key, suffix)
    resources.any? { |r| r.key?(key) && r[key].match("#{suffix}$") }
  end

  def resources_include?(resources, key, value)
    resources.any? { |r| r[key] == value }
  end

  def api_config(param)
    @api_config = {
      :user       => "api_user_id",
      :password   => "api_user_password",
      :user_name  => "API User",
      :group_name => "API User Group",
      :role_name  => "API User Role",
      :entrypoint => "/api"
    }
    @api_config[param]
  end

  def define_user
    @role  = FactoryGirl.create(:miq_user_role, :name => api_config(:role_name))
    @group = FactoryGirl.create(:miq_group, :description => api_config(:group_name), :miq_user_role => @role)
    @user  = FactoryGirl.create(:user,
                                :name             => api_config(:user_name),
                                :userid           => api_config(:user),
                                :password         => api_config(:password),
                                :miq_groups       => [@group],
                                :current_group_id => @group.id)
  end

  def init_api_spec_env
    MiqDatabase.seed
    Vmdb::Application.config.secret_token = MiqDatabase.first.session_secret_token
    @guid, @server, @zone = EvmSpecHelper.create_guid_miq_server_zone

    collections = %w(automation_requests availability_zones categories chargebacks clusters conditions
                     data_stores events features flavors groups hosts instances pictures policies policy_actions
                     policy_profiles providers provision_dialogs provision_requests rates
                     reports request_tasks requests resource_pools results roles security_groups
                     servers service_dialogs service_catalogs service_orders service_requests
                     service_templates services settings tags tasks templates tenants users virtual_templates vms zones
                     container_deployments)

    define_entrypoint_url_methods
    define_url_methods(collections)
    define_user

    ApplicationController.handle_exceptions = true
  end

  def define_entrypoint_url_methods
    self.class.class_eval do
      define_method(:entrypoint_url) do
        api_config(:entrypoint)
      end
      define_method(:auth_url) do
        "#{api_config(:entrypoint)}/auth"
      end
    end
  end

  def define_url_methods(collections)
    collections.each do |collection|
      self.class.class_eval do
        define_method("#{collection}_url".to_sym) do |id = nil|
          path = "#{api_config(:entrypoint)}/#{collection}"
          id.nil? ? path : "#{path}/#{id}"
        end
      end
    end
  end

  def api_basic_authorize(*identifiers)
    update_user_role(@role, *identifiers)
    basic_authorize api_config(:user), api_config(:password)
  end

  def basic_authorize(user, password)
    @http_authorization = ActionController::HttpAuthentication::Basic.encode_credentials(user, password)
  end

  def update_user_role(role, *identifiers)
    return if identifiers.blank?
    product_features = identifiers.collect do |identifier|
      MiqProductFeature.find_or_create_by(:identifier => identifier)
    end
    role.update_attributes!(:miq_product_features => product_features)
  end

  def miq_server_guid
    @miq_server_guid ||= MiqUUID.new_guid
  end

  def action_identifier(type, action, selection = :resource_actions, method = :post)
    Api::Settings.collections.fetch_path(type, selection, method)
      .detect { |spec| spec[:name] == action.to_s }[:identifier]
  end

  def collection_action_identifier(type, action, method = :post)
    action_identifier(type, action, :collection_actions, method)
  end

  def subcollection_action_identifier(type, subtype, action, method = :post)
    subtype_actions = "#{subtype}_subcollection_actions".to_sym
    if Api::Settings.collections.fetch_path(type, subtype_actions).present?
      action_identifier(type, action, subtype_actions, method)
    else
      action_identifier(subtype, action, :subcollection_actions, method)
    end
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

  def declare_actions(*names)
    include("actions" => a_collection_containing_exactly(*names.map { |name| a_hash_including("name" => name) }))
  end

  def include_actions(*names)
    include("actions" => a_collection_including(*names.map { |name| a_hash_including("name" => name) }))
  end

  # Rest API Expects

  def expect_request_success
    expect(response).to have_http_status(:ok)
  end

  def expect_request_success_with_no_content
    expect(response).to have_http_status(:no_content)
  end

  def expect_bad_request(error_message = nil)
    expect(response).to have_http_status(:bad_request)
    return if error_message.blank?

    expect(response_hash).to have_key("error")
    expect(response_hash["error"]["message"]).to match(error_message)
  end

  def expect_user_unauthorized
    expect(response).to have_http_status(:unauthorized)
  end

  def expect_request_forbidden
    expect(response).to have_http_status(:forbidden)
  end

  def expect_resource_not_found
    expect(response).to have_http_status(:not_found)
  end

  def expect_result_resources_to_include_data(collection, data)
    expect(response_hash).to have_key(collection)
    fetch_value(data).each do |key, value|
      value_list = fetch_value(value)
      expect(response_hash[collection].size).to eq(value_list.size)
      expect(response_hash[collection].collect { |r| r[key] }).to match_array(value_list)
    end
  end

  def expect_result_resources_to_include_hrefs(collection, hrefs)
    expect(response_hash).to have_key(collection)
    href_list = fetch_value(hrefs)
    expect(response_hash[collection].size).to eq(href_list.size)
    href_list.each do |href|
      expect(resources_include_suffix?(response_hash[collection], "href", href)).to be_truthy
    end
  end

  def expect_result_resources_to_match_key_data(collection, key, values)
    value_list = fetch_value(values)
    expect(response_hash).to have_key(collection)
    expect(response_hash[collection].size).to eq(value_list.size)
    value_list.zip(response_hash[collection]) do |value, hash|
      expect(hash).to have_key(key)
      expect(hash[key]).to match(value)
    end
  end

  def expect_result_resource_keys_to_match_pattern(collection, key, pattern)
    pattern = fetch_value(pattern)
    expect(response_hash).to have_key(collection)
    expect(response_hash[collection].all? { |result| result[key].match(pattern) }).to be_truthy
  end

  def expect_result_to_have_keys(keys)
    expect_hash_to_have_keys(response_hash, keys)
  end

  def expect_hash_to_have_keys(hash, keys)
    fetch_value(keys).each { |key| expect(hash).to have_key(key) }
  end

  def expect_result_to_have_only_keys(keys)
    expect_hash_to_have_only_keys(response_hash, keys)
  end

  def expect_hash_to_have_only_keys(hash, keys)
    expect(hash.keys).to match_array(fetch_value(keys))
  end

  def expect_result_to_match_hash(result, attr_hash)
    attr_hash = fetch_value(attr_hash)
    attr_hash.each do |key, value|
      value = fetch_value(value)
      attr_hash[key] = (key == "href" || key.ends_with?("_href")) ? a_string_matching(value) : value
    end
    expect(result).to include(attr_hash)
  end

  def expect_results_to_match_hash(collection, result_hash)
    expect(response_hash).to have_key(collection)
    fetch_value(result_hash).zip(response_hash[collection]) do |expected, actual|
      expect_result_to_match_hash(actual, expected)
    end
  end

  def expect_result_resources_to_match_hash(result_hash)
    expect_results_to_match_hash("resources", result_hash)
  end

  def expect_result_resource_keys_to_be_like_klass(collection, key, klass)
    expect(response_hash).to have_key(collection)
    expect(response_hash[collection].all? { |result| result[key].kind_of?(klass) }).to be_truthy
  end

  def expect_result_resources_to_include_keys(collection, keys)
    expect(response_hash).to have_key(collection)
    results = response_hash[collection]
    fetch_value(keys).each { |key| expect(results.all? { |r| r.key?(key) }).to be_truthy, "resource missing: #{key}" }
  end

  def expect_result_resources_to_have_only_keys(collection, keys)
    key_list = fetch_value(keys).sort
    expect(response_hash).to have_key(collection)
    expect(response_hash[collection].all? { |result| result.keys.sort == key_list }).to be_truthy
  end

  def expect_results_match_key_pattern(collection, key, value)
    pattern = fetch_value(value)
    expect(response_hash).to have_key(collection)
    expect(response_hash[collection].all? { |result| result[key].match(pattern) }).to be_truthy
  end

  def expect_result_to_represent_task(result)
    expect(result).to have_key("task_id")
    expect(result).to have_key("task_href")
  end

  # Primary result construct methods

  def expect_empty_query_result(collection)
    expect_request_success
    expect(response_hash).to include("name" => collection.to_s, "resources" => [])
  end

  def expect_query_result(collection, subcount, count = nil)
    expect_request_success
    expect(response_hash).to include("name" => collection.to_s, "subcount" => fetch_value(subcount))
    expect(response_hash["resources"].size).to eq(fetch_value(subcount))
    expect(response_hash["count"]).to eq(fetch_value(count)) if count.present?
  end

  def expect_single_resource_query(attr_hash = {})
    expect_request_success
    expect_result_to_match_hash(response_hash, fetch_value(attr_hash))
  end

  def expect_single_action_result(options = {})
    expect_request_success
    expect(response_hash).to include("success" => options[:success]) if options.key?(:success)
    expect(response_hash).to include("message" => a_string_matching(options[:message])) if options[:message]
    expect(response_hash).to include("href" => a_string_matching(fetch_value(options[:href]))) if options[:href]
    expect_result_to_represent_task(response_hash) if options[:task]
  end

  def expect_multiple_action_result(count, options = {})
    expect_request_success
    expect(response_hash).to have_key("results")
    results = response_hash["results"]
    expect(results.size).to eq(count)
    expect(results.all? { |r| r["success"] }).to be_truthy

    results.each { |r| expect_result_to_represent_task(r) } if options[:task]
  end

  def expect_tagging_result(tagging_results)
    expect_request_success
    tag_results = fetch_value(tagging_results)
    expect(response_hash).to have_key("results")
    results = response_hash["results"]
    expect(results.size).to eq(tag_results.size)
    tag_results.zip(results) do |tag_result, result|
      expect(result).to include(
        "success"      => tag_result[:success],
        "href"         => a_string_matching(tag_result[:href]),
        "tag_category" => tag_result[:tag_category],
        "tag_name"     => tag_result[:tag_name]
      )
    end
  end
end
