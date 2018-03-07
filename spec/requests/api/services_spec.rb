#
# Rest API Request Tests - Services specs
#
# - Create service              /api/services/        action "create"
#
# - Edit service                /api/services/:id     action "edit"
# - Edit service via PUT        /api/services/:id     PUT
# - Edit service via PATCH      /api/services/:id     PATCH
# - Edit multiple services      /api/services         action "edit"
#
# - Delete service              /api/services/:id     DELETE
# - Delete multiple services    /api/services         action "delete"
#
# - Retire service now          /api/services/:id     action "retire"
# - Retire service future       /api/services/:id     action "retire"
# - Retire multiple services    /api/services         action "retire"
#
# - Reconfigure service         /api/services/:id     action "reconfigure"
#
# - Query vms subcollection     /api/services/:id/vms
#                               /api/services/:id?expand=vms
#   with subcollection
#   virtual attribute:          /api/services/:id?expand=vms&attributes=vms.cpu_total_cores
#
describe "Services API" do
  let(:svc)  { FactoryGirl.create(:service, :name => "svc",  :description => "svc description")  }
  let(:svc1) { FactoryGirl.create(:service, :name => "svc1", :description => "svc1 description") }
  let(:svc2) { FactoryGirl.create(:service, :name => "svc2", :description => "svc2 description") }
  let(:svc_orchestration) { FactoryGirl.create(:service_orchestration) }
  let(:orchestration_template) { FactoryGirl.create(:orchestration_template) }
  let(:ems) { FactoryGirl.create(:ext_management_system) }

  describe "Services create" do
    it "rejects requests without appropriate role" do
      api_basic_authorize

      run_post(services_url, gen_request(:create, "name" => "svc_new_1"))

      expect(response).to have_http_status(:forbidden)
    end

    it "supports creates of single resource" do
      api_basic_authorize collection_action_identifier(:services, :create)

      expect do
        run_post(services_url, gen_request(:create, "name" => "svc_new_1"))
      end.to change(Service, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect_results_to_match_hash("results", [{"name" => "svc_new_1"}])
    end

    it "supports creates of multiple resources" do
      api_basic_authorize collection_action_identifier(:services, :create)

      expect do
        run_post(services_url, gen_request(:create,
                                           [{"name" => "svc_new_1"},
                                            {"name" => "svc_new_2"}]))
      end.to change(Service, :count).by(2)

      expect(response).to have_http_status(:ok)
      expect_results_to_match_hash("results",
                                   [{"name" => "svc_new_1"},
                                    {"name" => "svc_new_2"}])
    end

    it 'supports creation of a single resource with href references' do
      api_basic_authorize collection_action_identifier(:services, :create)

      request = {
        'action'   => 'create',
        'resource' => {
          'type'                   => 'ServiceOrchestration',
          'name'                   => 'svc_new',
          'parent_service'         => { 'href' => services_url(svc1.id)},
          'orchestration_template' => { 'href' => orchestration_templates_url(orchestration_template.id) },
          'orchestration_manager'  => { 'href' => providers_url(ems.id) }
        }
      }
      expect do
        run_post(services_url, request)
      end.to change(Service, :count).by(1)
      expect(response).to have_http_status(:ok)
      expect_results_to_match_hash("results", [{"name" => "svc_new"}])
    end

    it 'supports creation of a single resource with id references' do
      api_basic_authorize collection_action_identifier(:services, :create)

      request = {
        'action'   => 'create',
        'resource' => {
          'type'                   => 'ServiceOrchestration',
          'name'                   => 'svc_new',
          'parent_service'         => { 'id' => svc1.id},
          'orchestration_template' => { 'id' => orchestration_template.id },
          'orchestration_manager'  => { 'id' => ems.id }
        }
      }
      expect do
        run_post(services_url, request)
      end.to change(Service, :count).by(1)
      expect(response).to have_http_status(:ok)
      expect_results_to_match_hash("results", [{"name" => "svc_new"}])
    end
  end

  describe "Services edit" do
    it "rejects requests without appropriate role" do
      api_basic_authorize

      run_post(services_url(svc.id), gen_request(:edit, "name" => "sample service"))

      expect(response).to have_http_status(:forbidden)
    end

    it "supports edits of single resource" do
      api_basic_authorize collection_action_identifier(:services, :edit)

      run_post(services_url(svc.id), gen_request(:edit, "name" => "updated svc1"))

      expect_single_resource_query("id" => svc.id, "href" => services_url(svc.id), "name" => "updated svc1")
      expect(svc.reload.name).to eq("updated svc1")
    end

    it 'accepts reference signature hrefs' do
      api_basic_authorize collection_action_identifier(:services, :edit)

      resource = {
        'action'   => 'edit',
        'resource' => {
          'parent_service'         => { 'href' => services_url(svc1.id) },
          'orchestration_template' => { 'href' => orchestration_templates_url(orchestration_template.id) },
          'orchestration_manager'  => { 'href' => providers_url(ems.id) }
        }
      }
      run_post(services_url(svc_orchestration.id), resource)

      expected = {
        'id'       => svc_orchestration.id,
        'ancestry' => svc1.id.to_s
      }
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
      expect(svc_orchestration.reload.parent).to eq(svc1)
      expect(svc_orchestration.orchestration_template).to eq(orchestration_template)
      expect(svc_orchestration.orchestration_manager).to eq(ems)
    end

    it 'accepts reference signature ids' do
      api_basic_authorize collection_action_identifier(:services, :edit)

      resource = {
        'action'   => 'edit',
        'resource' => {
          'parent_service'         => { 'id' => svc1.id },
          'orchestration_template' => { 'id' => orchestration_template.id },
          'orchestration_manager'  => { 'id' => ems.id }
        }
      }
      run_post(services_url(svc_orchestration.id), resource)

      expected = {
        'id'       => svc_orchestration.id,
        'ancestry' => svc1.id.to_s
      }
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
      expect(svc_orchestration.reload.parent).to eq(svc1)
      expect(svc_orchestration.orchestration_template).to eq(orchestration_template)
      expect(svc_orchestration.orchestration_manager).to eq(ems)
    end

    it "supports edits of single resource via PUT" do
      api_basic_authorize collection_action_identifier(:services, :edit)

      run_put(services_url(svc.id), "name" => "updated svc1")

      expect_single_resource_query("id" => svc.id, "href" => services_url(svc.id), "name" => "updated svc1")
      expect(svc.reload.name).to eq("updated svc1")
    end

    it "supports edits of single resource via PATCH" do
      api_basic_authorize collection_action_identifier(:services, :edit)

      run_patch(services_url(svc.id), [{"action" => "edit",   "path" => "name",        "value" => "updated svc1"},
                                       {"action" => "remove", "path" => "description"},
                                       {"action" => "add",    "path" => "display",     "value" => true}])

      expect_single_resource_query("id" => svc.id, "name" => "updated svc1", "display" => true)
      expect(svc.reload.name).to eq("updated svc1")
      expect(svc.description).to be_nil
      expect(svc.display).to be_truthy
    end

    it "supports edits of multiple resources" do
      api_basic_authorize collection_action_identifier(:services, :edit)

      run_post(services_url, gen_request(:edit,
                                         [{"href" => services_url(svc1.id), "name" => "updated svc1"},
                                          {"href" => services_url(svc2.id), "name" => "updated svc2"}]))

      expect(response).to have_http_status(:ok)
      expect_results_to_match_hash("results",
                                   [{"id" => svc1.id, "name" => "updated svc1"},
                                    {"id" => svc2.id, "name" => "updated svc2"}])
      expect(svc1.reload.name).to eq("updated svc1")
      expect(svc2.reload.name).to eq("updated svc2")
    end
  end

  describe "Services delete" do
    it "rejects POST delete requests without appropriate role" do
      api_basic_authorize

      run_post(services_url, gen_request(:delete, "href" => services_url(100)))

      expect(response).to have_http_status(:forbidden)
    end

    it "rejects DELETE requests without appropriate role" do
      api_basic_authorize

      run_delete(services_url(100))

      expect(response).to have_http_status(:forbidden)
    end

    it "rejects requests for invalid resources" do
      api_basic_authorize collection_action_identifier(:services, :delete)

      run_delete(services_url(999_999))

      expect(response).to have_http_status(:not_found)
    end

    it "supports single resource deletes" do
      api_basic_authorize collection_action_identifier(:services, :delete)

      run_delete(services_url(svc.id))

      expect(response).to have_http_status(:no_content)
      expect { svc.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "can be deleted via POST with an appropriate role" do
      service = FactoryGirl.create(:service)
      api_basic_authorize(action_identifier(:services, :delete))

      expect do
        run_post(services_url(service.id), :action => "delete")
      end.to change(Service, :count).by(-1)

      expected = {
        "success" => true,
        "message" => "services id: #{service.id} deleting",
        "href"    => a_string_matching(services_url(service.id))
      }
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end

    it "won't delete a service via POST without an appropriate role" do
      service = FactoryGirl.create(:service)
      api_basic_authorize

      expect do
        run_post(services_url(service.id), :action => "delete")
      end.not_to change(Service, :count)

      expect(response).to have_http_status(:forbidden)
    end

    it "supports multiple resource deletes" do
      api_basic_authorize collection_action_identifier(:services, :delete)

      run_post(services_url, gen_request(:delete,
                                         [{"href" => services_url(svc1.id)},
                                          {"href" => services_url(svc2.id)}]))
      expect_multiple_action_result(2)
      expect_result_resources_to_include_hrefs("results",
                                               [services_url(svc1.id), services_url(svc2.id)])
      expect { svc1.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { svc2.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "Services retirement" do
    def format_retirement_date(time)
      time.in_time_zone('UTC').strftime("%Y-%m-%dT%H:%M:%SZ")
    end

    it "rejects requests without appropriate role" do
      api_basic_authorize

      run_post(services_url(100), gen_request(:retire))

      expect(response).to have_http_status(:forbidden)
    end

    it "rejects multiple requests without appropriate role" do
      api_basic_authorize

      run_post(services_url, gen_request(:retire, [{"href" => services_url(1)}, {"href" => services_url(2)}]))

      expect(response).to have_http_status(:forbidden)
    end

    it "supports single service retirement now" do
      api_basic_authorize collection_action_identifier(:services, :retire)

      expect(MiqEvent).to receive(:raise_evm_event).once

      run_post(services_url(svc.id), gen_request(:retire))

      expect_single_resource_query("id" => svc.id, "href" => services_url(svc.id))
    end

    it "supports single service retirement in future" do
      api_basic_authorize collection_action_identifier(:services, :retire)

      ret_date = format_retirement_date(Time.now + 5.days)

      run_post(services_url(svc.id), gen_request(:retire, "date" => ret_date, "warn" => 2))

      expect_single_resource_query("id" => svc.id, "retires_on" => ret_date, "retirement_warn" => 2)
      expect(format_retirement_date(svc.reload.retires_on)).to eq(ret_date)
      expect(svc.retirement_warn).to eq(2)
    end

    it "supports multiple service retirement now" do
      api_basic_authorize collection_action_identifier(:services, :retire)

      expect(MiqEvent).to receive(:raise_evm_event).twice

      run_post(services_url, gen_request(:retire,
                                         [{"href" => services_url(svc1.id)},
                                          {"href" => services_url(svc2.id)}]))

      expect_results_to_match_hash("results", [{"id" => svc1.id}, {"id" => svc2.id}])
    end

    it "supports multiple service retirement in future" do
      api_basic_authorize collection_action_identifier(:services, :retire)

      ret_date = format_retirement_date(Time.now + 2.days)

      run_post(services_url, gen_request(:retire,
                                         [{"href" => services_url(svc1.id), "date" => ret_date, "warn" => 3},
                                          {"href" => services_url(svc2.id), "date" => ret_date, "warn" => 5}]))

      expect_results_to_match_hash("results",
                                   [{"id" => svc1.id, "retires_on" => ret_date, "retirement_warn" => 3},
                                    {"id" => svc2.id, "retires_on" => ret_date, "retirement_warn" => 5}])
      expect(format_retirement_date(svc1.reload.retires_on)).to eq(ret_date)
      expect(svc1.retirement_warn).to eq(3)
      expect(format_retirement_date(svc2.reload.retires_on)).to eq(ret_date)
      expect(svc2.retirement_warn).to eq(5)
    end
  end

  describe "Service reconfiguration" do
    let(:dialog1) { FactoryGirl.create(:dialog_with_tab_and_group_and_field) }
    let(:st1)     { FactoryGirl.create(:service_template, :name => "template1") }
    let(:ra1) do
      FactoryGirl.create(:resource_action, :action => "Reconfigure", :dialog => dialog1,
                         :ae_namespace => "namespace", :ae_class => "class", :ae_instance => "instance")
    end

    it "rejects requests without appropriate role" do
      api_basic_authorize

      run_post(services_url(100), gen_request(:reconfigure))

      expect(response).to have_http_status(:forbidden)
    end

    it "does not return reconfigure action for non-reconfigurable services" do
      api_basic_authorize(action_identifier(:services, :read, :resource_actions, :get),
                          action_identifier(:services, :retire),
                          action_identifier(:services, :reconfigure))

      run_get services_url(svc1.id)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to declare_actions("retire")
    end

    it "returns reconfigure action for reconfigurable services" do
      api_basic_authorize(action_identifier(:services, :read, :resource_actions, :get),
                          action_identifier(:services, :retire),
                          action_identifier(:services, :reconfigure))

      st1.resource_actions = [ra1]
      svc1.service_template_id = st1.id
      svc1.save

      run_get services_url(svc1.id)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to declare_actions("retire", "reconfigure")
    end

    it "accepts action when service is reconfigurable" do
      api_basic_authorize
      update_user_role(@role, action_identifier(:services, :reconfigure))

      st1.resource_actions = [ra1]
      svc1.service_template_id = st1.id
      svc1.save

      run_post(services_url(svc1.id), gen_request(:reconfigure, "text1" => "updated_text"))

      expect_single_action_result(:success => true, :message => /reconfiguring/i, :href => services_url(svc1.id))
    end
  end

  describe "Services" do
    let(:hw1) { FactoryGirl.build(:hardware, :cpu_total_cores => 2) }
    let(:vm1) { FactoryGirl.create(:vm_vmware, :hardware => hw1) }

    let(:hw2) { FactoryGirl.build(:hardware, :cpu_total_cores => 4) }
    let(:vm2) { FactoryGirl.create(:vm_vmware, :hardware => hw2) }

    before do
      api_basic_authorize(action_identifier(:services, :read, :resource_actions, :get))

      svc1 << vm1
      svc1 << vm2
      svc1.save

      @svc1_vm_list = ["#{services_url(svc1.id)}/vms/#{vm1.id}", "#{services_url(svc1.id)}/vms/#{vm2.id}"]
    end

    def expect_svc_with_vms
      expect_single_resource_query("href" => services_url(svc1.id))
      expect_result_resources_to_include_hrefs("vms", @svc1_vm_list)
    end

    it "can query vms as subcollection" do
      run_get "#{services_url(svc1.id)}/vms"

      expect_query_result(:vms, 2, 2)
      expect_result_resources_to_include_hrefs("resources", @svc1_vm_list)
    end

    it "supports expansion of virtual attributes" do
      run_get services_url, :expand => "resources", :attributes => "power_states"

      expected = {
        "resources" => [
          a_hash_including("power_states" => svc1.power_states)
        ]
      }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected)
    end

    it "can query vms as subcollection via expand" do
      run_get services_url(svc1.id), :expand => "vms"

      expect_svc_with_vms
    end

    it "can query vms as subcollection via expand with additional virtual attributes" do
      run_get services_url(svc1.id), :expand => "vms", :attributes => "vms.cpu_total_cores"

      expect_svc_with_vms
      expect_results_to_match_hash("vms", [{"id" => vm1.id, "cpu_total_cores" => 2},
                                           {"id" => vm2.id, "cpu_total_cores" => 4}])
    end

    it "can query vms as subcollection via decorators with additional decorators" do
      run_get(services_url(svc1.id), :expand => "vms", :decorators => "vms.supports_console?,vms.supports_cockpit?,vms.supports_vnc_console?")

      expected = {
        "vms" => [
          a_hash_including("id" => vm1.id, "supports_console?" => true, "supports_cockpit?" => anything, "supports_vnc_console?" => anything),
          a_hash_including("id" => vm2.id, "supports_console?" => true, "supports_cockpit?" => anything, "supports_vnc_console?" => anything)
        ]
      }
      expect(response.parsed_body).to include(expected)
    end

    it "cannot query vms via both virtual attribute and subcollection" do
      run_get services_url(svc1.id), :expand => "vms", :attributes => "vms"

      expect_bad_request("Cannot expand subcollection vms by name and virtual attribute")
    end
  end

  describe "Power Operations" do
    describe "start" do
      it "will start a service for a user with appropriate role" do
        service = FactoryGirl.create(:service)
        api_basic_authorize(action_identifier(:services, :start))

        run_post(services_url(service.id), :action => "start")

        expected = {
          "href"    => a_string_matching(services_url(service.id)),
          "success" => true,
          "message" => a_string_matching("starting")
        }
        expect(response.parsed_body).to include(expected)
        expect(response).to have_http_status(:ok)
      end

      it "can start multiple services for a user with appropriate role" do
        service_1, service_2 = FactoryGirl.create_list(:service, 2)
        api_basic_authorize(collection_action_identifier(:services, :start))

        run_post(services_url, :action => "start", :resources => [{:id => service_1.id}, {:id => service_2.id}])

        expected = {
          "results" => a_collection_containing_exactly(
            a_hash_including("success"   => true,
                             "message"   => a_string_matching("starting"),
                             "task_id"   => anything,
                             "task_href" => anything,
                             "href"      => a_string_matching(services_url(service_1.id))),
            a_hash_including("success"   => true,
                             "message"   => a_string_matching("starting"),
                             "task_id"   => anything,
                             "task_href" => anything,
                             "href"      => a_string_matching(services_url(service_2.id))),
          )
        }
        expect(response.parsed_body).to include(expected)
        expect(response).to have_http_status(:ok)
      end

      it "will not start a service for a user without an appropriate role" do
        service = FactoryGirl.create(:service)
        api_basic_authorize

        run_post(services_url(service.id), :action => "start")

        expect(response).to have_http_status(:forbidden)
      end
    end

    describe "stop" do
      it "will stop a service for a user with appropriate role" do
        service = FactoryGirl.create(:service)
        api_basic_authorize(action_identifier(:services, :stop))

        run_post(services_url(service.id), :action => "stop")

        expected = {
          "href"    => a_string_matching(services_url(service.id)),
          "success" => true,
          "message" => a_string_matching("stopping")
        }
        expect(response.parsed_body).to include(expected)
        expect(response).to have_http_status(:ok)
      end

      it "can stop multiple services for a user with appropriate role" do
        service_1, service_2 = FactoryGirl.create_list(:service, 2)
        api_basic_authorize(collection_action_identifier(:services, :stop))

        run_post(services_url, :action => "stop", :resources => [{:id => service_1.id}, {:id => service_2.id}])

        expected = {
          "results" => a_collection_containing_exactly(
            a_hash_including("success"   => true,
                             "message"   => a_string_matching("stopping"),
                             "task_id"   => anything,
                             "task_href" => anything,
                             "href"      => a_string_matching(services_url(service_1.id))),
            a_hash_including("success"   => true,
                             "message"   => a_string_matching("stopping"),
                             "task_id"   => anything,
                             "task_href" => anything,
                             "href"      => a_string_matching(services_url(service_2.id))),
          )
        }
        expect(response.parsed_body).to include(expected)
        expect(response).to have_http_status(:ok)
      end

      it "will not stop a service for a user without an appropriate role" do
        service = FactoryGirl.create(:service)
        api_basic_authorize

        run_post(services_url(service.id), :action => "stop")

        expect(response).to have_http_status(:forbidden)
      end
    end

    describe "suspend" do
      it "will suspend a service for a user with appropriate role" do
        service = FactoryGirl.create(:service)
        api_basic_authorize(action_identifier(:services, :suspend))

        run_post(services_url(service.id), :action => "suspend")

        expected = {
          "href"    => a_string_matching(services_url(service.id)),
          "success" => true,
          "message" => a_string_matching("suspending")
        }
        expect(response.parsed_body).to include(expected)
        expect(response).to have_http_status(:ok)
      end

      it "can suspend multiple services for a user with appropriate role" do
        service_1, service_2 = FactoryGirl.create_list(:service, 2)
        api_basic_authorize(collection_action_identifier(:services, :suspend))

        run_post(services_url, :action => "suspend", :resources => [{:id => service_1.id}, {:id => service_2.id}])

        expected = {
          "results" => a_collection_containing_exactly(
            a_hash_including("success"   => true,
                             "message"   => a_string_matching("suspending"),
                             "task_id"   => anything,
                             "task_href" => anything,
                             "href"      => a_string_matching(services_url(service_1.id))),
            a_hash_including("success"   => true,
                             "message"   => a_string_matching("suspending"),
                             "task_id"   => anything,
                             "task_href" => anything,
                             "href"      => a_string_matching(services_url(service_2.id))),
          )
        }
        expect(response.parsed_body).to include(expected)
        expect(response).to have_http_status(:ok)
      end

      it "will not suspend a service for a user without an appropriate role" do
        service = FactoryGirl.create(:service)
        api_basic_authorize

        run_post(services_url(service.id), :action => "suspend")

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'Orchestration Stack subcollection' do
    let(:os) { FactoryGirl.create(:orchestration_stack) }

    before do
      svc.add_resource!(os, :name => ResourceAction::PROVISION)
    end

    it 'can query orchestration stacks as a subcollection' do
      api_basic_authorize subcollection_action_identifier(:services, :orchestration_stacks, :read, :get)

      run_get("#{services_url(svc.id)}/orchestration_stacks", :expand => 'resources')

      expected = {
        'resources' => [
          a_hash_including('id' => os.id)
        ]
      }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected)
    end

    it 'can query a specific orchestration stack' do
      api_basic_authorize subcollection_action_identifier(:services, :orchestration_stacks, :read, :get)

      run_get("#{services_url(svc.id)}/orchestration_stacks/#{os.id}")

      expected = {
        'id' => os.id
      }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected)
    end

    it 'can query a specific orchestration stack asking for stdout' do
      api_basic_authorize subcollection_action_identifier(:services, :orchestration_stacks, :read, :get)

      allow_any_instance_of(OrchestrationStack).to receive(:stdout).with(nil).and_return("default text stdout")
      run_get("#{services_url(svc.id)}/orchestration_stacks/#{os.id}", :attributes => "stdout")

      expected = {
        'id'     => os.id,
        'stdout' => "default text stdout"
      }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected)
    end

    it 'can query a specific orchestration stack asking for stdout in alternate format' do
      api_basic_authorize subcollection_action_identifier(:services, :orchestration_stacks, :read, :get)

      allow_any_instance_of(OrchestrationStack).to receive(:stdout).with("json").and_return("json stdout")
      run_get("#{services_url(svc.id)}/orchestration_stacks/#{os.id}", :attributes => "stdout", :format_attributes => "stdout=json")

      expected = {
        'id'     => os.id,
        'stdout' => "json stdout"
      }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected)
    end

    it 'will not return orchestration stacks without an appropriate role' do
      api_basic_authorize

      run_get("#{services_url(svc.id)}/orchestration_stacks")

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'add_resource' do
    let(:vm1) { FactoryGirl.create(:vm_vmware) }
    let(:vm2) { FactoryGirl.create(:vm_vmware) }

    it 'can add vm to services by href with an appropriate role' do
      api_basic_authorize(collection_action_identifier(:services, :add_resource))
      request = {
        'action'    => 'add_resource',
        'resources' => [
          { 'href' => services_url(svc.id), 'resource' => {'href' => vms_url(vm1.id)} },
          { 'href' => services_url(svc1.id), 'resource' => {'href' => vms_url(vm2.id)} }
        ]
      }

      run_post(services_url, request)

      expected = {
        'results' => [
          { 'success' => true, 'message' => "Assigned resource vms id:#{vm1.id} to Service id:#{svc.id} name:'#{svc.name}'"},
          { 'success' => true, 'message' => "Assigned resource vms id:#{vm2.id} to Service id:#{svc1.id} name:'#{svc1.name}'"}
        ]
      }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(expected)
      expect(svc.reload.vms).to eq([vm1])
      expect(svc1.reload.vms).to eq([vm2])
    end

    it 'returns individual success and failures' do
      user = FactoryGirl.create(:user)
      user.miq_groups << @user.current_group
      api_basic_authorize(collection_action_identifier(:services, :add_resource))
      request = {
        'action'    => 'add_resource',
        'resources' => [
          { 'href' => services_url(svc.id), 'resource' => {'href' => vms_url(vm1.id)} },
          { 'href' => services_url(svc1.id), 'resource' => {'href' => users_url(user.id)} }
        ]
      }

      run_post(services_url, request)

      expected = {
        'results' => [
          { 'success' => true, 'message' => "Assigned resource vms id:#{vm1.id} to Service id:#{svc.id} name:'#{svc.name}'"},
          { 'success' => false, 'message' => "Cannot assign users to Service id:#{svc1.id} name:'#{svc1.name}'"}
        ]
      }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(expected)
      expect(svc.reload.vms).to eq([vm1])
    end

    it 'requires a valid resource' do
      api_basic_authorize(collection_action_identifier(:services, :add_resource))
      request = {
        'action'   => 'add_resource',
        'resource' => { 'resource' => { 'href' => '1' } }
      }

      run_post(services_url(svc.id), request)

      expected = { 'success' => false, 'message' => "Invalid resource href specified 1"}

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(expected)
    end

    it 'requires the resource to respond to add_to_service' do
      user = FactoryGirl.create(:user)
      user.miq_groups << @user.current_group
      api_basic_authorize(collection_action_identifier(:services, :add_resource))
      request = {
        'action'   => 'add_resource',
        'resource' => { 'resource' => { 'href' => users_url(user.id) } }
      }

      run_post(services_url(svc.id), request)

      expected = { 'success' => false, 'message' => "Cannot assign users to Service id:#{svc.id} name:'#{svc.name}'"}

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(expected)
    end

    it 'requires a resource reference' do
      api_basic_authorize(collection_action_identifier(:services, :add_resource))
      request = {
        'action'   => 'add_resource',
        'resource' => { 'resource' => {} }
      }

      run_post(services_url(svc.id), request)

      expected = { 'success' => false, 'message' => "Must specify a resource reference"}

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(expected)
    end

    it 'can add a vm to a resource with appropriate role' do
      api_basic_authorize(collection_action_identifier(:services, :add_resource))
      request = {
        'action'   => 'add_resource',
        'resource' => { 'resource' => {'href' => vms_url(vm1.id)} }
      }

      run_post(services_url(svc.id), request)

      expected = { 'success' => true, 'message' => "Assigned resource vms id:#{vm1.id} to Service id:#{svc.id} name:'#{svc.name}'"}

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(expected)
      expect(svc.reload.vms).to eq([vm1])
    end

    it 'cannot add multiple vms to multiple services by href without an appropriate role' do
      api_basic_authorize

      run_post(services_url, 'action' => 'add_resource')

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'remove_resource' do
    let(:vm1) { FactoryGirl.create(:vm_vmware) }
    let(:vm2) { FactoryGirl.create(:vm_vmware) }

    before do
      svc.add_resource(vm1)
      svc1.add_resource(vm2)
    end

    it 'cannot remove vms from services without an appropriate role' do
      api_basic_authorize

      run_post(services_url, 'action' => 'remove_resource')

      expect(response).to have_http_status(:forbidden)
    end

    it 'can remove vms from multiple services by href with an appropriate role' do
      api_basic_authorize collection_action_identifier(:services, :remove_resource)
      request = {
        'action'    => 'remove_resource',
        'resources' => [
          { 'href' => services_url(svc.id), 'resource' => { 'href' => vms_url(vm1.id)} },
          { 'href' => services_url(svc1.id), 'resource' => { 'href' => vms_url(vm2.id)} }
        ]
      }

      run_post(services_url, request)

      expected = {
        'results' => [
          { 'success' => true, 'message' => "Unassigned resource vms id:#{vm1.id} from Service id:#{svc.id} name:'#{svc.name}'" },
          { 'success' => true, 'message' => "Unassigned resource vms id:#{vm2.id} from Service id:#{svc1.id} name:'#{svc1.name}'" }
        ]
      }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(expected)
      expect(svc.reload.service_resources).to eq([])
      expect(svc1.reload.service_resources).to eq([])
    end

    it 'requires a service id to be specified' do
      api_basic_authorize collection_action_identifier(:services, :remove_resource)
      request = {
        'action'    => 'remove_resource',
        'resources' => [
          { 'href' => services_url, 'resource' => { 'href' => vms_url(vm1.id)} }
        ]
      }

      run_post(services_url, request)

      expected = {
        'results' => [
          { 'success' => false, 'message' => 'Must specify a resource to remove_resource from' }
        ]
      }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(expected)
    end

    it 'requires that a resource be specified' do
      api_basic_authorize collection_action_identifier(:services, :remove_resource)
      request = {
        'action'    => 'remove_resource',
        'resources' => [
          { 'href' => services_url(svc.id), 'resource' => {} }
        ]
      }

      run_post(services_url, request)

      expected = {
        'results' => [
          { 'success' => false, 'message' => 'Must specify a resource reference' }
        ]
      }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(expected)
    end

    it 'cannot remove a vm from a service without an appropriate role' do
      api_basic_authorize

      run_post(services_url(svc.id), 'action' => 'remove_resource')

      expect(response).to have_http_status(:forbidden)
    end

    it 'can remove a vm from a service by href with an appropriate role' do
      api_basic_authorize collection_action_identifier(:services, :remove_resource)
      request = {
        'action'   => 'remove_resource',
        'resource' => { 'resource' => {'href' => vms_url(vm1.id)} }
      }

      run_post(services_url(svc.id), request)

      expected = {
        'success' => true,
        'message' => "Unassigned resource vms id:#{vm1.id} from Service id:#{svc.id} name:'#{svc.name}'"
      }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(expected)
      expect(svc.reload.service_resources).to eq([])
    end
  end

  describe 'remove_all_resources' do
    let(:vm1) { FactoryGirl.create(:vm_vmware) }
    let(:vm2) { FactoryGirl.create(:vm_vmware) }
    let(:vm3) { FactoryGirl.create(:vm_vmware) }

    before do
      svc.add_resource(vm1)
      svc.add_resource(vm2)
      svc1.add_resource(vm3)
    end

    it 'cannot remove all resources without an appropriate role' do
      api_basic_authorize

      run_post(services_url, 'action' => 'remove_all_resources')

      expect(response).to have_http_status(:forbidden)
    end

    it 'can remove all resources from multiple services' do
      api_basic_authorize collection_action_identifier(:services, :remove_all_resources)
      request = {
        'action'    => 'remove_all_resources',
        'resources' => [
          { 'href' => services_url(svc.id) },
          { 'href' => services_url(svc1.id) }
        ]
      }

      run_post(services_url, request)

      expected = {
        'results' => [
          { 'success' => true, 'message' =>  "Removed all resources from Service id:#{svc.id} name:'#{svc.name}'"},
          { 'success' => true, 'message' =>  "Removed all resources from Service id:#{svc1.id} name:'#{svc1.name}'"}
        ]
      }
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(expected)
      expect(svc.reload.service_resources).to eq([])
      expect(svc1.reload.service_resources).to eq([])
    end

    it 'cannot remove all resources without an appropriate role' do
      api_basic_authorize

      run_post(services_url(svc.id), :action => 'remove_all_resources')

      expect(response).to have_http_status(:forbidden)
    end

    it 'can remove all resources from a service' do
      api_basic_authorize collection_action_identifier(:services, :remove_all_resources)

      run_post(services_url(svc.id), :action => 'remove_all_resources')

      expected = {
        'success' => true, 'message' => "Removed all resources from Service id:#{svc.id} name:'#{svc.name}'"
      }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq(expected)
      expect(svc.reload.service_resources).to eq([])
    end
  end
end
