#
# For testing REST API via Rspec requests
#

module Spec
  module Support
    module ApiHelper
      def headers
        @headers ||= {}
      end

      def run_get(url, options = {})
        headers = options.delete(:headers) || {}
        get url, :params => options, :headers => self.headers.merge!(headers)
      end

      def run_post(url, body = {}, headers = {})
        post url, :params => body.to_json, :headers => self.headers.merge!(headers)
      end

      def run_put(url, body = {}, headers = {})
        put url, :params => body.to_json, :headers => self.headers.merge!(headers)
      end

      def run_patch(url, body = {}, headers = {})
        patch url, :params => body.to_json, :headers => self.headers.merge!(headers)
      end

      def run_delete(url, headers = {})
        delete url, :headers => self.headers.merge!(headers)
      end

      def run_options(url, headers = {})
        options url, self.headers.merge!(headers)
      end

      def resources_include_suffix?(resources, key, suffix)
        resources.any? { |r| r.key?(key) && r[key].match("#{suffix}$") }
      end

      def api_config(param)
        @api_config ||= {
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
        @guid, @server, @zone = EvmSpecHelper.create_guid_miq_server_zone

        define_user
      end

      def entrypoint_url
        api_config(:entrypoint)
      end

      def auth_url
        "#{api_config(:entrypoint)}/auth"
      end

      (Api::ApiConfig.collections.keys - [:auth]).each do |collection|
        define_method("#{collection}_url".to_sym) do |id = nil|
          path = "#{api_config(:entrypoint)}/#{collection}"
          id.nil? ? path : "#{path}/#{id}"
        end
      end

      def api_basic_authorize(*identifiers)
        update_user_role(@role, *identifiers)
        basic_authorize api_config(:user), api_config(:password)
      end

      def basic_authorize(user, password)
        headers["HTTP_AUTHORIZATION"] = ActionController::HttpAuthentication::Basic.encode_credentials(user, password)
      end

      def update_user_role(role, *identifiers)
        return if identifiers.blank?
        product_features = identifiers.flatten.collect do |identifier|
          MiqProductFeature.find_or_create_by(:identifier => identifier)
        end
        role.update_attributes!(:miq_product_features => product_features)
      end

      def miq_server_guid
        @miq_server_guid ||= MiqUUID.new_guid
      end

      def stub_api_action_role(collection, action_type, method, action, identifier)
        new_action_role = Config::Options.new.merge!("name" => action.to_s, "identifier" => identifier)
        updated_method = Api::ApiConfig.collections[collection][action_type][method].collect do |method_action|
          method_action.name == action.to_s ? new_action_role : method_action
        end
        allow(Api::ApiConfig.collections[collection][action_type]).to receive(method) { updated_method }
      end

      def action_identifier(type, action, selection = :resource_actions, method = :post)
        Api::ApiConfig.collections[type][selection][method]
          .detect { |spec| spec[:name] == action.to_s }[:identifier]
      end

      def collection_action_identifier(type, action, method = :post)
        action_identifier(type, action, :collection_actions, method)
      end

      def subcollection_action_identifier(type, subtype, action, method = :post)
        subtype_actions = "#{subtype}_subcollection_actions".to_sym
        if Api::ApiConfig.collections[type][subtype_actions]
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

      def declare_actions(*names)
        include("actions" => a_collection_containing_exactly(*names.map { |name| a_hash_including("name" => name) }))
      end

      def include_actions(*names)
        include("actions" => a_collection_including(*names.map { |name| a_hash_including("name" => name) }))
      end

      def include_error_with_message(error_message)
        include("error" => hash_including("message" => a_string_matching(error_message)))
      end

      # Rest API Expects

      def expect_bad_request(error_message)
        expect(response.parsed_body).to include_error_with_message(error_message)
        expect(response).to have_http_status(:bad_request)
      end

      def expect_result_resources_to_include_data(collection, data)
        expect(response.parsed_body).to have_key(collection)
        data.each do |key, value_list|
          expect(response.parsed_body[collection].size).to eq(value_list.size)
          expect(response.parsed_body[collection].collect { |r| r[key] }).to match_array(value_list)
        end
      end

      def expect_result_resources_to_include_hrefs(collection, hrefs)
        expect(response.parsed_body).to have_key(collection)
        expect(response.parsed_body[collection].size).to eq(hrefs.size)
        hrefs.each do |href|
          expect(resources_include_suffix?(response.parsed_body[collection], "href", href)).to be_truthy
        end
      end

      def expect_result_to_have_keys(keys)
        expect(response.parsed_body).to include(*keys)
      end

      def expect_result_to_have_only_keys(keys)
        expect_hash_to_have_only_keys(response.parsed_body, keys)
      end

      def expect_hash_to_have_only_keys(hash, keys)
        expect(hash.keys).to match_array(keys)
      end

      def expect_result_to_match_hash(result, attr_hash)
        attr_hash.each do |key, value|
          attr_hash[key] = (key == "href" || key.ends_with?("_href")) ? a_string_matching(value) : value
        end
        expect(result).to include(attr_hash)
      end

      def expect_results_to_match_hash(collection, result_hash)
        expect(response.parsed_body).to have_key(collection)
        result_hash.zip(response.parsed_body[collection]) do |expected, actual|
          expect_result_to_match_hash(actual, expected)
        end
      end

      def expect_result_resources_to_match_hash(result_hash)
        expect_results_to_match_hash("resources", result_hash)
      end

      def expect_result_resources_to_include_keys(collection, keys)
        expect(response.parsed_body).to include(collection => all(a_hash_including(*keys)))
      end

      # Primary result construct methods

      def expect_empty_query_result(collection)
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to include("name" => collection.to_s, "resources" => [])
      end

      def expect_query_result(collection, subcount, count = nil)
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to include("name" => collection.to_s, "subcount" => subcount)
        expect(response.parsed_body["resources"].size).to eq(subcount)
        expect(response.parsed_body["count"]).to eq(count) if count.present?
      end

      def expect_single_resource_query(attr_hash)
        expect(response).to have_http_status(:ok)
        expect_result_to_match_hash(response.parsed_body, attr_hash)
      end

      def expect_single_action_result(options = {})
        expect(response).to have_http_status(:ok)
        expected = {}
        expected["success"] = options[:success] if options.key?(:success)
        expected["message"] = a_string_matching(options[:message]) if options[:message]
        expected["href"] = a_string_matching(options[:href]) if options[:href]
        expected.merge!(expected_task_response) if options[:task]
        expect(response.parsed_body).to include(expected)
        expect(response.parsed_body).not_to include("actions")
      end

      def expect_multiple_action_result(count, options = {})
        expect(response).to have_http_status(:ok)
        expected_result = {"success" => true}
        expected_result.merge!(expected_task_response) if options[:task]
        expected = {"results" => Array.new(count) { a_hash_including(expected_result) }}
        expect(response.parsed_body).to include(expected)
      end

      def expected_task_response
        {"task_id" => anything, "task_href" => anything}
      end

      def expect_tagging_result(tag_results)
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to have_key("results")
        results = response.parsed_body["results"]
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
  end
end
