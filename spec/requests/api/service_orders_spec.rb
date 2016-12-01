RSpec.describe "service orders API" do
  it "can list all service orders" do
    service_order = FactoryGirl.create(:shopping_cart, :user => @user)
    api_basic_authorize collection_action_identifier(:service_orders, :read, :get)

    run_get service_orders_url

    expect(response).to have_http_status(:ok)
    expect_result_resources_to_include_hrefs("resources", [service_orders_url(service_order.id)])
  end

  it "won't show another user's service orders" do
    shopping_cart_for_user = FactoryGirl.create(:shopping_cart, :user => @user)
    _shopping_cart_for_some_other_user = FactoryGirl.create(:shopping_cart)
    api_basic_authorize collection_action_identifier(:service_orders, :read, :get)

    run_get service_orders_url

    expected = {
      "count"     => 2,
      "subcount"  => 1,
      "resources" => [{"href" => a_string_matching(service_orders_url(shopping_cart_for_user.id))}]
    }
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include(expected)
  end

  it "can create a service order" do
    api_basic_authorize collection_action_identifier(:service_orders, :create)

    expect do
      run_post service_orders_url, :name => "service order", :state => "wish"
    end.to change(ServiceOrder, :count).by(1)

    expect(response).to have_http_status(:ok)
  end

  it "can create multiple service orders" do
    api_basic_authorize collection_action_identifier(:service_orders, :create)

    expect do
      run_post(service_orders_url,
               :action => "create", :resources => [{:name => "service order 1", :state => "wish"},
                                                   {:name => "service order 2", :state => "wish"}])
    end.to change(ServiceOrder, :count).by(2)
    expect(response).to have_http_status(:ok)
  end

  specify "the default state for a service order is 'cart'" do
    api_basic_authorize collection_action_identifier(:service_orders, :create)

    run_post(service_orders_url, :name => "shopping cart")

    expect(response.parsed_body).to include("results" => [a_hash_including("state" => ServiceOrder::STATE_CART)])
  end

  specify "a service order cannot be created in the 'ordered' state" do
    api_basic_authorize collection_action_identifier(:service_orders, :create)

    expect do
      run_post(service_orders_url, :name => "service order", :state => ServiceOrder::STATE_ORDERED)
    end.not_to change(ServiceOrder, :count)

    expect(response).to have_http_status(:bad_request)
    expected = {"error" => a_hash_including("message" => /can't create an ordered service order/i)}
    expect(response.parsed_body).to include(expected)
  end

  it "can read a service order" do
    service_order = FactoryGirl.create(:service_order, :user => @user)
    api_basic_authorize action_identifier(:service_orders, :read, :resource_actions, :get)

    run_get service_orders_url(service_order.id)

    expect_result_to_match_hash(response.parsed_body, "name" => service_order.name, "state" => service_order.state)
    expect(response).to have_http_status(:ok)
  end

  it "can show the shopping cart" do
    shopping_cart = FactoryGirl.create(:shopping_cart, :user => @user)
    api_basic_authorize action_identifier(:service_orders, :read, :resource_actions, :get)

    run_get service_orders_url("cart")

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to include("id"   => shopping_cart.id,
                                     "href" => a_string_matching(service_orders_url(shopping_cart.id)))
  end

  it "returns an empty response when there is no shopping cart" do
    api_basic_authorize action_identifier(:service_orders, :read, :resource_actions, :get)

    run_get service_orders_url("cart")

    expect(response).to have_http_status(:not_found)
    expect(response.parsed_body).to include("error" => a_hash_including("kind"    => "not_found",
                                                                 "message" => /Couldn't find ServiceOrder/))
  end

  it "can update a service order" do
    service_order = FactoryGirl.create(:service_order, :name => "old name", :user => @user)
    api_basic_authorize action_identifier(:service_orders, :edit)

    run_post service_orders_url(service_order.id), :action => "edit", :resource => {:name => "new name"}

    expect_result_to_match_hash(response.parsed_body, "name" => "new name")
    expect(response).to have_http_status(:ok)
  end

  it "can update multiple service orders" do
    service_order_1 = FactoryGirl.create(:service_order, :user => @user, :name => "old name 1")
    service_order_2 = FactoryGirl.create(:service_order, :user => @user, :name => "old name 2")
    api_basic_authorize collection_action_identifier(:service_orders, :edit)

    run_post(service_orders_url,
             :action => "edit", :resources => [{:id => service_order_1.id, :name => "new name 1"},
                                               {:id => service_order_2.id, :name => "new name 2"}])

    expect_results_to_match_hash("results", [{"name" => "new name 1"}, {"name" => "new name 2"}])
    expect(response).to have_http_status(:ok)
  end

  it "can delete a service order" do
    service_order = FactoryGirl.create(:service_order, :user => @user)
    api_basic_authorize action_identifier(:service_orders, :delete, :resource_actions, :delete)

    expect do
      run_delete service_orders_url(service_order.id)
    end.to change(ServiceOrder, :count).by(-1)
    expect(response).to have_http_status(:no_content)
  end

  it "can delete a service order through POST" do
    service_order = FactoryGirl.create(:service_order, :user => @user)
    api_basic_authorize action_identifier(:service_orders, :delete)

    expect do
      run_post service_orders_url(service_order.id), :action => "delete"
    end.to change(ServiceOrder, :count).by(-1)
    expect(response).to have_http_status(:ok)
  end

  it "can delete multiple service orders" do
    service_order_1 = FactoryGirl.create(:service_order, :user => @user, :name => "old name")
    service_order_2 = FactoryGirl.create(:service_order, :user => @user, :name => "old name")
    api_basic_authorize collection_action_identifier(:service_orders, :delete)

    expect do
      run_post(service_orders_url,
               :action => "delete", :resources => [{:id => service_order_1.id},
                                                   {:id => service_order_2.id}])
    end.to change(ServiceOrder, :count).by(-2)
    expect(response).to have_http_status(:ok)
  end

  context "service requests subcollection" do
    context "with an appropriate role" do
      it "can list a shopping cart's service requests" do
        service_request = FactoryGirl.create(:service_template_provision_request, :requester => @user)
        _shopping_cart = FactoryGirl.create(:shopping_cart, :user => @user, :miq_requests => [service_request])
        api_basic_authorize action_identifier(:service_requests, :read, :subcollection_actions, :get)

        url = "#{service_orders_url("cart")}/service_requests"
        run_get url

        expected_href = a_string_matching("#{url}/#{service_request.id}")
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to include("count"     => 1,
                                         "name"      => "service_requests",
                                         "resources" => [a_hash_including("href" => expected_href)],
                                         "subcount"  => 1)
      end

      it "can show a shopping cart's service request" do
        service_request = FactoryGirl.create(:service_template_provision_request, :requester => @user)
        _shopping_cart = FactoryGirl.create(:shopping_cart, :user => @user, :miq_requests => [service_request])
        api_basic_authorize action_identifier(:service_requests, :read, :subresource_actions, :get)

        url = "#{service_orders_url("cart")}/service_requests/#{service_request.id}"
        run_get url

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to include("id" => service_request.id, "href" => a_string_matching(url))
      end

      it "can add a service request to a shopping cart" do
        dialog = FactoryGirl.create(:dialog_with_tab_and_group_and_field)
        service_template = FactoryGirl.create(:service_template)
        service_template.resource_actions << FactoryGirl.create(:resource_action,
                                                                :action => "Provision",
                                                                :dialog => dialog)
        shopping_cart = FactoryGirl.create(:shopping_cart, :user => @user)
        api_basic_authorize action_identifier(:service_requests, :add, :subcollection_actions)

        expect do
          run_post("#{service_orders_url("cart")}/service_requests",
                   :action    => :add,
                   :resources => [{:service_template_href => service_templates_url(service_template.id)}])
        end.to change { shopping_cart.reload.miq_requests.count }.by(1)

        actual_requests = shopping_cart.reload.miq_requests
        expected = {
          "results" => [
            a_hash_including(
              "success"              => true,
              "message"              => /Adding service_request/,
              "service_request_id"   => actual_requests.first.id,
              "service_request_href" => a_string_matching(service_requests_url(actual_requests.first.id))
            )
          ]
        }
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to include(expected)
      end

      it "can add muliple service requests to a shopping cart by href" do
        dialog = FactoryGirl.create(:dialog_with_tab_and_group_and_field)

        service_template_1, service_template_2 = FactoryGirl.create_list(:service_template, 2)
        service_template_1.resource_actions << FactoryGirl.create(:resource_action,
                                                                  :action => "Provision",
                                                                  :dialog => dialog)
        service_template_2.resource_actions << FactoryGirl.create(:resource_action,
                                                                  :action => "Provision",
                                                                  :dialog => dialog)

        shopping_cart = FactoryGirl.create(:shopping_cart, :user => @user)
        api_basic_authorize action_identifier(:service_requests, :add, :subcollection_actions)

        expect do
          run_post(
            "#{service_orders_url("cart")}/service_requests",
            :action    => :add,
            :resources => [
              {:service_template_href => service_templates_url(service_template_1.id)},
              {:service_template_href => service_templates_url(service_template_2.id)}
            ]
          )
        end.to change { shopping_cart.reload.miq_requests.count }.by(2)

        actual_requests = shopping_cart.reload.miq_requests
        expected = {
          "results" => a_collection_containing_exactly(
            a_hash_including(
              "success"              => true,
              "message"              => /Adding service_request/,
              "service_request_id"   => actual_requests.first.id,
              "service_request_href" => a_string_matching(service_requests_url(actual_requests.first.id))
            ),
            a_hash_including(
              "success"              => true,
              "message"              => /Adding service_request/,
              "service_request_id"   => actual_requests.second.id,
              "service_request_href" => a_string_matching(service_requests_url(actual_requests.second.id))
            )
          )
        }
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to include(expected)
      end

      it "can remove a service request from a shopping cart" do
        service_request = FactoryGirl.create(:service_template_provision_request, :requester => @user)
        shopping_cart = FactoryGirl.create(:shopping_cart, :user => @user, :miq_requests => [service_request])
        api_basic_authorize action_identifier(:service_requests, :remove, :subresource_actions)

        run_post "#{service_orders_url("cart")}/service_requests/#{service_request.id}", :action => :remove

        expected = {
          "success"              => true,
          "message"              => a_string_starting_with("Removing Service Request id:#{service_request.id}"),
          "service_request_href" => a_string_matching(service_requests_url(service_request.id)),
          "service_request_id"   => service_request.id
        }
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to include(expected)
        expect(shopping_cart.reload.miq_requests).not_to include(service_request)
      end

      it "can remove multiple service requests from a shopping cart by href" do
        service_request_1, service_request_2 = FactoryGirl.create_list(:service_template_provision_request,
                                                                       2,
                                                                       :requester => @user)
        shopping_cart = FactoryGirl.create(:shopping_cart,
                                           :user         => @user,
                                           :miq_requests => [service_request_1, service_request_2])
        api_basic_authorize action_identifier(:service_requests, :remove, :subcollection_actions)

        run_post(
          "#{service_orders_url("cart")}/service_requests",
          :action    => :remove,
          :resources => [
            {:href => service_requests_url(service_request_1.id)},
            {:href => service_requests_url(service_request_2.id)}
          ]
        )

        expected = {
          "results" => a_collection_containing_exactly(
            a_hash_including(
              "success"              => true,
              "message"              => a_string_starting_with("Removing Service Request id:#{service_request_1.id}"),
              "service_request_href" => a_string_matching(service_requests_url(service_request_1.id)),
              "service_request_id"   => service_request_1.id
            ),
            a_hash_including(
              "success"              => true,
              "message"              => a_string_starting_with("Removing Service Request id:#{service_request_2.id}"),
              "service_request_href" => a_string_matching(service_requests_url(service_request_2.id)),
              "service_request_id"   => service_request_2.id
            )
          )
        }
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to include(expected)
        expect(shopping_cart.reload.miq_requests).not_to include(service_request_1, service_request_2)
      end

      it "can remove multiple service requests from a shopping cart by id" do
        service_request_1, service_request_2 = FactoryGirl.create_list(:service_template_provision_request,
                                                                       2,
                                                                       :requester => @user)
        shopping_cart = FactoryGirl.create(:shopping_cart,
                                           :user         => @user,
                                           :miq_requests => [service_request_1, service_request_2])
        api_basic_authorize action_identifier(:service_requests, :remove, :subcollection_actions)

        run_post(
          "#{service_orders_url("cart")}/service_requests",
          :action    => :remove,
          :resources => [
            {:id => service_request_1.id},
            {:id => service_request_2.id}
          ]
        )

        expected = {
          "results" => a_collection_containing_exactly(
            a_hash_including(
              "success"              => true,
              "message"              => a_string_starting_with("Removing Service Request id:#{service_request_1.id}"),
              "service_request_href" => a_string_matching(service_requests_url(service_request_1.id)),
              "service_request_id"   => service_request_1.id
            ),
            a_hash_including(
              "success"              => true,
              "message"              => a_string_starting_with("Removing Service Request id:#{service_request_2.id}"),
              "service_request_href" => a_string_matching(service_requests_url(service_request_2.id)),
              "service_request_id"   => service_request_2.id
            )
          )
        }
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to include(expected)
        expect(shopping_cart.reload.miq_requests).not_to include(service_request_1, service_request_2)
      end

      it "can clear a shopping cart" do
        service_request_1, service_request_2 = FactoryGirl.create_list(:service_template_provision_request,
                                                                       2,
                                                                       :requester => @user)
        shopping_cart = FactoryGirl.create(:shopping_cart,
                                           :user         => @user,
                                           :miq_requests => [service_request_1, service_request_2])
        api_basic_authorize action_identifier(:service_orders, :clear)

        run_post service_orders_url("cart"), :action => :clear

        expected = {
          "href" => a_string_matching(service_orders_url(shopping_cart.id)),
          "id"   => shopping_cart.id
        }
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to include(expected)
        expect(shopping_cart.reload.miq_requests).to be_empty
      end

      it "notifies that a shopping cart cannot be cleared if it has already been checked out" do
        service_request = FactoryGirl.create(:service_template_provision_request, :requester => @user)
        shopping_cart = FactoryGirl.create(:shopping_cart, :user => @user, :miq_requests => [service_request])
        api_basic_authorize action_identifier(:service_orders, :clear)

        shopping_cart.checkout
        run_post service_orders_url(shopping_cart.id), :action => :clear

        expected = {
          "error" => a_hash_including(
            "kind"    => "bad_request",
            "message" => a_string_matching(/Invalid operation \[clear\]/)
          )
        }
        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body).to include(expected)
      end

      it "can checkout a shopping cart" do
        service_request_1, service_request_2 = FactoryGirl.create_list(:service_template_provision_request,
                                                                       2,
                                                                       :requester => @user)
        shopping_cart = FactoryGirl.create(:shopping_cart,
                                           :user         => @user,
                                           :miq_requests => [service_request_1, service_request_2])
        api_basic_authorize action_identifier(:service_orders, :order)

        run_post service_orders_url("cart"), :action => :order

        expected = {
          "state" => ServiceOrder::STATE_ORDERED
        }
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to include(expected)
        expect(shopping_cart.reload.state).to eq(ServiceOrder::STATE_ORDERED)
      end
    end

    context "without an appropriate role" do
      it "will not list a shopping cart's service requests" do
        service_request = FactoryGirl.create(:service_template_provision_request, :requester => @user)
        _shopping_cart = FactoryGirl.create(:shopping_cart, :user => @user, :miq_requests => [service_request])
        api_basic_authorize

        run_get "#{service_orders_url("cart")}/service_requests"

        expect(response).to have_http_status(:forbidden)
      end

      it "will not show a service orders's shopping cart" do
        service_request = FactoryGirl.create(:service_template_provision_request, :requester => @user)
        _shopping_cart = FactoryGirl.create(:shopping_cart, :user => @user, :miq_requests => [service_request])
        api_basic_authorize

        run_get "#{service_orders_url("cart")}/service_requests/#{service_request.id}"

        expect(response).to have_http_status(:forbidden)
      end

      it "will not add a service request to a shopping cart" do
        dialog = FactoryGirl.create(:dialog_with_tab_and_group_and_field)
        service_template = FactoryGirl.create(:service_template)
        service_template.resource_actions << FactoryGirl.create(:resource_action,
                                                                :action => "Provision",
                                                                :dialog => dialog)
        shopping_cart = FactoryGirl.create(:shopping_cart, :user => @user)
        api_basic_authorize

        run_post "#{service_orders_url("cart")}/service_requests",
                 :action    => :add,
                 :resources => [{:service_template_href => service_templates_url(service_template.id)}]

        expect(response).to have_http_status(:forbidden)
        expect(shopping_cart.reload.miq_requests).to be_empty
      end

      it "will not add multiple service requests to a shopping cart" do
        dialog = FactoryGirl.create(:dialog_with_tab_and_group_and_field)
        service_template_1, service_template_2 = FactoryGirl.create_list(:service_template, 2)
        service_template_1.resource_actions << FactoryGirl.create(:resource_action,
                                                                  :action => "Provision",
                                                                  :dialog => dialog)
        service_template_2.resource_actions << FactoryGirl.create(:resource_action,
                                                                  :action => "Provision",
                                                                  :dialog => dialog)
        shopping_cart = FactoryGirl.create(:shopping_cart, :user => @user)
        api_basic_authorize

        expect do
          run_post(
            "#{service_orders_url("cart")}/service_requests",
            :action    => :add,
            :resources => [
              {:service_template_href => service_templates_url(service_template_1.id)},
              {:service_template_href => service_templates_url(service_template_2.id)}
            ]
          )
        end.not_to change { shopping_cart.reload.miq_requests.count }

        expect(response).to have_http_status(:forbidden)
      end

      it "will not remove a service request from a shopping cart" do
        service_request = FactoryGirl.create(:service_template_provision_request, :requester => @user)
        shopping_cart = FactoryGirl.create(:shopping_cart, :user => @user, :miq_requests => [service_request])
        api_basic_authorize

        run_post "#{service_orders_url("cart")}/service_requests/#{service_request.id}", :action => :remove

        expect(response).to have_http_status(:forbidden)
        expect(shopping_cart.reload.miq_requests).to include(service_request)
      end

      it "will not remove multiple service requests from a shopping cart" do
        service_request_1, service_request_2 = FactoryGirl.create_list(:service_template_provision_request,
                                                                       2,
                                                                       :requester => @user)
        shopping_cart = FactoryGirl.create(:shopping_cart,
                                           :user         => @user,
                                           :miq_requests => [service_request_1, service_request_2])
        api_basic_authorize

        run_post(
          "#{service_orders_url("cart")}/service_requests",
          :action    => :remove,
          :resources => [
            {:href => service_requests_url(service_request_1.id)},
            {:href => service_requests_url(service_request_2.id)}
          ]
        )

        expect(response).to have_http_status(:forbidden)
        expect(shopping_cart.reload.miq_requests).to include(service_request_1, service_request_2)
      end

      it "will not clear a shopping cart" do
        service_request_1, service_request_2 = FactoryGirl.create_list(:service_template_provision_request,
                                                                       2,
                                                                       :requester => @user)
        shopping_cart = FactoryGirl.create(:shopping_cart,
                                           :user         => @user,
                                           :miq_requests => [service_request_1, service_request_2])
        api_basic_authorize

        run_post service_orders_url("cart"), :action => :clear

        expect(response).to have_http_status(:forbidden)
        expect(shopping_cart.reload.miq_requests).to include(service_request_1, service_request_2)
      end

      it "will not checkout a shopping cart" do
        service_request_1, service_request_2 = FactoryGirl.create_list(:service_template_provision_request,
                                                                       2,
                                                                       :requester => @user)
        shopping_cart = FactoryGirl.create(:shopping_cart,
                                           :user         => @user,
                                           :miq_requests => [service_request_1, service_request_2])
        api_basic_authorize

        run_post service_orders_url("cart"), :action => :order

        expect(response).to have_http_status(:forbidden)
        expect(shopping_cart.reload.state).to eq(ServiceOrder::STATE_CART)
      end
    end
  end

  context 'Copy Service Order' do
    before do
      @service_order = FactoryGirl.create(:shopping_cart, :user => @user)
      @service_order_2 = FactoryGirl.create(:shopping_cart, :user => @user)
    end

    it 'forbids service order copy without an appropriate role' do
      api_basic_authorize

      run_post(service_orders_url(@service_order.id), :action => 'copy')

      expect(response).to have_http_status(:forbidden)
    end

    it 'can copy a single service order' do
      api_basic_authorize action_identifier(:service_orders, :copy)

      expect do
        run_post(service_orders_url(@service_order.id), :action => 'copy', :name => 'foo')
      end.to change(ServiceOrder, :count).by(1)
      expect(response.parsed_body).to include('name' => 'foo')
      expect(response).to have_http_status(:ok)
    end

    it 'can copy multiple service orders' do
      api_basic_authorize collection_action_identifier(:service_orders, :copy)

      expected = {
        'results' => a_collection_including(
          a_hash_including('name' => 'foo'),
          a_hash_including('name' => 'bar')
        )
      }
      expect do
        run_post(service_orders_url, :action => 'copy', :resources => [
                   { :id => @service_order.id, :name => 'foo'},
                   { :id => @service_order_2.id, :name => 'bar' }
                 ])
      end.to change(ServiceOrder, :count).by(2)
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end
  end
end
