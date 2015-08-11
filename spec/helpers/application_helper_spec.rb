require "spec_helper"
include ActionView::Helpers::JqueryHelper
include JsHelper

describe ApplicationHelper do
  before do
    # mimic config.include ApplicationController::CurrentUser :type => :controller

    controller.send(:extend, ApplicationHelper)

    # mimic config.include ApplicationController::CurrentUser :type => :helper
    self.class.send(:include, ApplicationHelper)
  end

  context "build_toolbar_buttons_and_xml" do
    it 'should substitute dynamic function values' do
      req        = ActionDispatch::Request.new Rack::MockRequest.env_for '/?controller=foo'
      allow(controller).to receive(:role_allows).and_return(true)
      allow(controller).to receive(:request).and_return(req)
      json,      = controller.build_toolbar_buttons_and_xml 'storages_center_tb'
      title_text = ui_lookup(:tables => "storages")
      menu_info  = JSON.parse json

      menu_info.each_value do |value|
        %w( title confirm ).each do |field|
          if value[field]
            expect(value[field]).to match(title_text)
          end
        end
      end
    end

    it 'should substitute dynamic ivar values' do
      req = ActionDispatch::Request.new Rack::MockRequest.env_for '/?controller=foo'
      allow(controller).to receive(:role_allows).and_return(true)
      allow(controller).to receive(:request).and_return(req)
      controller.instance_variable_set(:@sb,
                                       :active_tree => :cb_reports_tree,
                                       :nodeid      => 'storages',
                                       :mode        => 'foo')

      json, = controller.build_toolbar_buttons_and_xml 'miq_policies_center_tb'
      title_text = ui_lookup(:model => "storages")

      menu_info = JSON.parse json
      menu_info.each_value do |value|
        next unless value['title']
        expect(value['title']).to match(title_text)
        expect(value['title']).to match("Foo") # from :mode
      end
    end
  end

  describe "#role_allows" do
    let(:features) { MiqProductFeature.find_all_by_identifier("everything") }
    before(:each) do
      MiqRegion.seed
      EvmSpecHelper.seed_specific_product_features("miq_report", "service")

      @admin_role  = FactoryGirl.create(:miq_user_role, :name => "admin", :miq_product_features => features)
      @admin_group = FactoryGirl.create(:miq_group, :miq_user_role => @admin_role)
      @user        = FactoryGirl.create(:user, :name => 'wilma', :miq_groups => [@admin_group])
      login_as  @user
    end

    context "when with :feature" do
      context "and :any" do
        it "and entitled" do
          role_allows(:feature=>"miq_report", :any=>true).should be_true
        end

        it "and not entitled" do
          @user.stub(:role_allows_any? => false)
          role_allows(:feature=>"miq_report", :any=>true).should be_false
        end
      end

      context "and no :any" do
        it "and entitled" do
          role_allows(:feature=>"miq_report").should be_true
        end

        it "and not entitled" do
          @user.stub(:role_allows? => false)
          role_allows(:feature=>"miq_report").should be_false
        end
      end
    end

    context "when with :main_tab_id" do
      include UiConstants
      it "and entitled" do
        Menu::DefaultMenu.services_menu_section.visible?.should be_true
      end

      it "and not entitled" do
        @user.stub(:role_allows_any? => false)
        Menu::DefaultMenu.services_menu_section.visible?.should be_false
      end
    end

    it "when not with :feature or :main_tab_id" do
      role_allows.should be_false
    end
  end

  describe "#model_to_controller" do
    subject { model_to_controller(@record) }

    it "when with any record" do
      @record = FactoryGirl.create(:vm_vmware)
      subject.should == @record.class.base_model.name.underscore
    end

    it "when record is nil" do
      lambda { model_to_controller(nil) }.should raise_error(NoMethodError)
    end
  end

  describe "#object_types_for_flash_message" do
    before do
      @record_1 = FactoryGirl.create(:vm_openstack, :type => ManageIQ::Providers::Openstack::CloudManager::Vm.name,       :template => false )
      @record_2 = FactoryGirl.create(:vm_openstack, :type => ManageIQ::Providers::Openstack::CloudManager::Vm.name,       :template => false )
      @record_3 = FactoryGirl.create(:vm_openstack, :type => ManageIQ::Providers::Openstack::CloudManager::Template.name, :template => true )
      @record_4 = FactoryGirl.create(:vm_openstack, :type => ManageIQ::Providers::Openstack::CloudManager::Template.name, :template => true )
      @record_5 = FactoryGirl.create(:vm_redhat,    :type => ManageIQ::Providers::Redhat::InfraManager::Vm.name)
      @record_6 = FactoryGirl.create(:vm_vmware,    :type => ManageIQ::Providers::Vmware::InfraManager::Vm.name)
    end

    context "when formatting flash message for VM or Templates class" do
      before do
        @klass = VmOrTemplate
      end

      it "with one Instance" do
        record_ids = [ @record_1.id ]
        object_types_for_flash_message(@klass, record_ids).should == "Instance"
      end

      it "with multiple Instances" do
        record_ids = [ @record_1.id, @record_2.id ]
        object_types_for_flash_message(@klass, record_ids).should == "Instances"
      end

      it "with one Instance and one Image" do
        record_ids = [ @record_1.id, @record_3.id ]
        object_types_for_flash_message(@klass, record_ids).should == "Image and Instance"
      end

      it "with one Instance and multiple Images" do
        record_ids = [ @record_1.id, @record_3.id, @record_4.id ]
        object_types_for_flash_message(@klass, record_ids).should == "Images and Instance"
      end

      it "with multiple Instances and multiple Images" do
        record_ids = [ @record_1.id, @record_2.id, @record_3.id, @record_4.id ]
        object_types_for_flash_message(@klass, record_ids).should == "Images and Instances"
      end

      it "with multiple Instances and one Virtual Machine" do
        record_ids = [ @record_1.id, @record_2.id, @record_5.id ]
        object_types_for_flash_message(@klass, record_ids).should == "Instances and Virtual Machine"
      end

      it "with multiple Instances and multiple Virtual Machines" do
        record_ids = [ @record_1.id, @record_2.id, @record_5.id, @record_6.id ]
        object_types_for_flash_message(@klass, record_ids).should == "Instances and Virtual Machines"
      end

      it "with multiple Instances, one Image and multiple Virtual Machines" do
        record_ids = [ @record_5.id, @record_6.id, @record_1.id, @record_2.id, @record_4.id ]
        object_types_for_flash_message(@klass, record_ids).should == "Image, Instances, and Virtual Machines"
      end

      it "with multiple Instances, multiple Images and multiple Virtual Machines" do
        record_ids = [ @record_5.id, @record_6.id, @record_1.id, @record_2.id, @record_3.id, @record_4.id ]
        object_types_for_flash_message(@klass, record_ids).should == "Images, Instances, and Virtual Machines"
      end
    end

    context "when formatting flash message for Non VM or Templates class" do
      before do
        @klass = Service
      end

      it "with one Service" do
        record_ids = [ @record_1.id ]
        object_types_for_flash_message(@klass, record_ids).should == "Service"
      end

      it "with multiple Services" do
        record_ids = [ @record_1.id, @record_2.id ]
        object_types_for_flash_message(@klass, record_ids).should == "Services"
      end
    end

  end

  describe "#url_for_record" do
    subject { url_for_record(@record, @action = "show") }

    it "when record is VmOrTemplate" do
      @record = Vm.new
      subject.should == url_for_db(controller_for_vm(model_for_vm(@record)), @action)
    end

    it "when record is not VmOrTemplate" do
      @record = FactoryGirl.create(:host)
      subject.should == url_for_db(@record.class.base_class.to_s, @action)
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
          url_for_db(db, @action).should == url_for(:controller => "vm_or_template",
                                                    :action     => @lastaction,
                                                    :id         => @vm,
                                                    :show       => @id)
        end
      end

      it "otherwise" do
        db = "vm"
        c, a = db_to_controller(db, @action)
        url_for_db(db, @action).should == url_for(:controller=>c, :action=>a, :id=>@id)
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
           url_for_db(db, @action).should == url_for(:controller=>"host", :action=>@lastaction, :id=>@host, :show=>@id)
         end
       end

       it "otherwise" do
         db = "vm"
         c, a = db_to_controller(db, @action)
         url_for_db(db, @action).should == url_for(:controller=>c, :action=>a, :id=>@id)
      end
    end

    it "when with no @vm, no @host, and no @db" do
      db = 'Vm'
      url_for_db(db, @action).should == "/vm/#{@action}/#{@id}"
    end
  end

  describe "#db_to_controller" do
    subject { db_to_controller(@db) }

    context "when with ActionSet" do
      before { @db = "ActionSet" }

      it "and @explorer" do
        @explorer = true
        subject[0].should == "miq_action"
        subject[1].should == "show_set"
      end

      it "and not @explorer" do
        @explorer = nil
        subject[0].should == "miq_action"
        subject[1].should == "show_set"
      end
    end

    context "when with AutomationRequest" do
      before { @db = "AutomationRequest" }

      it "and @explorer" do
        @explorer = true
        subject[0].should == "miq_request"
        subject[1].should == "show"
      end

      it "and not @explorer" do
        @explorer = nil
        subject[0].should == "miq_request"
        subject[1].should == "show"
      end
    end

    context "when with ConditionSet" do
      before do
        @db = "ConditionSet"
      end

      it "and @explorer" do
        @explorer = true
        subject[0].should == "condition"
        subject[1].should == "x_show"
      end

      it "and not @explorer" do
        @explorer = nil
        subject[0].should == "condition"
        subject[1].should == "show"
      end
    end

    context "when with EmsInfra" do
      before { @db = "EmsInfra" }

      it "and @explorer" do
        @explorer = true
        subject[0].should == "ems_infra"
        subject[1].should == "x_show"
      end

      it "and not @explorer" do
        @explorer = nil
        subject[0].should == "ems_infra"
        subject[1].should == "show"
      end
    end

    context "when with EmsCloud" do
      before { @db = "EmsCloud" }

      it "and @explorer" do
        @explorer = true
        subject[0].should == "ems_cloud"
        subject[1].should == "x_show"
      end

      it "and not @explorer" do
        @explorer = nil
        subject[0].should == "ems_cloud"
        subject[1].should == "show"
      end
    end

    context "when with ScanItemSet" do
      before { @db = "ScanItemSet" }

      it "and @explorer" do
        @explorer = true
        subject[0].should == "ops"
        subject[1].should == "ap_show"
      end

      it "and not @explorer" do
        @explorer = nil
        subject[0].should == "ops"
        subject[1].should == "ap_show"
      end
    end

    context "when with MiqEventDefinition" do
      before { @db = "MiqEventDefinition" }

      it "and @explorer" do
        @explorer = true
        subject[0].should == "event"
        subject[1].should == "_none_"
      end

      it "and not @explorer" do
        @explorer = nil
        subject[0].should == "event"
        subject[1].should == "_none_"
      end
    end

    ["User", "Group", "Patch", "GuestApplication"].each do |db|
      context "when with #{db}" do
        before { @db = db ; @lastaction = "some_action"}

        it "and @explorer" do
          @explorer = true
          subject[0].should == "vm"
          subject[1].should == @lastaction
        end

        it "and not @explorer" do
          @explorer = nil
          subject[0].should == "vm"
          subject[1].should == @lastaction
        end
      end
    end

    context "when with MiqReportResult" do
      before { @db = "MiqReportResult" }

      it "and @explorer" do
        @explorer = true
        subject[0].should == "report"
        subject[1].should == "show_saved"
      end

      it "and not @explorer" do
        @explorer = nil
        subject[0].should == "report"
        subject[1].should == "show_saved"
      end
    end

    context "when with MiqAeClass" do
      before { @db = "MiqAeClass" }

      it "and @explorer" do
        @explorer = true
        subject[0].should == "miq_ae_class"
        subject[1].should == "show_instances"
      end

      it "and not @explorer" do
        @explorer = nil
        subject[0].should == "miq_ae_class"
        subject[1].should == "show_instances"
      end
    end

    context "when with MiqAeInstance" do
      before { @db = "MiqAeInstance" }

      it "and @explorer" do
        @explorer = true
        subject[0].should == "miq_ae_class"
        subject[1].should == "show_details"
      end

      it "and not @explorer" do
        @explorer = nil
        subject[0].should == "miq_ae_class"
        subject[1].should == "show_details"
      end
    end

    ["ServiceResource", "ServiceTemplate"].each do |db|
      context "when with #{db}" do
        before { @db = db }

        it "and @explorer" do
          @explorer = true
          subject[0].should == "catalog"
          subject[1].should == "x_show"
        end

        it "and not @explorer" do
          @explorer = nil
          subject[0].should == "catalog"
          subject[1].should == "show"
        end
      end
    end

    context "when with ManageIQ::Providers::ContainerManager" do
      before { @db = "ManageIQ::Providers::ContainerManager" }

      it "and @explorer" do
        @explorer = true
        subject[0].should == "ems_container"
        subject[1].should == "x_show"
      end

      it "and not @explorer" do
        @explorer = nil
        subject[0].should == "ems_container"
        subject[1].should == "show"
      end
    end
  end

  describe "#field_to_col" do
    subject { field_to_col(field) }
    context "when field likes 'Vm.hardware.disks-size'" do
      let(:field) { "Vm.hardware.disks-size" }
      it { should == "disks.size" }
    end

    context "when field likes 'disks-size'" do
      let(:field) { "disks-size" }
      it { should == "size" }
    end

    context "when field likes 'size'" do
      let(:field) { "size" }
      it { should be_false }
    end

    context "when field likes 'Vm.size'" do
      let(:field) { "Vm.size" }
      it { should_not == "size" }
    end
  end

  context "#get_vmdb_config" do
    it "Replaces calls to VMDB::Config.new in the views/controllers" do
      get_vmdb_config.should equal(@vmdb_config)
    end
  end

  context "#to_cid" "(id)" do
    it "converts record id to compressed id" do
      to_cid(12000000000056).should == '12r56'
    end
  end

  context "#from_cid" "(cid)" do
    it "converts compressed id to record id" do
      from_cid("12r56").should == 12000000000056
    end
  end

  context "#title_from_layout" do
    let(:title) { I18n.t('product.name') }
    subject { title_from_layout(@layout) }

    it "when layout is blank" do
      @layout = ""
      subject.should == title
    end

    it "when layout = 'miq_server'" do
      @layout = "miq_server"
      subject.should == title + ": Servers"
    end

    it "when layout = 'usage'" do
      @layout = "usage"
      subject.should == title + ": VM Usage"
    end

    it "when layout = 'scan_profile'" do
      @layout = "scan_profile"
      subject.should == title + ": Analysis Profiles"
    end

    it "when layout = 'miq_policy_rsop'" do
      @layout = "miq_policy_rsop"
      subject.should == title + ": Policy Simulation"
    end

    it "when layout = 'all_ui_tasks'" do
      @layout = "all_ui_tasks"
      subject.should == title + ": All UI Tasks"
    end

    it "when layout = 'rss'" do
      @layout = "rss"
      subject.should == title + ": RSS"
    end

    it "when layout = 'management_system'" do
      @layout = "management_system"
      subject.should == title + ": Management Systems"
    end

    it "when layout = 'storage_manager'" do
      @layout = "storage_manager"
      subject.should == title + ": Storage - Storage Managers"
    end

    it "when layout = 'ops'" do
      @layout = "ops"
      subject.should == title + ": Configuration"
    end

    it "when layout = 'pxe'" do
      @layout = "pxe"
      subject.should == title + ": PXE"
    end

    it "when layout = 'vm_or_template'" do
      @layout = "vm_or_template"
      subject.should == title + ": Workloads"
    end

    it "when layout likes 'miq_ae_*'" do
      @layout = "miq_ae_some_thing"
      subject.should == title + ": Automate"
    end

    it "when layout likes 'miq_policy*'" do
      @layout = "miq_policy_some_thing"
      subject.should == title + ": Control"
    end

    it "when layout likes 'miq_capacity*'" do
      @layout = "miq_capacity_some_thing"
      subject.should == title + ": Optimize"
    end

    it "when layout likes 'miq_request*'" do
      @layout = "miq_request_some_thing"
      subject.should == title + ": Requests"
    end

    it "when layout likes 'cim_*' or 'snia_*'" do
      @layout = "cim_base_storage_extent"
      subject.should == title  + ": Storage - #{ui_lookup(:tables=>@layout)}"
    end

    it "otherwise" do
      @layout = "xxx"
      subject.should == title  + ": #{ui_lookup(:tables=>@layout)}"
    end
 end

  context "#controller_model_name" do
    it "returns the model's title" do
      controller_model_name("OntapFileShare").should == "Storage - File Share"
      controller_model_name("CimStorageExtent").should == "Storage - Extent"
    end
  end

  context "#is_browser_ie7?" do
    it "when browser's explorer version 7.x" do
      ActionController::TestSession.any_instance.stub(:fetch_path).with(:browser, :name).and_return('explorer')
      ActionController::TestSession.any_instance.stub(:fetch_path).with(:browser, :version).and_return('7.10')
      is_browser_ie7?.should be_true
    end

    it "when browser's NOT explorer version 7.x" do
      ActionController::TestSession.any_instance.stub(:fetch_path).with(:browser, :name).and_return('explorer')
      ActionController::TestSession.any_instance.stub(:fetch_path).with(:browser, :version).and_return('6.10')
      is_browser_ie7?.should be_false
    end
  end

  context "#is_browser_ie?" do
    it "when browser's explorer" do
      ActionController::TestSession.any_instance.stub(:fetch_path).with(:browser, :name).and_return('explorer')
      is_browser_ie?.should be_true
    end

    it "when browser's NOT explorer" do
      ActionController::TestSession.any_instance.stub(:fetch_path).with(:browser, :name).and_return('safari')
      is_browser_ie?.should be_false
    end
  end

  context "#is_browser?" do
    it "when browser's name is in the list" do
      ActionController::TestSession.any_instance.stub(:fetch_path).with(:browser, :name).and_return('safari')
      is_browser?(["firefox","opera","safari"]).should be_true
    end

    it "when browser's name is NOT in the list" do
      ActionController::TestSession.any_instance.stub(:fetch_path).with(:browser, :name).and_return('explorer')
      is_browser?(["firefox","opera","safari"]).should be_false
    end
  end

  context "#is_browser_os?" do
    it "when browser's OS is in the list" do
      ActionController::TestSession.any_instance.stub(:fetch_path).with(:browser, :os).and_return('windows')
      is_browser_os?(["windows", "linux"]).should be_true
    end

    it "when browser's OS is NOT in the list" do
      ActionController::TestSession.any_instance.stub(:fetch_path).with(:browser, :os).and_return('macos')
      is_browser_os?(["windows", "linux"]).should be_false
    end
  end

  context "#browser_info" do
    it "downcases by default" do
      type = :a_type
      ActionController::TestSession.any_instance.stub(:fetch_path).with(:browser, type).and_return('checked_by_A_TYPE')
      browser_info(type).should == 'checked_by_a_type'
    end

    it "can provide full case" do
      type = :a_type
      ActionController::TestSession.any_instance.stub(:fetch_path).with(:browser, type).and_return('checked_by_A_TYPE')
      browser_info(type, false).should == 'checked_by_A_TYPE'
    end
  end

  describe "#javascript_for_timer_type" do
    subject { javascript_for_timer_type(timer_type) }

    context "when timer_type == nil" do
      let(:timer_type) { nil }
      specify { subject.should be_empty }
    end

    context "when timer_type == 'Monthly'" do
      let(:timer_type) { 'Monthly' }
      it { should include("$('\#weekly_span').hide();") }
      it { should include("$('\#daily_span').hide();") }
      it { should include("$('\#hourly_span').hide();") }
      it { should include("$('\#monthly_span').show();") }
    end

    context "when timer_type == 'Weekly'" do
      let(:timer_type) { 'Weekly' }
      it { should include("$('\#daily_span').hide();") }
      it { should include("$('\#hourly_span').hide();") }
      it { should include("$('\#monthly_span').hide();") }
      it { should include("$('\#weekly_span').show();") }
    end

    context "when timer_type == 'Daily'" do
      let(:timer_type) { 'Daily' }
      it { should include("$('\#hourly_span').hide();") }
      it { should include("$('\#monthly_span').hide();") }
      it { should include("$('\#weekly_span').hide();") }
      it { should include("$('\#daily_span').show();") }
    end

    context "when timer_type == 'Hourly'" do
      let(:timer_type) { 'Hourly' }
      it { should include("$('\#daily_span').hide();") }
      it { should include("$('\#monthly_span').hide();") }
      it { should include("$('\#weekly_span').hide();") }
      it { should include("$('\#hourly_span').show();") }
    end

    context "when timer_type == 'something_else'" do
      let(:timer_type) { 'something_else' }
      it { should include("$('\#daily_span').hide();") }
      it { should include("$('\#hourly_span').hide();") }
      it { should include("$('\#monthly_span').hide();") }
      it { should include("$('\#weekly_span').hide();") }
    end
  end

  describe "#javascript_for_miq_button_visibility" do
    subject { javascript_for_miq_button_visibility(display) }
    context "when display == true" do
      let(:display) { true }
      it { should == "miqButtons('show');" }
    end

    context "when dsiplay == false" do
      let(:display) { false }
      it { should == "miqButtons('hide');" }
    end
  end

  context "#javascript_for_toolbar_reload" do
    let(:test_tab)    {"some_center_tb"}
    let(:test_buttons) {"x_button"}
    let(:test_xml)    {"x_xml"}
    subject { javascript_for_toolbar_reload(test_tab, test_buttons, test_xml)}

    it { should include("ManageIQ.toolbars.#{test_tab}.obj.unload();") }
    it { should include("#{test_tab} = new dhtmlXToolbarObject('#{test_tab}', 'miq_blue');") }
    it { should include("buttons: #{test_buttons}") }
    it { should include("xml: \"#{test_xml}\"") }
    it { should include("miqInitToolbar(ManageIQ.toolbars['some_center_tb']);") }
  end

  context "#javascript_set_value" do
    let(:element_id)    {"text_field"}
    let(:element_value) {"something"}
    subject { javascript_set_value(element_id, element_value)}

    it { should eq("$('#text_field').val('something');") }
  end

  context "#set_edit_timer_from_schedule" do
    before(:each) do
      @edit = {:tz => 'Eastern Time (US & Canada)', :new => Hash.new}
      @interval = '3'
      @date = "6/28/2012"
      @hour = "0#{11-4}"
      @min = "14"
      @run_at = {:start_time => "2012-06-28 11:14:00".to_time(:utc),
                 :interval   => {:value => @interval}}
      @schedule = double( :run_at => @run_at )
    end

    describe "when schedule.run_at == nil" do
      it "sets defaults" do
        schedule = double(:run_at => nil)
        set_edit_timer_from_schedule schedule
        @edit[:new].should include(
          :timer_typ => "Once",
          :start_hour => "00",
          :start_min => "00"
        )
      end
    end

    describe "when schedule.run_at != nil" do
      it "sets values as monthly" do
        @run_at[:interval][:unit] = 'monthly'
        set_edit_timer_from_schedule @schedule
        @edit[:new].should include(
          :timer_typ => 'Monthly',
          :timer_months => @interval,
          :start_hour => @hour,
          :start_min => @min,
          :start_date => @date
        )
        @edit[:new].should_not include( :timer_months => '1' )
      end

      it "sets values as weekly" do
        @run_at[:interval][:unit] = 'weekly'
        set_edit_timer_from_schedule @schedule
        @edit[:new].should include(
          :timer_typ => 'Weekly',
          :timer_weeks => @interval,
          :start_hour => @hour,
          :start_min => @min,
          :start_date => @date
        )
        @edit[:new].should_not include( :timer_weeks => '1' )
      end

      it "sets values as daily" do
        @run_at[:interval][:unit] = 'daily'
        set_edit_timer_from_schedule @schedule
        @edit[:new].should include(
          :timer_typ => 'Daily',
          :timer_days => @interval,
          :start_hour => @hour,
          :start_min => @min,
          :start_date => @date
        )
        @edit[:new].should_not include( :timer_days => '1' )
      end

      it "sets values as hourly" do
        @run_at[:interval][:unit] = 'hourly'
        set_edit_timer_from_schedule @schedule
        @edit[:new].should include(
          :timer_typ => 'Hourly',
          :timer_hours => @interval,
          :start_hour => @hour,
          :start_min => @min,
          :start_date => @date
        )
        @edit[:new].should_not include( :timer_hours => '1' )
      end
    end
  end

  context "#perf_parent?" do
    it "when model != 'VmOrTemplate'" do
      @perf_options = {:model => 'OntapVolumeDerivedMetric'}
      perf_parent?.should be_false
    end

    it "when model == 'VmOrTemplate' and typ == 'realtime'" do
      @perf_options = {:model => 'VmOrTemplate', :typ => 'realtime'}
      perf_parent?.should be_false
    end

    it "when model == 'VmOrTemplate', typ != 'realtime' and parent is 'Host'" do
      @perf_options = {:model => 'VmOrTemplate', :typ => 'Hourly', :parent => 'Host'}
      perf_parent?.should be_true
    end

    it "when model == 'VmOrTemplate', typ != 'realtime' and parent is 'EmsCluster'" do
      @perf_options = {:model => 'VmOrTemplate', :typ => 'Hourly', :parent => 'EmsCluster'}
      perf_parent?.should be_true
    end

    it "when model == 'VmOrTemplate', typ != 'realtime' and parent is 'invalid parent'" do
      @perf_options = {:model => 'VmOrTemplate', :typ => 'Hourly', :parent => 'invalid parent'}
      perf_parent?.should be_false
    end

    it "when model == 'VmOrTemplate', typ != 'realtime' and parent == nil" do
      @perf_options = {:model => 'VmOrTemplate', :typ => 'Hourly', :parent => nil}
      perf_parent?.should be_false
    end
  end

  context "#perf_compare_vm?" do
    it "when model != 'OntapLogicalDisk'" do
      @perf_options = {:model => 'OntapVolumeDerivedMetric'}
      perf_compare_vm?.should be_false
    end

    it "when model == 'OntapLogicalDisk' and typ == 'realtime'" do
      @perf_options = {:model => 'OntapLogicalDisk', :typ => 'realtime'}
      perf_compare_vm?.should be_false
    end

    it "when model == 'OntapLogicalDisk', typ != 'realtime' and compare_vm == nil" do
      @perf_options = {:model => 'OntapLogicalDisk', :typ => 'Daily', :compare_vm => nil}
      perf_compare_vm?.should be_false
    end

    it "when model == 'OntapLogicalDisk', typ != 'realtime' and compare_vm != nil" do
      @perf_options = {:model => 'OntapLogicalDisk', :typ => 'Daily', :compare_vm => 'something'}
      perf_compare_vm?.should be_true
    end
  end

  context "#model_report_type" do
    it "when model == nil" do
      model_report_type(nil).should be_false
    end

    it "when model likes '...Performance' or '...MetricsRollup'" do
      model_report_type("VmPerformance").should == :performance
      model_report_type("OntapVolumeMetricsRollup").should == :performance
    end

    it "when model == VimPerformanceTrend" do
      model_report_type("VimPerformanceTrend").should == :trend
    end

    it "when model == Chargeback" do
      model_report_type("Chargeback").should == :chargeback
    end
  end

  context "tree related methods" do
    before do
      @sb = { :active_tree => :svcs_tree,
              :trees => { :svcs_tree => { :tree => :svcs_tree }}}
    end

    it "#x_node_set" do
      @sb[:trees][:svcs_tree]      = {:active_node => 'root'}
      @sb[:trees][:vm_filter_tree] = {:active_node => 'abc'}

      x_node_set('def', :vm_filter_tree)
      @sb[:trees][:svcs_tree][:active_node].should      == 'root'
      @sb[:trees][:vm_filter_tree][:active_node].should == 'def'

      x_node_set(nil, :vm_filter_tree)
      @sb[:trees][:svcs_tree][:active_node].should      == 'root'
      @sb[:trees][:vm_filter_tree][:active_node].should be_nil

      x_node_set('', :vm_filter_tree)
      @sb[:trees][:svcs_tree][:active_node].should      == 'root'
      @sb[:trees][:vm_filter_tree][:active_node].should == ''
    end

    it "#x_node=" do
      helper.x_node = 'root'
      @sb[:trees][:svcs_tree][:active_node].should == 'root'

      helper.x_node = nil
      @sb[:trees][:svcs_tree][:active_node].should be_nil

      helper.x_node = ''
      @sb[:trees][:svcs_tree][:active_node].should == ''
    end

    context "#x_node" do
      it "without tree param" do
        @sb[:trees][:svcs_tree] = {:active_node => 'root'}
        x_node.should == 'root'

        @sb[:trees][:svcs_tree] = {:active_node => nil}
        x_node.should be_nil

        @sb[:trees][:svcs_tree] = {:active_node => ''}
        x_node.should == ''
      end

      it "with tree param" do
        @sb[:trees][:svcs_tree]      = {:active_node => 'root'}
        @sb[:trees][:vm_filter_tree] = {:active_node => 'abc'}

        x_node(:svcs_tree).should      == "root"
        x_node(:vm_filter_tree).should == "abc"
      end
    end

    context "#x_tree" do
      it "without tree param" do
        @sb[:trees][:vm_filter_tree] = {:tree => :vm_filter_tree}

        x_tree.should == @sb[:trees][:svcs_tree]
        @sb[:active_tree] = :vm_filter_tree
        x_tree.should == @sb[:trees][:vm_filter_tree]
      end

      it "with tree param" do
        @sb[:trees][:vm_filter_tree] = {:tree => :vm_filter_tree}
        @sb[:trees][:svcs_tree]      = {:tree => :svcs_tree}

        x_tree(:svcs_tree).should      == @sb[:trees][:svcs_tree]
        x_tree(:vm_filter_tree).should == @sb[:trees][:vm_filter_tree]
      end
    end

    it "#x_active_tree=" do
      helper.x_active_tree = 'vms_filter_tree'
      @sb[:active_tree].should == :vms_filter_tree

      helper.x_active_tree = 'svcs_tree'
      @sb[:active_tree].should == :svcs_tree
    end

    it "#x_active_tree" do
      x_active_tree.should == :svcs_tree
      @sb[:active_tree] = :vm_filter_tree
      x_active_tree.should == :vm_filter_tree
    end

    context "#x_tree_init" do
      it "does not replace existing trees" do
        x_tree_init(:svcs_tree, :xxx, "XXX")

        @sb[:trees][:svcs_tree].should == { :tree => :svcs_tree }
      end

      it "has default values" do
        x_tree_init(:vm_filter_tree, :vm_filter, "Vm")

        @sb[:trees][:vm_filter_tree].should == {
          :tree       => :vm_filter_tree,
          :type       => :vm_filter,
          :leaf       => "Vm",
          :add_root   => true,
          :open_nodes => []
        }
      end

      it "can override default values" do
        x_tree_init(:vm_filter_tree, :vm_filter, "Vm",
          :add_root   => false,
          :open_nodes => [:a],
          :open_all   => true,
          :full_ids   => true
        )

        @sb[:trees][:vm_filter_tree].should == {
          :tree       => :vm_filter_tree,
          :type       => :vm_filter,
          :leaf       => "Vm",
          :add_root   => false,
          :open_nodes => [:a],
          :open_all   => true,
          :full_ids   => true
        }
      end
    end

    it "#x_tree_history" do
      @sb = { :history => { :svcs_tree => %w(service1 service2 service3) },
              :active_tree => :svcs_tree }
      x_tree_history.should == %w(service1 service2 service3)
    end
  end

  describe "truncate text for quad icons" do

    ["front", "middle", "back"].each do |trunc|

      context "remove #{trunc} of text" do

        before(:each) do
          @settings = {:display=>{:quad_truncate=>trunc[0]}}
        end

        it "when value is nil" do
          text = truncate_for_quad(nil)
          text.should be_nil
        end

        it "when value is < 13 long" do
          text = truncate_for_quad("Test")
          text.should == "Test"
        end

        it "when value is 12 long" do
          text = truncate_for_quad("ABCDEFGHIJKL")
          text.should == "ABCDEFGHIJKL"
        end

        it "when value is 13 long" do
          text = truncate_for_quad("ABCDEooo12345")
          text.should == case trunc[0]
                           when "f"; "...DEooo12345"
                           when "m"; "ABCDE...12345"
                           when "b"; "ABCDEooo12..."
                         end
        end

        it "when value is 25 long" do
          text = truncate_for_quad("ABCDEooooooooooooooo12345")
          text.should == case trunc[0]
                           when "f"; "...ooooo12345"
                           when "m"; "ABCDE...12345"
                           when "b"; "ABCDEooooo..."
                         end
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

      ["miq_template","ems_cloud","ems_cluster","ems_infra","host","storage"].each do |table|

        it "for table #{table}" do
          @layout = table
          @display = "main"
          text = custom_toolbar_filename
          text.should == "custom_buttons_tb"
        end

      end

      # Just a few tables that don't have custom toolbars
      ["ems_events","storage_managers"].each do |table|

        it "for table #{table}" do
          @layout = table
          text = custom_toolbar_filename
          text.should be_nil
        end

      end

    end

    context "for classic (non-explorer) CI non-main summary screens" do

      before(:each) do
        @lastaction = "show"
        @record = true
      end

      ["miq_template","ems_cluster","host","storage","management_system"].each do |table|

        it "for table #{table}" do
          @layout = table
          @display = "not_main"
          text = custom_toolbar_filename
          text.should be_nil
        end

      end

    end

    context "for classic (non-explorer) CI list view screens" do

      before(:each) do
        @lastaction = "show_list"
        @record = true
      end

      ["miq_template","ems_cluster","host","storage","management_system"].each do |table|

        it "for table #{table}" do
          @layout = table
          text = custom_toolbar_filename
          text.should be_nil
        end

      end

      # Just a few tables that don't have custom toolbars
      ["ems_events","storage_managers"].each do |table|

        it "for table #{table}" do
          @layout = table
          text = custom_toolbar_filename
          text.should be_nil
        end

      end

    end

    context "for explorer-based screens" do

      before(:each) do
        @explorer = true
        @sb = {:active_tree => "my_tree",
               :trees       => {"my_tree" => {:active_node=>nil}}
              }
      end

      it "for non custom toolbar controller" do
        helper.stub(:params) { {:controller => "policy"} }
        text = helper.custom_toolbar_filename
        text.should be_nil
      end

      ["vm_or_template","service"].each do |table|

        it "for #{table} controller on root node" do
          @sb[:trees][@sb[:active_tree]][:active_node] = "root"
          helper.stub(:params) { {:controller => table} }
          text = helper.custom_toolbar_filename
          text.should == "blank_view_tb"
        end

        it "for #{table} controller on record node summary screen" do
          @sb[:trees][@sb[:active_tree]][:active_node] = "v-1r35"
          @display = "main"
          @record = true
          helper.stub(:params) { {:controller => table} }
          text = helper.custom_toolbar_filename
          text.should == "custom_buttons_tb"
        end

        it "for #{table} controller on record node, but not summary screen" do
          @sb[:trees][@sb[:active_tree]][:active_node] = "v-1r35"
          @display = "not_main"
          @record = true
          helper.stub(:params) { {:controller => table} }
          text = helper.custom_toolbar_filename
          text.should == "blank_view_tb"
        end

      end

    end

    context "#center_div_height" do
      it "calculates height for center div" do
        @winH = 800
        max = 627
        min = 200
        height = @winH < max ? min : @winH - (max - min)
        res = center_div_height
        res.should == height

        max = 757
        min = 400
        height = @winH < max ? min : @winH - (max - min)
        res = center_div_height(false, 400)
        res.should == height
      end
    end
  end

  describe '#pressed2model_action' do
    examples = {
      'miq_template_bar' => ['miq_template', 'bar'],
      'boo_far'          => ['boo', 'far'],
      'boo_far_bar'      => ['boo', 'far_bar'],
    }

    examples.each_pair do |input,output|
      it "gives '#{output}' on '#{input}'" do
        helper.pressed2model_action(input).should == output
      end
    end
  end

  describe "update_paging_url_parms", :type => :request do

    context "when the given parameter is a hash" do
      before do
        get("/vm/show_list/100", "bc=VMs+running+on+2014-08-25&menu_click=Display-VMs-on_2-6-5"\
           "&page=2&sb_controller=host")
        Object.any_instance.stub(:query_string).and_return(@request.query_string)
        allow_message_expectations_on_nil
      end

      it "updates the query string with the given hash value and returns the full url path" do
        update_paging_url_parms("show_list", :page => 1).should eq("/vm/show_list/100?bc=VMs+running+on+2014-08-25"\
          "&menu_click=Display-VMs-on_2-6-5&page=1&sb_controller=host")
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

      result = title_for_clusters
      result.should eq("Clusters / Deployment Roles")
    end

    it "returns 'Clusters' when there are only non-openstack clusters" do
      FactoryGirl.create(:ems_cluster, :ems_id => @ems1.id)

      result = title_for_clusters
      result.should eq("Clusters")
    end

    it "returns 'Deployment Roles' when there are only openstack clusters" do
      FactoryGirl.create(:ems_cluster, :ems_id => @ems2.id)

      result = title_for_clusters
      result.should eq("Deployment Roles")
    end
  end

  context "#title_for_cluster" do
    before(:each) do
      @ems1 = FactoryGirl.create(:ems_vmware)
      @ems2 = FactoryGirl.create(:ems_openstack_infra)
    end

    it "returns 'Cluster' for non-openstack cluster" do
      FactoryGirl.create(:ems_cluster, :ems_id => @ems1.id)

      result = title_for_cluster
      result.should eq("Cluster")
    end

    it "returns 'Deployment Role' for openstack cluster" do
      FactoryGirl.create(:ems_cluster, :ems_id => @ems2.id)

      result = title_for_cluster
      result.should eq("Deployment Role")
    end
  end

  context "#title_for_cluster_record" do
    before(:each) do
      @ems1 = FactoryGirl.create(:ems_vmware)
      @ems2 = FactoryGirl.create(:ems_openstack_infra)
    end

    it "returns 'Cluster' for non-openstack host" do
      cluster = FactoryGirl.create(:ems_cluster, :ems_id => @ems1.id)

      result = title_for_cluster_record(cluster)
      result.should eq("Cluster")
    end

    it "returns 'Deployment Role' for openstack host" do
      cluster = FactoryGirl.create(:ems_cluster, :ems_id => @ems2.id)

      result = title_for_cluster_record(cluster)
      result.should eq("Deployment Role")
    end
  end

  context "#title_for_hosts" do
    before(:each) do
      @ems1 = FactoryGirl.create(:ems_vmware)
      @ems2 = FactoryGirl.create(:ems_openstack_infra)
    end

    it "returns 'Hosts / Nodes' when there are both openstack & non-openstack hosts" do
      FactoryGirl.create(:host_vmware_esx, :ems_id => @ems1.id)
      FactoryGirl.create(:host_redhat, :ems_id => @ems2.id)

      result = title_for_hosts
      result.should eq("Hosts / Nodes")
    end

    it "returns 'Hosts' when there are only non-openstack hosts" do
      FactoryGirl.create(:host_vmware_esx, :ems_id => @ems1.id)

      result = title_for_hosts
      result.should eq("Hosts")
    end

    it "returns 'Nodes' when there are only openstack hosts" do
      FactoryGirl.create(:host_redhat, :ems_id => @ems2.id)

      result = title_for_hosts
      result.should eq("Nodes")
    end
  end

  context "#title_for_host" do
    before(:each) do
      @ems1 = FactoryGirl.create(:ems_vmware)
      @ems2 = FactoryGirl.create(:ems_openstack_infra)
    end

    it "returns 'Host' for non-openstack host" do
      FactoryGirl.create(:host_vmware, :ems_id => @ems1.id)

      result = title_for_host
      result.should eq("Host")
    end

    it "returns 'Node' for openstack host" do
      FactoryGirl.create(:host_redhat, :ems_id => @ems2.id)

      result = title_for_host
      result.should eq("Node")
    end
  end

  context "#title_for_host_record" do
    before(:each) do
      @ems1 = FactoryGirl.create(:ems_vmware)
      @ems2 = FactoryGirl.create(:ems_openstack_infra)
    end

    it "returns 'Host' for non-openstack host" do
      host = FactoryGirl.create(:host_vmware, :ems_id => @ems1.id)

      result = title_for_host_record(host)
      result.should eq("Host")
    end

    it "returns 'Node' for openstack host" do
      host = FactoryGirl.create(:host_redhat, :ems_id => @ems2.id)

      result = title_for_host_record(host)
      result.should eq("Node")
    end
  end

  context "#start_page_allowed?" do
    def role_allows(_)
      true
    end

    it "should return true for storage start pages when product flag is set" do
      cfg = VMDB::Config.new("vmdb")
      cfg.config.store_path(:product, :storage, true)
      VMDB::Config.stub(:new).and_return(cfg)
      result = start_page_allowed?("cim_storage_extent_show_list")
      result.should be_true
    end

    it "should return false for storage start pages when product flag is not set" do
      result = start_page_allowed?("cim_storage_extent_show_list")
      result.should be_false
    end

    it "should return true for containers start pages when product flag is set" do
      cfg = VMDB::Config.new("vmdb")
      cfg.config.store_path(:product, :containers, true)
      VMDB::Config.stub(:new).and_return(cfg)
      result = start_page_allowed?("ems_container_show_list")
      result.should be_true
    end

    it "should return false for containers start pages when product flag is not set" do
      result = start_page_allowed?("ems_container_show_list")
      result.should be_false
    end

    it "should return true for host start page" do
      result = start_page_allowed?("host_show_list")
      result.should be_true
    end
  end

  context "#vm_explorer_tree?" do
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
      result = controller.vm_explorer_tree?
      result.should be_true
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
      result = controller.vm_explorer_tree?
      result.should be_false
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
      result = controller.show_advanced_search?
      result.should be_true
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
      result = controller.show_advanced_search?
      result.should be_false
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
      result = controller.show_advanced_search?
      result.should be_true
    end
  end

  context "#listicon_image_tag" do
    it "returns correct image for job record based upon it's status" do
      job_attrs = {"state" => "running", "status" => "ok"}
      image = listicon_image_tag("Job", job_attrs)
      image.should eq("<img valign=\"middle\" width=\"16\" height=\"16\" title=\"Status = Running\" src=\"/images/icons/new/job-running.png\" />")
    end
  end

  it 'output of remote_function should not be html_safe' do
    remote_function(:url => {:controller => 'vm_infra', :action => 'explorer'}).html_safe?.should be_false
  end
end
