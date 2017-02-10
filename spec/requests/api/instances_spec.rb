RSpec.describe "Instances API" do
  def update_raw_power_state(state, *instances)
    instances.each { |instance| instance.update_attributes!(:raw_power_state => state) }
  end

  let(:zone) { FactoryGirl.create(:zone, :name => "api_zone") }
  let(:ems) { FactoryGirl.create(:ems_openstack_infra, :zone => zone) }
  let(:host) { FactoryGirl.create(:host_openstack_infra) }
  let(:instance) { FactoryGirl.create(:vm_openstack, :ems_id => ems.id, :host => host) }
  let(:instance1) { FactoryGirl.create(:vm_openstack, :ems_id => ems.id, :host => host) }
  let(:instance2) { FactoryGirl.create(:vm_openstack, :ems_id => ems.id, :host => host) }
  let(:instance_url) { instances_url(instance.id) }
  let(:instance1_url) { instances_url(instance1.id) }
  let(:instance2_url) { instances_url(instance2.id) }
  let(:invalid_instance_url) { instances_url(999_999) }
  let(:instances_list) { [instance1_url, instance2_url] }

  context "Instance index" do
    it "lists only the cloud instances (no infrastructure vms)" do
      api_basic_authorize collection_action_identifier(:instances, :read, :get)
      instance = FactoryGirl.create(:vm_openstack)
      _vm = FactoryGirl.create(:vm_vmware)

      run_get(instances_url)

      expect_query_result(:instances, 1, 1)
      expect_result_resources_to_include_hrefs("resources", [instances_url(instance.id)])
    end
  end

  describe "instance terminate action" do
    it "responds not found for an invalid instance" do
      api_basic_authorize action_identifier(:instances, :terminate)

      run_post(invalid_instance_url, gen_request(:terminate))

      expect(response).to have_http_status(:not_found)
    end

    it "responds forbidden for an invalid instance without appropriate role" do
      api_basic_authorize

      run_post(invalid_instance_url, gen_request(:terminate))

      expect(response).to have_http_status(:forbidden)
    end

    it "terminates a single valid Instance" do
      api_basic_authorize action_identifier(:instances, :terminate)

      run_post(instance_url, gen_request(:terminate))

      expect_single_action_result(
        :success => true,
        :message => /#{instance.id}.* terminating/i,
        :href    => instance_url
      )
    end

    it "terminates multiple valid Instances" do
      api_basic_authorize collection_action_identifier(:instances, :terminate)

      run_post(instances_url, gen_request(:terminate, [{"href" => instance1_url}, {"href" => instance2_url}]))

      expected = {
        "results" => a_collection_containing_exactly(
          a_hash_including(
            "message" => a_string_matching(/#{instance1.id}.* terminating/i),
            "success" => true,
            "href"    => a_string_matching(instance1_url)
          ),
          a_hash_including(
            "message" => a_string_matching(/#{instance2.id}.* terminating/i),
            "success" => true,
            "href"    => a_string_matching(instance2_url)
          )
        )
      }
      expect(response.parsed_body).to include(expected)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "instance stop action" do
    it "responds not found for an invalid instance" do
      api_basic_authorize action_identifier(:instances, :stop)

      run_post(invalid_instance_url, gen_request(:stop))

      expect(response).to have_http_status(:not_found)
    end

    it "stopping an invalid instance without appropriate role is forbidden" do
      api_basic_authorize

      run_post(invalid_instance_url, gen_request(:stop))

      expect(response).to have_http_status(:forbidden)
    end

    it "fails to stop a powered off instance" do
      api_basic_authorize action_identifier(:instances, :stop)
      update_raw_power_state("poweredOff", instance)

      run_post(instance_url, gen_request(:stop))

      expect_single_action_result(:success => false, :message => "is not powered on", :href => instance_url)
    end

    it "stops a valid instance" do
      api_basic_authorize action_identifier(:instances, :stop)

      run_post(instance_url, gen_request(:stop))

      expect_single_action_result(:success => true, :message => "stopping", :href => instance_url, :task => true)
    end

    it "stops multiple valid instances" do
      api_basic_authorize action_identifier(:instances, :stop)

      run_post(instances_url, gen_request(:stop, nil, instance1_url, instance2_url))

      expect_multiple_action_result(2, :task => true)
      expect_result_resources_to_include_hrefs("results", instances_list)
    end
  end

  describe "instance start action" do
    it "responds not found for an invalid instance" do
      api_basic_authorize action_identifier(:instances, :start)

      run_post(invalid_instance_url, gen_request(:start))

      expect(response).to have_http_status(:not_found)
    end

    it "starting an invalid instance without appropriate role is forbidden" do
      api_basic_authorize

      run_post(invalid_instance_url, gen_request(:start))

      expect(response).to have_http_status(:forbidden)
    end

    it "fails to start a powered on instance" do
      api_basic_authorize action_identifier(:instances, :start)

      run_post(instance_url, gen_request(:start))

      expect_single_action_result(:success => false, :message => "is powered on", :href => instance_url)
    end

    it "starts an instance" do
      api_basic_authorize action_identifier(:instances, :start)
      update_raw_power_state("poweredOff", instance)

      run_post(instance_url, gen_request(:start))

      expect_single_action_result(:success => true, :message => "starting", :href => instance_url, :task => true)
    end

    it "starts multiple instances" do
      api_basic_authorize action_identifier(:instances, :start)
      update_raw_power_state("poweredOff", instance1, instance2)

      run_post(instances_url, gen_request(:start, nil, instance1_url, instance2_url))

      expect_multiple_action_result(2, :task => true)
      expect_result_resources_to_include_hrefs("results", instances_list)
    end
  end

  describe "instance pause action" do
    it "responds not found for an invalid instance" do
      api_basic_authorize action_identifier(:instances, :pause)

      run_post(invalid_instance_url, gen_request(:pause))

      expect(response).to have_http_status(:not_found)
    end

    it "pausing an invalid instance without appropriate role is forbidden" do
      api_basic_authorize

      run_post(invalid_instance_url, gen_request(:pause))

      expect(response).to have_http_status(:forbidden)
    end

    it "fails to pause a powered off instance" do
      api_basic_authorize action_identifier(:instances, :pause)
      update_raw_power_state("poweredOff", instance)

      run_post(instance_url, gen_request(:pause))

      expect_single_action_result(:success => false, :message => "is not powered on", :href => instance_url)
    end

    it "fails to pause a paused instance" do
      api_basic_authorize action_identifier(:instances, :pause)
      update_raw_power_state("paused", instance)

      run_post(instance_url, gen_request(:pause))

      expect_single_action_result(:success => false, :message => "is not powered on", :href => instance_url)
    end

    it "pauses an instance" do
      api_basic_authorize action_identifier(:instances, :pause)

      run_post(instance_url, gen_request(:pause))

      expect_single_action_result(:success => true, :message => "pausing", :href => instance_url, :task => true)
    end

    it "pauses multiple instances" do
      api_basic_authorize action_identifier(:instances, :pause)

      run_post(instances_url, gen_request(:pause, nil, instance1_url, instance2_url))

      expect_multiple_action_result(2, :task => true)
      expect_result_resources_to_include_hrefs("results", instances_list)
    end
  end

  context "Instance suspend action" do
    it "responds not found for an invalid instance" do
      api_basic_authorize action_identifier(:instances, :suspend)

      run_post(invalid_instance_url, gen_request(:suspend))

      expect(response).to have_http_status(:not_found)
    end

    it "responds forbidden for an invalid instance without appropriate role" do
      api_basic_authorize

      run_post(invalid_instance_url, gen_request(:suspend))

      expect(response).to have_http_status(:forbidden)
    end

    it "cannot suspend a powered off instance" do
      api_basic_authorize action_identifier(:instances, :suspend)
      update_raw_power_state("poweredOff", instance)

      run_post(instance_url, gen_request(:suspend))

      expect_single_action_result(:success => false, :message => "is not powered on", :href => instance_url)
    end

    it "cannot suspend a suspended instance" do
      api_basic_authorize action_identifier(:instances, :suspend)
      update_raw_power_state("suspended", instance)

      run_post(instance_url, gen_request(:suspend))

      expect_single_action_result(:success => false, :message => "is not powered on", :href => instance_url)
    end

    it "suspends an instance" do
      api_basic_authorize action_identifier(:instances, :suspend)

      run_post(instance_url, gen_request(:suspend))

      expect_single_action_result(:success => true, :message => "suspending", :href => instance_url, :task => true)
    end

    it "suspends multiple instances" do
      api_basic_authorize action_identifier(:instances, :suspend)

      run_post(instances_url, gen_request(:suspend, nil, instance1_url, instance2_url))

      expect_multiple_action_result(2, :task => true)
      expect_result_resources_to_include_hrefs("results", instances_list)
    end
  end

  context "Instance shelve action" do
    it "responds not found for an invalid instance" do
      api_basic_authorize action_identifier(:instances, :shelve)

      run_post(invalid_instance_url, gen_request(:shelve))

      expect(response).to have_http_status(:not_found)
    end

    it "responds forbidden for an invalid instance without appropriate role" do
      api_basic_authorize

      run_post(invalid_instance_url, gen_request(:shelve))

      expect(response).to have_http_status(:forbidden)
    end

    it "shelves a powered off instance" do
      api_basic_authorize action_identifier(:instances, :shelve)
      update_raw_power_state("SHUTOFF", instance)

      run_post(instance_url, gen_request(:shelve))

      expect_single_action_result(:success => true, :message => 'shelving', :href => instance_url)
    end

    it "shelves a suspended instance" do
      api_basic_authorize action_identifier(:instances, :shelve)
      update_raw_power_state("SUSPENDED", instance)

      run_post(instance_url, gen_request(:shelve))

      expect_single_action_result(:success => true, :message => 'shelving', :href => instance_url)
    end

    it "shelves a paused instance" do
      api_basic_authorize action_identifier(:instances, :shelve)
      update_raw_power_state("PAUSED", instance)

      run_post(instance_url, gen_request(:shelve))

      expect_single_action_result(:success => true, :message => 'shelving', :href => instance_url)
    end

    it "cannot shelve a shelved instance" do
      api_basic_authorize action_identifier(:instances, :shelve)
      update_raw_power_state("SHELVED", instance)

      run_post(instance_url, gen_request(:shelve))

      expect_single_action_result(
        :success => false,
        :message => "The VM can't be shelved, current state has to be powered on, off, suspended or paused",
        :href    => instance_url
      )
    end

    it "shelves an instance" do
      api_basic_authorize action_identifier(:instances, :shelve)

      run_post(instance_url, gen_request(:shelve))

      expect_single_action_result(:success => true,
                                  :message => "shelving",
                                  :href    => instance_url,
                                  :task    => true)
    end

    it "shelves multiple instances" do
      api_basic_authorize action_identifier(:instances, :shelve)

      run_post(instances_url, gen_request(:shelve, nil, instance1_url, instance2_url))

      expect_multiple_action_result(2, :task => true)
      expect_result_resources_to_include_hrefs("results", instances_list)
    end
  end

  describe "instance reboot guest action" do
    it "responds not found for an invalid instance" do
      api_basic_authorize action_identifier(:instances, :reboot_guest)

      run_post(invalid_instance_url, gen_request(:reboot_guest))

      expect(response).to have_http_status(:not_found)
    end

    it "responds forbidden for an invalid instance without appropriate role" do
      api_basic_authorize

      run_post(invalid_instance_url, gen_request(:reboot_guest))

      expect(response).to have_http_status(:forbidden)
    end

    it "fails to reboot a powered off instance" do
      api_basic_authorize action_identifier(:instances, :reboot_guest)
      update_raw_power_state("poweredOff", instance)

      run_post(instance_url, gen_request(:reboot_guest))

      expect_single_action_result(:success => false, :message => "is not powered on", :href => instance_url)
    end

    it "reboots a valid instance" do
      api_basic_authorize action_identifier(:instances, :reboot_guest)

      run_post(instance_url, gen_request(:reboot_guest))

      expect_single_action_result(:success => true, :message => "rebooting", :href => instance_url, :task => true)
    end

    it "reboots multiple valid instances" do
      api_basic_authorize action_identifier(:instances, :reboot_guest)

      run_post(instances_url, gen_request(:reboot_guest, nil, instance1_url, instance2_url))

      expect_multiple_action_result(2, :task => true)
      expect_result_resources_to_include_hrefs("results", instances_list)
    end
  end

  describe "instance reset action" do
    it "responds not found for an invalid instance" do
      api_basic_authorize action_identifier(:instances, :reset)

      run_post(invalid_instance_url, gen_request(:reset))

      expect(response).to have_http_status(:not_found)
    end

    it "responds forbidden for an invalid instance without appropriate role" do
      api_basic_authorize

      run_post(invalid_instance_url, gen_request(:reset))

      expect(response).to have_http_status(:forbidden)
    end

    it "fails to reset a powered off instance" do
      api_basic_authorize action_identifier(:instances, :reset)
      update_raw_power_state("poweredOff", instance)

      run_post(instance_url, gen_request(:reset))

      expect_single_action_result(:success => false, :message => "is not powered on", :href => instance_url)
    end

    it "resets a valid instance" do
      api_basic_authorize action_identifier(:instances, :reset)

      run_post(instance_url, gen_request(:reset))

      expect_single_action_result(:success => true, :message => "resetting", :href => instance_url, :task => true)
    end

    it "resets multiple valid instances" do
      api_basic_authorize action_identifier(:instances, :reset)

      run_post(instances_url, gen_request(:reset, nil, instance1_url, instance2_url))

      expect_multiple_action_result(2, :task => true)
      expect_result_resources_to_include_hrefs("results", instances_list)
    end
  end

  context 'load balancers subcollection' do
    before do
      @vm = FactoryGirl.create(:vm_amazon)
      @load_balancer = FactoryGirl.create(:load_balancer_amazon)
      load_balancer_listener = FactoryGirl.create(:load_balancer_listener_amazon)
      load_balancer_pool = FactoryGirl.create(:load_balancer_pool_amazon)
      load_balancer_pool_member = FactoryGirl.create(:load_balancer_pool_member_amazon)
      @load_balancer.load_balancer_listeners << load_balancer_listener
      load_balancer_listener.load_balancer_pools << load_balancer_pool
      load_balancer_pool.load_balancer_pool_members << load_balancer_pool_member
      @vm.load_balancer_pool_members << load_balancer_pool_member
    end

    it 'queries all load balancers on an instance' do
      api_basic_authorize subcollection_action_identifier(:instances, :load_balancers, :show, :get)
      expected = {
        'name'      => 'load_balancers',
        'resources' => [
          { 'href' => a_string_matching("#{instances_url(@vm.id)}/load_balancers/#{@load_balancer.id}") }
        ]
      }
      run_get("#{instances_url(@vm.id)}/load_balancers")

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(expected)
    end

    it "will not show an instance's load balancers without the appropriate role" do
      api_basic_authorize

      run_get("#{instances_url(@vm.id)}/load_balancers")

      expect(response).to have_http_status(:forbidden)
    end

    it 'queries a single load balancer on an instance' do
      api_basic_authorize subcollection_action_identifier(:instances, :load_balancers, :show, :get)
      run_get("#{instances_url(@vm.id)}/load_balancers/#{@load_balancer.id}")

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include('id' => @load_balancer.id)
    end

    it "will not show an instance's load balancer without the appropriate role" do
      api_basic_authorize

      run_get("#{instances_url(@vm.id)}/load_balancers/#{@load_balancer.id}")

      expect(response).to have_http_status(:forbidden)
    end
  end
end
