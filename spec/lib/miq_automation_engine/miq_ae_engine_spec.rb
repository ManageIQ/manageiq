describe MiqAeEngine do
  include Spec::Support::AutomationHelper

  before(:each) do
    MiqAeDatastore.reset
    EvmSpecHelper.local_guid_miq_server_zone
    @user   = FactoryGirl.create(:user_with_group)
    @domain = 'SPEC_DOMAIN'
    @model_data_dir = File.join(File.dirname(__FILE__), "data")
    @root_tenant_id = Tenant.root_tenant.id
    @miq_server_id = MiqServer.first.id
  end

  def call_automate(obj_type, obj_id)
    MiqAeEngine.deliver(:object_type      => obj_type,
                        :object_id        => obj_id,
                        :attrs            => nil,
                        :instance_name    => nil,
                        :user_id          => @user.id,
                        :miq_group_id     => @user.current_group.id,
                        :tenant_id        => @user.current_tenant.id,
                        :automate_message => nil)
  end

  after(:each) do
    MiqAeDatastore.reset
  end

  context ".deliver" do
    before(:each) do
      @ems              = FactoryGirl.create(:ems_vmware)
      @cluster          = FactoryGirl.create(:ems_cluster)
      @vm               = FactoryGirl.create(:vm_vmware)
      @attrs            = {}
      @instance_name    = 'AUTOMATION'
      @user_id          = nil
      @state            = nil
      @automate_message = nil
      @ae_fsm_started   = nil
      @ae_state_started = nil
      @ae_state_retries = nil
    end

    it "via MiqQueue" do
      args = {
        :namespace        => "SYSTEM",
        :class_name       => "PROCESS",
        :instance_name    => "Request",
        :automate_message => "create",
        :attrs            => {"request" => "InspectMe"},
        :object_type      => @vm.class.name,
        :object_id        => @vm.id,
        :user_id          => @user.id,
        :miq_group_id     => @user.current_group.id,
        :tenant_id        => @user.current_tenant.id
      }

      q = MiqQueue.put(
        :role        => 'automate',
        :class_name  => 'MiqAeEngine',
        :method_name => 'deliver',
        :args        => [args]
      )

      status, message, result = q.deliver
      if status == MiqQueue::STATUS_ERROR
        puts "#{q.last_exception.class.name}: #{q.last_exception.message}"
        puts q.last_exception.backtrace
      end
      expect(status).not_to eq(MiqQueue::STATUS_ERROR)
    end

    context "when Automate instantiation fails" do
      before(:each) do
        allow(MiqAeEngine).to receive(:resolve_automation_object).and_return(nil)
      end

      it "with defaults and non-STI object" do
        object_type = @cluster.class.name
        object_id   = @cluster.id
        automate_attrs = {"#{object_type}::#{object_type.underscore}" => object_id,
                          "User::user"                                => @user.id}
        expect(MiqAeEngine).to receive(:create_automation_object).with(@instance_name, automate_attrs, {:vmdb_object => @cluster}).and_return('uri')
        expect(call_automate(object_type, object_id)).to be_nil
      end

      it "with defaults and STI object" do
        base_name   = @ems.class.base_class.name
        object_type = @ems.class.name
        object_id   = @ems.id
        automate_attrs = {"#{base_name}::#{base_name.underscore}" => object_id,
                          "User::user"                            => @user.id}
        expect(MiqAeEngine).to receive(:create_automation_object).with(@instance_name, automate_attrs, {:vmdb_object => @ems}).and_return('uri')
        expect(call_automate(object_type, object_id)).to be_nil
      end
    end

    context "when Automate instantiation succeeds" do
      context "with ae_result of 'error'" do
        before(:each) do
          root = {'ae_result' => 'error'}
          @ws = double('ws')
          allow(@ws).to receive_messages(:root => root)
          allow(MiqAeEngine).to receive(:resolve_automation_object).and_return(@ws)
        end

        it "with defaults" do
          object_type = @ems.class.name
          object_id   = @ems.id
          expect(call_automate(object_type, object_id)).to eq(@ws)
        end
      end

      context "with ae_result of 'ok'" do
        before(:each) do
          root = {'ae_result' => 'ok'}
          @ws = double('ws')
          allow(@ws).to receive_messages(:root => root)
          allow(MiqAeEngine).to receive(:resolve_automation_object).and_return(@ws)
        end

        it "with defaults" do
          object_type = @ems.class.name
          object_id   = @ems.id
          expect(call_automate(object_type, object_id)).to eq(@ws)
        end

        it "with a starting point instead of /SYSTEM/PROCESS" do
          args = {}
          attrs = {'User::user' => @user.id}
          args[:instance_name]    = "DEFAULT"
          args[:fqclass_name] = "Factory/StateMachines/ServiceProvision_template"
          args[:user_id] = @user.id
          expect(MiqAeEngine).to receive(:create_automation_object).with("DEFAULT", attrs, :fqclass => "Factory/StateMachines/ServiceProvision_template").and_return('uri')
          expect(MiqAeEngine.deliver(args)).to eq(@ws)
        end
      end

      context "with ae_result of 'retry'" do
        before(:each) do
          root = {'ae_result' => 'retry'}
          @ws = double('ws')
          allow(@ws).to receive_messages(:root => root)
          allow(@ws).to receive_messages(:persist_state_hash => {})
          allow(@ws).to receive_messages(:current_state_info => {})
          allow(MiqAeEngine).to receive(:resolve_automation_object).and_return(@ws)
        end

        it "with defaults" do
          object_type = @ems.class.name
          object_id   = @ems.id
          expect(call_automate(object_type, object_id)).to eq(@ws)

          expect(MiqQueue.count).to eq(1)

          q = MiqQueue.first
          expect(q.class_name).to eq('MiqAeEngine')
          expect(q.method_name).to eq('deliver')
          expect(q.zone).to be_nil
          expect(q.role).to eq('automate')
          expect(q.msg_timeout).to eq(60.minutes)

          args = {
            :object_type      => object_type,
            :object_id        => object_id,
            :attrs            => @attrs,
            :instance_name    => @instance_name,
            :user_id          => @user.id,
            :miq_group_id     => @user.current_group.id,
            :tenant_id        => @user.current_tenant.id,
            :state            => @state,
            :automate_message => @automate_message,
            :ae_fsm_started   => @ae_fsm_started,
            :ae_state_started => @ae_state_started,
            :ae_state_retries => @ae_state_retries,
          }
          expect(q.args.first).to eq(args)
        end

        it "with defaults, automate role, valid zone" do
          allow_any_instance_of(MiqServer).to receive_messages(:has_active_role? => true)
          object_type = @ems.class.name
          object_id   = @ems.id
          expect(call_automate(object_type, object_id)).to eq(@ws)

          expect(MiqQueue.count).to eq(1)
          expect(MiqQueue.first).to have_attributes(
            :class_name  => 'MiqAeEngine',
            :method_name => 'deliver',
            :zone        => MiqServer.my_zone,
            :role        => 'automate',
            :msg_timeout => 60.minutes,
          )
        end

        it "with defaults, no automate role, nil zone" do
          allow_any_instance_of(MiqServer).to receive_messages(:has_active_role? => false)
          object_type = @ems.class.name
          object_id   = @ems.id
          expect(call_automate(object_type, object_id)).to eq(@ws)

          expect(MiqQueue.count).to eq(1)

          expect(MiqQueue.first).to have_attributes(
            :class_name  => 'MiqAeEngine',
            :method_name => 'deliver',
            :zone        => nil,
            :role        => 'automate',
            :msg_timeout => 60.minutes,
          )
        end
      end
    end
  end

  context ".create_automation_object" do
    it "with various URIs" do
      extras = "MiqServer%3A%3Amiq_server=#{@miq_server_id}"
      env = 'dev'
      {
        "/System/Process/REQUEST?#{extras}&environment=#{env}&message=get_container_info&object_name=REQUEST&request=UI_PROVISION_INFO"  => {'request' => 'UI_PROVISION_INFO', 'message' => 'get_container_info',  'environment' => env},
        "/System/Process/REQUEST?#{extras}&environment=#{env}&message=get_allowed_num_vms&object_name=REQUEST&request=UI_PROVISION_INFO" => {'request' => 'UI_PROVISION_INFO', 'message' => 'get_allowed_num_vms', 'environment' => env},
        "/System/Process/REQUEST?#{extras}&message=get_lease_times&object_name=REQUEST&request=UI_PROVISION_INFO"                        => {'request' => 'UI_PROVISION_INFO', 'message' => 'get_lease_times'},
        "/System/Process/REQUEST?#{extras}&message=get_ttl_warnings&object_name=REQUEST&request=UI_PROVISION_INFO"                       => {'request' => 'UI_PROVISION_INFO', 'message' => 'get_ttl_warnings'},
        "/System/Process/REQUEST?#{extras}&message=get_networks&object_name=REQUEST&request=UI_PROVISION_INFO"                           => {'request' => 'UI_PROVISION_INFO', 'message' => 'get_networks'},
        "/System/Process/REQUEST?#{extras}&message=get_vmname&object_name=REQUEST&request=UI_PROVISION_INFO"                             => {'request' => 'UI_PROVISION_INFO', 'message' => 'get_vmname'},
        "/System/Process/REQUEST?#{extras}&message=get_dialogs&object_name=REQUEST&request=UI_PROVISION_INFO"                            => {'request' => 'UI_PROVISION_INFO', 'message' => 'get_dialogs'},
      }.each { |uri, attrs|
        saved = attrs.dup
        expect(MiqAeEngine.create_automation_object('REQUEST', attrs)).to eq(uri)
        expect(attrs).to eq(saved)
      }

      prov = MiqProvision.new
      prov.id = 42
      expect(MiqAeEngine.create_automation_object('REQUEST', {'request' => 'UI_PROVISION_INFO', 'message' => 'get_host_and_storage'}, :vmdb_object => prov)).to eq("/System/Process/REQUEST?MiqProvision%3A%3Amiq_provision=#{prov.id}&#{extras}&message=get_host_and_storage&object_name=REQUEST&request=UI_PROVISION_INFO&vmdb_object_type=miq_provision")

      user = User.new
      user.id = 42
      begin
        Thread.current[:user] = user
        expect(MiqAeEngine.create_automation_object('REQUEST', {'request' => 'UI_PROVISION_INFO', 'message' => 'get_host_and_storage'}, :vmdb_object => prov)).to eq("/System/Process/REQUEST?MiqProvision%3A%3Amiq_provision=#{prov.id}&#{extras}&User%3A%3Auser=#{user.id}&message=get_host_and_storage&object_name=REQUEST&request=UI_PROVISION_INFO&vmdb_object_type=miq_provision")
      ensure
        Thread.current[:user] = nil
      end
    end

    it "with a Vm (special case)" do
      vm = FactoryGirl.create(:vm_vmware)
      extras = "MiqServer%3A%3Amiq_server=#{@miq_server_id}"
      uri = "/System/Process/AUTOMATION?#{extras}&VmOrTemplate%3A%3Avm=#{vm.id}&object_name=AUTOMATION&vmdb_object_type=vm"
      expect(MiqAeEngine.create_automation_object("AUTOMATION", {}, :vmdb_object => vm)).to eq(uri)
    end

    it "with a starting point other than /SYSTEM/PROCESS" do
      vm = FactoryGirl.create(:vm_vmware)
      fqclass = "Factory/StateMachines/ServiceProvision_template"
      uri = MiqAeEngine.create_automation_object("DEFAULT", {}, :vmdb_object => vm, :fqclass => fqclass)
      extras = "MiqServer%3A%3Amiq_server=#{@miq_server_id}"
      expected_uri = "/#{fqclass}/DEFAULT?#{extras}&VmOrTemplate%3A%3Avm=#{vm.id}&object_name=DEFAULT&vmdb_object_type=vm"
      expect(uri).to eq(expected_uri)
    end

    it "will not override values in attrs" do
      host  = FactoryGirl.create(:host)
      attrs = {"Host::host" => host.id, "MiqServer::miq_server" => "12"}
      extras = "MiqServer%3A%3Amiq_server=12"
      uri = "/System/Process/AUTOMATION?Host%3A%3Ahost=#{host.id}&#{extras}&object_name=AUTOMATION&vmdb_object_type=host"
      expect(MiqAeEngine.create_automation_object("AUTOMATION", attrs, :vmdb_object => host)).to eq(uri)
    end

    it "will process an array of objects" do
      FactoryGirl.create(:host)
      hash       = {"hosts" => Host.all}
      attrs      = {"Array::my_hosts" => hash["hosts"].collect { |h| "Host::#{h.id}" }}
      result_str = "Array%3A%3Amy_hosts=" + hash["hosts"].collect { |h| "Host%3A%3A#{h.id}" }.join(",")
      extras = "MiqServer%3A%3Amiq_server=#{@miq_server_id}"
      uri = "/System/Process/AUTOMATION?#{result_str}&#{extras}&object_name=AUTOMATION"
      expect(MiqAeEngine.create_automation_object("AUTOMATION", attrs)).to eq(uri)
    end

    it "will process an empty array" do
      attrs      = {"Array::my_hosts" => ""}
      result_str = "Array%3A%3Amy_hosts="
      extras = "MiqServer%3A%3Amiq_server=#{@miq_server_id}"
      uri = "/System/Process/AUTOMATION?#{result_str}&#{extras}&object_name=AUTOMATION"
      expect(MiqAeEngine.create_automation_object("AUTOMATION", attrs)).to eq(uri)
    end

    it "will process an array of objects with a server and user" do
      extras = "MiqServer%3A%3Amiq_server=12"
      FactoryGirl.create(:small_environment)
      attrs = {"MiqServer::miq_server" => "12", "array::tag" => "Classification::1,Classification::2"}
      result_str = "array%3A%3Atag=Classification%3A%3A1%2CClassification%3A%3A2"
      uri = "/System/Process/AUTOMATION?#{extras}&#{result_str}&object_name=AUTOMATION"
      expect(MiqAeEngine.create_automation_object("AUTOMATION", attrs)).to eq(uri)
    end
  end

  context ".create_automation_attribute_key" do
    it "with a Vm (special case)" do
      vm = FactoryGirl.create(:vm_vmware)
      expect(MiqAeEngine.create_automation_attribute_key(vm)).to eq("VmOrTemplate::vm")
    end

    it "with an EMS" do
      ems = FactoryGirl.create(:ems_vmware)
      expect(MiqAeEngine.create_automation_attribute_key(ems)).to eq("ExtManagementSystem::ext_management_system")
    end

    it "with a Host" do
      host = FactoryGirl.create(:host)
      expect(MiqAeEngine.create_automation_attribute_key(host)).to eq("Host::host")
    end

    it "with an EmsCluster" do
      cluster = FactoryGirl.create(:ems_cluster)
      expect(MiqAeEngine.create_automation_attribute_key(cluster)).to eq("EmsCluster::ems_cluster")
    end

    it "with an Array:: name" do
      expect(MiqAeEngine.create_automation_attribute_key("Array::var1")).to eq("Array::var1")
    end
  end

  context ".create_automation_attribute_class_name" do
    it "with an Array:: name" do
      expect(MiqAeEngine.create_automation_attribute_class_name("Array::fred")).to eq("Array::fred")
    end

    it "with an VmOrTemplate" do
      vm = FactoryGirl.create(:vm_vmware)
      expect(MiqAeEngine.create_automation_attribute_class_name(vm)).to eq("VmOrTemplate")
    end

    it "with an Host" do
      host = FactoryGirl.create(:host)
      expect(MiqAeEngine.create_automation_attribute_class_name(host)).to eq("Host")
    end
  end

  context ".create_automation_attributes" do
    before(:each) do
      FactoryGirl.create(:small_environment)
    end

    it "with an array of Vms" do
      hash          = {"vms" => Vm.all}
      result_str    = "Array::vms=" + hash["vms"].collect { |v| "ManageIQ::Providers::Vmware::InfraManager::Vm::#{v.id}" }.join(",")
      result_arr    = hash["vms"].collect { |v| "ManageIQ::Providers::Vmware::InfraManager::Vm::#{v.id}" }.join(",")
      result        = MiqAeEngine.create_automation_attributes(hash)
      expect(MiqAeEngine.create_automation_attributes_string(hash)).to eq(result_str)
      expect(result["Array::vms"]).to eq(result_arr)
    end

    it "with an array containing a single Vm" do
      hash          = {"vms" => [Vm.first]}
      result_str    = "Array::vms=" + hash["vms"].collect { |v| "ManageIQ::Providers::Vmware::InfraManager::Vm::#{v.id}" }.join(",")
      result_arr    = hash["vms"].collect { |v| "ManageIQ::Providers::Vmware::InfraManager::Vm::#{v.id}" }.join(",")
      result        = MiqAeEngine.create_automation_attributes(hash)
      expect(MiqAeEngine.create_automation_attributes_string(hash)).to eq(result_str)
      expect(result["Array::vms"]).to eq(result_arr)
    end

    it "with an empty array" do
      result        = MiqAeEngine.create_automation_attributes({"vms" => []})
      expect(result["Array::vms"]).to eq("")
    end

    it "with a hash containing a single Vm" do
      vm            = Vm.first
      hash          = {"vms" => vm}
      result        = MiqAeEngine.create_automation_attributes(hash)
      expect(MiqAeEngine.create_automation_attributes_string(hash)).to eq("VmOrTemplate::vms=#{vm.id}")
      expect(result["VmOrTemplate::vms"]).to eq(vm.id)
    end

    it "with an array of Hosts" do
      hash          = {"hosts" => Host.all}
      result_str    = "Array::hosts=" + hash["hosts"].collect { |h| "Host::#{h.id}" }.join(",")
      result_arr    = hash["hosts"].collect { |h| "Host::#{h.id}" }.join(",")
      result        = MiqAeEngine.create_automation_attributes(hash)
      expect(MiqAeEngine.create_automation_attributes_string(hash)).to eq(result_str)
      expect(result["Array::hosts"]).to eq(result_arr)
    end

    it "with multiple arrays" do
      hash            = {"vms" => Vm.all}
      vm_result_str   = "Array::vms=" + hash["vms"].collect { |v| "ManageIQ::Providers::Vmware::InfraManager::Vm::#{v.id}" }.join(",")
      vm_result_arr   = hash["vms"].collect { |v| "ManageIQ::Providers::Vmware::InfraManager::Vm::#{v.id}" }.join(",")
      hash["hosts"]   = Host.all
      host_result_str = "Array::hosts=" + hash["hosts"].collect { |h| "Host::#{h.id}" }.join(",")
      host_result_arr = hash["hosts"].collect { |h| "Host::#{h.id}" }.join(",")
      result          = MiqAeEngine.create_automation_attributes(hash)
      expect(result["Array::vms"]).to eq(vm_result_arr)
      expect(result["Array::hosts"]).to eq(host_result_arr)
      result_str = MiqAeEngine.create_automation_attributes_string(hash)
      expect(result_str).to include(vm_result_str)
      expect(result_str).to include(host_result_str)
    end

    it "with invalid object references" do
      hash          = {"vms" => ["bogus::12"]}
      result        = MiqAeEngine.create_automation_attributes(hash)
      expect(result["Array::vms"]).to eq("bogus::12")
      expect(MiqAeEngine.create_automation_attributes_string(hash)).to eq("Array::vms=bogus::12")
    end

    it "with garbage values" do
      hash          = {"vms" => ["bogus::12,garbage::moreso,notevenclose"]}
      bogus_arr     = "bogus::12,garbage::moreso,notevenclose"
      result        = MiqAeEngine.create_automation_attributes(hash)
      expect(result["Array::vms"]).to eq(bogus_arr)
      expect(MiqAeEngine.create_automation_attributes_string(hash)).to eq("Array::vms=bogus::12,garbage::moreso,notevenclose")
    end

    it "with a string value" do
      expect(MiqAeEngine.create_automation_attributes("somestring")).to eq("somestring")
      expect(MiqAeEngine.create_automation_attributes("somestring")).to eq("somestring")
    end

    it "with a string value" do
      expect(MiqAeEngine.create_automation_attributes("")).to eq("")
      expect(MiqAeEngine.create_automation_attributes("")).to eq("")
    end
  end

  context ".set_automation_attributes_from_objects" do
    before(:each) do
      FactoryGirl.create(:small_environment)
    end
    it "with an array of nil objects" do
      hash = {}
      MiqAeEngine.set_automation_attributes_from_objects([nil, nil], hash)
      expect(hash).to be_empty
    end

    it "with an array of nil and valid objects" do
      hash = {:a => 'A', 'b' => 'b'}
      expected_hash = hash.merge("VmOrTemplate::vm" => Vm.first.id, "Host::host" => Host.first.id)
      MiqAeEngine.set_automation_attributes_from_objects([Vm.first, nil, Host.first], hash)
      expect(hash).to eq(expected_hash)
    end

    it "raise error if the object is already in the hash" do
      hash = {:a => 'A', "VmOrTemplate::vm" => Vm.first.id}
      expect { MiqAeEngine.set_automation_attributes_from_objects([Vm.first], hash) }
        .to raise_error(RuntimeError, /vm already exists in hash/)
    end
  end

  context ".automation_attribute_is_array?" do
    it "is true" do
      expect(MiqAeEngine.automation_attribute_is_array?("Array::doesntmatter")).to be_truthy
    end

    it "is true lower case" do
      expect(MiqAeEngine.automation_attribute_is_array?("array::doesntmatter")).to be_truthy
    end

    it "is false" do
      expect(MiqAeEngine.automation_attribute_is_array?("somethingelse::doesntmatter")).to be_falsey
    end

    it "is false with nil value" do
      expect(MiqAeEngine.automation_attribute_is_array?(nil)).to be_falsey
    end
  end

  it "a namespace containing a slash is parsed correctly " do
    start   = "namespace/more_namespace/my_favorite_class"
    msg_attrs = "message=testmessage&object_name=REQUEST&request=NOT_THERE"
    extras = "MiqServer%3A%3Amiq_server=#{@miq_server_id}"
    uri =  "/namespace/more_namespace/my_favorite_class/REQUEST?#{extras}&#{msg_attrs}"
    attrs  = {'request' => 'NOT_THERE', 'message' => 'testmessage'}
    expect(MiqAeEngine.create_automation_object('REQUEST', attrs, :fqclass => start)).to eq(uri)
  end

  it "a namespace not containing a slash is parsed correctly " do
    start   = "namespace/my_favorite_class"
    msg_attrs = "message=testmessage&object_name=REQUEST&request=NOT_THERE"
    extras = "MiqServer%3A%3Amiq_server=#{@miq_server_id}"
    uri =  "/namespace/my_favorite_class/REQUEST?#{extras}&#{msg_attrs}"
    attrs  = {'request' => 'NOT_THERE', 'message' => 'testmessage'}
    expect(MiqAeEngine.create_automation_object('REQUEST', attrs, :fqclass => start)).to eq(uri)
  end

  it "instantiates attributes properly" do
    EvmSpecHelper.import_yaml_model(File.join(@model_data_dir, "miq_ae_engine_spec1"), @domain)

    ws = MiqAeEngine.instantiate("/EVM/AUTOMATE/test3", @user)
    expect(ws).not_to be_nil
    roots = ws.roots
    expect(roots).not_to be_nil
    expect(roots).to be_a_kind_of(Array)
    expect(roots.length).to eq(1)
    expect(roots.first.attributes["attr1"]).to eq("Gregg TEST2 Oleg")

    ws.instantiate("/EVM/AUTOMATE/test2", @user)
    expect(ws.roots.length).to eq(2)
    expect(ws.roots[1].attributes["attr1"]).to eq("TEST2")

    ws.instantiate("/EVM/AUTOMATE/test1", @user)
    expect(ws.roots.length).to eq(3)
    expect(ws.roots[2].attributes["attr1"]).to eq("frank")

    ws.instantiate("/EVM/AUTOMATE/test4", @user)
    expect(ws.roots.length).to eq(4)
    expect(ws.roots[3].attributes["attr1"]).to eq("frank")

    # puts ws.to_expanded_xml()

    ws = MiqAeEngine.instantiate("/EVM/AUTOMATE/test_password", @user)
    expect(ws).not_to be_nil
    roots = ws.roots
    expect(roots).not_to be_nil
    expect(roots).to be_a_kind_of(Array)
    expect(roots.length).to eq(1)
    expect(MiqAePassword.decrypt_if_password(roots.first.attributes["password"])).to eq("secret")
    # puts ws.to_expanded_xml()
  end

  it "follows relationships properly" do
    EvmSpecHelper.import_yaml_model(File.join(@model_data_dir, "relation"), @domain)
    ws = MiqAeEngine.instantiate("/EVM/AUTOMATE/test3", @user)
    expect(ws).not_to be_nil
    roots = ws.roots
    expect(roots).not_to be_nil
    expect(roots).to be_a_kind_of(Array)
    expect(roots.length).to eq(1)

    root = roots.first
    expect(root.namespace).to eql("#{@domain}/EVM")
    expect(root.klass).to eql("AUTOMATE")
    expect(root.instance).to eql("test3")

    children = root.children
    expect(children).not_to be_nil
    expect(children.length).to eq(1)

    child = children.first
    expect(child.namespace).to eql("#{@domain}/EVM")
    expect(child.klass).to eql("AUTOMATE")
    expect(child.instance).to eql("test2")

    ws = MiqAeEngine.instantiate("/EVM/AUTOMATE/test_wildcard", @user)
    expect(ws).not_to be_nil
    roots = ws.roots
    expect(roots).not_to be_nil
    expect(roots).to be_a_kind_of(Array)
    expect(roots.length).to eq(1)
    root = roots.first
    children = root.children
    expect(children).not_to be_nil
    expect(children.length).to eq(2)

    ws = MiqAeEngine.instantiate("/EVM/AUTOMATE/test_message1", @user)
    expect(ws).not_to be_nil
    roots = ws.roots
    expect(roots).not_to be_nil
    expect(roots).to be_a_kind_of(Array)
    expect(roots.length).to eq(1)
    root = roots.first
    children = root.children
    expect(children).not_to be_nil
    expect(children.length).to eq(1)

    ws = MiqAeEngine.instantiate("/EVM/AUTOMATE/test_message1#discover", @user)
    expect(ws).not_to be_nil
    roots = ws.roots
    expect(roots).not_to be_nil
    expect(roots).to be_a_kind_of(Array)
    expect(roots.length).to eq(1)
    root = roots.first
    children = root.children
    expect(children).not_to be_nil
    expect(children.length).to eq(2)
  end

  it "does not allow cyclical relationships" do
    EvmSpecHelper.import_yaml_model(File.join(@model_data_dir, "miq_ae_engine_spec2"), @domain)
    expect { MiqAeEngine.instantiate("/CYCLICAL/AUTOMATE/test4", @user) }.to raise_error(MiqAeException::CyclicalRelationship)
  end

  it "raises exception if invalid path" do
    expect { MiqAeEngine.instantiate("miqaedb:A/EVM", @user) }.to raise_exception(MiqAeException::InvalidPathFormat)
  end

  it "raises exception if invalid path" do
    expect { MiqAeEngine.instantiate("abc:A/EVM", @user) }.to raise_exception(MiqAeException::InvalidPathFormat)
  end

  it "properly processes assertions" do
    EvmSpecHelper.import_yaml_model(File.join(@model_data_dir, "miq_ae_engine_spec3"), @domain)
    ws = MiqAeEngine.instantiate("/SYSTEM/EVM/AUTOMATE/test1", @user)
    expect(ws).not_to be_nil
    roots = ws.roots
    expect(roots).not_to be_nil
    expect(roots).to be_a_kind_of(Array)
    expect(roots.length).to eq(1)

    ws = MiqAeEngine.instantiate("/SYSTEM/EVM/AUTOMATE/test2", @user)
    expect(ws).not_to be_nil
    roots = ws.roots
    expect(roots).not_to be_nil
    expect(roots).to be_a_kind_of(Array)
    expect(roots.length).to eq(0)

    ws = MiqAeEngine.instantiate("/SYSTEM/EVM/AUTOMATE/test3", @user)
    expect(ws).not_to be_nil
    roots = ws.roots
    expect(roots).not_to be_nil
    expect(roots).to be_a_kind_of(Array)
    expect(roots.length).to eq(1)

    ws = MiqAeEngine.instantiate("/SYSTEM/EVM/AUTOMATE/test4", @user)
    expect(ws).not_to be_nil
    roots = ws.roots
    expect(roots).not_to be_nil
    expect(roots).to be_a_kind_of(Array)
    expect(roots.length).to eq(1)
  end

  it "properly processes .missing_instance" do
    EvmSpecHelper.import_yaml_model(File.join(@model_data_dir, "relation"), @domain)

    ws = MiqAeEngine.instantiate("/EVM/MY_AUTOMATE/test_boo", @user)
    expect(ws).not_to be_nil
    roots = ws.roots
    expect(roots).not_to be_nil
    expect(roots).to be_a_kind_of(Array)
    expect(roots.length).to eq(0)
  end

  it "properly processes substitution" do
    EvmSpecHelper.import_yaml_model(File.join(@model_data_dir, "substitution"), @domain)
    ws = MiqAeEngine.instantiate("/EVM/A/a1", @user)
    expect(ws).not_to be_nil
    roots = ws.roots
    expect(roots).not_to be_nil
    expect(roots).to be_a_kind_of(Array)
    expect(roots.length).to eq(1)
    a1 = roots[0]
    b1 = a1.children[0]
    expect(b1.attributes["attr1"]).to eq("defaultA")

    ws = MiqAeEngine.instantiate("/EVM/A/a2", @user)
    expect(ws).not_to be_nil
    roots = ws.roots
    expect(roots).not_to be_nil
    expect(roots).to be_a_kind_of(Array)
    expect(roots.length).to eq(1)
    a2 = roots[0]
    b2 = a2.children[0]
    expect(b2.attributes["attr1"]).to eq("a2")

    ws = MiqAeEngine.instantiate("/EVM/B/b3", @user)
    expect(ws).not_to be_nil
    roots = ws.roots
    expect(roots).not_to be_nil
    expect(roots).to be_a_kind_of(Array)
    expect(roots.length).to eq(1)
    b3 = roots[0]
    expect(b3.attributes["attr2"]).to eq("b3")

    ws = MiqAeEngine.instantiate("/EVM/A/a4", @user)
    expect(ws).not_to be_nil
    roots = ws.roots
    expect(roots).not_to be_nil
    expect(roots).to be_a_kind_of(Array)
    expect(roots.length).to eq(1)
    a4 = roots[0]
    b4 = a4.children[0]
    expect(b4.attributes["attr1"]).to eq("a4")

    expect { MiqAeEngine.instantiate("/EVM/A/a5", @user) }.to raise_error(MiqAeException::InvalidPathFormat)
    expect { MiqAeEngine.instantiate("/EVM/A/a6", @user) }.to raise_error(MiqAeException::ObjectNotFound)
    expect { MiqAeEngine.instantiate("/EVM/A/a7", @user) }.to raise_error(MiqAeException::ObjectNotFound)

    ws = MiqAeEngine.instantiate("/EVM/A/a8", @user)
    expect(ws).not_to be_nil
    roots = ws.roots
    expect(roots).not_to be_nil
    expect(roots).to be_a_kind_of(Array)
    expect(roots.length).to eq(1)
    a8 = roots[0]
    b8 = a8.children[0]
    expect(b8.attributes["attr1"]).to eq("${}")

    ws = MiqAeEngine.instantiate("/EVM/A/a9", @user)
    expect(ws).not_to be_nil
    roots = ws.roots
    expect(roots).not_to be_nil
    expect(roots).to be_a_kind_of(Array)
    expect(roots.length).to eq(1)
    a9 = roots[0]
    b9 = a9.children[0]
    expect(b9.attributes["attr1"]).to eq("foo")

    ws = MiqAeEngine.instantiate("/EVM/A/a10", @user)
    expect(ws).not_to be_nil
    roots = ws.roots
    expect(roots).not_to be_nil
    expect(roots).to be_a_kind_of(Array)
    expect(roots.length).to eql(1)
    a10 = roots[0]
    b10 = a10.children[0]
    expect(b10.attributes["attr1"]).to eql('Bamm Bamm Rubble')
    expect(b10.attributes["attr3"]).to eql('Pearl/Slaghoople')
  end

  it "properly processes substitution with methods" do
    EvmSpecHelper.import_yaml_model(File.join(@model_data_dir, "miq_ae_engine_spec4"), @domain)
    allow_any_instance_of(MiqProvision).to receive(:validate).and_return(:true)
    allow_any_instance_of(MiqProvision).to receive(:set_template_and_networking)
    prov = MiqProvision.create!(:provision_type => 'clone_to_template', :state => 'pending', :status => 'Ok')
    ws   = MiqAeEngine.instantiate("/System/Process/REQUEST?MiqProvision::miq_provision=#{prov.id}&request=test_subst", @user)
    expect(ws).not_to be_nil

    roots = ws.roots
    expect(roots).not_to be_nil
    expect(roots).to be_a_kind_of(Array)
    expect(roots.length).to eql(1)
    root  = roots[0]
    expect(root['request']).to eql('test_subst')
    child = root.children[0]
    expect(child['test_attr']).to eq("target_type=template")
  end

  it "processes arrays arguments properly" do
    vm_name = 'fred flintstone'
    vm1 = FactoryGirl.create(:vm_vmware, :name => vm_name)
    vm2 = FactoryGirl.create(:vm_vmware, :name => vm_name)
    ems = FactoryGirl.create(:ems_vmware)

    EvmSpecHelper.import_yaml_model(File.join(@model_data_dir, "miq_ae_engine_spec5"), @domain)
    ws = MiqAeEngine.instantiate("/EVM/AUTOMATE/test1?Array::my_objects=Vm::#{vm1.id},ExtManagementSystem::#{ems.id},Vm::#{vm2.id}", @user)
    my_objects_array = ws.root("my_objects")
    expect(my_objects_array.length).to eq(3)
    my_objects_array.each { |o| o.kind_of?(MiqAeMethodService::MiqAeServiceModelBase) }
  end

  it "processes an empty array properly" do
    EvmSpecHelper.import_yaml_model(File.join(@model_data_dir, "miq_ae_engine_spec6"), @domain)
    ws = MiqAeEngine.instantiate("/EVM/AUTOMATE/test1?Array::my_objects=", @user)
    my_objects_array = ws.root("my_objects")
    expect(my_objects_array.length).to eq(0)
    expect(my_objects_array).to eq([])
  end
