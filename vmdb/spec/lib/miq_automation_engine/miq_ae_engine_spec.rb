require "spec_helper"

module MiqAeEngineSpec
  include MiqAeEngine
  describe MiqAeEngine do
    before(:each) do
      MiqServer.my_server_clear_cache
      MiqAeDatastore.reset
      @domain = 'SPEC_DOMAIN'
      @model_data_dir = File.join(File.dirname(__FILE__), "data")
    end

    after(:each) do
      MiqAeDatastore.reset
    end

    context ".deliver" do
      before(:each) do
        MiqServer.stub(:my_zone).and_return("default")
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
          :attrs            => { "request"=>"InspectMe" },
          :object_type      => @vm.class.name,
          :object_id        => @vm.id
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
        status.should_not == MiqQueue::STATUS_ERROR
      end

      context "when Automate instantiation fails" do
        before(:each) do
          MiqAeEngine.stub(:resolve_automation_object).and_return(nil)
        end

        it "with defaults and non-STI object" do
          object_type = @cluster.class.name
          object_id   = @cluster.id
          automate_attrs = {"#{object_type}::#{object_type.underscore}" => object_id}
          MiqAeEngine.should_receive(:create_automation_object).with(@instance_name, automate_attrs, {:vmdb_object => @cluster}).and_return('uri')
          MiqAeEngine.deliver(object_type, object_id).should be_nil
        end

        it "with defaults and STI object" do
          base_name   = @ems.class.base_class.name
          object_type = @ems.class.name
          object_id   = @ems.id
          automate_attrs = {"#{base_name}::#{base_name.underscore}" => object_id}
          MiqAeEngine.should_receive(:create_automation_object).with(@instance_name, automate_attrs, {:vmdb_object => @ems}).and_return('uri')
          MiqAeEngine.deliver(object_type, object_id).should be_nil
        end
      end

      context "when Automate instantiation succeeds" do
        context "with ae_result of 'error'" do
          before(:each) do
            root = { 'ae_result' => 'error' }
            @ws = double('ws')
            @ws.stub(:root => root)
            MiqAeEngine.stub(:resolve_automation_object).and_return(@ws)
          end

          it "with defaults" do
            object_type = @ems.class.name
            object_id   = @ems.id
            MiqAeEngine.deliver(object_type, object_id).should == @ws
          end

        end

        context "with ae_result of 'ok'" do
          before(:each) do
            root = { 'ae_result' => 'ok' }
            @ws = double('ws')
            @ws.stub(:root => root)
            MiqAeEngine.stub(:resolve_automation_object).and_return(@ws)
          end

          it "with defaults" do
            object_type = @ems.class.name
            object_id   = @ems.id
            MiqAeEngine.deliver(object_type, object_id).should == @ws
          end

          it "with a starting point instead of /SYSTEM/PROCESS" do
            args = {}
            automate_attrs =  {}
            args[:instance_name]    = "DEFAULT"
            args[:fqclass_name] = "Factory/StateMachines/ServiceProvision_template"
            MiqAeEngine.should_receive(:create_automation_object).with("DEFAULT", automate_attrs, {:fqclass => "Factory/StateMachines/ServiceProvision_template"}).and_return('uri')
            MiqAeEngine.deliver(args).should == @ws
          end

        end

        context "with ae_result of 'retry'" do
          before(:each) do
            root = { 'ae_result' => 'retry' }
            @ws = double('ws')
            @ws.stub(:root => root)
            @ws.stub(:persist_state_hash => {})
            MiqAeEngine.stub(:resolve_automation_object).and_return(@ws)
          end

          it "with defaults" do
            object_type = @ems.class.name
            object_id   = @ems.id
            MiqAeEngine.deliver(object_type, object_id).should == @ws

            MiqQueue.count.should == 1

            q = MiqQueue.first
            q.class_name.should  == 'MiqAeEngine'
            q.method_name.should == 'deliver'
            q.zone.should        == MiqServer.my_zone
            q.role.should        == 'automate'
            q.msg_timeout.should == 60.minutes

            args = {
              :object_type      => object_type,
              :object_id        => object_id,
              :attrs            => @attrs,
              :instance_name    => @instance_name,
              :user_id          => @user_id,
              :state            => @state,
              :automate_message => @automate_message,
              :ae_fsm_started   => @ae_fsm_started,
              :ae_state_started => @ae_state_started,
              :ae_state_retries => @ae_state_retries
            }
            q.args.first.should == args
          end

        end
      end
    end

    context ".create_automation_object" do
      it "with various URIs" do
        env = 'dev'
        {
          "/System/Process/REQUEST?environment=#{env}&message=get_container_info&object_name=REQUEST&request=UI_PROVISION_INFO"   => { 'request' => 'UI_PROVISION_INFO', 'message' => 'get_container_info',  'environment' => env },
          "/System/Process/REQUEST?environment=#{env}&message=get_allowed_num_vms&object_name=REQUEST&request=UI_PROVISION_INFO"  => { 'request' => 'UI_PROVISION_INFO', 'message' => 'get_allowed_num_vms', 'environment' => env },
          "/System/Process/REQUEST?message=get_lease_times&object_name=REQUEST&request=UI_PROVISION_INFO"                         => { 'request' => 'UI_PROVISION_INFO', 'message' => 'get_lease_times' },
          "/System/Process/REQUEST?message=get_ttl_warnings&object_name=REQUEST&request=UI_PROVISION_INFO"                        => { 'request' => 'UI_PROVISION_INFO', 'message' => 'get_ttl_warnings' },
          "/System/Process/REQUEST?message=get_networks&object_name=REQUEST&request=UI_PROVISION_INFO"                            => { 'request' => 'UI_PROVISION_INFO', 'message' => 'get_networks' },
          "/System/Process/REQUEST?message=get_domains&object_name=REQUEST&request=UI_PROVISION_INFO"                             => { 'request' => 'UI_PROVISION_INFO', 'message' => 'get_domains' },
          "/System/Process/REQUEST?message=get_vmname&object_name=REQUEST&request=UI_PROVISION_INFO"                              => { 'request' => 'UI_PROVISION_INFO', 'message' => 'get_vmname' },
          "/System/Process/REQUEST?message=get_dialogs&object_name=REQUEST&request=UI_PROVISION_INFO"                             => { 'request' => 'UI_PROVISION_INFO', 'message' => 'get_dialogs' },
        }.each { |uri, attrs|
          saved = attrs.dup
          MiqAeEngine.create_automation_object('REQUEST', attrs).should == uri
          attrs.should == saved
        }

        prov = MiqProvision.new
        prov.id = 42
        MiqAeEngine.create_automation_object('REQUEST', { 'request' => 'UI_PROVISION_INFO', 'message' => 'get_host_and_storage' }, :vmdb_object => prov).should == "/System/Process/REQUEST?MiqProvision%3A%3Amiq_provision=#{prov.id}&message=get_host_and_storage&object_name=REQUEST&request=UI_PROVISION_INFO&vmdb_object_type=miq_provision"

        user = User.new
        user.id = 42
        begin
          Thread.current[:user] = user
          MiqAeEngine.create_automation_object('REQUEST', { 'request' => 'UI_PROVISION_INFO', 'message' => 'get_host_and_storage' }, :vmdb_object => prov).should == "/System/Process/REQUEST?MiqProvision%3A%3Amiq_provision=#{prov.id}&User%3A%3Auser=#{user.id}&message=get_host_and_storage&object_name=REQUEST&request=UI_PROVISION_INFO&vmdb_object_type=miq_provision"
        ensure
          Thread.current[:user] = nil
        end
      end

      it "with a Vm (special case)" do
        vm = FactoryGirl.create(:vm_vmware)
        MiqAeEngine.create_automation_object("AUTOMATION", {}, :vmdb_object => vm).should == "/System/Process/AUTOMATION?VmOrTemplate%3A%3Avm=#{vm.id}&object_name=AUTOMATION&vmdb_object_type=vm"
      end

      it "with a starting point other than /SYSTEM/PROCESS" do
        vm = FactoryGirl.create(:vm_vmware)
        MiqAeEngine.create_automation_object("DEFAULT", {}, :vmdb_object => vm, :fqclass => "Factory/StateMachines/ServiceProvision_template").should == "/Factory/StateMachines/ServiceProvision_template/DEFAULT?VmOrTemplate%3A%3Avm=#{vm.id}&object_name=DEFAULT&vmdb_object_type=vm"
      end

      it "will not override values in attrs" do
        host  = FactoryGirl.create(:host)
        attrs = {"Host::host" => host.id, "MiqServer::miq_server" => "12"}
        MiqAeEngine.create_automation_object("AUTOMATION", attrs, :vmdb_object => host).should == "/System/Process/AUTOMATION?Host%3A%3Ahost=#{host.id}&MiqServer%3A%3Amiq_server=12&object_name=AUTOMATION&vmdb_object_type=host"
      end

      it "will process an array of objects" do
        FactoryGirl.create(:host)
        hash       = {"hosts" => Host.all}
        attrs      = {"Array::my_hosts" => hash["hosts"].collect { |h| "Host::#{h.id}" }}
        result_str = "Array%3A%3Amy_hosts=" + hash["hosts"].collect { |h| "Host%3A%3A#{h.id}" }.join(",")
        MiqAeEngine.create_automation_object("AUTOMATION", attrs).should == "/System/Process/AUTOMATION?#{result_str}&object_name=AUTOMATION"
      end

      it "will process an empty array" do
        hash       = {"hosts" => []}
        attrs      = {"Array::my_hosts" => ""}
        result_str = "Array%3A%3Amy_hosts="""
        MiqAeEngine.create_automation_object("AUTOMATION", attrs).should == "/System/Process/AUTOMATION?#{result_str}&object_name=AUTOMATION"
      end

      it "will process an array of objects with a server and user" do
        FactoryGirl.create(:small_environment)
        attrs      = {"MiqServer::miq_server" => "12", "array::tag" => "Classification::1,Classification::2"}
        result_str = "MiqServer%3A%3Amiq_server=12&array%3A%3Atag=Classification%3A%3A1%2CClassification%3A%3A2"
        MiqAeEngine.create_automation_object("AUTOMATION", attrs).should == "/System/Process/AUTOMATION?#{result_str}&object_name=AUTOMATION"
      end

    end

    context ".create_automation_attribute_key" do
      it "with a Vm (special case)" do
        vm = FactoryGirl.create(:vm_vmware)
        MiqAeEngine.create_automation_attribute_key(vm).should == "VmOrTemplate::vm"
      end

      it "with an EMS" do
        ems = FactoryGirl.create(:ems_vmware)
        MiqAeEngine.create_automation_attribute_key(ems).should == "ExtManagementSystem::ext_management_system"
      end

      it "with a Host" do
        host = FactoryGirl.create(:host)
        MiqAeEngine.create_automation_attribute_key(host).should == "Host::host"
      end

      it "with an EmsCluster" do
        cluster = FactoryGirl.create(:ems_cluster)
        MiqAeEngine.create_automation_attribute_key(cluster).should == "EmsCluster::ems_cluster"
      end

      it "with an Array:: name" do
        MiqAeEngine.create_automation_attribute_key("Array::var1").should == "Array::var1"
      end

    end

    context ".create_automation_attribute_class_name" do
      it "with an Array:: name" do
        MiqAeEngine.create_automation_attribute_class_name("Array::fred").should == "Array::fred"
      end

      it "with an VmOrTemplate" do
        vm = FactoryGirl.create(:vm_vmware)
        MiqAeEngine.create_automation_attribute_class_name(vm).should == "VmOrTemplate"
      end

      it "with an Host" do
        host = FactoryGirl.create(:host)
        MiqAeEngine.create_automation_attribute_class_name(host).should == "Host"
      end

    end


    context ".create_automation_attributes" do
      before(:each) do
        FactoryGirl.create(:small_environment)
      end

      it "with an array of Vms" do
        hash          = {"vms" => Vm.all}
        result_str    = "Array::vms=" + hash["vms"].collect { |v| "VmVmware::#{v.id}" }.join(",")
        result_arr    = hash["vms"].collect { |v| "VmVmware::#{v.id}" }.join(",")
        result        = MiqAeEngine.create_automation_attributes(hash)
        MiqAeEngine.create_automation_attributes_string(hash).should == result_str
        result["Array::vms"].should == result_arr
      end

      it "with an array containing a single Vm" do
        hash          = {"vms" => [Vm.first]}
        result_str    = "Array::vms=" + hash["vms"].collect { |v| "VmVmware::#{v.id}" }.join(",")
        result_arr    = hash["vms"].collect { |v| "VmVmware::#{v.id}" }.join(",")
        result        = MiqAeEngine.create_automation_attributes(hash)
        MiqAeEngine.create_automation_attributes_string(hash).should == result_str
        result["Array::vms"].should == result_arr
      end

      it "with an empty array" do
        result        = MiqAeEngine.create_automation_attributes({"vms" => []})
        result["Array::vms"].should == ""
      end

      it "with a hash containing a single Vm" do
        vm            = Vm.first
        hash          = {"vms" => vm}
        result        = MiqAeEngine.create_automation_attributes(hash)
        MiqAeEngine.create_automation_attributes_string(hash).should == "VmOrTemplate::vms=#{vm.id}"
        result["VmOrTemplate::vms"].should == vm.id
      end

      it "with an array of Hosts" do
        hash          = {"hosts" => Host.all}
        result_str    = "Array::hosts=" + hash["hosts"].collect { |h| "Host::#{h.id}" }.join(",")
        result_arr    = hash["hosts"].collect { |h| "Host::#{h.id}" }.join(",")
        result        = MiqAeEngine.create_automation_attributes(hash)
        MiqAeEngine.create_automation_attributes_string(hash).should == result_str
        result["Array::hosts"].should == result_arr
      end

     it "with multiple arrays" do
        hash            = {"vms" => Vm.all}
        vm_result_str   = "Array::vms=" + hash["vms"].collect { |v| "VmVmware::#{v.id}" }.join(",")
        vm_result_arr   = hash["vms"].collect { |v| "VmVmware::#{v.id}" }.join(",")
        hash["hosts"]   = Host.all
        host_result_str = "Array::hosts=" + hash["hosts"].collect { |h| "Host::#{h.id}" }.join(",")
        host_result_arr = hash["hosts"].collect { |h| "Host::#{h.id}" }.join(",")
        result          = MiqAeEngine.create_automation_attributes(hash)
        result["Array::vms"].should == vm_result_arr
        result["Array::hosts"].should == host_result_arr
        result_str = MiqAeEngine.create_automation_attributes_string(hash)
        result_str.should include(vm_result_str)
        result_str.should include(host_result_str)
      end

     it "with invalid object references" do
        hash          = {"vms" => ["bogus::12"]}
        result        = MiqAeEngine.create_automation_attributes(hash)
        result["Array::vms"].should == "bogus::12"
        MiqAeEngine.create_automation_attributes_string(hash).should == "Array::vms=bogus::12"
      end

     it "with garbage values" do
        hash          = {"vms" => ["bogus::12,garbage::moreso,notevenclose"]}
        bogus_arr     = "bogus::12,garbage::moreso,notevenclose"
        result        = MiqAeEngine.create_automation_attributes(hash)
        result["Array::vms"].should == bogus_arr
        MiqAeEngine.create_automation_attributes_string(hash).should == "Array::vms=bogus::12,garbage::moreso,notevenclose"
      end

     it "with a string value" do
        MiqAeEngine.create_automation_attributes("somestring").should == "somestring"
        MiqAeEngine.create_automation_attributes("somestring").should == "somestring"
      end

     it "with a string value" do
        MiqAeEngine.create_automation_attributes("").should == ""
        MiqAeEngine.create_automation_attributes("").should == ""
      end

    end

    context ".automation_attribute_is_array?" do
      it "is true" do
       MiqAeEngine.automation_attribute_is_array?("Array::doesntmatter").should be_true
      end

      it "is true lower case" do
        MiqAeEngine.automation_attribute_is_array?("array::doesntmatter").should be_true
      end

      it "is false" do
        MiqAeEngine.automation_attribute_is_array?("somethingelse::doesntmatter").should be_false
      end

      it "is false with nil value" do
        MiqAeEngine.automation_attribute_is_array?(nil).should be_false
      end
    end

    it "a namespace containing a slash is parsed correctly " do
      start   = "namespace/more_namespace/my_favorite_class"
      uri =  "/namespace/more_namespace/my_favorite_class/REQUEST?message=testmessage&object_name=REQUEST&request=NOT_THERE"
      attrs  = { 'request' => 'NOT_THERE', 'message' => 'testmessage' }
      MiqAeEngine.create_automation_object('REQUEST', attrs, :fqclass => start).should == uri
    end

    it "a namespace not containing a slash is parsed correctly " do
      start   = "namespace/my_favorite_class"
      uri =  "/namespace/my_favorite_class/REQUEST?message=testmessage&object_name=REQUEST&request=NOT_THERE"
      attrs  = { 'request' => 'NOT_THERE', 'message' => 'testmessage' }
      MiqAeEngine.create_automation_object('REQUEST', attrs, :fqclass => start).should == uri
    end

    it "instantiates attributes properly" do
      EvmSpecHelper.import_yaml_model(File.join(@model_data_dir, "miq_ae_engine_spec1"), @domain)

      ws = MiqAeEngine.instantiate("/EVM/AUTOMATE/test3")
      ws.should_not be_nil
      roots = ws.roots
      roots.should_not be_nil
      roots.should be_a_kind_of(Array)
      roots.length.should == 1
      roots.first.attributes["attr1"].should == "Gregg TEST2 Oleg"

      ws.instantiate("/EVM/AUTOMATE/test2")
      ws.roots.length.should == 2
      ws.roots[1].attributes["attr1"].should == "TEST2"

      ws.instantiate("/EVM/AUTOMATE/test1")
      ws.roots.length.should == 3
      ws.roots[2].attributes["attr1"].should == "frank"

      ws.instantiate("/EVM/AUTOMATE/test4")
      ws.roots.length.should == 4
      ws.roots[3].attributes["attr1"].should == "frank"

      # puts ws.to_expanded_xml()

      ws = MiqAeEngine.instantiate("/EVM/AUTOMATE/test_password")
      ws.should_not be_nil
      roots = ws.roots
      roots.should_not be_nil
      roots.should be_a_kind_of(Array)
      roots.length.should == 1
      MiqAePassword.decrypt_if_password(roots.first.attributes["password"]).should == "secret"
      # puts ws.to_expanded_xml()
    end

    it "follows relationships properly" do
      EvmSpecHelper.import_yaml_model(File.join(@model_data_dir, "relation"), @domain)
      ws = MiqAeEngine.instantiate("/EVM/AUTOMATE/test3")
      ws.should_not be_nil
      roots = ws.roots
      roots.should_not be_nil
      roots.should be_a_kind_of(Array)
      roots.length.should == 1

      root = roots.first
      root.namespace.should eql("#{@domain}/EVM")
      root.klass.should eql("AUTOMATE")
      root.instance.should eql("test3")

      children = root.children
      children.should_not be_nil
      children.length.should == 1

      child = children.first
      child.namespace.should eql("#{@domain}/EVM")
      child.klass.should eql("AUTOMATE")
      child.instance.should eql("test2")

      ws = MiqAeEngine.instantiate("/EVM/AUTOMATE/test_wildcard")
      ws.should_not be_nil
      roots = ws.roots
      roots.should_not be_nil
      roots.should be_a_kind_of(Array)
      roots.length.should == 1
      root = roots.first
      children = root.children
      children.should_not be_nil
      children.length.should == 2

      ws = MiqAeEngine.instantiate("/EVM/AUTOMATE/test_message1")
      ws.should_not be_nil
      roots = ws.roots
      roots.should_not be_nil
      roots.should be_a_kind_of(Array)
      roots.length.should == 1
      root = roots.first
      children = root.children
      children.should_not be_nil
      children.length.should == 1

      ws = MiqAeEngine.instantiate("/EVM/AUTOMATE/test_message1#discover")
      ws.should_not be_nil
      roots = ws.roots
      roots.should_not be_nil
      roots.should be_a_kind_of(Array)
      roots.length.should == 1
      root = roots.first
      children = root.children
      children.should_not be_nil
      children.length.should == 2
    end

    it "does not allow cyclical relationships" do
      EvmSpecHelper.import_yaml_model(File.join(@model_data_dir, "miq_ae_engine_spec2"), @domain)
      lambda {MiqAeEngine.instantiate("/CYCLICAL/AUTOMATE/test4")}.should raise_error(MiqAeException::CyclicalRelationship)
    end

    it "properly processes assertions" do
      EvmSpecHelper.import_yaml_model(File.join(@model_data_dir, "miq_ae_engine_spec3"), @domain)
      ws = MiqAeEngine.instantiate("/SYSTEM/EVM/AUTOMATE/test1")
      ws.should_not be_nil
      roots = ws.roots
      roots.should_not be_nil
      roots.should be_a_kind_of(Array)
      roots.length.should == 1

      ws = MiqAeEngine.instantiate("/SYSTEM/EVM/AUTOMATE/test2")
      ws.should_not be_nil
      roots = ws.roots
      roots.should_not be_nil
      roots.should be_a_kind_of(Array)
      roots.length.should == 0

      ws = MiqAeEngine.instantiate("/SYSTEM/EVM/AUTOMATE/test3")
      ws.should_not be_nil
      roots = ws.roots
      roots.should_not be_nil
      roots.should be_a_kind_of(Array)
      roots.length.should == 1

      ws = MiqAeEngine.instantiate("/SYSTEM/EVM/AUTOMATE/test4")
      ws.should_not be_nil
      roots = ws.roots
      roots.should_not be_nil
      roots.should be_a_kind_of(Array)
      roots.length.should == 1
    end

    it "properly processes inheritance" do
      EvmSpecHelper.import_yaml_model(File.join(@model_data_dir, "relation"), @domain)

      ws = MiqAeEngine.instantiate("/EVM/MY_AUTOMATE/test1")
      ws.should_not be_nil
      roots = ws.roots
      roots.should_not be_nil
      roots.should be_a_kind_of(Array)
      roots.length.should == 1

      obj = roots.first
      ["attr1", "foo"].each {|a| obj.attributes.should have_key(a) }
      obj.attributes["attr1"].should == "frank"
      obj.attributes["foo"].should   == "bar"

      ws = MiqAeEngine.instantiate("/EVM/MY_AUTOMATE/test2")
      ws.should_not be_nil
      roots = ws.roots
      roots.should_not be_nil
      roots.should be_a_kind_of(Array)
      roots.length.should == 1

      obj = roots.first
      ["attr1", "foo"].each {|a| assert obj.attributes.has_key?(a)}
      obj.attributes["attr1"].should == "miqaedb:/EVM/AUTOMATE/test1"
      obj.attributes["foo"].should   == "bar"
    end

    it "properly processes .missing_instance" do
      EvmSpecHelper.import_yaml_model(File.join(@model_data_dir, "relation"), @domain)

      ws = MiqAeEngine.instantiate("/EVM/MY_AUTOMATE/test_boo")
      ws.should_not be_nil
      roots = ws.roots
      roots.should_not be_nil
      roots.should be_a_kind_of(Array)
      roots.length.should == 0
    end

    it "properly processes substitution" do
      EvmSpecHelper.import_yaml_model(File.join(@model_data_dir, "substitution"), @domain)
      ws = MiqAeEngine.instantiate("/EVM/A/a1")
      ws.should_not be_nil
      roots = ws.roots
      roots.should_not be_nil
      roots.should be_a_kind_of(Array)
      roots.length.should == 1
      a1 = roots[0]
      b1 = a1.children[0]
      b1.attributes["attr1"].should == "defaultA"

      ws = MiqAeEngine.instantiate("/EVM/A/a2")
      ws.should_not be_nil
      roots = ws.roots
      roots.should_not be_nil
      roots.should be_a_kind_of(Array)
      roots.length.should == 1
      a2 = roots[0]
      b2 = a2.children[0]
      b2.attributes["attr1"].should == "a2"

      ws = MiqAeEngine.instantiate("/EVM/B/b3")
      ws.should_not be_nil
      roots = ws.roots
      roots.should_not be_nil
      roots.should be_a_kind_of(Array)
      roots.length.should == 1
      b3 = roots[0]
      b3.attributes["attr2"].should == "b3"

      ws = MiqAeEngine.instantiate("/EVM/A/a4")
      ws.should_not be_nil
      roots = ws.roots
      roots.should_not be_nil
      roots.should be_a_kind_of(Array)
      roots.length.should == 1
      a4 = roots[0]
      b4 = a4.children[0]
      b4.attributes["attr1"].should == "a4"

      -> { MiqAeEngine.instantiate("/EVM/A/a5") }.should raise_error(MiqAeException::InvalidPathFormat)
      -> { MiqAeEngine.instantiate("/EVM/A/a6") }.should raise_error(MiqAeException::ObjectNotFound)
      -> { MiqAeEngine.instantiate("/EVM/A/a7") }.should raise_error(MiqAeException::ObjectNotFound)

      ws = MiqAeEngine.instantiate("/EVM/A/a8")
      ws.should_not be_nil
      roots = ws.roots
      roots.should_not be_nil
      roots.should be_a_kind_of(Array)
      roots.length.should == 1
      a8 = roots[0]
      b8 = a8.children[0]
      b8.attributes["attr1"].should == "${}"

      ws = MiqAeEngine.instantiate("/EVM/A/a9")
      ws.should_not be_nil
      roots = ws.roots
      roots.should_not be_nil
      roots.should be_a_kind_of(Array)
      roots.length.should == 1
      a9 = roots[0]
      b9 = a9.children[0]
      b9.attributes["attr1"].should == "foo"

      ws = MiqAeEngine.instantiate("/EVM/A/a10")
      ws.should_not be_nil
      roots = ws.roots
      roots.should_not be_nil
      roots.should be_a_kind_of(Array)
      roots.length.should eql(1)
      a10 = roots[0]
      b10 = a10.children[0]
      b10.attributes["attr1"].should eql('Bamm Bamm Rubble')
      b10.attributes["attr3"].should eql('Pearl/Slaghoople')
    end

    it "properly processes substitution with methods" do
      EvmSpecHelper.import_yaml_model(File.join(@model_data_dir, "miq_ae_engine_spec4"), @domain)
      MiqProvision.any_instance.stub(:validate).and_return(:true)
      MiqProvision.any_instance.stub(:set_template_and_networking)
      prov = MiqProvision.create!(:provision_type => 'clone_to_template', :state => 'pending', :status => 'Ok')
      ws   = MiqAeEngine.instantiate "/System/Process/REQUEST?MiqProvision::miq_provision=#{prov.id}&request=test_subst"
      ws.should_not be_nil

      roots = ws.roots
      roots.should_not be_nil
      roots.should be_a_kind_of(Array)
      roots.length.should eql(1)
      root  = roots[0]
      root['request'].should eql('test_subst')
      child = root.children[0]
      child['test_attr'].should == "target_type=template"
    end

    it "processes arrays arguments properly" do
      vm_name = 'fred flintstone'
      vm1 = FactoryGirl.create(:vm_vmware, :name => vm_name)
      vm2 = FactoryGirl.create(:vm_vmware, :name => vm_name)
      ems = FactoryGirl.create(:ems_vmware)

      EvmSpecHelper.import_yaml_model(File.join(@model_data_dir, "miq_ae_engine_spec5"), @domain)
      ws = MiqAeEngine.instantiate("/EVM/AUTOMATE/test1?Array::my_objects=Vm::#{vm1.id},ExtManagementSystem::#{ems.id},Vm::#{vm2.id}")
      my_objects_array = ws.root("my_objects")
      my_objects_array.length.should  == 3
      my_objects_array.each { |o| o.kind_of?(MiqAeMethodService::MiqAeServiceModelBase) }
    end

    it "processes an empty array properly" do

      EvmSpecHelper.import_yaml_model(File.join(@model_data_dir, "miq_ae_engine_spec6"), @domain)
      ws = MiqAeEngine.instantiate("/EVM/AUTOMATE/test1?Array::my_objects=")
      my_objects_array = ws.root("my_objects")
      my_objects_array.length.should  == 0
      my_objects_array.should == []
    end
  end
end
