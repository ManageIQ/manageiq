describe ApplicationHelper do
  before do
    login_as @user = FactoryGirl.create(:user)
    allow(@user).to receive(:role_allows?).and_return(true)
    allow(@user).to receive(:role_allows_any?).and_return(true)
  end

  context "build_toolbar" do
    it 'should substitute dynamic function values' do
      req        = ActionDispatch::Request.new Rack::MockRequest.env_for '/?controller=foo'
      menu_info  = helper.build_toolbar 'storages_center_tb'
      title_text = ui_lookup(:tables => "storages")

      menu_info[0][:items].collect do |value|
        ['title', :confirm].each do |field|
          if value[field]
            expect(value[field]).to match(title_text)
          end
        end
      end
    end

    it 'should substitute dynamic ivar values' do
      req = ActionDispatch::Request.new Rack::MockRequest.env_for '/?controller=foo'
      controller.instance_variable_set(:@sb,
                                       :active_tree => :cb_reports_tree,
                                       :nodeid      => 'Storage',
                                       :mode        => 'foo')

      menu_info  = helper.build_toolbar 'miq_policies_center_tb'
      title_text = ui_lookup(:model => "Storage")

      menu_info[0][:items].collect do |value|
        next unless value['title']
        expect(value['title']).to match(title_text)
        expect(value['title']).to match("Foo") # from :mode
      end
    end
  end

  describe "#role_allows" do
    let(:features) { MiqProductFeature.find_all_by_identifier("everything") }
    before(:each) do
      EvmSpecHelper.seed_specific_product_features("miq_report", "service")

      @user        = FactoryGirl.create(:user, :features => features)
      login_as  @user
    end

    context "permission store" do
      it 'consults the permission store' do
        begin
          current_store = Vmdb::PermissionStores.instance
          Tempfile.open('foo') do |tf|
            menu = Menu::DefaultMenu.services_menu_section

            tf.write Psych.dump [menu.id]
            tf.close

            Vmdb::PermissionStores.configure do |config|
              config.backend = 'yaml'
              config.options[:filename] = tf.path
            end
            Vmdb::PermissionStores.initialize!

            expect(Menu::DefaultMenu.services_menu_section.visible?).to be_truthy
            expect(Menu::DefaultMenu.cloud_inteligence_menu_section.visible?).to be_falsey

            allow(User).to receive_message_chain(:current_user, :role_allows?).and_return(true)
            expect(Menu::DefaultMenu.cloud_inteligence_menu_section.visible?).to be_falsey
          end
        ensure
          Vmdb::PermissionStores.instance = current_store
        end
      end
    end

    context "when with :feature" do
      context "and :any" do
        it "and entitled" do
          expect(helper.role_allows(:feature => "miq_report", :any => true)).to be_truthy
        end

        it "and not entitled" do
          allow(@user).to receive_messages(:role_allows_any? => false)
          expect(helper.role_allows(:feature => "miq_report", :any => true)).to be_falsey
        end
      end

      context "and no :any" do
        it "and entitled" do
          expect(helper.role_allows(:feature => "miq_report")).to be_truthy
        end

        it "and not entitled" do
          allow(@user).to receive_messages(:role_allows? => false)
          expect(helper.role_allows(:feature => "miq_report")).to be_falsey
        end
      end
    end

    context "when with :main_tab_id" do
      it "and entitled" do
        expect(Menu::DefaultMenu.services_menu_section.visible?).to be_truthy
      end

      it "and not entitled" do
        allow(@user).to receive_messages(:role_allows_any? => false)
        expect(Menu::DefaultMenu.services_menu_section.visible?).to be_falsey
      end
    end

    it "when not with :feature or :main_tab_id" do
      expect(helper.role_allows).to be_falsey
    end
  end

  describe "#model_to_controller" do
    subject { helper.model_to_controller(@record) }

    it "when with any record" do
      @record = FactoryGirl.create(:vm_vmware)
      expect(subject).to eq(@record.class.base_model.name.underscore)
    end

    it "when record is nil" do
      expect { helper.model_to_controller(nil) }.to raise_error(NoMethodError)
    end
  end

  describe "#object_types_for_flash_message" do
    before do
      @record_1 = FactoryGirl.create(:vm_openstack, :type => ManageIQ::Providers::Openstack::CloudManager::Vm.name,       :template => false)
      @record_2 = FactoryGirl.create(:vm_openstack, :type => ManageIQ::Providers::Openstack::CloudManager::Vm.name,       :template => false)
      @record_3 = FactoryGirl.create(:vm_openstack, :type => ManageIQ::Providers::Openstack::CloudManager::Template.name, :template => true)
      @record_4 = FactoryGirl.create(:vm_openstack, :type => ManageIQ::Providers::Openstack::CloudManager::Template.name, :template => true)
      @record_5 = FactoryGirl.create(:vm_redhat,    :type => ManageIQ::Providers::Redhat::InfraManager::Vm.name)
      @record_6 = FactoryGirl.create(:vm_vmware,    :type => ManageIQ::Providers::Vmware::InfraManager::Vm.name)
    end

    context "when formatting flash message for VM or Templates class" do
      before do
        @klass = VmOrTemplate
      end

      it "with one Instance" do
        record_ids = [@record_1.id]
        expect(helper.object_types_for_flash_message(@klass, record_ids)).to eq("Instance")
      end

      it "with multiple Instances" do
        record_ids = [@record_1.id, @record_2.id]
        expect(helper.object_types_for_flash_message(@klass, record_ids)).to eq("Instances")
      end

      it "with one Instance and one Image" do
        record_ids = [@record_1.id, @record_3.id]
        expect(helper.object_types_for_flash_message(@klass, record_ids)).to eq("Image and Instance")
      end

      it "with one Instance and multiple Images" do
        record_ids = [@record_1.id, @record_3.id, @record_4.id]
        expect(helper.object_types_for_flash_message(@klass, record_ids)).to eq("Images and Instance")
      end

      it "with multiple Instances and multiple Images" do
        record_ids = [@record_1.id, @record_2.id, @record_3.id, @record_4.id]
        expect(helper.object_types_for_flash_message(@klass, record_ids)).to eq("Images and Instances")
      end

      it "with multiple Instances and one Virtual Machine" do
        record_ids = [@record_1.id, @record_2.id, @record_5.id]
        expect(helper.object_types_for_flash_message(@klass, record_ids)).to eq("Instances and Virtual Machine")
      end

      it "with multiple Instances and multiple Virtual Machines" do
        record_ids = [@record_1.id, @record_2.id, @record_5.id, @record_6.id]
        expect(helper.object_types_for_flash_message(@klass, record_ids)).to eq("Instances and Virtual Machines")
      end

      it "with multiple Instances, one Image and multiple Virtual Machines" do
        record_ids = [@record_5.id, @record_6.id, @record_1.id, @record_2.id, @record_4.id]
        expect(helper.object_types_for_flash_message(@klass, record_ids)).to eq("Image, Instances, and Virtual Machines")
      end

      it "with multiple Instances, multiple Images and multiple Virtual Machines" do
        record_ids = [@record_5.id, @record_6.id, @record_1.id, @record_2.id, @record_3.id, @record_4.id]
        expect(helper.object_types_for_flash_message(@klass, record_ids)).to eq("Images, Instances, and Virtual Machines")
      end
    end

    context "when formatting flash message for Non VM or Templates class" do
      before do
        @klass = Service
      end

      it "with one Service" do
        record_ids = [@record_1.id]
        expect(helper.object_types_for_flash_message(@klass, record_ids)).to eq("Service")
      end

      it "with multiple Services" do
        record_ids = [@record_1.id, @record_2.id]
        expect(helper.object_types_for_flash_message(@klass, record_ids)).to eq("Services")
      end
    end
  end

  describe "#url_for_record" do
    subject { helper.url_for_record(@record, @action = "show") }

    it "when record is VmOrTemplate" do
      @record = Vm.new
      expect(subject).to eq(helper.url_for_db(helper.controller_for_vm(helper.model_for_vm(@record)), @action))
    end

    it "when record is not VmOrTemplate" do
      @record = FactoryGirl.create(:host)
      expect(subject).to eq(helper.url_for_db(@record.class.base_class.to_s, @action))
    end
  end

  describe "#url_for_db" do
    before do
      @action = 'show'
      @id = 12
    end

    context "when with @vm" do
      before do
        @vm = FactoryGirl.create(:vm_vmware)
      end

      ["Account", "User", "Group", "Patch", "GuestApplication"].each do |d|
        it "and db = #{d}" do
          db = d
          @last_action = (d == "Account" ? "users" : d.tableize)
          expect(helper.url_for_db(db, @action)).to eq(helper.url_for(:controller => "vm_or_template",
                                                                      :action     => @lastaction,
                                                                      :id         => @vm,
                                                                      :show       => @id))
        end
      end

      it "otherwise" do
        db = "vm"
        c, a = helper.db_to_controller(db, @action)
        expect(helper.url_for_db(db, @action)).to eq(helper.url_for(:controller => c, :action => a, :id => @id))
      end
    end

    context "when with @host" do
      before do
        @host = FactoryGirl.create(:host)
        @lastaction = "list"
      end

      ["Patch", "GuestApplication"].each do |d|
        it "and db = #{d}" do
          db = d
          expect(helper.url_for_db(db, @action))
            .to eq(helper.url_for(:controller => "host", :action => @lastaction, :id => @host, :show => @id))
        end
      end

      it "otherwise" do
        db = "vm"
        c, a = helper.db_to_controller(db, @action)
        expect(helper.url_for_db(db, @action)).to eq(helper.url_for(:controller => c, :action => a, :id => @id))
      end
    end

    it "when with no @vm, no @host, and no @db" do
      db = 'Vm'
      expect(helper.url_for_db(db, @action)).to eq("/vm/#{@action}/#{@id}")
    end
  end

  describe "#db_to_controller" do
    subject { helper.db_to_controller(@db) }

    context "when with ActionSet" do
      before { @db = "ActionSet" }

      it "and @explorer" do
        @explorer = true
        expect(subject[0]).to eq("miq_action")
        expect(subject[1]).to eq("show_set")
      end

      it "and not @explorer" do
        @explorer = nil
        expect(subject[0]).to eq("miq_action")
        expect(subject[1]).to eq("show_set")
      end
    end

    context "when with AutomationRequest" do
      before { @db = "AutomationRequest" }

      it "and @explorer" do
        @explorer = true
        expect(subject[0]).to eq("miq_request")
        expect(subject[1]).to eq("show")
      end

      it "and not @explorer" do
        @explorer = nil
        expect(subject[0]).to eq("miq_request")
        expect(subject[1]).to eq("show")
      end
    end

    context "when with ConditionSet" do
      before do
        @db = "ConditionSet"
      end

      it "and @explorer" do
        @explorer = true
        expect(subject[0]).to eq("condition")
        expect(subject[1]).to eq("x_show")
      end

      it "and not @explorer" do
        @explorer = nil
        expect(subject[0]).to eq("condition")
        expect(subject[1]).to eq("show")
      end
    end

    context "when with EmsInfra" do
      before { @db = "EmsInfra" }

      it "and @explorer" do
        @explorer = true
        expect(subject[0]).to eq("ems_infra")
        expect(subject[1]).to eq("x_show")
      end

      it "and not @explorer" do
        @explorer = nil
        expect(subject[0]).to eq("ems_infra")
        expect(subject[1]).to eq("show")
      end
    end

    context "when with EmsCloud" do
      before { @db = "EmsCloud" }

      it "and @explorer" do
        @explorer = true
        expect(subject[0]).to eq("ems_cloud")
        expect(subject[1]).to eq("x_show")
      end

      it "and not @explorer" do
        @explorer = nil
        expect(subject[0]).to eq("ems_cloud")
        expect(subject[1]).to eq("show")
      end
    end

    context "when with ScanItemSet" do
      before { @db = "ScanItemSet" }

      it "and @explorer" do
        @explorer = true
        expect(subject[0]).to eq("ops")
        expect(subject[1]).to eq("ap_show")
      end

      it "and not @explorer" do
        @explorer = nil
        expect(subject[0]).to eq("ops")
        expect(subject[1]).to eq("ap_show")
      end
    end

    context "when with MiqEventDefinition" do
      before { @db = "MiqEventDefinition" }

      it "and @explorer" do
        @explorer = true
        expect(subject[0]).to eq("event")
        expect(subject[1]).to eq("_none_")
      end

      it "and not @explorer" do
        @explorer = nil
        expect(subject[0]).to eq("event")
        expect(subject[1]).to eq("_none_")
      end
    end

    ["User", "Group", "Patch", "GuestApplication"].each do |db|
      context "when with #{db}" do
        before { @db = db; @lastaction = "some_action" }

        it "and @explorer" do
          @explorer = true
          expect(subject[0]).to eq("vm")
          expect(subject[1]).to eq(@lastaction)
        end

        it "and not @explorer" do
          @explorer = nil
          expect(subject[0]).to eq("vm")
          expect(subject[1]).to eq(@lastaction)
        end
      end
    end

    context "when with MiqReportResult" do
      before { @db = "MiqReportResult" }

      it "and @explorer" do
        @explorer = true
        expect(subject[0]).to eq("report")
        expect(subject[1]).to eq("show_saved")
      end

      it "and not @explorer" do
        @explorer = nil
        expect(subject[0]).to eq("report")
        expect(subject[1]).to eq("show_saved")
      end
    end

    context "when with MiqAeClass" do
      before { @db = "MiqAeClass" }

      it "and @explorer" do
        @explorer = true
        expect(subject[0]).to eq("miq_ae_class")
        expect(subject[1]).to eq("show_instances")
      end

      it "and not @explorer" do
        @explorer = nil
        expect(subject[0]).to eq("miq_ae_class")
        expect(subject[1]).to eq("show_instances")
      end
    end

    context "when with MiqAeInstance" do
      before { @db = "MiqAeInstance" }

      it "and @explorer" do
        @explorer = true
        expect(subject[0]).to eq("miq_ae_class")
        expect(subject[1]).to eq("show_details")
      end

      it "and not @explorer" do
        @explorer = nil
        expect(subject[0]).to eq("miq_ae_class")
        expect(subject[1]).to eq("show_details")
      end
    end

    ["ServiceResource", "ServiceTemplate"].each do |db|
      context "when with #{db}" do
        before { @db = db }

        it "and @explorer" do
          @explorer = true
          expect(subject[0]).to eq("catalog")
          expect(subject[1]).to eq("x_show")
        end

        it "and not @explorer" do
          @explorer = nil
          expect(subject[0]).to eq("catalog")
          expect(subject[1]).to eq("show")
        end
      end
    end

    context "when with ManageIQ::Providers::ContainerManager" do
      before { @db = "ManageIQ::Providers::ContainerManager" }

      it "and @explorer" do
        @explorer = true
        expect(subject[0]).to eq("ems_container")
        expect(subject[1]).to eq("x_show")
      end

      it "and not @explorer" do
        @explorer = nil
        expect(subject[0]).to eq("ems_container")
        expect(subject[1]).to eq("show")
      end
    end
  end

  describe "#field_to_col" do
    subject { helper.field_to_col(field) }
    context "when field likes 'Vm.hardware.disks-size'" do
      let(:field) { "Vm.hardware.disks-size" }
      it { is_expected.to eq("disks.size") }
    end

    context "when field likes 'disks-size'" do
      let(:field) { "disks-size" }
      it { is_expected.to eq("size") }
    end

    context "when field likes 'size'" do
      let(:field) { "size" }
      it { is_expected.to be_falsey }
    end

    context "when field likes 'Vm.size'" do
      let(:field) { "Vm.size" }
      it { is_expected.not_to eq("size") }
    end
  end

  context "#get_vmdb_config" do
    it "Replaces calls to VMDB::Config.new in the views/controllers" do
      expect(helper.get_vmdb_config).to eq(VMDB::Config.new("vmdb").config)
    end
  end

  context "#to_cid" "(id)" do
    it "converts record id to compressed id" do
      expect(helper.to_cid(12_000_000_000_056)).to eq('12r56')
    end
  end

  context "#from_cid" "(cid)" do
    it "converts compressed id to record id" do
      expect(helper.from_cid("12r56")).to eq(12_000_000_000_056)
    end
  end

  context "#title_from_layout" do
    let(:title) { I18n.t('product.name') }
    subject { helper.title_from_layout(@layout) }

    it "when layout is blank" do
      @layout = ""
      expect(subject).to eq(title)
    end

    it "when layout = 'miq_server'" do
      @layout = "miq_server"
      expect(subject).to eq(title + ": Servers")
    end

    it "when layout = 'usage'" do
      @layout = "usage"
      expect(subject).to eq(title + ": VM Usage")
    end

    it "when layout = 'scan_profile'" do
      @layout = "scan_profile"
      expect(subject).to eq(title + ": Analysis Profiles")
    end

    it "when layout = 'miq_policy_rsop'" do
      @layout = "miq_policy_rsop"
      expect(subject).to eq(title + ": Policy Simulation")
    end

    it "when layout = 'all_ui_tasks'" do
      @layout = "all_ui_tasks"
      expect(subject).to eq(title + ": All UI Tasks")
    end

    it "when layout = 'rss'" do
      @layout = "rss"
      expect(subject).to eq(title + ": RSS")
    end

    it "when layout = 'management_system'" do
      @layout = "management_system"
      expect(subject).to eq(title + ": Management Systems")
    end

    it "when layout = 'storage_manager'" do
      @layout = "storage_manager"
      expect(subject).to eq(title + ": Storage - Storage Managers")
    end

    it "when layout = 'ops'" do
      @layout = "ops"
      expect(subject).to eq(title + ": Configuration")
    end

    it "when layout = 'pxe'" do
      @layout = "pxe"
      expect(subject).to eq(title + ": PXE")
    end

    it "when layout = 'vm_or_template'" do
      @layout = "vm_or_template"
      expect(subject).to eq(title + ": Workloads")
    end

    it "when layout likes 'miq_ae_*'" do
      @layout = "miq_ae_some_thing"
      expect(subject).to eq(title + ": Automate")
    end

    it "when layout likes 'miq_policy*'" do
      @layout = "miq_policy_some_thing"
      expect(subject).to eq(title + ": Control")
    end

    it "when layout likes 'miq_capacity*'" do
      @layout = "miq_capacity_some_thing"
      expect(subject).to eq(title + ": Optimize")
    end

    it "when layout likes 'miq_request*'" do
      @layout = "miq_request_some_thing"
      expect(subject).to eq(title + ": Requests")
    end

    it "when layout likes 'cim_*' or 'snia_*'" do
      @layout = "cim_base_storage_extent"
      expect(subject).to eq(title + ": Storage - #{ui_lookup(:tables => @layout)}")
    end

    it "otherwise" do
      @layout = "xxx"
      expect(subject).to eq(title + ": #{ui_lookup(:tables => @layout)}")
    end
  end

  context "#controller_model_name" do
    it "returns the model's title" do
      expect(helper.controller_model_name("OntapFileShare")).to eq("Storage - File Share")
      expect(helper.controller_model_name("CimStorageExtent")).to eq("Storage - Extent")
    end
  end

  context "#is_browser_ie7?" do
    it "when browser's explorer version 7.x" do
      allow_any_instance_of(ActionController::TestSession)
        .to receive(:fetch_path).with(:browser, :name).and_return('explorer')
      allow_any_instance_of(ActionController::TestSession)
        .to receive(:fetch_path).with(:browser, :version).and_return('7.10')
      expect(helper.is_browser_ie7?).to be_truthy
    end

    it "when browser's NOT explorer version 7.x" do
      allow_any_instance_of(ActionController::TestSession)
        .to receive(:fetch_path).with(:browser, :name).and_return('explorer')
      allow_any_instance_of(ActionController::TestSession)
        .to receive(:fetch_path).with(:browser, :version).and_return('6.10')
      expect(helper.is_browser_ie7?).to be_falsey
    end
  end

  context "#is_browser_ie?" do
    it "when browser's explorer" do
      allow_any_instance_of(ActionController::TestSession)
        .to receive(:fetch_path).with(:browser, :name).and_return('explorer')
      expect(helper.is_browser_ie?).to be_truthy
    end

    it "when browser's NOT explorer" do
      allow_any_instance_of(ActionController::TestSession)
        .to receive(:fetch_path).with(:browser, :name).and_return('safari')
      expect(helper.is_browser_ie?).to be_falsey
    end
  end

  context "#is_browser?" do
    it "when browser's name is in the list" do
      allow_any_instance_of(ActionController::TestSession)
        .to receive(:fetch_path).with(:browser, :name).and_return('safari')
      expect(helper.is_browser?(%w(firefox opera safari))).to be_truthy
    end

    it "when browser's name is NOT in the list" do
      allow_any_instance_of(ActionController::TestSession)
        .to receive(:fetch_path).with(:browser, :name).and_return('explorer')
      expect(helper.is_browser?(%w(firefox opera safari))).to be_falsey
    end
  end

  context "#is_browser_os?" do
    it "when browser's OS is in the list" do
      allow_any_instance_of(ActionController::TestSession)
        .to receive(:fetch_path).with(:browser, :os).and_return('windows')
      expect(helper.is_browser_os?(%w(windows linux))).to be_truthy
    end

    it "when browser's OS is NOT in the list" do
      allow_any_instance_of(ActionController::TestSession)
        .to receive(:fetch_path).with(:browser, :os).and_return('macos')
      expect(helper.is_browser_os?(%w(windows linux))).to be_falsey
    end
  end

  context "#browser_info" do
    it "preserves the case" do
      type = :a_type
      allow_any_instance_of(ActionController::TestSession)
        .to receive(:fetch_path).with(:browser, type).and_return('checked_by_A_TYPE')
      expect(helper.browser_info(type)).to eq('checked_by_A_TYPE')
    end
  end

  describe "#javascript_for_timer_type" do
    subject { helper.javascript_for_timer_type(timer_type) }

    context "when timer_type == nil" do
      let(:timer_type) { nil }
      specify { expect(subject).to be_empty }
    end

    context "when timer_type == 'Monthly'" do
      let(:timer_type) { 'Monthly' }
      it { is_expected.to include("$('\#weekly_span').hide();") }
      it { is_expected.to include("$('\#daily_span').hide();") }
      it { is_expected.to include("$('\#hourly_span').hide();") }
      it { is_expected.to include("$('\#monthly_span').show();") }
    end

    context "when timer_type == 'Weekly'" do
      let(:timer_type) { 'Weekly' }
      it { is_expected.to include("$('\#daily_span').hide();") }
      it { is_expected.to include("$('\#hourly_span').hide();") }
      it { is_expected.to include("$('\#monthly_span').hide();") }
      it { is_expected.to include("$('\#weekly_span').show();") }
    end

    context "when timer_type == 'Daily'" do
      let(:timer_type) { 'Daily' }
      it { is_expected.to include("$('\#hourly_span').hide();") }
      it { is_expected.to include("$('\#monthly_span').hide();") }
      it { is_expected.to include("$('\#weekly_span').hide();") }
      it { is_expected.to include("$('\#daily_span').show();") }
    end

    context "when timer_type == 'Hourly'" do
      let(:timer_type) { 'Hourly' }
      it { is_expected.to include("$('\#daily_span').hide();") }
      it { is_expected.to include("$('\#monthly_span').hide();") }
      it { is_expected.to include("$('\#weekly_span').hide();") }
      it { is_expected.to include("$('\#hourly_span').show();") }
    end

    context "when timer_type == 'something_else'" do
      let(:timer_type) { 'something_else' }
      it { is_expected.to include("$('\#daily_span').hide();") }
      it { is_expected.to include("$('\#hourly_span').hide();") }
      it { is_expected.to include("$('\#monthly_span').hide();") }
      it { is_expected.to include("$('\#weekly_span').hide();") }
    end
  end

  describe "#javascript_for_miq_button_visibility" do
    subject { helper.javascript_for_miq_button_visibility(display) }
    context "when display == true" do
      let(:display) { true }
      it { is_expected.to eq("miqButtons('show');") }
    end

    context "when dsiplay == false" do
      let(:display) { false }
      it { is_expected.to eq("miqButtons('hide');") }
    end
  end

  context "#javascript_pf_toolbar_reload" do
    let(:test_tab) { "some_center_tb" }
    subject { helper.javascript_pf_toolbar_reload(test_tab, 'foobar') }

    it "returns javascript to reload toolbar" do
      expect(helper).to receive(:buttons_to_html).and_return('foobar')
      is_expected.to include("$('##{test_tab}').html('foobar');")
      is_expected.to include("miqInitToolbars();")
    end
  end

  context "#set_edit_timer_from_schedule" do
    before(:each) do
      @edit = {:tz => 'Eastern Time (US & Canada)', :new => {}}
      @interval = '3'
      @date = "6/28/2012"
      @hour = "0#{11 - 4}"
      @min = "14"
      @run_at = {:start_time => "2012-06-28 11:14:00".to_time(:utc),
                 :interval   => {:value => @interval}}
      @schedule = double(:run_at => @run_at)
    end

    describe "when schedule.run_at == nil" do
      it "sets defaults" do
        schedule = double(:run_at => nil)
        helper.set_edit_timer_from_schedule schedule
        expect(@edit[:new][:timer].to_h).to include(
          :typ => 'Once',
          :start_hour => "00",
          :start_min => '00'
        )
      end
    end

    describe "when schedule.run_at != nil" do
      it "sets values as monthly" do
        @run_at[:interval][:unit] = 'monthly'
        helper.set_edit_timer_from_schedule @schedule
        expect(@edit[:new][:timer].to_h).to include(
          :start_date => @date,
          :start_hour => @hour,
          :start_min => @min,
          :months => @interval,
          :typ => 'Monthly'
        )
        expect(@edit[:new][:timer].to_h).not_to include(:months => '1')
      end

      it "sets values as weekly" do
        @run_at[:interval][:unit] = 'weekly'
        helper.set_edit_timer_from_schedule @schedule
        expect(@edit[:new][:timer].to_h).to include(
          :start_date => @date,
          :start_hour => @hour,
          :start_min   => @min,
          :weeks => @interval,
          :typ => 'Weekly'
        )
        expect(@edit[:new][:timer].to_h).not_to include(:weeks => '1')
      end

      it "sets values as daily" do
        @run_at[:interval][:unit] = 'daily'
        helper.set_edit_timer_from_schedule @schedule
        expect(@edit[:new][:timer].to_h).to include(
          :start_date => @date,
          :start_hour => @hour,
          :start_min  => @min,
          :days => @interval,
          :typ => 'Daily'
        )
        expect(@edit[:new][:timer].to_h).not_to include(:days => '1')
      end

      it "sets values as hourly" do
        @run_at[:interval][:unit] = 'hourly'
        helper.set_edit_timer_from_schedule @schedule
        expect(@edit[:new][:timer].to_h).to include(
          :start_date => @date,
          :start_hour => @hour,
          :start_min   => @min,
          :hours => @interval,
          :typ => 'Hourly'
        )
        expect(@edit[:new][:timer].to_h).not_to include(:hours => '1')
      end
    end
  end

  context "#perf_parent?" do
    it "when model != 'VmOrTemplate'" do
      @perf_options = {:model => 'OntapVolumeDerivedMetric'}
      expect(helper.perf_parent?).to be_falsey
    end

    it "when model == 'VmOrTemplate' and typ == 'realtime'" do
      @perf_options = {:model => 'VmOrTemplate', :typ => 'realtime'}
      expect(helper.perf_parent?).to be_falsey
    end

    it "when model == 'VmOrTemplate', typ != 'realtime' and parent is 'Host'" do
      @perf_options = {:model => 'VmOrTemplate', :typ => 'Hourly', :parent => 'Host'}
      expect(helper.perf_parent?).to be_truthy
    end

    it "when model == 'VmOrTemplate', typ != 'realtime' and parent is 'EmsCluster'" do
      @perf_options = {:model => 'VmOrTemplate', :typ => 'Hourly', :parent => 'EmsCluster'}
      expect(helper.perf_parent?).to be_truthy
    end

    it "when model == 'VmOrTemplate', typ != 'realtime' and parent is 'invalid parent'" do
      @perf_options = {:model => 'VmOrTemplate', :typ => 'Hourly', :parent => 'invalid parent'}
      expect(helper.perf_parent?).to be_falsey
    end

    it "when model == 'VmOrTemplate', typ != 'realtime' and parent == nil" do
      @perf_options = {:model => 'VmOrTemplate', :typ => 'Hourly', :parent => nil}
      expect(helper.perf_parent?).to be_falsey
    end
  end

  context "#perf_compare_vm?" do
    it "when model != 'OntapLogicalDisk'" do
      @perf_options = {:model => 'OntapVolumeDerivedMetric'}
      expect(helper.perf_compare_vm?).to be_falsey
    end

    it "when model == 'OntapLogicalDisk' and typ == 'realtime'" do
      @perf_options = {:model => 'OntapLogicalDisk', :typ => 'realtime'}
      expect(helper.perf_compare_vm?).to be_falsey
    end

    it "when model == 'OntapLogicalDisk', typ != 'realtime' and compare_vm == nil" do
      @perf_options = {:model => 'OntapLogicalDisk', :typ => 'Daily', :compare_vm => nil}
      expect(helper.perf_compare_vm?).to be_falsey
    end

    it "when model == 'OntapLogicalDisk', typ != 'realtime' and compare_vm != nil" do
      @perf_options = {:model => 'OntapLogicalDisk', :typ => 'Daily', :compare_vm => 'something'}
      expect(helper.perf_compare_vm?).to be_truthy
    end
  end

  context "#model_report_type" do
    it "when model == nil" do
      expect(helper.model_report_type(nil)).to be_falsey
    end

    it "when model likes '...Performance' or '...MetricsRollup'" do
      expect(helper.model_report_type("VmPerformance")).to eq(:performance)
      expect(helper.model_report_type("OntapVolumeMetricsRollup")).to eq(:performance)
    end

    it "when model == VimPerformanceTrend" do
      expect(helper.model_report_type("VimPerformanceTrend")).to eq(:trend)
    end

    it "when model == Chargeback" do
      expect(helper.model_report_type("Chargeback")).to eq(:chargeback)
    end
  end

  context "tree related methods" do
    before do
      @sb = {:active_tree => :svcs_tree,
             :trees       => {:svcs_tree => {:tree => :svcs_tree}}}
    end

    it "#x_node_set" do
      @sb[:trees][:svcs_tree]      = {:active_node => 'root'}
      @sb[:trees][:vm_filter_tree] = {:active_node => 'abc'}

      helper.x_node_set('def', :vm_filter_tree)
      expect(@sb[:trees][:svcs_tree][:active_node]).to eq('root')
      expect(@sb[:trees][:vm_filter_tree][:active_node]).to eq('def')

      helper.x_node_set(nil, :vm_filter_tree)
      expect(@sb[:trees][:svcs_tree][:active_node]).to eq('root')
      expect(@sb[:trees][:vm_filter_tree][:active_node]).to be_nil

      helper.x_node_set('', :vm_filter_tree)
      expect(@sb[:trees][:svcs_tree][:active_node]).to eq('root')
      expect(@sb[:trees][:vm_filter_tree][:active_node]).to eq('')
    end

    it "#x_node=" do
      helper.x_node = 'root'
      expect(@sb[:trees][:svcs_tree][:active_node]).to eq('root')

      helper.x_node = nil
      expect(@sb[:trees][:svcs_tree][:active_node]).to be_nil

      helper.x_node = ''
      expect(@sb[:trees][:svcs_tree][:active_node]).to eq('')
    end

    context "#x_node" do
      it "without tree param" do
        @sb[:trees][:svcs_tree] = {:active_node => 'root'}
        expect(helper.x_node).to eq('root')

        @sb[:trees][:svcs_tree] = {:active_node => nil}
        expect(helper.x_node).to be_nil

        @sb[:trees][:svcs_tree] = {:active_node => ''}
        expect(helper.x_node).to eq('')
      end

      it "with tree param" do
        @sb[:trees][:svcs_tree]      = {:active_node => 'root'}
        @sb[:trees][:vm_filter_tree] = {:active_node => 'abc'}

        expect(helper.x_node(:svcs_tree)).to eq("root")
        expect(helper.x_node(:vm_filter_tree)).to eq("abc")
      end
    end

    context "#x_tree" do
      it "without tree param" do
        @sb[:trees][:vm_filter_tree] = {:tree => :vm_filter_tree}

        expect(helper.x_tree).to eq(@sb[:trees][:svcs_tree])
        @sb[:active_tree] = :vm_filter_tree
        expect(helper.x_tree).to eq(@sb[:trees][:vm_filter_tree])
      end

      it "with tree param" do
        @sb[:trees][:vm_filter_tree] = {:tree => :vm_filter_tree}
        @sb[:trees][:svcs_tree]      = {:tree => :svcs_tree}

        expect(helper.x_tree(:svcs_tree)).to eq(@sb[:trees][:svcs_tree])
        expect(helper.x_tree(:vm_filter_tree)).to eq(@sb[:trees][:vm_filter_tree])
      end
    end

    it "#x_active_tree=" do
      helper.x_active_tree = 'vms_filter_tree'
      expect(@sb[:active_tree]).to eq(:vms_filter_tree)

      helper.x_active_tree = 'svcs_tree'
      expect(@sb[:active_tree]).to eq(:svcs_tree)
    end

    it "#x_active_tree" do
      expect(helper.x_active_tree).to eq(:svcs_tree)
      @sb[:active_tree] = :vm_filter_tree
      expect(helper.x_active_tree).to eq(:vm_filter_tree)
    end

    context "#x_tree_init" do
      it "does not replace existing trees" do
        helper.x_tree_init(:svcs_tree, :xxx, "XXX")

        expect(@sb[:trees][:svcs_tree]).to eq(:tree => :svcs_tree)
      end

      it "has default values" do
        helper.x_tree_init(:vm_filter_tree, :vm_filter, "Vm")

        expect(@sb[:trees][:vm_filter_tree]).to eq(:tree       => :vm_filter_tree,
                                                   :type       => :vm_filter,
                                                   :leaf       => "Vm",
                                                   :add_root   => true,
                                                   :open_nodes => [])
      end

      it "can override default values" do
        helper.x_tree_init(:vm_filter_tree, :vm_filter, "Vm",
                           :add_root   => false,
                           :open_nodes => [:a],
                           :open_all   => true,
                           :full_ids   => true
                          )

        expect(@sb[:trees][:vm_filter_tree]).to eq(:tree       => :vm_filter_tree,
                                                   :type       => :vm_filter,
                                                   :leaf       => "Vm",
                                                   :add_root   => false,
                                                   :open_nodes => [:a],
                                                   :open_all   => true,
                                                   :full_ids   => true)
      end
    end

    it "#x_tree_history" do
      @sb = {:history     => {:svcs_tree => %w(service1 service2 service3)},
             :active_tree => :svcs_tree}
      expect(helper.x_tree_history).to eq(%w(service1 service2 service3))
    end
  end

  describe "truncate text for quad icons" do
    ["front", "middle", "back"].each do |trunc|
      context "remove #{trunc} of text" do
        before(:each) do
          @settings = {:display => {:quad_truncate => trunc[0]}}
        end

        it "when value is nil" do
          text = helper.truncate_for_quad(nil)
          expect(text).to be_nil
        end

        it "when value is < 13 long" do
          text = helper.truncate_for_quad("Test")
          expect(text).to eq("Test")
        end

        it "when value is 12 long" do
          text = helper.truncate_for_quad("ABCDEFGHIJKL")
          expect(text).to eq("ABCDEFGHIJKL")
        end

        it "when value is 13 long" do
          text = helper.truncate_for_quad("ABCDEooo12345")
          expect(text).to eq(case trunc[0]
                             when "f" then "...DEooo12345"
                             when "m" then "ABCDE...12345"
                             when "b" then "ABCDEooo12..."
                             end)
        end

        it "when value is 25 long" do
          text = helper.truncate_for_quad("ABCDEooooooooooooooo12345")
          expect(text).to eq(case trunc[0]
                             when "f" then "...ooooo12345"
                             when "m" then "ABCDE...12345"
                             when "b" then "ABCDEooooo..."
                             end)
        end
      end
    end
  end

  describe "generate custom toolbar file names" do
    context "for classic (non-explorer) CI main summary screens" do
      before(:each) do
        @lastaction = "show"
        @record = true
      end

      ["miq_template", "ems_cloud", "ems_cluster", "ems_infra", "host", "storage"].each do |table|
        it "for table #{table}" do
          @layout = table
          @display = "main"
          text = helper.custom_toolbar_filename
          expect(text).to eq("custom_buttons_tb")
        end
      end

      # Just a few tables that don't have custom toolbars
      ["ems_events", "storage_managers"].each do |table|
        it "for table #{table}" do
          @layout = table
          text = helper.custom_toolbar_filename
          expect(text).to be_nil
        end
      end
    end

    context "for classic (non-explorer) CI non-main summary screens" do
      before(:each) do
        @lastaction = "show"
        @record = true
      end

      ["miq_template", "ems_cluster", "host", "storage", "management_system"].each do |table|
        it "for table #{table}" do
          @layout = table
          @display = "not_main"
          text = helper.custom_toolbar_filename
          expect(text).to be_nil
        end
      end
    end

    context "for classic (non-explorer) CI list view screens" do
      before(:each) do
        @lastaction = "show_list"
        @record = true
      end

      ["miq_template", "ems_cluster", "host", "storage", "management_system"].each do |table|
        it "for table #{table}" do
          @layout = table
          text = helper.custom_toolbar_filename
          expect(text).to be_nil
        end
      end

      # Just a few tables that don't have custom toolbars
      ["ems_events", "storage_managers"].each do |table|
        it "for table #{table}" do
          @layout = table
          text = helper.custom_toolbar_filename
          expect(text).to be_nil
        end
      end
    end

    context "for explorer-based screens" do
      before(:each) do
        @explorer = true
        @sb = {:active_tree => "my_tree",
               :trees       => {"my_tree" => {:active_node => nil}}
              }
      end

      it "for non custom toolbar controller" do
        allow(helper).to receive(:params) { {:controller => "policy"} }
        text = helper.custom_toolbar_filename
        expect(text).to be_nil
      end

      ["vm_or_template", "service"].each do |table|
        it "for #{table} controller on root node" do
          @sb[:trees][@sb[:active_tree]][:active_node] = "root"
          allow(helper).to receive(:params) { {:controller => table} }
          text = helper.custom_toolbar_filename
          expect(text).to eq("blank_view_tb")
        end

        it "for #{table} controller on record node summary screen" do
          @sb[:trees][@sb[:active_tree]][:active_node] = "v-1r35"
          @display = "main"
          @record = true
          allow(helper).to receive(:params) { {:controller => table} }
          text = helper.custom_toolbar_filename
          expect(text).to eq("custom_buttons_tb")
        end

        it "for #{table} controller on record node, but not summary screen" do
          @sb[:trees][@sb[:active_tree]][:active_node] = "v-1r35"
          @display = "not_main"
          @record = true
          allow(helper).to receive(:params) { {:controller => table} }
          text = helper.custom_toolbar_filename
          expect(text).to eq("blank_view_tb")
        end
      end
    end

    context "#center_div_height" do
      it "calculates height for center div" do
        @winH = 800
        max = 627
        min = 200
        height = @winH < max ? min : @winH - (max - min)
        res = helper.center_div_height
        expect(res).to eq(height)

        max = 757
        min = 400
        height = @winH < max ? min : @winH - (max - min)
        res = helper.center_div_height(false, 400)
        expect(res).to eq(height)
      end
    end
  end

  describe '#pressed2model_action' do
    examples = {
      'miq_template_bar' => ['miq_template', 'bar'],
      'boo_far'          => ['boo', 'far'],
      'boo_far_bar'      => ['boo', 'far_bar'],
    }

    examples.each_pair do |input, output|
      it "gives '#{output}' on '#{input}'" do
        expect(helper.pressed2model_action(input)).to eq(output)
      end
    end
  end

  describe "update_paging_url_parms", :type => :request do
    before do
      MiqServer.seed
    end

    context "when the given parameter is a hash" do
      before do
        get "/vm/show_list/100", :params => "bc=VMs+running+on+2014-08-25&menu_click=Display-VMs-on_2-6-5&page=2&sb_controller=host"
        allow_any_instance_of(Object).to receive(:query_string).and_return(@request.query_string)
        allow_message_expectations_on_nil
      end

      it "updates the query string with the given hash value and returns the full url path" do
        expect(helper.update_paging_url_parms("show_list", :page => 1)).to eq("/vm/show_list/100?bc=VMs+running+on+2014-08-25"\
          "&menu_click=Display-VMs-on_2-6-5&page=1&sb_controller=host")
      end
    end
    context "when the controller uses restful paths" do
      before do
        FactoryGirl.create(:ems_cloud, :zone => Zone.seed)
        @record = ManageIQ::Providers::CloudManager.first
        get "/ems_cloud/#{@record.id}", :params => { :display => 'images' }
        allow_any_instance_of(Object).to receive(:query_string).and_return(@request.query_string)
        allow_message_expectations_on_nil
      end

      it "uses restful paths for pages" do
        expect(helper.update_paging_url_parms("show", :page => 2)).to eq("/ems_cloud/#{@record.id}?display=images&page=2")
      end
    end
  end

  context "#title_for_clusters" do
    before(:each) do
      @ems1 = FactoryGirl.create(:ems_vmware)
      @ems2 = FactoryGirl.create(:ems_openstack_infra)
    end

    it "returns 'Clusters / Deployment Roles' when there are both openstack & non-openstack clusters" do
      FactoryGirl.create(:ems_cluster, :ems_id => @ems1.id)
      FactoryGirl.create(:ems_cluster, :ems_id => @ems2.id)

      result = helper.title_for_clusters
      expect(result).to eq("Clusters / Deployment Roles")
    end

    it "returns 'Clusters' when there are only non-openstack clusters" do
      FactoryGirl.create(:ems_cluster, :ems_id => @ems1.id)

      result = helper.title_for_clusters
      expect(result).to eq("Clusters")
    end

    it "returns 'Deployment Roles' when there are only openstack clusters" do
      FactoryGirl.create(:ems_cluster, :ems_id => @ems2.id)

      result = helper.title_for_clusters
      expect(result).to eq("Deployment Roles")
    end
  end

  context "#title_for_cluster" do
    before(:each) do
      @ems1 = FactoryGirl.create(:ems_vmware)
      @ems2 = FactoryGirl.create(:ems_openstack_infra)
    end

    it "returns 'Cluster' for non-openstack cluster" do
      FactoryGirl.create(:ems_cluster, :ems_id => @ems1.id)

      result = helper.title_for_cluster
      expect(result).to eq("Cluster")
    end

    it "returns 'Deployment Role' for openstack cluster" do
      FactoryGirl.create(:ems_cluster, :ems_id => @ems2.id)

      result = helper.title_for_cluster
      expect(result).to eq("Deployment Role")
    end
  end

  context "#title_for_cluster_record" do
    before(:each) do
      @ems1 = FactoryGirl.create(:ems_vmware)
      @ems2 = FactoryGirl.create(:ems_openstack_infra)
    end

    it "returns 'Cluster' for non-openstack host" do
      cluster = FactoryGirl.create(:ems_cluster, :ems_id => @ems1.id)

      result = helper.title_for_cluster_record(cluster)
      expect(result).to eq("Cluster")
    end

    it "returns 'Deployment Role' for openstack host" do
      cluster = FactoryGirl.create(:ems_cluster, :ems_id => @ems2.id)

      result = helper.title_for_cluster_record(cluster)
      expect(result).to eq("Deployment Role")
    end
  end

  context "#title_for_hosts" do
    it "returns 'Hosts / Nodes' when there are both openstack & non-openstack hosts" do
      FactoryGirl.create(:host_vmware_esx, :ext_management_system => FactoryGirl.create(:ems_vmware))
      FactoryGirl.create(:host_openstack_infra, :ext_management_system => FactoryGirl.create(:ems_openstack_infra))

      expect(helper.title_for_hosts).to eq("Hosts / Nodes")
    end

    it "returns 'Hosts' when there are only non-openstack hosts" do
      FactoryGirl.create(:host_vmware_esx, :ext_management_system => FactoryGirl.create(:ems_vmware))

      expect(helper.title_for_hosts).to eq("Hosts")
    end

    it "returns 'Nodes' when there are only openstack hosts" do
      FactoryGirl.create(:host_openstack_infra, :ext_management_system => FactoryGirl.create(:ems_openstack_infra))

      expect(helper.title_for_hosts).to eq("Nodes")
    end
  end

  context "#title_for_host" do
    it "returns 'Host' for non-openstack host" do
      FactoryGirl.create(:host_vmware, :ext_management_system => FactoryGirl.create(:ems_vmware))

      expect(helper.title_for_host).to eq("Host")
    end

    it "returns 'Node' for openstack host" do
      FactoryGirl.create(:host_openstack_infra, :ext_management_system => FactoryGirl.create(:ems_openstack_infra))

      expect(helper.title_for_host).to eq("Node")
    end
  end

  context "#title_for_host_record" do
    it "returns 'Host' for non-openstack host" do
      host = FactoryGirl.create(:host_vmware, :ext_management_system => FactoryGirl.create(:ems_vmware))

      expect(helper.title_for_host_record(host)).to eq("Host")
    end

    it "returns 'Node' for openstack host" do
      host = FactoryGirl.create(:host_openstack_infra, :ext_management_system => FactoryGirl.create(:ems_openstack_infra))

      expect(helper.title_for_host_record(host)).to eq("Node")
    end
  end

  context "#start_page_allowed?" do
    it "should return true for storage start pages when product flag is set" do
      allow(helper).to receive(:get_vmdb_config).and_return(:product => { :storage => true })
      result = helper.start_page_allowed?("cim_storage_extent_show_list")
      expect(result).to be_truthy
    end

    it "should return false for storage start pages when product flag is not set" do
      result = helper.start_page_allowed?("cim_storage_extent_show_list")
      expect(result).to be_falsey
    end

    it "should return true for containers start pages when product flag is set" do
      allow(helper).to receive(:get_vmdb_config).and_return(:product => { :containers => true })
      result = helper.start_page_allowed?("ems_container_show_list")
      expect(result).to be_truthy
    end

    it "should return false for containers start pages when product flag is not set" do
      result = helper.start_page_allowed?("ems_container_show_list")
      expect(result).to be_falsey
    end

    it "should return true for host start page" do
      result = helper.start_page_allowed?("host_show_list")
      expect(result).to be_truthy
    end
  end

  context "#tree_with_advanced_search?" do
    it 'should return true for explorer trees with advanced search' do
      controller.instance_variable_set(:@sb,
                                       :active_tree => :vms_instances_filter_tree,
                                       :trees       => {
                                         :vms_instances_filter_tree => {
                                           :tree => :vms_instances_filter_tree,
                                           :type => :vms_instances_filter
                                         }
                                       }
                                      )
      result = helper.tree_with_advanced_search?
      expect(result).to be_truthy
    end

    it 'should return false for tree w/o advanced search' do
      controller.instance_variable_set(:@sb,
                                       :active_tree => :reports_tree,
                                       :trees       => {
                                         :reports_tree => {
                                           :tree => :reports_tree,
                                           :type => :reports
                                         }
                                       }
                                      )
      result = helper.tree_with_advanced_search?
      expect(result).to be_falsey
    end
  end

  context "#show_adv_search?" do
    it 'should return false for explorer screen with no trees such as automate/simulation' do
      controller.instance_variable_set(:@explorer, true)
      controller.instance_variable_set(:@sb, {})
      result = helper.show_adv_search?
      expect(result).to be_falsey
    end

    it 'should return true for VM explorer trees' do
      controller.instance_variable_set(:@explorer, true)
      controller.instance_variable_set(:@sb,
                                       :active_tree => :vms_instances_filter_tree,
                                       :trees       => {
                                         :vms_instances_filter_tree => {
                                           :tree => :vms_instances_filter_tree,
                                           :type => :vms_instances_filter
                                         }
                                       }
      )
      result = helper.show_adv_search?
      expect(result).to be_truthy
    end
  end

  context "#show_advanced_search?" do
    it 'should return true for VM explorer trees' do
      controller.instance_variable_set(:@sb,
                                       :active_tree => :vms_instances_filter_tree,
                                       :trees       => {
                                         :vms_instances_filter_tree => {
                                           :tree => :vms_instances_filter_tree,
                                           :type => :vms_instances_filter
                                         }
                                       }
                                      )
      result = helper.show_advanced_search?
      expect(result).to be_truthy
    end

    it 'should return false for non-VM explorer trees' do
      controller.instance_variable_set(:@sb,
                                       :active_tree => :reports_tree,
                                       :trees       => {
                                         :reports_tree => {
                                           :tree => :reports_tree,
                                           :type => :reports
                                         }
                                       }
                                      )
      result = helper.show_advanced_search?
      expect(result).to be_falsey
    end

    it 'should return true for non-VM explorer trees when @show_adv_search is set' do
      controller.instance_variable_set(:@sb,
                                       :active_tree => :reports_tree,
                                       :trees       => {
                                         :reports_tree => {
                                           :tree => :reports_tree,
                                           :type => :reports
                                         }
                                       }
                                      )
      controller.instance_variable_set(:@show_adv_search, true)
      result = helper.show_advanced_search?
      expect(result).to be_truthy
    end
  end

  context "#listicon_image_tag" do
    it "returns correct image for job record based upon it's status" do
      job_attrs = {"state" => "running", "status" => "ok"}
      image = helper.listicon_image_tag("Job", job_attrs)
      expect(image).to eq("<img valign=\"middle\" width=\"16\" height=\"16\" title=\"Status = Running\"" \
                          " src=\"#{ActionController::Base.helpers.image_path('100/job-running.png')}\" />")
    end
  end

  context '#skip_days_from_time_profile' do
    it 'should return empty array for whole week' do
      expect(helper.skip_days_from_time_profile((0..6).to_a)).to eq([])
    end

    it 'should return whole week for empty array' do
      expect(helper.skip_days_from_time_profile([])).to eq((1..7).to_a)
    end

    it 'should handle Sundays' do
      expect(helper.skip_days_from_time_profile((1..6).to_a)).to eq([7])
    end
  end

  it 'output of remote_function should not be html_safe' do
    expect(helper.remote_function(:url => {:controller => 'vm_infra', :action => 'explorer'}).html_safe?).to be_falsey
  end

  describe '#miq_accordion_panel' do
    subject do
      helper.miq_accordion_panel('title', active, 'identifier') do
        "content"
      end
    end

    context 'active tab' do
      let(:active) { true }
      it 'renders an active accordion' do
        expect(subject).to eq("<div class=\"panel panel-default\"><div class=\"panel-heading\"><h4 class=\"panel-title\"><a data-parent=\"#accordion\" data-toggle=\"collapse\" class=\"\" href=\"#identifier\">title</a></h4></div><div id=\"identifier\" class=\"panel-collapse collapse in\"><div class=\"panel-body\">content</div></div></div>")
      end
    end

    context 'inactive tab' do
      let(:active) { false }
      it 'renders an active accordion' do
        expect(subject).to eq("<div class=\"panel panel-default\"><div class=\"panel-heading\"><h4 class=\"panel-title\"><a data-parent=\"#accordion\" data-toggle=\"collapse\" class=\"collapsed\" href=\"#identifier\">title</a></h4></div><div id=\"identifier\" class=\"panel-collapse collapse \"><div class=\"panel-body\">content</div></div></div>")
      end
    end
  end

  describe '#restful_routed_action?' do
    context 'When controller is Dashboard and action is maintab' do
      it 'returns false' do
        expect(helper.restful_routed_action?('dashboard', 'maintab')).to eq(false)
      end
    end

    context 'When controller is ems_infra and action is show' do
      it 'returns false' do
        expect(helper.restful_routed_action?('ems_infra', 'show')).to eq(true)
      end
    end

    context 'When controller is ems_cloud and action is show_list' do
      it 'returns false' do
        expect(helper.restful_routed_action?('ems_cloud', 'show_list')).to eq(false)
      end
    end

    context 'When controller is ems_cloud and action is show' do
      it 'returns true' do
        expect(helper.restful_routed_action?('ems_cloud', 'show')).to eq(true)
      end
    end
  end

  describe '#li_link' do
    context 'with :if condition true' do
      let(:args) do
        {:if         => true,
         :controller => "ems_infra",
         :record_id  => 1}
      end

      subject { li_link(args) }

      it "returns HTML with enabled links" do
        expect(subject).to_not have_selector('li.disabled')
      end

    end

    context 'with :if condition false' do

      let(:args) do
        {:if        => false,
         :record_id => 1}
      end

      subject { li_link(args) }

      it 'renders disabled link_to' do
        expect(subject).to have_selector('li.disabled')
      end
    end
  end

  describe '#view_to_association' do
    [%w(AdvancedSetting advanced_settings), %w(OrchestrationStackOutput outputs),
     %w(OrchestrationStackParameter parameters), %w(OrchestrationStackResource resources), %w(Filesystem filesystems),
     %w(FirewallRule firewall_rules), %w(GuestApplication guest_applications), %w(Patch patches),
     %w(RegistryItem registry_items), %w(ScanHistory scan_histories)].each do |spec|
      it "finds the table name for #{spec[0]}" do
        view = double
        allow(view).to receive_messages(:db => spec[0], :scoped_association => nil)
        expect(helper.view_to_association(view, nil)).to eq(spec[1])
      end
    end

    it "finds table name for SystemService host" do
      allow(view).to receive_messages(:db => 'SystemService', :scoped_association => nil)
      expect(
        helper.view_to_association(
          view,
          ManageIQ::Providers::Vmware::InfraManager::Host.new
        )
      ).to eq('host_services')
    end
  end
end
