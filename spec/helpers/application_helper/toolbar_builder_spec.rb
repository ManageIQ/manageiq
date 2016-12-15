describe ApplicationHelper do
  before do
    controller.send(:extend, ApplicationHelper)
    controller.send(:extend, ApplicationController::CurrentUser)
    self.class.send(:include, ApplicationHelper)
    self.class.send(:include, ApplicationController::CurrentUser)
  end

  def method_missing(sym, *args)
    b = _toolbar_builder
    if b.respond_to?(sym, true)
      b.send(sym, *args)
    else
      super
    end
  end

  describe "custom_buttons" do
    let(:user) { FactoryGirl.create(:user, :role => "super_administrator") }

    shared_examples "no custom buttons" do
      it("#get_custom_buttons")           { expect(get_custom_buttons(subject)).to be_blank }
      it("#custom_buttons_hash")          { expect(custom_buttons_hash(subject)).to be_blank }
      it("#custom_toolbar_class") { expect(custom_toolbar_class(subject).definition).to be_blank }
      it("#record_to_service_buttons")    { expect(record_to_service_buttons(subject)).to be_blank }
    end

    shared_examples "with custom buttons" do
      before do
        @button_set = FactoryGirl.create(:custom_button_set, :set_data => {:applies_to_class => applies_to_class})
        login_as user
        @button1 = FactoryGirl.create(:custom_button, :applies_to_class => applies_to_class, :visibility => {:roles => ["_ALL_"]}, :options => {})
        @button_set.add_member @button1
      end

      it "#get_custom_buttons" do
        expected_button1 = {
          :id            => @button1.id,
          :class         => @button1.applies_to_class,
          :name          => @button1.name,
          :description   => @button1.description,
          :image         => @button1.options[:button_image],
          :text_display  => @button1.options.key?(:display) ? @button1.options[:display] : true,
          :target_object => subject.id
        }
        expected_button_set = {
          :id           => @button_set.id,
          :text         => @button_set.name,
          :description  => @button_set.description,
          :image        => @button_set.set_data[:button_image],
          :text_display => @button_set.set_data.key?(:display) ? @button_set.set_data[:display] : true,
          :buttons      => [expected_button1]
        }

        expect(get_custom_buttons(subject)).to eq([expected_button_set])
      end

      it "#record_to_service_buttons" do
        expect(record_to_service_buttons(subject)).to be_blank
      end

      it "#custom_buttons_hash" do
        escaped_button1_text = CGI.escapeHTML(@button1.name.to_s)
        button1 = {
          :id    => "custom__custom_#{@button1.id}",
          :type      => :button,
          :icon      => "product product-custom-#{@button1.options[:button_image]} fa-lg",
          :title     => CGI.escapeHTML(@button1.description.to_s),
          :text      => escaped_button1_text,
          :enabled   => true,
          :klass     => ApplicationHelper::Button::ButtonWithoutRbacCheck,
          :url       => "button",
          :url_parms => "?id=#{subject.id}&button_id=#{@button1.id}&cls=#{subject.class.name}&pressed=custom_button&desc=#{escaped_button1_text}"
        }
        button_set_item1_items = [button1]
        button_set_item1 = {
          :id           => "custom_#{@button_set.id}",
          :type         => :buttonSelect,
          :icon         => "product product-custom-#{@button_set.set_data[:button_image]} fa-lg",
          :title        => @button_set.description,
          :text         => @button_set.name,
          :enabled      => true,
          :items        => button_set_item1_items
        }
        items = [button_set_item1]
        name = "custom_buttons_#{@button_set.name}"
        expect(custom_buttons_hash(subject)).to eq([:name => name, :items => items])
      end

      it "#custom_toolbar_class" do
        escaped_button1_text = CGI.escapeHTML(@button1.name.to_s)
        button1 = {
          :id        => "custom__custom_#{@button1.id}",
          :type      => :button,
          :icon      => "product product-custom-#{@button1.options[:button_image]} fa-lg",
          :title     => CGI.escapeHTML(@button1.description.to_s),
          :text      => escaped_button1_text,
          :enabled   => true,
          :klass     => ApplicationHelper::Button::ButtonWithoutRbacCheck,
          :url       => "button",
          :url_parms => "?id=#{subject.id}&button_id=#{@button1.id}&cls=#{subject.class.name}&pressed=custom_button&desc=#{escaped_button1_text}"
        }
        button_set_item1_items = [button1]
        button_set_item1 = {
          :id           => "custom_#{@button_set.id}",
          :type         => :buttonSelect,
          :icon         => "product product-custom-#{@button_set.set_data[:button_image]} fa-lg",
          :title        => @button_set.description,
          :text         => @button_set.name,
          :enabled      => true,
          :items        => button_set_item1_items
        }
        group_name = "custom_buttons_#{@button_set.name}"
        expect(custom_toolbar_class(subject).definition[group_name].buttons).to eq([button_set_item1])
      end
    end

    context "for VM" do
      let(:applies_to_class) { 'Vm' }
      subject { FactoryGirl.create(:vm_vmware) }

      it_behaves_like "no custom buttons"
      it_behaves_like "with custom buttons"
    end

    context "for Service" do
      let(:applies_to_class) { 'ServiceTemplate' }
      let(:service_template) { FactoryGirl.create(:service_template) }
      subject                { FactoryGirl.create(:service, :service_template => service_template) }

      it_behaves_like "no custom buttons"
      it_behaves_like "with custom buttons"
    end
  end

  describe "#get_image" do
    subject { get_image(@img, @button_name) }

    context "when with show_summary" do
      before do
        @button_name = "show_summary"
        @img = "reload"
      end

      it "and layout is scan_profile" do
        @layout = "scan_profile"
        expect(subject).to eq("summary-green")
      end

      it "and layout is miq_schedule" do
        @layout = "miq_schedule"
        expect(subject).to eq("summary-green")
      end

      it "and layout is miq_proxy" do
        @layout = "miq_schedule"
        expect(subject).to eq("summary-green")
      end

      it "otherwise" do
        @layout = "some_thing"
        expect(subject).to eq(@img)
      end
    end

    it "when not with show_summary" do
      @button_name = "summary_reload"
      @img = "reload"
      expect(subject).to eq(@img)
    end
  end # get_image

  describe "#hide_button?" do
    let(:user) { FactoryGirl.create(:user) }
    subject { hide_button?(@id) }
    before do
      @record = double("record")
      login_as user
      @settings = {
        :views => {
          :compare      => 'compressed',
          :drift        => 'compressed',
          :compare_mode => 'exists',
          :drift_mode   => 'exists',
          :treesize     => '32'
        }
      }
    end

    %w(
      history_1
      history_2
      history_3
      history_4
      history_5
      history_6
      history_7
      history_8
      history_9
      history_10
    ).each do |item|
      it "when with history item #{item}" do
        @id = item
        expect(subject).to be_falsey
      end
    end

    it "when with show_summary and not explorer" do
      @id = "show_summary"
      @explorer = false
      expect(subject).to be_falsey
    end

    it "when with show_summary and explorer" do
      @id = "show_summary"
      @explorer = true
      expect(subject).to be_truthy
    end

    it "when id likes old_dialogs_*" do
      @id = "old_dialogs_some_thing"
      expect(subject).to be_truthy
    end

    it "when id likes ab_*" do
      @id = "ab_some_thing"
      expect(subject).to be_truthy
    end

    ["miq_task_", "compare_", "drift_", "comparemode_", "driftmode_", "custom_"].each do |i|
      it "when id likes #{i}*" do
        @id = "#{i}some_thing"
        expect(subject).to be_falsey
      end
    end

    context "when with miq_request_reload" do
      before { @id = "miq_request_reload" }
      it "and lastaction is show_list" do
        @lastaction = "show_list"
        expect(subject).to be_falsey
      end

      it "and lastaction is not show_list" do
        @lastaction = "log"
        expect(subject).to be_truthy
      end
    end

    context "when with miq_request_reload" do
      before { @id = "miq_request_reload" }
      it "and showtype is miq_provisions" do
        @showtype = "miq_provisions"
        expect(subject).to be_falsey
      end

      it "and showtype is not miq_provisions" do
        @showtype = "compare"
        expect(subject).to be_truthy
      end
    end

    it "when id likes dialog_*" do
      @id = "dialog_some_thing"
      expect(subject).to be_falsey
    end

    it "when with miq_request_approve and allowed by the role" do
      @id = "miq_request_approve"
      # when the role allows the feature
      stub_user(:features => :all)
      expect(subject).to be_falsey
    end

    it "when with miq_request_deny and allowed by the role" do
      @id = "miq_request_deny"
      # when the role allows the feature
      stub_user(:features => :all)
      expect(subject).to be_falsey
    end

    it "when not with miq_request_approve or miq_request_deny and not allowed by the role" do
      @id = "miq_request_edit"
      expect(subject).to be_truthy
    end

    ["ems_cluster_protect", "ext_management_system_protect",
     "host_analyze_check_compliance", "host_check_compliance",
     "host_enter_maint_mode", "host_exit_maint_mode",
     "repo_protect",
     "resource_pool_protect",
     "vm_check_compliance",
     "vm_start",
     "vm_suspend",
     "vm_snapshot_add",
     "vm_snapshot_delete",
     "vm_snapshot_delete_all",
     "vm_snapshot_revert"].each do |id|
      it "when with #{id}" do
        @id = id
        stub_user(:features => :all)
        expect(subject).to be_falsey
      end
    end

    %w(host_miq_request_new vm_miq_request_new vm_pre_prov).each do |id|
      it "when with #{id}" do
        @id = id
        stub_user(:features => :all)
        expect(subject).to be_falsey
      end
    end

    context "when with miq_task_canceljob" do
      before do
        @id = 'miq_task_canceljob'
        stub_user(:features => :all)
      end

      it "and @layout != all_tasks" do
        @layout = "x_tasks"
        expect(subject).to be_truthy
      end

      it "and @layout != all_ui_tasks" do
        @layout = "x_ui_tasks"
        expect(subject).to be_truthy
      end

      it "and @layout = all_tasks" do
        @layout = "all_tasks"
        expect(subject).to be_falsey
      end

      it "and @layout = all_ui_tasks" do
        @layout = "all_ui_tasks"
        expect(subject).to be_falsey
      end
    end

    context "when with vm_miq_request_new" do
      it "and @lastaction = show, @display = vms" do
        @id = "vm_miq_request_new"
        @lastaction = "show"
        @display = "vms"
        stub_user(:features => :all)
        expect(subject).to be_falsey
      end
    end

    context "when with vm_console" do
      before do
        @id = "vm_console"
        stub_user(:features => :all)
        allow(@record).to receive_messages(:console_supported? => false)
      end

      it "and record is not console supported" do
        expect(subject).to be_truthy
      end

      it "and server's remote_console_type not set" do
        stub_settings(:server => {})
        expect(subject).to be_truthy
      end

      it "and server's remote_console_type is not MKS" do
        stub_settings(:server => {:remote_console_type => "not_MKS"})
        expect(subject).to be_truthy
      end

      it "and record is console supported and server's remote_console_type is MKS" do
        allow(@record).to receive_messages(:console_supported? => true)
        stub_settings(:server => {:remote_console_type => "MKS"})
        expect(subject).to be_falsey
      end
    end

    context "when with vm_vnc_console" do
      before do
        @id = "vm_vnc_console"
        stub_user(:features => :all)
        allow(@record).to receive_messages(:console_supported? => false)
        allow(@record).to receive_messages(:vendor => "vmware")
      end

      it "and record is not console supported" do
        expect(subject).to be_truthy
      end

      it "and server's remote_console_type not set" do
        stub_settings(:server => {})
        expect(subject).to be_truthy
      end

      it "and server's remote_console_type is not VNC" do
        stub_settings(:server => {:remote_console_type => "not_VNC"})
        expect(subject).to be_truthy
      end

      it "and record is console supported and server's remote_console_type is VNC" do
        allow(@record).to receive_messages(:console_supported? => true)
        stub_settings(:server => {:remote_console_type => "VNC"})
        expect(subject).to be_falsey
      end

      it "and record is console supported and not vmware" do
        allow(@record).to receive_messages(:console_supported? => true)
        allow(@record).to receive_messages(:vendor => "not_vmware")
        expect(subject).to be_falsey
      end
    end

    context "when with vm_vmrc_console" do
      before do
        @id = "vm_vmrc_console"
        stub_user(:features => :all)
        allow(@record).to receive_messages(:console_supported? => false)
      end

      it "and record is not console supported" do
        expect(subject).to be_truthy
      end

      it "and server's remote_console_type not set" do
        stub_settings(:server => {})
        expect(subject).to be_truthy
      end

      it "and server's remote_console_type is not VMRC" do
        stub_settings(:server => {:remote_console_type => "not_VMRC"})
        expect(subject).to be_truthy
      end

      it "and record is console supported and server's remote_console_type is VMRC" do
        allow(@record).to receive_messages(:console_supported? => true)
        stub_settings(:server => {:remote_console_type => "VMRC"})
        expect(subject).to be_falsey
      end
    end

    ["ontap_storage_system_statistics", "ontap_logical_disk_statistics", "ontap_storage_volume_statistics", "ontap_file_share_statistics"].each do |id|
      context "when with #{id}" do
        before do
          @id = id
          stub_user(:features => :all)
        end

        it "and Settings.product.smis != true " do
          stub_settings(:product => {:smis => false})
          expect(subject).to be_truthy
        end

        it "and Settings.product.smis = true " do
          stub_settings(:product => {:smis => true})
          expect(subject).to be_falsey
        end
      end
    end

    context "CustomButtonSet" do
      before do
        @record = CustomButtonSet.new
        @sb = {:active_tree => :sandt_tree}
      end

      %w(ab_button_new ab_group_edit ab_group_delete).each do |id|
        it "hides #{id} action from toolbar when user has view permission only" do
          @id = id
          expect(subject).to be_truthy
        end
      end
    end

    context "when with Host" do
      before do
        @record = Host.new
        stub_user(:features => :all)
      end

      context "and id = common_drift" do
        before do
          @id = 'common_drift'
          @lastaction = 'drift_history'
        end

        it "and lastaction = drift_history" do
          expect(subject).to be_falsey
        end
      end
    end

    context "ServiceTemplate" do
      before do
        @record = ServiceTemplate.new
        @sb = {:active_tree => :sandt_tree}
      end

      %w(ab_button_new ab_group_new catalogitem_edit catalogitem_delete).each do |id|
        it "hides #{id} action from toolbar when user has view permission only" do
          @id = id
          expect(subject).to be_truthy
        end
      end
    end

    context "when id = ems_infra_scale" do
      before do
        @id = "ems_infra_scale"
      end

      context "when @record = EmsOpenstackInfra" do
        before do
          @record = FactoryGirl.create(:ems_openstack_infra_with_stack)
        end

        it "user allowed" do
          stub_user(:features => :all)
          expect(subject).to be_falsey
        end

        it "user not allowed" do
          stub_user(:features => :none)
          expect(subject).to be_truthy
        end

        it "button hidden if provider has no stacks" do
          @record = FactoryGirl.create(:ems_openstack_infra)
          stub_user(:features => :all)
          expect(subject).to be_truthy
        end
      end

      context "when @record != EmsOpenstackInfra" do
        before do
          @record = ManageIQ::Providers::Vmware::InfraManager.new
        end

        it "user allowed but hide button because wrong provider" do
          stub_user(:features => :all)
          expect(subject).to be_truthy
        end

        it "user not allowed" do
          stub_user(:features => :all)
          expect(subject).to be_truthy
        end
      end
    end

    context "when record class = ExtManagementSystem" do
      before do
        @record = FactoryGirl.create(:ems_amazon)
      end

      context "and id = ems_cloud_timeline" do
        before { @id = "ems_cloud_timeline" }

        it "hide timelines button for EC2 provider" do
          allow(@record).to receive(:has_events?).and_return(false)
          expect(subject).to be_truthy
        end
      end
    end
  end # end of hide_button?

  describe "#disable_button" do
    subject { disable_button(@id) }
    before do
      @gtl_type = 'list'
      @settings = {
        :views => {
          :compare      => 'compressed',
          :drift        => 'compressed',
          :compare_mode => 'exists',
          :drift_mode   => 'exists',
          :treesize     => '32'
        }
      }
    end

    def setup_firefox_with_linux
      # setup for mocking is_browser? and is_browser_os?
      allow_any_instance_of(ActionController::TestSession)
        .to receive(:fetch_path).with(:browser, :name).and_return('firefox')
      allow_any_instance_of(ActionController::TestSession)
        .to receive(:fetch_path).with(:browser, :os).and_return('linux')
    end

    ['list', 'tile', 'grid'].each do |g|
      it "when with view_#{g}" do
        @gtl_type = g
        expect(disable_button("view_#{g}")).to be_truthy
      end
    end

    it 'disables the add new iso datastore button when no EMSes are available' do
      expect(ManageIQ::Providers::Redhat::InfraManager)
        .to(receive(:any_without_iso_datastores?))
        .and_return(false)

      @layout = "pxe"
      @id = "iso_datastore_new"

      expect(subject).to match(/No.*are available/)
    end

    context "when record class = OntapStorageSystem" do
      before do
        @record = OntapStorageSystem.new
        allow(@record).to receive_messages(:latest_derived_metrics => true)
      end

      context "and id = ontap_storage_system_statistics" do
        before { @id = "ontap_storage_system_statistics" }
        it_behaves_like 'record without latest derived metrics', "No Statistics Collected"
        it_behaves_like 'default case'
      end
    end

    context "when record class = OntapLogicalDisk" do
      before { @record = OntapLogicalDisk.new }

      context "and id = ontap_logical_disk_perf" do
        before do
          @id = "ontap_logical_disk_perf"
          allow(@record).to receive_messages(:has_perf_data? => true)
        end
        it_behaves_like 'record without perf data', "No Capacity & Utilization data has been collected for this Logical Disk"
        it_behaves_like 'default case'
      end

      context "and id = ontap_logical_disk_statistics" do
        before do
          @id = "ontap_logical_disk_statistics"
          allow(@record).to receive_messages(:latest_derived_metrics => true)
        end
        it_behaves_like 'record without latest derived metrics', "No Statistics collected for this Logical Disk"
        it_behaves_like 'default case'
      end
    end

    context "when record class = CimBaseStorageExtent" do
      before do
        @record = CimBaseStorageExtent.new
        allow(@record).to receive_messages(:latest_derived_metrics => true)
      end

      context "and id = cim_base_storage_extent_statistics" do
        before { @id = "cim_base_storage_extent_statistics" }
        it_behaves_like 'record without latest derived metrics', "No Statistics Collected"
        it_behaves_like 'default case'
      end
    end

    context "when record class = OntapStorageVolume" do
      before do
        @record = OntapStorageVolume.new
        allow(@record).to receive_messages(:latest_derived_metrics => true)
      end

      context "and id = ontap_storage_volume_statistics" do
        before { @id = "ontap_storage_volume_statistics" }
        it_behaves_like 'record without latest derived metrics', "No Statistics Collected"
        it_behaves_like 'default case'
      end
    end

    context "when record class = OntapFileShare" do
      before do
        @record = OntapFileShare.new
        allow(@record).to receive_messages(:latest_derived_metrics => true)
      end
      context "and id = ontap_file_share_statistics" do
        before { @id = "ontap_file_share_statistics" }
        it_behaves_like 'record without latest derived metrics', "No Statistics Collected"
        it_behaves_like 'default case'
      end
    end

    context "when record class = SniaLocalFileSystem" do
      before do
        @record = SniaLocalFileSystem.new
        allow(@record).to receive_messages(:latest_derived_metrics => true)
      end
      context "and id = snia_local_file_system_statistics" do
        before { @id = "snia_local_file_system_statistics" }
        it_behaves_like 'record without latest derived metrics', "No Statistics Collected"
        it_behaves_like 'default case'
      end
    end

    context "when record class = EmsCluster" do
      before do
        @record = EmsCluster.new
        allow(@record).to receive_messages(:has_perf_data? => true, :has_events? => true)
      end

      context "and id = ems_cluster_perf" do
        before { @id = "ems_cluster_perf" }
        it_behaves_like 'record without perf data', "No Capacity & Utilization data has been collected for this Cluster"
        it_behaves_like 'default case'
      end

      context "and id = ems_cluster_timeline" do
        before { @id = "ems_cluster_timeline" }
        it_behaves_like 'record without ems events and policy events', "No Timeline data has been collected for this Cluster"
        it_behaves_like 'default case'
      end
    end

    context "when record class = Host" do
      before do
        @record = Host.new
        allow(@record).to receive_messages(:has_perf_data? => true)
      end

      context "and id = host_perf" do
        before { @id = "host_perf" }
        it_behaves_like 'record without perf data', "No Capacity & Utilization data has been collected for this Host"
        it_behaves_like 'default case'
      end

      context "and id = host_miq_request_new" do
        before do
          @id = "host_miq_request_new"
          allow(@record).to receive(:mac_address).and_return("00:0D:93:13:51:1A")
          allow(PxeServer).to receive(:all).and_return(%w(p1 p2))
        end
        it "when without mac address" do
          allow(@record).to receive(:mac_address).and_return(false)
          expect(subject).to eq("This Host can not be provisioned because the MAC address is not known")
        end

        it "when no PXE servers" do
          allow(PxeServer).to receive(:all).and_return([])
          expect(subject).to eq("No PXE Servers are available for Host provisioning")
        end

        it_behaves_like 'default case'
      end

      context "and id = host_timeline" do
        before do
          @id = "host_timeline"
          allow(@record).to receive(:has_events?).and_return(true)
        end

        it_behaves_like 'record without ems events and policy events', "No Timeline data has been collected for this Host"
        it_behaves_like 'default case'
      end
    end

    context "when record class = MiqServer" do
      let(:log_file) { FactoryGirl.create(:log_file) }
      let(:miq_task) { FactoryGirl.create(:miq_task) }
      let(:file_depot) { FactoryGirl.create(:file_depot) }
      let(:miq_server) { FactoryGirl.create(:miq_server) }

      before do
        @record = MiqServer.new('name' => 'Server1', 'id' => 'Server ID')
      end

      it "'collecting' log_file with started server and disables button" do
        @record.status = "not responding"
        error_msg = "Cannot collect current logs unless the Server is started"
        expect(disable_button("collect_logs")).to eq(error_msg)
      end

      it "log collecting is in progress and disables button" do
        log_file.resource = @record
        log_file.state = "collecting"
        log_file.save
        @record.status = "started"
        @record.log_files << log_file
        error_msg = "Log collection is already in progress for this Server"
        expect(disable_button("collect_logs")).to eq(error_msg)
      end

      it "log collection in progress with unfinished task and disables button" do
        @record.status = "started"
        miq_task.name = "Zipped log retrieval for XXX"
        miq_task.miq_server_id = @record.id
        miq_task.save
        error_msg = "Log collection is already in progress for this Server"
        expect(disable_button("collect_logs")).to eq(error_msg)
      end

      it "'collecting' with undefined depot and disables button" do
        @record.status = "started"
        @record.log_file_depot = nil
        error_msg = "Log collection requires the Log Depot settings to be configured"
        expect(disable_button("collect_logs")).to eq(error_msg)
      end

      it "'collecting' with undefined depot and disables button" do
        @record.status = "started"
        @record.log_file_depot = nil
        error_msg = "Log collection requires the Log Depot settings to be configured"
        expect(disable_button("collect_logs")).to eq(error_msg)
      end

      it "'collecting' with defined depot and enables button" do
        @record.status = "started"
        @record.log_file_depot = file_depot
        expect(disable_button("collect_logs")).to eq(false)
      end
    end

    context "when record class = Zone" do
      let(:log_file) { FactoryGirl.create(:log_file) }
      let(:miq_task) { FactoryGirl.create(:miq_task) }
      let(:file_depot) { FactoryGirl.create(:file_depot) }
      let(:miq_server) { FactoryGirl.create(:miq_server) }

      before do
        @record = FactoryGirl.create(:zone)
      end

      it "'collecting' without any started server and disables button" do
        miq_server.status = "not responding"
        @record.miq_servers << miq_server
        error_msg = "Cannot collect current logs unless there are started Servers in the Zone"
        expect(disable_button("zone_collect_logs")).to eq(error_msg)
      end

      it "log collecting is in progress and disables button" do
        log_file.resource = @record
        log_file.state = "collecting"
        log_file.save
        miq_server.log_files << log_file
        miq_server.status = "started"
        @record.miq_servers << miq_server
        @record.log_file_depot = file_depot
        error_msg = "Log collection is already in progress for one or more Servers in this Zone"
        expect(disable_button("zone_collect_logs")).to eq(error_msg)
      end

      it "log collection in progress with unfinished task and disables button" do
        miq_server.status = "started"
        @record.miq_servers << miq_server
        @record.log_file_depot = file_depot
        miq_task.name = "Zipped log retrieval for XXX"
        miq_task.miq_server_id = miq_server.id
        miq_task.save
        error_msg = "Log collection is already in progress for one or more Servers in this Zone"
        expect(disable_button("zone_collect_logs")).to eq(error_msg)
      end

      it "'collecting' with undefined depot and disables button" do
        miq_server.status = "started"
        @record.miq_servers << miq_server
        @record.log_file_depot = nil
        error_msg = "This Zone do not have Log Depot settings configured, collection not allowed"
        expect(disable_button("zone_collect_logs")).to eq(error_msg)
      end

      it "'collecting' with defined depot and enables button" do
        miq_server.status = "started"
        @record.miq_servers << miq_server
        @record.log_file_depot = file_depot
        expect(disable_button("zone_collect_logs")).to eq(false)
      end
    end

    context "when record class = ServiceTemplate" do
      context "and id = svc_catalog_provision" do
        before do
          @record = ServiceTemplate.new
          @id = "svc_catalog_provision"
        end

        it "no provision dialog is available when action = 'provision'" do
          allow(@record).to receive(:resource_actions).and_return([])
          expect(subject).to eq("No Ordering Dialog is available")
        end

        it "when a provision dialog is available" do
          allow(@record).to receive_messages(:resource_actions => [double(:action => 'Provision', :dialog_id => '10')])
          allow(Dialog).to receive_messages(:find_by_id => 'some thing')
          expect(subject).to be_falsey
        end
      end
    end

    context "when record class = Storage" do
      before { @record = Storage.new }

      context "and id = storage_perf" do
        before do
          @id = "storage_perf"
          allow(@record).to receive_messages(:has_perf_data? => true)
        end
        it_behaves_like 'record without perf data', "No Capacity & Utilization data has been collected for this Datastore"
        it_behaves_like 'default case'
      end

      context "and id = storage_delete" do
        before { @id = "storage_delete" }
        it "when with VMs or Hosts" do
          allow(@record).to receive(:hosts).and_return(%w(h1 h2))
          expect(subject).to eq("Only Datastore without VMs and Hosts can be removed")

          allow(@record).to receive_messages(:hosts => [], :vms_and_templates => ['v1'])
          expect(subject).to eq("Only Datastore without VMs and Hosts can be removed")
        end
        it_behaves_like 'default case'
      end
    end

    context "when record class = Vm" do
      before { @record = Vm.new }

      context "and id = vm_perf" do
        before do
          @id = "vm_perf"
          allow(@record).to receive_messages(:has_perf_data? => true)
        end
        it_behaves_like 'record without perf data', "No Capacity & Utilization data has been collected for this VM"
        it_behaves_like 'default case'
      end

      context "and id = vm_console" do
        before do
          @id = "vm_console"
          allow(@record).to receive_messages(:current_state => 'on')
          setup_firefox_with_linux
        end

        it_behaves_like 'vm not powered on', "The web-based console is not available because the VM is not powered on"
        it_behaves_like 'default case'
      end

      context "and id = vm_vnc_console" do
        before do
          @id = "vm_vnc_console"
          allow(@record).to receive_messages(:current_state => 'on', :ipaddresses => '192.168.1.1')
        end

        it_behaves_like 'vm not powered on', "The web-based VNC console is not available because the VM is not powered on"
        it_behaves_like 'default case'
      end

      context "and id = vm_vmrc_console" do
        before do
          @id = "vm_vmrc_console"
          allow(@record).to receive_messages(:current_state => 'on', :validate_remote_console_vmrc_support => true)
          setup_firefox_with_linux
        end

        it "raise MiqException::RemoteConsoleNotSupportedError when can't get remote console url" do
          allow(@record).to receive(:validate_remote_console_vmrc_support).and_call_original
          expect(subject).to include("VM VMRC Console error")
          expect(subject).to include("VMRC remote console is not supported on")
        end

        it_behaves_like 'vm not powered on', "The web-based console is not available because the VM is not powered on"
      end

      context "and id = storage_scan" do
        before do
          @id = "storage_scan"
          @record = FactoryGirl.create(:storage)
          host = FactoryGirl.create(:host_vmware,
                                    :ext_management_system => FactoryGirl.create(:ems_vmware),
                                    :storages              => [@record])
        end

        it "should be available for vmware storages" do
          expect(subject).to be(false)
        end
      end

      context "and id = storage_scan" do
        before do
          @id = "storage_scan"
          @record = FactoryGirl.create(:storage)
        end

        it "should be not be available for non-vmware storages" do
          expect(subject).to include('cannot be performed on selected')
        end
      end

      context "and id = vm_timeline" do
        before do
          @id = "vm_timeline"
          allow(@record).to receive(:has_events?).and_return(true)
        end
        it_behaves_like 'record without ems events and policy events', 'No Timeline data has been collected for this VM'
        it_behaves_like 'default case'
      end

      context "snapshot buttons" do
        before do
          @record = FactoryGirl.create(:vm_vmware, :vendor => "vmware")
        end

        context "and id = vm_snapshot_add" do
          before do
            @id = "vm_snapshot_add"
            allow(@record).to receive(:is_available?).with(:create_snapshot).and_return(false)
          end

          context "when number of snapshots <= 0" do
            before { allow(@record).to receive(:is_available?).with(:create_snapshot).and_return(false) }
            it_behaves_like 'record with error message', 'create_snapshot'
          end

          context "when number of snapshots > 0" do
            before do
              allow(@record).to receive(:number_of).with(:snapshots).and_return(4)
              allow(@record).to receive(:is_available?).with(:create_snapshot).and_return(false)
            end

            it_behaves_like 'record with error message', 'create_snapshot'

            it "when no available message but active" do
              allow(@record).to receive(:is_available?).with(:create_snapshot).and_return(false)
              @active = true
              expect(subject).to eq("The VM is not connected to a Host")
            end
          end
          it_behaves_like 'default true_case'
        end

        context "and id = vm_snapshot_delete" do
          before { @id = "vm_snapshot_delete" }
          context "when with available message" do
            before { allow(@record).to receive(:is_available?).with(:remove_snapshot).and_return(false) }
            it_behaves_like 'record with error message', 'remove_snapshot'
          end
          context "when without snapshots" do
            before { allow(@record).to receive_message_chain(:snapshots, :size).and_return(0) }
            it_behaves_like 'record with error message', 'remove_snapshot'
          end
          context "when with snapshots" do
            before { allow(@record).to receive_message_chain(:snapshots, :size).and_return(2) }
            it_behaves_like 'record with error message', 'remove_snapshot'
          end
        end

        context "and id = vm_snapshot_delete_all" do
          before { @id = "vm_snapshot_delete_all" }
          context "when with available message" do
            before { allow(@record).to receive(:is_available?).with(:remove_all_snapshots).and_return(false) }
            it_behaves_like 'record with error message', 'remove_all_snapshots'
          end
          context "when without snapshots" do
            before { allow(@record).to receive_message_chain(:snapshots, :size).and_return(0) }
            it_behaves_like 'record with error message', 'remove_all_snapshots'
          end
          context "when with snapshots" do
            before { allow(@record).to receive_message_chain(:snapshots, :size).and_return(2) }
            it_behaves_like 'record with error message', 'remove_all_snapshots'
          end
        end

        context "id = vm_snapshot_revert" do
          before { @id = "vm_snapshot_revert" }
          context "when with available message" do
            before { allow(@record).to receive(:is_available?).with(:revert_to_snapshot).and_return(false) }
            it_behaves_like 'record with error message', 'revert_to_snapshot'
          end
          context "when without snapshots" do
            before { allow(@record).to receive_message_chain(:snapshots, :size).and_return(0) }
            it_behaves_like 'record with error message', 'revert_to_snapshot'
          end
          context "when with snapshots" do
            before { allow(@record).to receive_message_chain(:snapshots, :size).and_return(2) }
            it_behaves_like 'record with error message', 'revert_to_snapshot'
          end
        end
      end

      # This is practically a copy paste from the VMWare tests, wasted lots of time trying ot make shared example but
      # unfortunately it kept failing on travis while passing localy, also causing other tests to fail from totaly
      # diffrent parts of the project. This is not nice but I can't spend more time on trying to figure it out.
      context "RHEV snapshot buttons" do
        before do
          @record = FactoryGirl.create(:vm_redhat, :vendor => "redhat")
        end

        context "and id = vm_snapshot_add" do
          before do
            @id = "vm_snapshot_add"
            allow(@record).to receive(:is_available?).with(:create_snapshot).and_return(false)
          end

          context "when number of snapshots <= 0" do
            before { allow(@record).to receive(:is_available?).with(:create_snapshot).and_return(false) }
            it_behaves_like 'record with error message', 'create_snapshot'
          end

          context "when number of snapshots > 0" do
            before do
              allow(@record).to receive(:number_of).with(:snapshots).and_return(4)
              allow(@record).to receive(:is_available?).with(:create_snapshot).and_return(false)
            end
            it_behaves_like 'record with error message', 'create_snapshot'
            it "when no available message but active" do
              allow(@record).to receive(:is_available?).with(:create_snapshot).and_return(false)
              @active = true
              expect(subject).to eq("Create Snapshot operation not supported for Redhat VM")
            end
          end
          it_behaves_like 'default true_case'
        end
        context "and id = vm_snapshot_delete" do
          before { @id = "vm_snapshot_delete" }
          context "when with available message" do
            before { allow(@record).to receive(:is_available?).with(:remove_snapshot).and_return(false) }
            it_behaves_like 'record with error message', 'remove_snapshot'
          end
          context "when without snapshots" do
            before { allow(@record).to receive_message_chain(:snapshots, :size).and_return(0) }
          end
          context "when with snapshots" do
            before { allow(@record).to receive_message_chain(:snapshots, :size).and_return(2) }
            it_behaves_like 'record with error message', 'remove_snapshot'
          end
        end

        context "and id = vm_snapshot_delete_all" do
          before { @id = "vm_snapshot_delete_all" }
          context "when with available message" do
            before { allow(@record).to receive(:is_available?).with(:remove_all_snapshots).and_return(false) }
            it_behaves_like 'record with error message', 'remove_all_snapshots'
          end
          context "when without snapshots" do
            before { allow(@record).to receive_message_chain(:snapshots, :size).and_return(0) }
            it_behaves_like 'record with error message', 'remove_all_snapshots'
          end
          context "when with snapshots" do
            before { allow(@record).to receive_message_chain(:snapshots, :size).and_return(2) }
            it 'returns error message on trying to remove all snapshots at once' do
              expect(subject).to eq "Removing all snapshots is currently not supported"
            end
          end
        end

        context "id = vm_snapshot_revert" do
          before { @id = "vm_snapshot_revert" }
          context "when with available message" do
            before { allow(@record).to receive(:is_available?).with(:revert_to_snapshot).and_return(false) }
            it_behaves_like 'record with error message', 'revert_to_snapshot'
          end
          context "when without snapshots" do
            before { allow(@record).to receive_message_chain(:snapshots, :size).and_return(0) }
            it_behaves_like 'record with error message', 'revert_to_snapshot'
          end
          context "when with snapshots" do
            before { allow(@record).to receive_message_chain(:snapshots, :size).and_return(2) }
            it_behaves_like 'record with error message', 'revert_to_snapshot'
          end
        end
      end


    end # end of Vm class

    context "Disable Retire button for already retired VMs and Instances" do
      it "button instance_retire_now" do
        @record = FactoryGirl.create(:vm_amazon, :retired => true)
        res = disable_button("instance_retire_now")
        expect(res).to be_truthy
        expect(res).to include("already retired")
      end
    end

    context "and id = miq_request_delete" do
      let(:server) { double("MiqServer", :logon_status => :ready) }
      let(:user)   { FactoryGirl.create(:user_admin) }
      before do
        allow(MiqServer).to receive(:my_server).and_return(server)

        @id = "miq_request_delete"
        login_as user
        @record = MiqProvisionRequest.new
        allow(@record).to receive_messages(:resource_type => "something", :approval_state => "xx", :requester_name => user.name)
      end

      it "and requester.name != @record.requester_name" do
        allow(@record).to receive_messages(:requester_name => 'admin')
        expect(disable_button("miq_request_delete")).to be_falsey
      end

      it "and approval_state = approved" do
        allow(@record).to receive_messages(:approval_state => "approved")
        expect(subject).to be_falsey
      end

      it "and requester.name = @record.requester_name & approval_state != approved|denied" do
        expect(subject).to be_falsey
      end

      it "and requester.name != @record.requester_name" do
        login_as FactoryGirl.create(:user, :role => "test")
        expect(disable_button("miq_request_delete")).to include("Users are only allowed to delete their own requests")
      end
    end
  end # end of disable button

  describe "#hide_button_ops" do
    subject { hide_button_ops(@id) }
    before do
      @record = FactoryGirl.create(:tenant, :parent => Tenant.seed)
      feature = EvmSpecHelper.specific_product_features(%w(ops_rbac rbac_group_add rbac_tenant_add rbac_tenant_delete))
      login_as FactoryGirl.create(:user, :features => feature)
      @sb = {:active_tree => :rbac_tree}
    end

    %w(rbac_group_add rbac_project_add rbac_tenant_add rbac_tenant_delete).each do |id|
      context "when with #{id} button should be visible" do
        before { @id = id }
        it "and record_id" do
          expect(subject).to be_falsey
        end
      end
    end

    %w(rbac_group_edit rbac_role_edit).each do |id|
      context "when with #{id} button should not be visible as user does not have access to these features" do
        before { @id = id }
        it "and record_id" do
          expect(subject).to be_truthy
        end
      end
    end
  end

  describe "#get_record_cls"  do
    subject { get_record_cls(record) }
    context "when record not exist" do
      let(:record) { nil }
      it { is_expected.to eq("NilClass") }
    end

    context "when record is array" do
      let(:record) { ["some", "thing"] }
      it { is_expected.to eq(record.class.name) }
    end

    context "when record is valid" do
      [ManageIQ::Providers::Redhat::InfraManager::Host].each do |c|
        it "and with #{c}" do
          record = c.new
          expect(get_record_cls(record)).to eq(record.class.base_class.to_s)
        end
      end

      it "and with 'VmOrTemplate'" do
        record = ManageIQ::Providers::Vmware::InfraManager::Template.new
        expect(get_record_cls(record)).to eq(record.class.base_model.to_s)
      end

      it "otherwise" do
        record = Job.new
        expect(get_record_cls(record)).to eq(record.class.to_s)
      end
    end
  end

  describe "#twostate_button_selected" do
    before do
      @gtl_type = 'list'
      @settings = {
        :views => {
          :compare      => 'compressed',
          :drift        => 'compressed',
          :compare_mode => 'exists',
          :drift_mode   => 'exists',
          :treesize     => '32'
        }
      }
    end
    subject { twostate_button_selected(id) }

    ['list', 'tile', 'grid'].each do |g|
      it "when with view_#{g}" do
        @gtl_type = g
        expect(twostate_button_selected("view_#{g}")).to be_truthy
      end
    end

    it "when with tree_large" do
      @settings[:views][:treesize] = 32
      expect(twostate_button_selected("tree_large")).to be_truthy
    end

    it "when with tree_small" do
      @settings[:views][:treesize] = 16
      expect(twostate_button_selected("tree_small")).to be_truthy
    end

    context  "when with 'compare_compressed'" do
      let(:id) { "compare_compressed" }
      it { is_expected.to be_truthy }
    end

    context  "when with 'drift_compressed'" do
      let(:id) { "drift_compressed" }
      it { is_expected.to be_truthy }
    end

    context  "when with 'compare_all'" do
      let(:id) { "compare_all" }
      it { is_expected.to be_truthy }
    end

    context  "when with 'drift_all'" do
      let(:id) { "drift_all" }
      it { is_expected.to be_truthy }
    end

    context  "when with 'comparemode_exists" do
      let(:id) { "comparemode_exists" }
      it { is_expected.to be_truthy }
    end

    context  "when with 'driftmode_exists" do
      let(:id) { "driftmode_exists" }
      it { is_expected.to be_truthy }
    end
  end

  describe "#apply_common_props" do
    before do
      @record = double(:id => 'record_id_xxx_001', :class => double(:name => 'record_xxx_class'))
      btn_num = "x_button_id_001"
      desc = 'the description for the button'
      @input = {:url       => "button",
                :url_parms => "?id=#{@record.id}&button_id=#{btn_num}&cls=#{@record.class.name}&pressed=custom_button&desc=#{desc}"
      }
      @tb_buttons = {}
      @button = {:id => "custom_#{btn_num}"}
      @button = ApplicationHelper::Button::Basic.new(nil, nil, {}, {:id => "custom_#{btn_num}"})
      allow_any_instance_of(Object).to receive(:query_string).and_return("")
      allow_message_expectations_on_nil
    end

    context "button visibility" do
      it "defaults to hidden false" do
        props = apply_common_props(@button, @input)
        expect(props[:hidden]).to be(false)
      end

      it "honors explicit input's hidden properties" do
        props = apply_common_props(@button, {:hidden => true})
        expect(props[:hidden]).to be(true)
      end
    end

    context "saves the item info by the same key" do
      subject do
        apply_common_props(@button, @input)
      end

      it "when input[:hidden] exists" do
        @input[:hidden] = 1
        expect(subject).to have_key(:hidden)
      end

      it "when input[:url_parms] exists" do
        expect(subject).to have_key(:url_parms)
      end

      it "when input[:confirm] exists" do
        @input[:confirm] = 'Are you sure?'
        expect(subject).to have_key(:confirm)
      end

      it "when input[:onwhen] exists" do
        @input[:onwhen] = '1+'
        expect(subject).to have_key(:onwhen)
      end
    end

    context "internationalization" do
      it "does translation of text title and confirm strings" do
        %i(text title confirm).each do |key|
          @input[key] = 'Configuration' # common button string, translated into Japanese
        end
        FastGettext.locale = 'ja'
        apply_common_props(@button, @input)
        %i(text title confirm).each do |key|
          expect(@button[key]).not_to match('Configuration')
        end
        FastGettext.locale = 'en'
      end

      it "does delayed translation of text title and confirm strings" do
        %i(text title confirm).each do |key|
          @input[key] = proc do
            _("Add New %{model}") % {:model => 'Model'}
          end
        end
        FastGettext.locale = 'ja'
        apply_common_props(@button, @input)
        %i(text title confirm).each do |key|
          expect(@button[key]).not_to match('Add New Model')
        end
        FastGettext.locale = 'en'
      end
    end
  end

  describe "#update_common_props" do
    before do
      @record = double(:id => 'record_id_xxx_001', :class => 'record_xxx_class')
      btn_num = "x_button_id_001"
      desc = 'the description for the button'
      @item = {:button    => "custom_#{btn_num}",
               :url       => "button",
               :url_parms => "?id=#{@record.id}&button_id=#{btn_num}&cls=#{@record.class}&pressed=custom_button&desc=#{desc}"
      }
      @tb_buttons = {}
      @item_out = {}
      allow_any_instance_of(Object).to receive(:query_string).and_return("")
      allow_message_expectations_on_nil
    end

    context "when item[:url] exists" do
      subject do
        update_common_props(@item, @item_out)
      end

      it "saves the value as it is otherwise" do
        expect(subject).to have_key(:url)
      end

      it "calls url_for_button" do
        b = _toolbar_builder
        expect(b).to receive(:url_for_button).and_call_original
        b.send(:update_common_props, @item, @item_out)
      end
    end
  end

  describe "url_for_button" do
    context "when restful routes" do
      before do
        allow(controller).to receive(:restful?) { true }
      end

      it "returns / when button is 'view_grid', 'view_tile' or 'view_list'" do
        result = url_for_button('view_list', '/1r2?', true)
        expect(result).to eq('/')
      end

      it "supports compressed ids" do
        result = url_for_button('view_list', '/1?', true)
        expect(result).to eq('/')
      end
    end
  end

  describe "update_url_parms", :type => :request do
    before do
      MiqServer.seed
    end

    context "when the given parameter exists in the request query string" do
      before do
        get "/vm/show_list/100", :params => "type=grid"
        allow_any_instance_of(Object).to receive(:query_string).and_return(@request.query_string)
        allow_any_instance_of(Object).to receive(:path_info).and_return(@request.path_info)
        allow_message_expectations_on_nil
      end

      it "updates the query string with the given parameter value" do
        expect(update_url_parms("?type=list")).to eq("?type=list")
      end
    end

    context "when the given parameters do not exist in the request query string" do
      before do
        get "/vm/show_list/100"
        allow_any_instance_of(Object).to receive(:query_string).and_return(@request.query_string)
        allow_any_instance_of(Object).to receive(:path_info).and_return(@request.path_info)
        allow_message_expectations_on_nil
      end

      it "adds the params in the query string" do
        expect(update_url_parms("?refresh=y&type=list")).to eq("?refresh=y&type=list")
      end
    end

    context "when the request query string has a few specific params to be retained" do
      before do
        get "/vm/show_list/100",
            :params => "bc=VMs+running+on+2014-08-25&menu_click=Display-VMs-on_2-6-5&sb_controller=host"
        allow_any_instance_of(Object).to receive(:query_string).and_return(@request.query_string)
        allow_any_instance_of(Object).to receive(:path_info).and_return(@request.path_info)
        allow_message_expectations_on_nil
      end

      it "retains the specific parameters and adds the new one" do
        expect(update_url_parms("?type=list")).to eq("?bc=VMs+running+on+2014-08-25&menu_click=Display-VMs-on_2-6-5"\
          "&sb_controller=host&type=list")
      end
    end

    context "when the request query string has a few specific params to be excluded" do
      before do
        get "/vm/show_list/100", :params => "page=1"
        allow_any_instance_of(Object).to receive(:query_string).and_return(@request.query_string)
        allow_any_instance_of(Object).to receive(:path_info).and_return(@request.path_info)
        allow_message_expectations_on_nil
      end

      it "excludes specific parameters and adds the new one" do
        expect(update_url_parms("?type=list")).to eq("?type=list")
      end
    end
  end

  context "toolbar_class" do
    before do
      controller.instance_variable_set(:@sb, :active_tree => :foo_tree)
      @pdf_button = {:id        => "download_choice__download_pdf",
                     :child_id  => "download_pdf",
                     :type      => :button,
                     :img       => "download_pdf.png",
                     :imgdis    => "download_pdf.png",
                     :img_url   => ActionController::Base.helpers.image_path("toolbars/download_pdf.png"),
                     :icon      => "fa fa-file-pdf-o fa-lg",
                     :text      => "Download as PDF",
                     :title     => "Download this report in PDF format",
                     :name      => "download_choice__download_pdf",
                     :hidden    => false,
                     :pressed   => nil,
                     :onwhen    => nil,
                     :enabled   => true,
                     :url       => "/download_data",
                     :url_parms => "?download_type=pdf",
                     :data      => nil}
      @layout = "catalogs"
      stub_user(:features => :all)
      allow(helper).to receive(:x_active_tree).and_return(:ot_tree)
    end

    it "Hides PDF button when PdfGenerator is not available" do
      allow(PdfGenerator).to receive_messages(:available? => false)
      buttons = helper.build_toolbar('gtl_view_tb').collect { |button| button[:items] if button[:id] == "download_choice" }.compact.flatten
      expect(buttons).not_to include(@pdf_button)
    end

    it "Displays PDF button when PdfGenerator is available" do
      allow(PdfGenerator).to receive_messages(:available? => true)
      buttons = helper.build_toolbar('gtl_view_tb').collect { |button| button[:items] if button[:id] == "download_choice" }.compact.flatten
      expect(buttons).to include(@pdf_button)
    end

    it "Enables edit and remove buttons for read-write orchestration templates" do
      @record = FactoryGirl.create(:orchestration_template)
      buttons = helper.build_toolbar('orchestration_template_center_tb').first[:items]
      edit_btn = buttons.find { |b| b[:id].end_with?("_edit") }
      remove_btn = buttons.find { |b| b[:id].end_with?("_remove") }
      expect(edit_btn[:enabled]).to eq(true)
      expect(remove_btn[:enabled]).to eq(true)
    end

    it "Disables edit and remove buttons for read-only orchestration templates" do
      @record = FactoryGirl.create(:orchestration_template_with_stacks)
      buttons = helper.build_toolbar('orchestration_template_center_tb').first[:items]
      edit_btn = buttons.find { |b| b[:id].end_with?("_edit") }
      remove_btn = buttons.find { |b| b[:id].end_with?("_remove") }
      expect(edit_btn[:enabled]).to eq(false)
      expect(remove_btn[:enabled]).to eq(false)
    end
  end

  describe "#build_toolbar" do
    context "when the toolbar to be built is a blank view" do
      let(:toolbar_to_build) { 'blank_view_tb' }

      it "returns nil" do
        expect(_toolbar_builder.build_toolbar(toolbar_to_build)).to be_nil
      end
    end

    context "when the toolbar to be built is a generic object toolbar" do
      let(:toolbar_to_build) { 'generic_object_definition_tb' }

      before do
        allow(Rbac).to receive(:role_allows?).and_return(true)
      end

      it "includes the button group" do
        expect(_toolbar_builder.build_toolbar(toolbar_to_build).first).to include(
          :id    => "generic_object_definition_choice",
          :type  => :buttonSelect,
          :icon  => "fa fa-cog fa-lg",
          :title => "Configuration",
          :text  => "Configuration"
        )
      end

      it "includes the correct button items" do
        expect(_toolbar_builder.build_toolbar(toolbar_to_build).first[:items].first).to include(
          :id    => "generic_object_definition_choice__generic_object_definition_create",
          :type  => :button,
          :icon  => "pficon pficon-add-circle-o fa-lg",
          :title => "Create a new Generic Object Definition",
          :text  => "Create a new Generic Object Definition",
          :data  => {
            'function'      => 'sendDataWithRx',
            'function-data' => '{"eventType": "showAddForm"}'
          }
        )
      end
    end
  end
end