end

describe MiqAeEngine do
  include Spec::Support::AutomationHelper

  before do
    @user = FactoryGirl.create(:user_with_group)
    ae_fields = {'var1' => {:aetype => 'attribute', :datatype => 'string'}}
    ae_instances = {'.missing' => {'var1' => {:value => "${#_missing_instance}"}}}
    create_ae_model(:name => 'DOM1', :ae_namespace => 'NS1', :ae_class => 'CLASS1',
                    :instance_name => '.missing', :ae_fields => ae_fields,
                    :ae_instances => ae_instances)
  end

  it "check _missing_instance" do
    ws = MiqAeEngine.instantiate("/DOM1/NS1/CLASS1/FRED", @user)
    expect(ws.root['var1']).to eq('FRED')
    expect(ws.root['_missing_instance']).to eq('FRED')
  end
end

describe MiqAeEngine do
  context "deliver to automate" do
    let(:test_class) do
      Class.new do
        def self.name; "TestClass"; end
        def before_ae_starts(_options); end
      end
    end
    let(:test_class_name) { test_class.name }
    let(:test_class_instance) { test_class.new }
    let(:workspace) { double("MiqAeEngine::MiqAeWorkspaceRuntime", :root => options) }
    let(:user) { FactoryGirl.create(:user_with_group) }
    let(:options) { {:user_id => user.id, :object_type => test_class_name} }

    it "#before_ae_starts" do
      allow(MiqAeEngine).to receive(:create_automation_object).with(any_args).and_return(nil)
      expect(test_class_name).to receive(:constantize).and_return(test_class)
      expect(test_class).to receive(:find_by).with(any_args).and_return(test_class_instance)
      allow(MiqAeEngine).to receive(:resolve_automation_object).with(any_args).and_return(workspace)
      allow(MiqAeEngine).to receive(:create_automation_attribute_key).with(any_args).and_return("abc")
      expect(test_class_instance).to receive(:before_ae_starts).once.with(options)
      MiqAeEngine.deliver(options)
    end
  end
end

describe MiqAeEngine do
  include Spec::Support::AutomationHelper

  before do
    @user = FactoryGirl.create(:user_with_group)
    nco_value = '${/#var1} || ${XY/ABC#var2} || Pebbles'
    default_value = '${/#var2} || ${XY/ABC#var2} || Bamm Bamm Rubble'
    instance_name = 'FRED'
    ae_instances = {instance_name => {'field1' => {:value => nco_value},
                                      'field2' => {:value => nil},
                                      'field3' => {:value => nil}}}

    ae_fields = {'field1' => {:aetype => 'attribute', :default_value => default_value,
                              :datatype => MiqAeField::NULL_COALESCING_DATATYPE},
                 'field2' => {:aetype => 'attribute', :default_value => default_value,
                              :datatype => MiqAeField::NULL_COALESCING_DATATYPE},
                 'field3' => {:aetype   => 'attribute',
                              :datatype => MiqAeField::NULL_COALESCING_DATATYPE}}
    create_ae_model(:name => 'LUIGI', :ae_class => 'BARNEY',
                    :ae_namespace => 'A/C',
                    :ae_fields => ae_fields, :ae_instances => ae_instances)
  end

  context "null colaescing" do
    it "uses default when variable missing" do
      workspace = MiqAeEngine.instantiate("/A/C/BARNEY/FRED", @user)

      expect(workspace.root['field1']).to eq('Pebbles')
      expect(workspace.root['field2']).to eq('Bamm Bamm Rubble')
    end

    it "first non nil value" do
      workspace = MiqAeEngine.instantiate("/A/C/BARNEY/FRED?var1=wilma", @user)

      expect(workspace.root['field1']).to eq('wilma')
      expect(workspace.root['field2']).to eq('Bamm Bamm Rubble')
    end

    it "undefined variable" do
      workspace = MiqAeEngine.instantiate("/A/C/BARNEY/FRED", @user)
      expect(workspace.root['field2']).to eq('Bamm Bamm Rubble')
      expect(workspace.root.attributes.keys.exclude?('field3')).to be_truthy
    end
  end
end
