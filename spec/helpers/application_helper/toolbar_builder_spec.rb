require "spec_helper"

describe ApplicationHelper do
  before do
    controller.send(:extend, ApplicationHelper)
    controller.send(:extend, ApplicationController::CurrentUser)
    self.class.send(:include, ApplicationHelper)
    self.class.send(:include, ApplicationController::CurrentUser)
  end

  def self.hide_action(*_args)
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
    before(:each) do
      @user = FactoryGirl.create(:user, :role => "super_administrator")
    end

    context "when record is VM" do
      before(:each) do
        @record = FactoryGirl.create(:vm_vmware)
      end

      context "and it has no custom buttons" do
        it "#get_custom_buttons" do
          get_custom_buttons(@record).should == []
        end

        it "#custom_buttons_hash" do
          custom_buttons_hash(@record).should == []
        end

        it "#build_custom_buttons_toolbar" do
          build_custom_buttons_toolbar(@record).should == {:button_groups => []}
        end

        it "#record_to_service_buttons" do
          record_to_service_buttons(@record).should == []
        end
      end

      context "and it has custom buttons" do
        before(:each) do
          @set_data = {:applies_to_class => 'Vm'}
          @button_set = FactoryGirl.create(:custom_button_set, :set_data => @set_data)
          login_as @user
          @button1 = FactoryGirl.create(:custom_button, :applies_to_class => 'Vm', :visibility => {:roles => ["_ALL_"]}, :options => {})
          @button_set.add_member @button1
          @button_set.save!
          @button1.save!
        end

        it "#get_custom_buttons" do
          expected_button1 = {
            :id            => @button1.id,
            :class         => @button1.applies_to_class,
            :name          => @button1.name,
            :description   => @button1.description,
            :image         => @button1.options[:button_image],
            :text_display  => @button1.options.key?(:display) ? @button1.options[:display] : true,
            :target_object => @record.id
          }
          expected_button_set = {
            :id           => @button_set.id,
            :text         => @button_set.name,
            :description  => @button_set.description,
            :image        => @button_set.set_data[:button_image],
            :text_display => @button_set.set_data.key?(:display) ? @button_set.set_data[:display] : true,
            :buttons      => [expected_button1]
          }

          get_custom_buttons(@record).should == [expected_button_set]
        end

        it "#record_to_service_buttons" do
          record_to_service_buttons(@record).should == []
        end

        it "#custom_buttons_hash" do
          escaped_button1_text = CGI.escapeHTML(@button1.name.to_s)
          button1 = {
            :button    => "custom__custom_#{@button1.id}",
            :image     => "custom-#{@button1.options[:button_image]}",
            :title     => CGI.escapeHTML(@button1.description.to_s),
            :text      => escaped_button1_text,
            :enabled   => "true",
            :url       => "button",
            :url_parms => "?id=#{@record.id}&button_id=#{@button1.id}&cls=#{@record.class.name}&pressed=custom_button&desc=#{escaped_button1_text}"
          }
          button_set_item1_items = [button1]
          button_set_item1 = {
            :buttonSelect => "custom_#{@button_set.id}",
            :image        => "custom-#{@button_set.set_data[:button_image]}",
            :title        => @button_set.description,
            :text         => @button_set.name,
            :enabled      => "true",
            :items        => button_set_item1_items
          }
          items = [button_set_item1]
          name = "custom_buttons_#{@button_set.name}"
          custom_buttons_hash(@record).should == [:name => name, :items => items]
        end

        it "#build_custom_buttons_toolbar" do
          escaped_button1_text = CGI.escapeHTML(@button1.name.to_s)
          button1 = {
            :button    => "custom__custom_#{@button1.id}",
            :image     => "custom-#{@button1.options[:button_image]}",
            :title     => CGI.escapeHTML(@button1.description.to_s),
            :text      => escaped_button1_text,
            :enabled   => "true",
            :url       => "button",
            :url_parms => "?id=#{@record.id}&button_id=#{@button1.id}&cls=#{@record.class.name}&pressed=custom_button&desc=#{escaped_button1_text}"
          }
          button_set_item1_items = [button1]
          button_set_item1 = {
            :buttonSelect => "custom_#{@button_set.id}",
            :image        => "custom-#{@button_set.set_data[:button_image]}",
            :title        => @button_set.description,
            :text         => @button_set.name,
            :enabled      => "true",
            :items        => button_set_item1_items
          }
          button_set1_header = {
            :name  => "custom_buttons_#{@button_set.name}",
            :items => [button_set_item1]
          }
          button_groups = [button_set1_header]
          build_custom_buttons_toolbar(@record).should == {:button_groups => button_groups}
        end
      end
    end

    context "when record is Service" do
      before(:each) do
        @service_template = FactoryGirl.create(:service_template)
        @record = FactoryGirl.create(:service, :service_template => @service_template)
      end

      context "and it has no custom buttons" do
        it "#get_custom_buttons" do
          get_custom_buttons(@record).should == []
        end

        it "#custom_buttons_hash" do
          custom_buttons_hash(@record).should == []
        end

        it "#build_custom_buttons_toolbar" do
          build_custom_buttons_toolbar(@record).should == {:button_groups => []}
        end

        it "#record_to_service_buttons" do
          record_to_service_buttons(@record).should == []
        end
      end

      context "and it has custom buttons" do
        before(:each) do
          @set_data = {:applies_to_class => 'ServiceTemplate', :applies_to_id => @service_template.id}
          @button_set = FactoryGirl.create(:custom_button_set, :set_data => @set_data)
          login_as @user
          @button1 = FactoryGirl.create(:custom_button, :applies_to_class => 'ServiceTemplate', :visibility => {:roles => ["_ALL_"]}, :options => {})
          @button_set.add_member @button1
          @button_set.save!
          @button1.save!
        end

        it "#custom_buttons_hash" do
          escaped_button1_text = CGI.escapeHTML(@button1.name.to_s)
          button1 = {
            :button    => "custom__custom_#{@button1.id}",
            :image     => "custom-#{@button1.options[:button_image]}",
            :title     => CGI.escapeHTML(@button1.description.to_s),
            :text      => escaped_button1_text,
            :enabled   => "true",
            :url       => "button",
            :url_parms => "?id=#{@record.id}&button_id=#{@button1.id}&cls=#{@record.class.name}&pressed=custom_button&desc=#{escaped_button1_text}"
          }
          button_set_item1_items = [button1]
          button_set_item1 = {
            :buttonSelect => "custom_#{@button_set.id}",
            :image        => "custom-#{@button_set.set_data[:button_image]}",
            :title        => @button_set.description,
            :text         => @button_set.name,
            :enabled      => "true",
            :items        => button_set_item1_items
          }
          items = [button_set_item1]
          name = "custom_buttons_#{@button_set.name}"
          custom_buttons_hash(@record).should == [:name => name, :items => items]
        end

        it "#build_custom_buttons_toolbar" do
          escaped_button1_text = CGI.escapeHTML(@button1.name.to_s)
          button1 = {
            :button    => "custom__custom_#{@button1.id}",
            :image     => "custom-#{@button1.options[:button_image]}",
            :title     => CGI.escapeHTML(@button1.description.to_s),
            :text      => escaped_button1_text,
            :enabled   => "true",
            :url       => "button",
            :url_parms => "?id=#{@record.id}&button_id=#{@button1.id}&cls=#{@record.class.name}&pressed=custom_button&desc=#{escaped_button1_text}"
          }
          button_set_item1_items = [button1]
          button_set_item1 = {
            :buttonSelect => "custom_#{@button_set.id}",
            :image        => "custom-#{@button_set.set_data[:button_image]}",
            :title        => @button_set.description,
            :text         => @button_set.name,
            :enabled      => "true",
            :items        => button_set_item1_items
          }
          button_set1_header = {
            :name  => "custom_buttons_#{@button_set.name}",
            :items => [button_set_item1]
          }
          button_groups = [button_set1_header]
          build_custom_buttons_toolbar(@record).should == {:button_groups => button_groups}

          @button2 = FactoryGirl.create(:custom_button, :applies_to_class => 'ServiceTemplate', :applies_to_id => @service_template.id, :visibility => {:roles => ["_ALL_"]}, :options => {})

          escaped_button2_text = CGI.escapeHTML(@button2.name.to_s)
          expected_button2 = {
            :button    => "custom__custom_#{@button2.id}",
            :image     => "custom-#{@button2.options[:button_image]}",
            :title     => CGI.escapeHTML(@button2.description.to_s),
            :text      => escaped_button2_text,
            :enabled   => nil,
            :url       => "button",
            :url_parms => "?id=#{@record.id}&button_id=#{@button2.id}&cls=#{@record.class.name}&pressed=custom_button&desc=#{escaped_button2_text}"
          }
          button_set2_header = {
            :name  => "custom_buttons_",
            :items => [expected_button2]
          }
          button_groups = [button_set1_header, button_set2_header]
          build_custom_buttons_toolbar(@record).should == {:button_groups => button_groups}
        end

        it "#get_custom_buttons" do
          expected_button1 = {
            :id            => @button1.id,
            :class         => @button1.applies_to_class,
            :name          => @button1.name,
            :description   => @button1.description,
            :image         => @button1.options[:button_image],
            :text_display  => @button1.options.key?(:display) ? @button1.options[:display] : true,
            :target_object => @record.id
          }
          expected_buttons = [expected_button1]
          expected_button_set = {
            :id           => @button_set.id,
            :text         => @button_set.name,
            :description  => @button_set.description,
            :image        => @button_set.set_data[:button_image],
            :text_display => @button_set.set_data.key?(:display) ? @button_set.set_data[:display] : true,
            :buttons      => [expected_button1]
          }

          get_custom_buttons(@record).should == [expected_button_set]

          button2 = FactoryGirl.create(:custom_button, :applies_to_class => 'ServiceTemplate', :applies_to_id => @service_template.id, :visibility => {:roles => ["_ALL_"]}, :options => {})

          get_custom_buttons(@record).should == [expected_button_set]
        end
      end

      it "#record_to_service_buttons" do
        record_to_service_buttons(@record).should == []
        button2 = FactoryGirl.create(:custom_button, :applies_to_class => 'ServiceTemplate', :applies_to_id => @service_template.id, :visibility => {:roles => ["_ALL_"]}, :options => {})
        expected_button2 = {
          :id            => button2.id,
          :class         => button2.applies_to_class,
          :name          => button2.name,
          :description   => button2.description,
          :image         => button2.options[:button_image],
          :text_display  => button2.options.key?(:display) ? button2.options[:display] : true,
          :target_object => @record.id
        }
        record_to_service_buttons(@record).should == [expected_button2]
      end
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
        subject.should == "summary-green"
      end

      it "and layout is miq_schedule" do
        @layout = "miq_schedule"
        subject.should == "summary-green"
      end

      it "and layout is miq_proxy" do
        @layout = "miq_schedule"
        subject.should == "summary-green"
      end

      it "otherwise" do
        @layout = "some_thing"
        subject.should == @img
      end
    end

    it "when not with show_summary" do
      @button_name = "summary_reload"
      @img = "reload"
      subject.should == @img
    end
  end # get_image

  describe "#build_toolbar_hide_button" do
    subject { build_toolbar_hide_button(@id) }
    before do
      @user = FactoryGirl.create(:user)
      @record = double("record")
      login_as @user
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

    def setup_x_tree_history
      @sb = {:history     => {:testing => %w(some thing to test with)},
             :active_tree => :testing}
    end

    %w(
      view_grid
      view_tile
      view_list
      download_text
      download_csv
      download_pdf
      download_view
      vm_download_pdf
      refresh_log
      fetch_log
    ).each do |item|
      it "when with #{item}" do
        @id = item
        subject.should be_false
      end
    end

    it "when with show_summary and not explorer" do
      @id = "show_summary"
      @explorer = false
      subject.should be_false
    end

    it "when with show_summary and explorer" do
      @id = "show_summary"
      @explorer = true
      subject.should be_true
    end

    it "when with history_1" do
      setup_x_tree_history
      @id = "history_1"
      subject.should be_false
    end

    %w(0 1 2 3 4).each do |n|
      it "when with existing history_#{n}" do
        setup_x_tree_history
        @id = "history_#{n}"
        subject.should be_false
      end
    end

    it "when not history_1 and the tree history not exist" do
      setup_x_tree_history
      @id = "history_10"
      subject.should be_true
    end

    it "when id likes old_dialogs_*" do
      @id = "old_dialogs_some_thing"
      subject.should be_true
    end

    it "when id likes ab_*" do
      @id = "ab_some_thing"
      subject.should be_true
    end

    context "when with button_add" do
      before { @id = "button_add" }
      it "and no record_id" do
        @edit = {:rec_id => nil}
        subject.should be_false
      end

      it "and record_id" do
        @edit = {:rec_id => "record id"}
        subject.should be_true
      end
    end

    ["button_save", "button_reset"].each do |id|
      context "when with #{id}" do
        before { @id = id }
        it "and record_id" do
          @edit = {:rec_id => "record id"}
          subject.should be_false
        end

        it "and no record_id" do
          @edit = {:rec_id => nil}
          subject.should be_true
        end
      end
    end

    it "when with button_cancel" do
      @id = "button_cancel"
      subject.should be_false
    end

    ["miq_task_", "compare_", "drift_", "comparemode_", "driftmode_", "custom_"].each do |i|
      it "when id likes #{i}*" do
        @id = "#{i}some_thing"
        subject.should be_false
      end
    end

    context "when with miq_request_reload" do
      before { @id = "miq_request_reload" }
      it "and lastaction is show_list" do
        @lastaction = "show_list"
        subject.should be_false
      end

      it "and lastaction is not show_list" do
        @lastaction = "log"
        subject.should be_true
      end
    end

    context "when with miq_request_reload" do
      before { @id = "miq_request_reload" }
      it "and showtype is miq_provisions" do
        @showtype = "miq_provisions"
        subject.should be_false
      end

      it "and showtype is not miq_provisions" do
        @showtype = "compare"
        subject.should be_true
      end
    end

    context "when with miq_request_approve" do
      before { @id = "miq_request_approve" }
      it "and miq_request_approval feature is not allowed" do
        subject.should be_true
      end

      it "and miq_request_approval feature is allowed" do
        @user.stub(:role_allows?).and_return(true)
        subject.should be_false
      end
    end

    context "when with miq_request_deny" do
      before { @id = "miq_request_deny" }
      it "and miq_request_approval feature is not allowed" do
        subject.should be_true
      end

      it "and miq_request_approval feature is allowed" do
        @user.stub(:role_allows?).and_return(true)
        subject.should be_false
      end
    end

    it "when id likes dialog_*" do
      @id = "dialog_some_thing"
      subject.should be_false
    end

    it "when with miq_request_approve and allowed by the role" do
      @id = "miq_request_approve"
      # when the role allows the feature
      @user.stub(:role_allows?).and_return(true)
      subject.should be_false
    end

    it "when with miq_request_deny and allowed by the role" do
      @id = "miq_request_deny"
      # when the role allows the feature
      @user.stub(:role_allows?).and_return(true)
      subject.should be_false
    end

    it "when not with miq_request_approve or miq_request_deny and not allowed by the role" do
      @id = "miq_request_edit"
      subject.should be_true
    end

    ["ems_cluster_protect", "ext_management_system_protect",
     "host_analyze_check_compliance", "host_check_compliance", "host_protect",
     "host_shutdown", "host_reboot", "host_standby",
     "host_enter_maint_mode", "host_exit_maint_mode",
     "host_start", "host_stop", "host_reset",
     "repo_protect",
     "resource_pool_protect",
     "vm_check_compliance",
     "vm_guest_startup",
     "vm_guest_shutdown",
     "vm_guest_standby",
     "vm_guest_restart",
     "vm_policy_sim",
     "vm_protect",
     "vm_start",
     "vm_stop",
     "vm_suspend",
     "vm_reset",
     "vm_retire",
     "vm_retire_now",
     "vm_snapshot_add",
     "vm_snapshot_delete",
     "vm_snapshot_delete_all",
     "vm_snapshot_revert"].each do |id|
      it "when with #{id}" do
        @id = id
        @user.stub(:role_allows?).and_return(true)
        subject.should be_false
      end
    end

    context "when with dialog_add_box" do
      before do
        @id = 'dialog_add_box'
        @edit = {:some => 'thing'}
      end

      it "and !@edit" do
        @edit = nil
        subject.should be_true
      end

      it "and nodes < 2" do
        @sb = {:trees       => {:svcs_tree => {:active_node => 'root'}},
               :active_tree => :svcs_tree}
        subject.should be_true

        @sb = {:trees       => {:svcs_tree => {:active_node => ''}},
               :active_tree => :svcs_tree}
        subject.should be_true
      end

      it "and 2 nodes" do
        @sb = {:trees       => {:svcs_tree => {:active_node => 'some_thing'}},
               :active_tree => :svcs_tree}
        subject.should be_false
      end

      it "and 3 nodes" do
        @sb = {:trees       => {:svcs_tree => {:active_node => 'something_to_test'}},
               :active_tree => :svcs_tree}
        subject.should be_false
      end

      it "and nodes > 3" do
        @sb = {:trees       => {:svcs_tree => {:active_node => 'some_thing_to_test'}},
               :active_tree => :svcs_tree}
        subject.should be_true
      end
    end

    context "when with dialog_add_element" do
      before do
        @id = "dialog_add_element"
        @edit = {:some => 'thing'}
      end

      it "and !@edit" do
        @edit = nil
        subject.should be_true
      end

      it "and nodes < 3" do
        @sb = {:trees       => {:svcs_tree => {:active_node => 'some_thing'}},
               :active_tree => :svcs_tree}
        subject.should be_true

        @sb = {:trees       => {:svcs_tree => {:active_node => ''}},
               :active_tree => :svcs_tree}
        subject.should be_true
      end

      it "and 3 nodes" do
        @sb = {:trees       => {:svcs_tree => {:active_node => 'something_to_test'}},
               :active_tree => :svcs_tree}
        subject.should be_false
      end

      it "and 4 nodes" do
        @sb = {:trees       => {:svcs_tree => {:active_node => 'some_thing_to_test'}},
               :active_tree => :svcs_tree}
        subject.should be_false
      end

      it "and nodes > 4" do
        @sb = {:trees       => {:svcs_tree => {:active_node => 'some_thing_to_test_with'}},
               :active_tree => :svcs_tree}
        subject.should be_true
      end
    end

    context "when with dialog_add_tab" do
      before do
        @id = "dialog_add_tab"
        @edit = {:some => 'thing'}
      end

      it "and !@edit" do
        @edit = nil
        subject.should be_true
      end

      it "and nodes <= 2" do
        @sb = {:trees       => {:svcs_tree => {:active_node => 'some_thing'}},
               :active_tree => :svcs_tree}
        subject.should be_false

        @sb = {:trees       => {:svcs_tree => {:active_node => 'something'}},
               :active_tree => :svcs_tree}
        subject.should be_false

        @sb = {:trees       => {:svcs_tree => {:active_node => ''}},
               :active_tree => :svcs_tree}
        subject.should be_false
      end

      it "and nodes > 2" do
        @sb = {:trees       => {:svcs_tree => {:active_node => 'something_to_test'}},
               :active_tree => :svcs_tree}
        subject.should be_true
      end
    end

    context "when with dialog_res_discard" do
      before do
        @id = "dialog_res_discard"
        @edit = {:some => 'thing'}
      end

      it "and !@edit" do
        @edit = nil
        subject.should be_true
      end

      it "and @sb[:edit_typ] != 'add'" do
        @sb = {:edit_typ => "something"}
        subject.should be_true
      end

      it "and @sb[:edit_typ] = 'add'" do
        # @sb[:trees][@sb[:active_tree]][:active_node] is required to pass the test.
        @sb = {:trees       => {:svcs_tree => {:active_node => 'something_to_test'}},
               :active_tree => :svcs_tree,
               :edit_typ    => 'add'}

        subject.should be_false
      end
    end

    context "when with dialog_resource_remove" do
      before do
        @id = "dialog_resource_remove"
        @edit = {:some => 'thing'}
        @sb = {:trees       => {:svcs_tree => {:active_node => 'something_to_test'}},
               :active_tree => :svcs_tree}
      end

      it "and !@edit" do
        @edit = nil
        subject.should be_true
      end

      it "and @sb[:edit_typ] = 'add'" do
        @sb[:edit_typ] = 'add'
        subject.should be_true
      end

      it "and @sb[:edit_typ] != 'add'" do
        subject.should be_false
      end

      it "and active_node = 'root'" do
        @sb = {:trees       => {:svcs_tree => {:active_node => 'root'}},
               :active_tree => :svcs_tree}
        subject.should be_true
      end

      it "and active_node != 'root'" do
        subject.should be_false
      end
    end

    ["dialog_copy", "dialog_delete", "dialog_edit", "dialog_new"].each do |id|
      context "when with #{id}" do
        before do
          @id = id
          @edit = nil
        end

        it "and @edit" do
          @edit = {:rec_id => "record id", :current => {}}
          subject.should be_true
        end

        it "and !@edit" do
          subject.should be_false
        end
      end
    end

    ["host_miq_request_new", "vm_miq_request_new", "vm_clone", "vm_publish", "vm_pre_prov"].each do |id|
      it "when with #{id}" do
        @id = id
        @user.stub(:role_allows?).and_return(true)
        subject.should be_false
      end
    end

    context "when with miq_task_canceljob" do
      before do
        @id = 'miq_task_canceljob'
        @user.stub(:role_allows?).and_return(true)
      end

      it "and @layout != all_tasks" do
        @layout = "x_tasks"
        subject.should == true
      end

      it "and @layout != all_ui_tasks" do
        @layout = "x_ui_tasks"
        subject.should == true
      end

      it "and @layout = all_tasks" do
        @layout = "all_tasks"
        subject.should == false
      end

      it "and @layout = all_ui_tasks" do
        @layout = "all_ui_tasks"
        subject.should == false
      end
    end

    context "when with vm_console" do
      before do
        @id = "vm_console"
        @user.stub(:role_allows?).and_return(true)
        @record.stub(:console_supported? => false)
      end

      it "and record is not console supported" do
        subject.should be_true
      end

      it "and server's remote_console_type not set" do
        @vmdb_config = {:server => nil}
        subject.should be_true
      end

      it "and server's remote_console_type is not MKS" do
        @vmdb_config = {:server => {:remote_console_type => "not_MKS"}}
        subject.should be_true
      end

      it "and record is console supported and server's remote_console_type is MKS" do
        @record.stub(:console_supported? => true)
        @vmdb_config = {:server => {:remote_console_type => "MKS"}}
        subject.should be_false
      end
    end

    context "when with vm_vnc_console" do
      before do
        @id = "vm_vnc_console"
        @user.stub(:role_allows?).and_return(true)
        @record.stub(:console_supported? => false)
      end

      it "and record is not console supported" do
        subject.should == true
      end

      it "and server's remote_console_type not set" do
        @vmdb_config = {:server => nil}
        subject.should == true
      end

      it "and server's remote_console_type is not VNC" do
        @vmdb_config = {:server => {:remote_console_type => "not_VNC"}}
        subject.should == true
      end

      it "and record is console supported and server's remote_console_type is VNC" do
        @record.stub(:console_supported? => true)
        @vmdb_config = {:server => {:remote_console_type => "VNC"}}
        subject.should == false
      end
    end

    context "when with vm_vmrc_console" do
      before do
        @id = "vm_vmrc_console"
        @user.stub(:role_allows?).and_return(true)
        @record.stub(:console_supported? => false)
      end

      it "and record is not console supported" do
        subject.should == true
      end

      it "and server's remote_console_type not set" do
        @vmdb_config = {:server => nil}
        subject.should == true
      end

      it "and server's remote_console_type is not VMRC" do
        @vmdb_config = {:server => {:remote_console_type => "not_VMRC"}}
        subject.should == true
      end

      it "and record is console supported and server's remote_console_type is VMRC" do
        @record.stub(:console_supported? => true)
        @vmdb_config = {:server => {:remote_console_type => "VMRC"}}
        subject.should == false
      end
    end

    ["ontap_storage_system_statistics", "ontap_logical_disk_statistics", "ontap_storage_volume_statistics", "ontap_file_share_statistics"].each do |id|
      context "when with #{id}" do
        before do
          @id = id
          @user.stub(:role_allows?).and_return(true)
        end

        it "and @vmdb_config[:product][:smis] != true " do
          @vmdb_config = {:product => {:smis => false}}
          subject.should == true
        end

        it "and @vmdb_config[:product][:smis] = true " do
          @vmdb_config = {:product => {:smis => true}}
          subject.should == false
        end
      end
    end

    context "when with AssignedServerRole" do
      before do
        @record = AssignedServerRole.new
        @user.stub(:role_allows?).and_return(true)
      end

      it "and id = delete_server" do
        @id = "delete_server"
        subject.should == true
      end

      it "and id != server_delete" do
        @id = "server_add"
        subject.should == false
      end
    end

    context "when with EmsCluster" do
      before do
        @record = EmsCluster.new
        @user.stub(:role_allows?).and_return(true)
      end

      context "and id = common_drift" do
        before do
          @id = 'common_drift'
          @lastaction = 'drift_history'
        end

        it "and lastaction = drift_history" do
          subject.should == false
        end
      end

      it "and id != common_drift" do
        @id = 'ems_cluster_view'
        subject.should == false
      end
    end

    context "when with Host" do
      before do
        @record = Host.new
        @user.stub(:role_allows?).and_return(true)
      end

      context "and id = common_drift" do
        before do
          @id = 'common_drift'
          @lastaction = 'drift_history'
        end

        it "and lastaction = drift_history" do
          subject.should == false
        end
      end

      context "and id = host_protect" do
        before do
          @id = 'host_protect'
          @record.stub(:smart? => false)
        end

        it "and record is not smart" do
          subject.should == true
        end

        it "and record is smart" do
          @record.stub(:smart? => true)
          subject.should == false
        end
      end

      context "and id = host_refresh" do
        before do
          @id = 'host_refresh'
          @record.stub(:is_refreshable? => false)
        end

        it "and record is not refreshable" do
          subject.should == true
        end

        it "and record is refreshable" do
          @record.stub(:is_refreshable? => true)
          subject.should == false
        end
      end

      context "and id = host_scan" do
        before { @id = 'host_scan' }

        it "and record is not scannable" do
          @record.stub(:is_scannable? => false)
          subject.should == true
        end

        it "and record is scannable" do
          @record.stub(:is_scannable? => true)
          subject.should == false
        end
      end

      ["host_shutdown", "host_standby", "host_reboot", "host_enter_maint_mode", "host_exit_maint_mode", "host_start", "host_stop", "host_reset"].each do |id|
        context "and id = #{id}" do
          before do
            @id = id
            @record.stub(:is_available? => false)
          end

          it "and record is not available" do
            subject.should == true
          end

          it "and record is available" do
            @record.stub(:is_available? => true)
            subject.should == false
          end
        end
      end

      ["perf_refresh", "perf_reload", "vm_perf_refresh", "vm_perf_reload"].each do |id|
        context "and id = #{id}" do
          before do
            @id = id
            @perf_options = {:typ => "realtime"}
          end

          it "and @perf_options[:typ] != 'realtime'" do
            @perf_options = {:typ => "Daily"}
            subject.should == true
          end

          it "and @perf_options[:typ] = 'realtime'" do
            subject.should == false
          end
        end
      end
    end

    ["MiqProvisionRequest", "MiqHostProvisionRequest", "VmReconfigureRequest", "VmMigrateRequest", "AutomationRequest", "ServiceTemplateProvisionRequest"].each do |cls|
      context "when with #{cls}" do
        before do
          @record = cls.constantize.new
          @user.stub(:role_allows?).and_return(true)
        end

        context "and id = miq_request_approve" do
          before do
            @id = "miq_request_approve"
            @record.stub(:resource_type => "something", :approval_state => "xx")
          end

          it "and resource_type = AutomationRequest" do
            @record.stub(:resource_type => "AutomationRequest")
            subject.should == false
          end

          it "and approval_state = approved" do
            @record.stub(:approval_state => "approved")
            subject.should == true
          end

          it "and showtype = miq_provisions" do
            @showtype = "miq_provisions"
            subject.should == true
          end

          it "and approval_state != approved and showtype != miq_provisions" do
            subject.should == false
          end
        end

        context "and id = miq_request_deny" do
          before do
            @id = "miq_request_deny"
            @record.stub(:resource_type => "something", :approval_state => "xx")
          end

          it "and resource_type = AutomationRequest" do
            @record.stub(:resource_type => "AutomationRequest")
            subject.should == false
          end

          it "and approval_state = approved" do
            @record.stub(:approval_state => "approved")
            subject.should == true
          end

          it "and approval_state = denied" do
            @record.stub(:approval_state => "denied")
            subject.should == true
          end

          it "and showtype = miq_provisions" do
            @showtype = "miq_provisions"
            subject.should == true
          end

          it "and approval_state != approved|denied and showtype != miq_provisions" do
            subject.should == false
          end
        end

        context "and id = miq_request_delete" do
          before do
            @id = "miq_request_delete"
            @record.stub(:resource_type => "something", :approval_state => "xx", :requester_name => @user.name)
            User.stub(:find_by_userid).and_return(@user)
          end

          it "and resource_type = AutomationRequest" do
            @record.stub(:resource_type => "AutomationRequest")
            subject.should == false
          end

          it "and requester.name != @record.requester_name" do
            @record.stub(:requester_name => 'admin')
            subject.should == false
          end

          it "and approval_state = approved" do
            @record.stub(:approval_state => "approved")
            subject.should == false
          end

          it "and approval_state = denied" do
            @record.stub(:approval_state => "denied")
            subject.should == false
          end

          it "and requester.name = @record.requester_name & approval_state != approved|denied" do
            subject.should == false
          end
        end

        context "and id = miq_request_edit" do
          before do
            @id = "miq_request_edit"
            @record.stub(:resource_type => "something", :approval_state => "xx", :requester_name => @user.name)
            User.stub(:find_by_userid).and_return(@user)
          end

          it "and resource_type = AutomationRequest" do
            @record.stub(:resource_type => "AutomationRequest")
            subject.should == true
          end

          it "and requester.name != @record.requester_name" do
            @record.stub(:requester_name => 'admin')
            subject.should == true
          end

          it "and approval_state = approved" do
            @record.stub(:approval_state => "approved")
            subject.should == true
          end

          it "and approval_state = denied" do
            @record.stub(:approval_state => "denied")
            subject.should == true
          end

          it "and requester.name = @record.requester_name & approval_state != approved|denied" do
            subject.should == false
          end
        end

        context "and id = miq_request_copy" do
          before do
            @id = "miq_request_copy"
            @record.stub(:resource_type  => "MiqProvisionRequest",
                         :approval_state => "pending_approval",
                         :requester_name => @user.name)
            User.stub(:find_by_userid).and_return(@user)
          end

          it "and resource_type = AutomationRequest" do
            @record.stub(:resource_type => "AutomationRequest")
            subject.should == true
          end

          it "and resource_type != MiqProvisionRequest" do
            @record.stub(:resource_type => "SomeRequest")
            subject.should == true
          end

          it "and requester.name != @record.requester_name & showtype = miq_provisions" do
            @showtype = "miq_provisions"
            @record.stub(:requester_name => 'admin')
            subject.should == true
          end

          it "and approval_state = approved & showtype = miq_provisions" do
            @showtype = "miq_provisions"
            @record.stub(:approval_state => "approved")
            subject.should == true
          end

          it "and approval_state = denied & showtype = miq_provisions" do
            @showtype = "miq_provisions"
            @record.stub(:approval_state => "denied")
            subject.should == true
          end

          it "and resource_type = MiqProvisionRequest & requester.name = @record.requester_name & approval_state != approved|denied" do
            @showtype = "miq_provisions"
            subject.should == false
          end

          it "and resource_type = MiqProvisionRequest & showtype != miq_provisions" do
            @record.stub(:requester_name => 'admin')
            subject.should == false
          end
        end
      end
    end

    context "when with MiqAlert" do
      before do
        @record = MiqAlert.new
        @layout = "miq_policy"
      end

      it "alert_copy don't hide if RBAC allows" do
        @user.stub(:role_allows?).and_return(true)
        @id = "alert_copy"
        subject.should be_false
      end

      it "alert_copy hide if RBAC denies" do
        @user.stub(:role_allows?).and_return(false)
        @id = "alert_copy"
        subject.should be_true
      end
    end

    context "when with MiqServer" do
      before do
        @record = MiqServer.new
        @user.stub(:role_allows?).and_return(true)
      end

      ["role_start", "role_suspend", "promote_server", "demote_server",
       "log_download", "refresh_logs", "log_collect", "log_reload", "logdepot_edit", "processmanager_restart", "refresh_workers"].each do |id|
        it "and id = #{id}" do
          @id = id
          subject.should == true
        end
      end

      it "otherwise" do
        @id = 'xx'
        subject.should == false
      end
    end

    context "when with ScanItemSet" do
      before do
        @record = ScanItemSet.new
        @user.stub(:role_allows?).and_return(true)
      end

      ["scan_delete", "scan_edit"].each do |id|
        context "and id = #{id}" do
          before do
            @id = id
            @record.stub(:read_only => false)
          end

          it "and record read only" do
            @record.stub(:read_only => true)
            subject.should == true
          end

          it "and record not read only" do
            subject.should == false
          end
        end
      end
    end

    context "when with ServerRole" do
      before do
        @record = ServerRole.new
        @user.stub(:role_allows?).and_return(true)
      end

      ["server_delete", "role_start", "role_suspend", "promote_server", "demote_server"].each do |id|
        it "and id = #{id}" do
          @id = id
          subject.should == true
        end
      end

      it "otherwise" do
        @id = 'xx'
        subject.should == false
      end
    end

    context "when with Vm" do
      before do
        @record = Vm.new
        @user.stub(:role_allows?).and_return(true)
      end

      %w(vm_migrate vm_publish vm_reconfigure).each do |id|
        context "and id = #{id}" do
          before { @id = id }

          it "and vendor is redhat" do
            @record = FactoryGirl.create(:vm_redhat)
            subject.should == true
          end

          it "and vendor is not redhat" do
            @record = FactoryGirl.create(:vm_vmware)
            subject.should == false
          end
        end
      end

      context "and id = vm_clone" do
        before { @id = "vm_clone" }

        it "record is not cloneable" do
          @record = Vm.create(:type => "ManageIQ::Providers::Microsoft::InfraManager::Vm", :name => "vm", :location => "l2", :vendor => "microsoft")
          subject.should == true
        end

        it "record is cloneable" do
          @record = Vm.create(:type => "ManageIQ::Providers::Redhat::InfraManager::Vm", :name => "rh", :location => "l1", :vendor => "redhat")
          subject.should == false
        end
      end

      context "and id = vm_collect_running_processes" do
        before do
          @id = "vm_collect_running_processes"
          @record.stub(:retired => false, :current_state => "new")
          @record.stub(:is_available?).with(:collect_running_processes).and_return(true)
        end

        it "and @record.retired & !@record.is_available?(:collect_running_processes)" do
          @record.stub(:retired => true)
          @record.stub(:is_available?).with(:collect_running_processes).and_return(false)
          subject.should == true
        end

        it "and @record.current_state = never & !@record.is_available?(:collect_running_processes)" do
          @record.stub(:is_available?).with(:collect_running_processes).and_return(false)
          @record.stub(:current_state => "never")
          subject.should == true
        end

        it "and @record.is_available?(:collect_running_processes)" do
          subject.should == false
        end

        it "and !@record.retired & @record.current_state != never" do
          subject.should == false
        end
      end

      context "and id = common_drift" do
        before do
          @id = "common_drift"
          @lastaction = "drift"
        end

        it "and @lastaction = drift_history" do
          @lastaction = "drift_history"
          subject.should == false
        end
      end

      ["vm_guest_startup", "vm_start"].each do |id|
        context "and id = #{id}" do
          before do
            @id = id
            @record.stub(:is_available?).with(:start).and_return(true)
          end

          it "and !@record.is_available?(:start)" do
            @record.stub(:is_available?).with(:start).and_return(false)
            subject.should == true
          end

          it "and @record.is_available?(:start)" do
            subject.should == false
          end
        end
      end

      context "and id = vm_guest_standby" do
        before do
          @id = "vm_guest_standby"
          @record.stub(:is_available?).with(:standby_guest).and_return(true)
        end

        it "and !@record.is_available?(:standby_guest)" do
          @record.stub(:is_available?).with(:standby_guest).and_return(false)
          subject.should == true
        end

        it "and @record.is_available?(:standby_guest)" do
          subject.should == false
        end
      end

      context "and id = vm_guest_shutdown" do
        before do
          @id = "vm_guest_shutdown"
          @record.stub(:is_available?).with(:shutdown_guest).and_return(true)
        end

        it "and !@record.is_available?(:shutdown_guest)" do
          @record.stub(:is_available?).with(:shutdown_guest).and_return(false)
          subject.should == true
        end

        it "and @record.is_available?(:shutdown_guest)" do
          subject.should == false
        end
      end

      context "and id = vm_guest_restart" do
        before do
          @id = "vm_guest_restart"
          @record.stub(:is_available?).with(:reboot_guest).and_return(true)
        end

        it "and !@record.is_available?(:reboot_guest)" do
          @record.stub(:is_available?).with(:reboot_guest).and_return(false)
          subject.should == true
        end

        it "and @record.is_available?(:reboot_guest)" do
          subject.should == false
        end
      end

      context "and id = vm_stop" do
        before do
          @id = "vm_stop"
          @record.stub(:is_available?).with(:stop).and_return(true)
        end

        it "and !@record.is_available?(:stop)" do
          @record.stub(:is_available?).with(:stop).and_return(false)
          subject.should == true
        end

        it "and @record.is_available?(:stop)" do
          subject.should == false
        end
      end

      context "and id = vm_reset" do
        before do
          @id = "vm_reset"
          @record.stub(:is_available?).with(:reset).and_return(true)
        end

        it "and !@record.is_available?(:reset)" do
          @record.stub(:is_available?).with(:reset).and_return(false)
          subject.should == true
        end

        it "and @record.is_available?(:reset)" do
          subject.should == false
        end
      end

      context "and id = vm_suspend" do
        before do
          @id = "vm_suspend"
          @record.stub(:is_available?).with(:suspend).and_return(true)
        end

        it "and !@record.is_available?(:suspend)" do
          @record.stub(:is_available?).with(:suspend).and_return(false)
          subject.should == true
        end

        it "and @record.is_available?(:suspend)" do
          subject.should == false
        end
      end

      ["vm_policy_sim", "vm_protect"].each do |id|
        context "and id = #{id}" do
          before do
            @id = id
            @record.stub(:host => double(:vmm_product => "Server"))
          end

          it "and @record.host.vmm_product = workstation" do
            @record.stub(:host => double(:vmm_product => "Workstation"))
            subject.should == true
          end

          it "and @record.host.vmm_product != workstation" do
            subject.should == false
          end

          it "and @record.host does exist" do
            @record.stub(:host => nil)
            subject.should == false
          end
        end
      end

      context "and id = vm_refresh" do
        before do
          @id = "vm_refresh"
          @record.stub(:host => double(:vmm_product => "Workstation"), :ext_management_system => true)
        end

        it "and !@record.ext_management_system & @record.host.vmm_product.downcase != workstation" do
          @record.stub(:host => double(:vmm_product => "Server"), :ext_management_system => false)
          subject.should == true
        end

        it "and @record.ext_management_system" do
          subject.should == false
        end

        it "and @record.host.vmm_product.downcase = workstation" do
          subject.should == false
        end
      end

      context "and id = vm_scan" do
        before do
          @id = "vm_scan"
          @record.stub(:has_proxy?).and_return(true)
        end

        it "and !@record.has_proxy?" do
          @record.stub(:has_proxy?).and_return(false)
          subject.should == true
        end

        it "and @record.has_proxy?" do
          subject.should == false
        end
      end

      ["perf_refresh", "perf_reload", "vm_perf_refresh", "vm_perf_reload"].each do |id|
        context "and id = #{id}" do
          before do
            @id = id
            @perf_options = {:typ => "realtime"}
          end

          it "and @perf_options[:typ] != realtime" do
            @perf_options = {:typ => "Daily"}
            subject.should == true
          end

          it "and @perf_options[:typ] = realtime" do
            subject.should == false
          end
        end
      end
    end # with Vm

    context "when with MiqTemplate" do
      before do
        @record = MiqTemplate.new
        @user.stub(:role_allows?).and_return(true)
      end

      context "and id = miq_template_clone" do
        before do
          @id = "miq_template_clone"
        end

        it "record is not cloneable" do
          @record =  MiqTemplate.create(:type     => "ManageIQ::Providers::Redhat::InfraManager::Template",
                                        :name     => "rh",
                                        :location => "loc1",
                                        :vendor   => "redhat")
          subject.should == true
        end

        it "record is cloneable" do
          @record =  MiqTemplate.create(:type     => "ManageIQ::Providers::Vmware::InfraManager::Template",
                                        :name     => "vm",
                                        :location => "loc2",
                                        :vendor   => "vmware")
          subject.should == false
        end
      end

      ["miq_template_policy_sim", "miq_template_protect"].each do |id|
        context "and id = #{id}" do
          before do
            @id = id
            @record.stub(:host => double(:vmm_product => "Server"))
          end

          it "and @record.host.vmm_product = workstation" do
            @record.stub(:host => double(:vmm_product => "Workstation"))
            subject.should == true
          end

          it "and !@record.host" do
            @record.stub(:host => nil)
            subject.should == false
          end

          it "and @record.host.vmm_product != workstation" do
            subject.should == false
          end
        end
      end

      context "and id = miq_template_refresh" do
        before do
          @id = "miq_template_refresh"
          @record.stub(:host => double(:vmm_product => "Workstation"), :ext_management_system => true)
        end

        it "and !@record.ext_management_system & @record.host.vmm_product != workstation" do
          @record.stub(:host => double(:vmm_product => "Server"), :ext_management_system => false)
          subject.should == true
        end

        it "and @record.ext_management_system" do
          subject.should == false
        end

        it "and @record.host.vmm_product = workstation" do
          subject.should == false
        end
      end

      context "and id = miq_template_scan" do
        before { @id = "miq_template_scan" }

        it "and !@record.has_proxy?" do
          subject.should == true
        end

        it "and @record.has_proxy?" do
          @record.stub(:has_proxy? => true)
          subject.should == false
        end
      end

      context "and id = miq_template_reload" do
        before { @id = "miq_template_reload" }

        it "and @perf_options[:typ] != realtime" do
          @perf_options = {:typ => "Daily"}
          subject.should == true
        end

        it "and @perf_options[:typ] = realtime" do
          @perf_options = {:typ => "realtime"}
          subject.should == false
        end
      end
    end # MiqTemplate

    context "when with record = nil" do
      before do
        @record = nil
        @user.stub(:role_allows?).and_return(true)
      end

      ["log_download", "log_reload"].each do |id|
        context "and id = #{id}" do
          before { @id = id }

          it "and @lastaction = workers" do
            @lastaction = "workers"
            subject.should == true
          end

          it "and @lastaction = download_logs" do
            @lastaction = "download_logs"
            subject.should == true
          end

          it "otherwise" do
            subject.should == false
          end
        end
      end

      ["log_collect", "logdepot_edit", "refresh_logs"].each do |id|
        context "and id = #{id}" do
          before { @id = id }

          it "and @lastaction = workers" do
            @lastaction = "workers"
            subject.should == true
          end

          it "and @lastaction = evm_logs" do
            @lastaction = "evm_logs"
            subject.should == true
          end

          it "and @lastaction = audit_logs" do
            @lastaction = "audit_logs"
            subject.should == true
          end

          it "otherwise" do
            subject.should == false
          end
        end
      end

      ["processmanager_restart", "refresh_workers"].each do |id|
        context "and id = #{id}" do
          before { @id = id }

          it "and @lastaction = download_logs" do
            @lastaction = "download_logs"
            subject.should == true
          end

          it "and @lastaction = evm_logs" do
            @lastaction = "evm_logs"
            subject.should == true
          end

          it "and @lastaction = audit_logs" do
            @lastaction = "audit_logs"
            subject.should == true
          end

          it "otherwise" do
            subject.should == false
          end
        end
      end

      ["usage_txt", "usage_csv", "usage_pdf", "usage_reportonly"].each do |id|
        context "and id = #{id}" do
          before { @id = id }

          it "and !@usage_options[:report]" do
            @usage_options = {:some => 'thing'}
            subject.should == true
          end

          it "and @usage_options[:report].table.data is empty" do
            table = double(:data => '')
            @usage_options = {:report => double(:table => table)}
            subject.should == true
          end

          it "and @usage_options[:report].table.data not empty" do
            table = double(:data => 'something interesting')
            @usage_options = {:report => double(:table => table)}
            subject.should == false
          end
        end
      end

      ["timeline_csv", "timeline_pdf", "timeline_txt"].each do |id|
        context "and id = #{id}" do
          before { @id = id }

          it "and !@report" do
            subject.should == true
          end

          it "and @report" do
            @report = ''
            subject.should == false
          end
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
          @user.stub(:role_allows?).and_return(true)
          subject.should == false
        end

        it "user not allowed" do
          @user.stub(:role_allows?).and_return(false)
          subject.should == true
        end

        it "button hidden if provider has no stacks" do
          @record = FactoryGirl.create(:ems_openstack_infra)
          @user.stub(:role_allows?).and_return(true)
          subject.should == true
        end
      end

      context "when @record != EmsOpenstackInfra" do
        before do
          @record = ManageIQ::Providers::Vmware::InfraManager.new
        end

        it "user allowed but hide button because wrong provider" do
          @user.stub(:role_allows?).and_return(true)
          subject.should == true
        end

        it "user not allowed" do
          @user.stub(:role_allows?).and_return(false)
          subject.should == true
        end
      end
    end

    context "when id == vm_scan" do
      before do
        @id = "vm_scan"
      end

      it "vm_scan button should be hidden when user does not have access to vm_rules feature" do
        feature = EvmSpecHelper.specific_product_features("vm_infra_explorer")
        login_as FactoryGirl.create(:user, :features => feature)
        subject.should == true
      end

      it "vm_scan button should be displayed when user does has access to vm_scan feature" do
        feature = EvmSpecHelper.specific_product_features("vm_infra_explorer", "vm_scan")
        login_as FactoryGirl.create(:user, :features => feature)
        subject.should == false
      end
    end
  end # end of build_toolbar_hide_button

  describe "#build_toolbar_disable_button" do
    subject { build_toolbar_disable_button(@id) }
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
      ActionController::TestSession.any_instance.stub(:fetch_path).with(:browser, :name).and_return('firefox')
      ActionController::TestSession.any_instance.stub(:fetch_path).with(:browser, :os).and_return('linux')
    end

    ['list', 'tile', 'grid'].each do |g|
      it "when with view_#{g}" do
        @gtl_type = g
        build_toolbar_disable_button("view_#{g}").should be_true
      end
    end

    it "when with 'history_1' and x_tree_history.length < 2" do
      # setup for x_tree_history
      @sb = {:history     => {:testing => %w(something)},
             :active_tree => :testing}
      build_toolbar_disable_button('history_1').should be_true
    end

    ['button_add', 'button_save', 'button_reset'].each do |b|
      it "when with #{b} and not changed" do
        @changed = false
        build_toolbar_disable_button(b).should be_true
      end
    end

    context "when record class = AssignedServerRole" do
      before(:each) { @record = AssignedServerRole.new }

      before do
        @sb = {:active_tree => :diagnostics_tree,
               :trees       => {:diagnostics_tree => {:tree => :diagnostics_tree}}}
        @server_role = ServerRole.new(:description => "some description")
      end

      context "and id = role_start" do
        before :each do
          @message = "This Role is already active on this Server"
          @id = "role_start"

          @record.stub(:miq_server => double(:started? => true), :active => true, :server_role => @server_role)
        end

        it "when miq server not started" do
          @record.stub(:miq_server => double(:started? => false))
          subject.should == @message
        end

        it "when miq server started but not active" do
          @record.stub(:active => false)
          @record.stub(:miq_server => double(:started? => false))
          subject.should == "Only available Roles on active Servers can be started"
        end

        it_behaves_like 'default true_case'
      end

      context "and id = role_suspend" do
        before(:each) do
          @id = "role_suspend"
          @miq_server = MiqServer.new(:name => "xx miq server", :id => "xx server id")
          @miq_server.stub(:started? => true)
          @record.stub(:miq_server => @miq_server, :active => true,
                          :server_role => @server_role)
          @server_role.max_concurrent = 1
        end

        context "when miq server started and active" do
          it "and server_role.max_concurrent == 1" do
            @record.stub(:miq_server => @miq_server)
            subject.should == "Activate the #{@record.server_role.description} Role on another Server to suspend it on #{@record.miq_server.name} [#{@record.miq_server.id}]"
          end
          it_behaves_like 'default true_case'
        end

        it "when miq_server not started or not active" do
          @record.stub(:miq_server => double(:started? => false), :active => false)
          subject.should == "Only active Roles on active Servers can be suspended"
        end
      end
    end

    context "when record class = OntapStorageSystem" do
      before do
        @record = OntapStorageSystem.new
        @record.stub(:latest_derived_metrics => true)
      end

      context "and id = ontap_storage_system_statistics" do
        before(:each) { @id = "ontap_storage_system_statistics" }
        it_behaves_like 'record without latest derived metrics', "No Statistics Collected"
        it_behaves_like 'default case'
      end
    end

    context "when record class = OntapLogicalDisk" do
      before { @record = OntapLogicalDisk.new }

      context "and id = ontap_logical_disk_perf" do
        before do
          @id = "ontap_logical_disk_perf"
          @record.stub(:has_perf_data? => true)
        end
        it_behaves_like 'record without perf data', "No Capacity & Utilization data has been collected for this Logical Disk"
        it_behaves_like 'default case'
      end

      context "and id = ontap_logical_disk_statistics" do
        before do
          @id = "ontap_logical_disk_statistics"
          @record.stub(:latest_derived_metrics => true)
        end
        it_behaves_like 'record without latest derived metrics', "No Statistics collected for this Logical Disk"
        it_behaves_like 'default case'
      end
    end

    context "when record class = CimBaseStorageExtent" do
      before do
        @record = CimBaseStorageExtent.new
        @record.stub(:latest_derived_metrics => true)
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
        @record.stub(:latest_derived_metrics => true)
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
        @record.stub(:latest_derived_metrics => true)
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
        @record.stub(:latest_derived_metrics => true)
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
        @record.stub(:has_perf_data? => true, :has_events? => true)
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

    context "when record class = ContainerProject" do
      before do
        @record = ContainerProject.new
        @record.stub(:has_perf_data? => true, :has_events? => true)
      end

      context "and id = container_project_timeline" do
        before { @id = "container_project_timeline" }
        it_behaves_like 'record without ems events and policy events', "No Timeline data has been collected for this Project"
        it_behaves_like 'default case'
      end
    end

    context "when record class = ContainerGroup" do
      before do
        @record = ContainerGroup.new
        @record.stub(:has_perf_data? => true, :has_events? => true)
      end

      context "and id = container_group_timeline" do
        before { @id = "container_group_timeline" }
        it_behaves_like 'record without ems events and policy events', "No Timeline data has been collected for this Pod"
        it_behaves_like 'default case'
      end
    end

    context "when record class = ContainerNode" do
      before do
        @record = ContainerNode.new
        @record.stub(:has_perf_data? => true, :has_events? => true)
      end

      context "and id = container_node_timeline" do
        before { @id = "container_node_timeline" }
        it_behaves_like 'record without ems events and policy events', "No Timeline data has been collected for this Node"
        it_behaves_like 'default case'
      end
    end

    context "when record class = Host" do
      before do
        @record = Host.new
        @record.stub(:has_perf_data? => true)
      end

      context "and id = host_perf" do
        before { @id = "host_perf" }
        it_behaves_like 'record without perf data', "No Capacity & Utilization data has been collected for this Host"
        it_behaves_like 'default case'
      end

      context "and id = host_miq_request_new" do
        before do
          @id = "host_miq_request_new"
          @record.stub(:mac_address).and_return("00:0D:93:13:51:1A")
          PxeServer.stub(:all).and_return(['p1', 'p2'])
        end
        it "when without mac address" do
          @record.stub(:mac_address).and_return(false)
          subject.should == "This Host can not be provisioned because the MAC address is not known"
        end

        it "when no PXE servers" do
          PxeServer.stub(:all).and_return([])
          subject.should == "No PXE Servers are available for Host provisioning"
        end

        it_behaves_like 'default case'
      end

      context "and id = host_refresh" do
        before do
          @id = "host_refresh"
          @record.stub(:is_refreshable_now? => true)
        end
        it "when not configured for refresh" do
          message = "Host not configured for refresh"
          @record.stub(:is_refreshable_now_error_message => message, :is_refreshable_now? => false)
          subject.should == message
        end

        it_behaves_like 'default case'
      end

      context "and id = host_scan" do
        before do
          @id = "host_scan"
          @record.stub(:is_scannable_now? => true)
        end

        it "when not scannable now" do
          message = "Provide credentials for IPMI"
          @record.stub(:is_scannable_now? => false, :is_scannable_now_error_message => message)
          subject.should == message
        end

        it_behaves_like 'default case'
      end

      context "and id = host_timeline" do
        before do
          @id = "host_timeline"
          @record.stub(:has_events?).and_return(true)
        end

        it_behaves_like 'record without ems events and policy events', "No Timeline data has been collected for this Host"
        it_behaves_like 'default case'
      end

      context "and id = host_shutdown" do
        before do
          @id = "host_shutdown"
          @record.stub(:is_available_now_error_message => false)
        end
        it_behaves_like 'record with error message', 'shutdown'
        it_behaves_like 'default case'
      end

      context "and id = host_restart" do
        before do
          @id = "host_restart"
          @record.stub(:is_available_now_error_message => false)
        end

        it_behaves_like 'record with error message', 'reboot'
        it_behaves_like 'default case'
      end
    end

    context "when record class = MiqServer" do
      context "and id = delete_server" do
        before do
          @record = MiqServer.new('name' => 'Server1', 'id' => 'Server ID')
          @id = "delete_server"
        end
        it "is deleteable?" do
          @record.stub(:is_deleteable?).and_return(false)
          subject.should include('Server ')
          subject.should include('can only be deleted if it is stopped or has not responded for a while')
        end
        it_behaves_like 'default case'
      end
    end

    context "when record class = MiqWidget" do
      context "and id = widget_generate_content" do
        before do
          @id = "widget_generate_content"
          @record = FactoryGirl.create(:miq_widget)
        end
        it "when not member of a widgetset" do
          subject.should == "Widget has to be assigned to a dashboard to generate content"
        end

        it "when Widget content generation is already running or queued up" do
          @widget_running = true
          db = FactoryGirl.create(:miq_widget_set)
          db.replace_children([@record])
          subject.should == "This Widget content generation is already running or queued up"
        end
      end
    end

    context "when record class = ServiceTemplate" do
      context "and id = svc_catalog_provision" do
        before do
          @record = ServiceTemplate.new
          @id = "svc_catalog_provision"
        end

        it "no provision dialog is available when action = 'provision'" do
          @record.stub(:resource_actions).and_return([])
          subject.should == "No Ordering Dialog is available"
        end

        it "when a provision dialog is available" do
          @record.stub(:resource_actions => [double(:action => 'Provision', :dialog_id => '10')])
          Dialog.stub(:find_by_id => 'some thing')
          subject.should be_false
        end
      end
    end

    context "when record class = Storage" do
      before { @record = Storage.new }

      context "and id = storage_perf" do
        before do
          @id = "storage_perf"
          @record.stub(:has_perf_data? => true)
        end
        it_behaves_like 'record without perf data', "No Capacity & Utilization data has been collected for this Datastore"
        it_behaves_like 'default case'
      end

      context "and id = storage_delete" do
        before { @id = "storage_delete" }
        it "when with VMs or Hosts" do
          @record.stub(:hosts).and_return(['h1', 'h2'])
          subject.should == "Only Datastore without VMs and Hosts can be removed"

          @record.stub(:hosts => [], :vms_and_templates => ['v1'])
          subject.should == "Only Datastore without VMs and Hosts can be removed"
        end
        it_behaves_like 'default case'
      end
    end

    context "when record class = Vm" do
      before { @record = Vm.new }

      context "and id = vm_perf" do
        before do
          @id = "vm_perf"
          @record.stub(:has_perf_data? => true)
        end
        it_behaves_like 'record without perf data', "No Capacity & Utilization data has been collected for this VM"
        it_behaves_like 'default case'
      end

      context "id = vm_collect_running_processes" do
        before do
          @id = "vm_collect_running_processes"
          @record.stub(:is_available_now_error_message).and_return(false)
        end
        it_behaves_like 'record with error message', 'collect_running_processes'
        it_behaves_like 'default case'
      end

      context "and id = vm_console" do
        before do
          @id = "vm_console"
          @record.stub(:current_state => 'on')
          setup_firefox_with_linux
        end

        it_behaves_like 'vm not powered on', "The web-based console is not available because the VM is not powered on"
        it_behaves_like 'default case'
      end

      context "and id = vm_vnc_console" do
        before do
          @id = "vm_vnc_console"
          @record.stub(:current_state => 'on', :ipaddresses => '192.168.1.1')
        end

        it_behaves_like 'vm not powered on', "The web-based VNC console is not available because the VM is not powered on"
        it_behaves_like 'default case'
      end

      context "and id = vm_vmrc_console" do
        before do
          @id = "vm_vmrc_console"
          @record.stub(:current_state => 'on', :validate_remote_console_vmrc_support => true)
          setup_firefox_with_linux
        end

        it "raise MiqException::RemoteConsoleNotSupportedError when can't get remote console url" do
          @record.unstub(:validate_remote_console_vmrc_support)
          subject.should include("VM VMRC Console error")
          subject.should include("VMRC remote console is not supported on")
        end

        it_behaves_like 'vm not powered on', "The web-based console is not available because the VM is not powered on"
      end

      context "and id = vm_guest_startup" do
        before do
          @id = "vm_guest_startup"
          @record.stub(:is_available_now_error_message).and_return(false)
        end
        it_behaves_like 'record with error message', 'start'
        it_behaves_like 'default case'
      end

      context "and id = vm_start" do
        before do
          @id = "vm_start"
          @record.stub(:is_available_now_error_message).and_return(false)
        end
        it_behaves_like 'record with error message', 'start'
        it_behaves_like 'default case'
      end

      context "and id = vm_guest_standby" do
        before do
          @id = "vm_guest_standby"
          @record.stub(:is_available_now_error_message).and_return(false)
        end
        it_behaves_like 'record with error message', 'standby_guest'
        it_behaves_like 'default case'
      end

      context "and id = vm_guest_shutdown" do
        before do
          @id = "vm_guest_shutdown"
          @record.stub(:is_available_now_error_message).and_return(false)
        end
        it_behaves_like 'record with error message', 'shutdown_guest'
        it_behaves_like 'default case'
      end

      context "and id = vm_guest_restart" do
        before do
          @id = "vm_guest_restart"
          @record.stub(:is_available_now_error_message).and_return(false)
        end
        it_behaves_like 'record with error message', 'reboot_guest'
        it_behaves_like 'default case'
      end

      context "and id = vm_stop" do
        before do
          @id = "vm_stop"
          @record.stub(:is_available_now_error_message).and_return(false)
        end
        it_behaves_like 'record with error message', 'stop'
        it_behaves_like 'default case'
      end

      context "and id = vm_reset" do
        before do
          @id = "vm_reset"
          @record.stub(:is_available_now_error_message).and_return(false)
        end
        it_behaves_like 'record with error message', 'reset'
        it_behaves_like 'default case'
      end

      context "and id = vm_suspend" do
        before do
          @id = "vm_suspend"
          @record.stub(:is_available_now_error_message).and_return(false)
        end
        it_behaves_like 'record with error message', 'suspend'
        it_behaves_like 'default case'
      end

      ["vm_retire", "vm_retire_now"].each do |button_id|
        context "and id = #{button_id}" do
          before { @id = button_id }
          it "when VM is already retired" do
            @record.stub(:retired => true)
            subject.should == "VM is already retired"
          end
          it_behaves_like 'default case'
        end
      end

      context "and id = vm_scan" do
        before do
          @id = "vm_scan"
          @record = FactoryGirl.create(:vm_vmware, :vendor => "vmware")
          @record.stub(:has_active_proxy? => true)
        end
        it "when no active proxy" do
          @record.stub(:has_active_proxy? => false)
          subject.should == "No active SmartProxies found to analyze this VM"
        end
        it_behaves_like 'default case'
      end

      context "and id = instance_scan" do
        before do
          @id = "instance_scan"
          @record = FactoryGirl.create(:vm_amazon, :vendor => "amazon")
          @record.stub(:has_active_proxy? => true)
        end
        before { @record.stub(:is_available?).with(:smartstate_analysis).and_return(false) }
        it_behaves_like 'record with error message', 'smartstate_analysis'
      end

      context "and id = vm_timeline" do
        before do
          @id = "vm_timeline"
          @record.stub(:has_events?).and_return(true)
        end
        it_behaves_like 'record without ems events and policy events', 'No Timeline data has been collected for this VM'
        it_behaves_like 'default case'
      end

      context "snapshot buttons" do
        before(:each) do
          @record = FactoryGirl.create(:vm_vmware, :vendor => "vmware")
        end

        context "and id = vm_snapshot_add" do
          before do
            @id = "vm_snapshot_add"
            @record.stub(:is_available?).with(:create_snapshot).and_return(false)
          end

          context "when number of snapshots <= 0" do
            before { @record.stub(:is_available?).with(:create_snapshot).and_return(false) }
            it_behaves_like 'record with error message', 'create_snapshot'
          end

          context "when number of snapshots > 0" do
            before do
              @record.stub(:number_of).with(:snapshots).and_return(4)
              @record.stub(:is_available?).with(:create_snapshot).and_return(false)
            end

            it_behaves_like 'record with error message', 'create_snapshot'

            it "when no available message but active" do
              @record.stub(:is_available?).with(:create_snapshot).and_return(false)
              @active = true
              subject.should == "The VM is not connected to a Host"
            end
          end
          it_behaves_like 'default true_case'
        end

        context "and id = vm_snapshot_delete" do
          before { @id = "vm_snapshot_delete" }
          context "when with available message" do
            before { @record.stub(:is_available?).with(:remove_snapshot).and_return(false) }
            it_behaves_like 'record with error message', 'remove_snapshot'
          end
          context "when without snapshots" do
            before { @record.stub_chain(:snapshots, :size).and_return(0) }
            it_behaves_like 'record with error message', 'remove_snapshot'
          end
          context "when with snapshots" do
            before { @record.stub_chain(:snapshots, :size).and_return(2) }
            it_behaves_like 'default case'
          end
        end

        context "and id = vm_snapshot_delete_all" do
          before { @id = "vm_snapshot_delete_all" }
          context "when with available message" do
            before { @record.stub(:is_available?).with(:remove_all_snapshots).and_return(false) }
            it_behaves_like 'record with error message', 'remove_all_snapshots'
          end
          context "when without snapshots" do
            before { @record.stub_chain(:snapshots, :size).and_return(0) }
            it_behaves_like 'record with error message', 'remove_all_snapshots'
          end
          context "when with snapshots" do
            before { @record.stub_chain(:snapshots, :size).and_return(2) }
            it_behaves_like 'default case'
          end
        end

        context "id = vm_snapshot_revert" do
          before { @id = "vm_snapshot_revert" }
          context "when with available message" do
            before { @record.stub(:is_available?).with(:revert_to_snapshot).and_return(false) }
            it_behaves_like 'record with error message', 'revert_to_snapshot'
          end
          context "when without snapshots" do
            before { @record.stub_chain(:snapshots, :size).and_return(0) }
            it_behaves_like 'record with error message', 'revert_to_snapshot'
          end
          context "when with snapshots" do
            before { @record.stub_chain(:snapshots, :size).and_return(2) }
            it_behaves_like 'default case'
          end
        end
      end
    end # end of Vm class

    context "Disable Snapshot buttons for RHEV VMs" do
      before(:each) { @record = FactoryGirl.create(:vm_redhat) }

      ['vm_snapshot_add', 'vm_snapshot_delete', 'vm_snapshot_delete_all', 'vm_snapshot_revert'].each do |b|
        it "button #{b}" do
          res = build_toolbar_disable_button(b)
          res.should be_true
          res.should include("not supported")
        end
      end
    end

    context "Disable Retire button for already retired VMs and Instances" do
      it "button vm_retire_now" do
        @record = FactoryGirl.create(:vm_redhat, :retired => true)
        res = build_toolbar_disable_button("vm_retire_now")
        res.should be_true
        res.should include("already retired")
      end

      it "button instance_retire_now" do
        @record = FactoryGirl.create(:vm_amazon, :retired => true)
        res = build_toolbar_disable_button("instance_retire_now")
        res.should be_true
        res.should include("already retired")
      end
    end

    context "and id = miq_request_delete" do
      let(:server) { active_record_instance_double("MiqServer", :logon_status => :ready) }
      before(:each) do
        MiqServer.stub(:my_server).with(true).and_return(server)

        # create User record...
        @user = FactoryGirl.create(:user_admin)

        @id = "miq_request_delete"
        login_as @user
        @record = MiqProvisionRequest.new
        @record.stub(:resource_type => "something", :approval_state => "xx", :requester_name => @user.name)
      end

      it "and requester.name != @record.requester_name" do
        @record.stub(:requester_name => 'admin')
        res = build_toolbar_disable_button("miq_request_delete")
        res.should == false
      end

      it "and approval_state = approved" do
        @record.stub(:approval_state => "approved")
        subject.should == false
      end

      it "and requester.name = @record.requester_name & approval_state != approved|denied" do
        subject.should == false
      end

      it "and requester.name != @record.requester_name" do
        login_as FactoryGirl.create(:user, :role => "test")
        res = build_toolbar_disable_button("miq_request_delete")
        res.should include("Users are only allowed to delete their own requests")
      end
    end
  end # end of disable button

  describe "#build_toolbar_hide_button_ops" do
    subject { build_toolbar_hide_button_ops(@id) }
    before do
      @record = FactoryGirl.create(:tenant)
      feature = EvmSpecHelper.specific_product_features(%w(ops_rbac rbac_group_add rbac_tenant_add rbac_tenant_delete))
      login_as FactoryGirl.create(:user, :features => feature)
      @sb = {:active_tree => :rbac_tree}
    end

    %w(rbac_group_add rbac_project_add rbac_tenant_add rbac_tenant_delete).each do |id|
      context "when with #{id} button should be visible" do
        before { @id = id }
        it "and record_id" do
          subject.should be_false
        end
      end
    end

    %w(rbac_group_edit rbac_role_edit).each do |id|
      context "when with #{id} button should not be visible as user does not have access to these features" do
        before { @id = id }
        it "and record_id" do
          subject.should be_true
        end
      end
    end
  end

  describe "#get_record_cls"  do
    subject { get_record_cls(record) }
    context "when record not exist" do
      let(:record) { nil }
      it { should == "NilClass" }
    end

    context "when record is array" do
      let(:record) { ["some", "thing"] }
      it { should == record.class.name }
    end

    context "when record is valid" do
      [ManageIQ::Providers::Redhat::InfraManager::Host].each do |c|
        it "and with #{c}" do
          record = c.new
          get_record_cls(record).should eql(record.class.base_class.to_s)
        end
      end

      it "and with 'VmOrTemplate'" do
        record = ManageIQ::Providers::Vmware::InfraManager::Template.new
        get_record_cls(record).should eql(record.class.base_model.to_s)
      end

      it "otherwise" do
        record = Job.new
        get_record_cls(record).should eql(record.class.to_s)
      end
    end
  end

  describe "#build_toolbar_select_button" do
    before :each do
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
    subject { build_toolbar_select_button(id) }

    ['list', 'tile', 'grid'].each do |g|
      it "when with view_#{g}" do
        @gtl_type = g
        build_toolbar_select_button("view_#{g}").should be_true
      end
    end

    it "when with tree_large" do
      @settings[:views][:treesize] = 32
      build_toolbar_select_button("tree_large").should be_true
    end

    it "when with tree_small" do
      @settings[:views][:treesize] = 16
      build_toolbar_select_button("tree_small").should be_true
    end

    context  "when with 'compare_compressed'" do
      let(:id) { "compare_compressed" }
      it { should be_true }
    end

    context  "when with 'drift_compressed'" do
      let(:id) { "drift_compressed" }
      it { should be_true }
    end

    context  "when with 'compare_all'" do
      let(:id) { "compare_all" }
      it { should be_true }
    end

    context  "when with 'drift_all'" do
      let(:id) { "drift_all" }
      it { should be_true }
    end

    context  "when with 'comparemode_exists" do
      let(:id) { "comparemode_exists" }
      it { should be_true }
    end

    context  "when with 'driftmode_exists" do
      let(:id) { "driftmode_exists" }
      it { should be_true }
    end
  end

  describe "#build_toolbar_save_button" do
    before do
      @record = double(:id => 'record_id_xxx_001', :class => 'record_xxx_class')
      btn_num = "x_button_id_001"
      desc = 'the description for the button'
      @item = {:button    => "custom_#{btn_num}",
               :url       => "button",
               :url_parms => "?id=#{@record.id}&button_id=#{btn_num}&cls=#{@record.class}&pressed=custom_button&desc=#{desc}"
      }
      @tb_buttons = {}
      @parent = nil
      Object.any_instance.stub(:query_string).and_return("")
      allow_message_expectations_on_nil
    end

    context "names the button" do
      subject do
        build_toolbar_save_button(@tb_buttons, @item, @parent)
        @tb_buttons
      end

      it "as item[:buttonSelect] when item[:buttonTwoState] does not exist" do
        @item[:buttonSelect] = 'tree_large'
        subject.should have_key("tree_large")
      end

      it "as item[:button] when both item[:buttonTwoState] and item[:buttonSelect] not exist" do
        subject.should have_key("#{@item[:button]}")
      end

      it "prefixed with 'parent__' when parent is passed in" do
        @parent = "testing"
        subject.should have_key("#{@parent}__#{@item[:button]}")
      end
    end

    context "saves the item info by the same key" do
      subject do
        build_toolbar_save_button(@tb_buttons, @item)
        @tb_buttons[@item[:button]]
      end

      it "when item[:hidden] exists" do
        @item[:hidden] = 1
        subject.should have_key(:hidden)
      end

      it "when both parent and item[:title] exists" do
        parent = "Vm"
        @item[:title] = "Power On this VM"
        build_toolbar_save_button(@tb_buttons, @item, parent)
        @tb_buttons["#{parent}__#{@item[:button]}"].should have_key(:title)
      end

      it "when item[:url_parms] exists" do
        subject.should have_key(:url_parms)
      end

      it "when item[:confirm] exists" do
        @item[:confirm] = 'Are you sure?'
        subject.should have_key(:confirm)
      end

      it "when item[:onwhen] exists" do
        @item[:onwhen] = '1+'
        subject.should have_key(:onwhen)
      end
    end

    context "when item[:url] exists" do
      subject do
        build_toolbar_save_button(@tb_buttons, @item)
        @tb_buttons[@item[:button]]
      end

      it "gets rid of first directory and anything after last slash when button is 'view_grid', 'view_tile' or 'view_list'" do
        @item = {:button => 'view_list', :url => '/some/path/to/the/testing/code'}
        subject.should include(:url => '/path/to/the/testing')
      end

      it "saves the value as it is otherwise" do
        subject.should have_key(:url)
      end
    end
  end

  describe "update_url_parms", :type => :request do
    context "when the given parameter exists in the request query string" do
      before do
        get("/vm/show_list/100", "type=grid")
        Object.any_instance.stub(:query_string).and_return(@request.query_string)
        Object.any_instance.stub(:path_info).and_return(@request.path_info)
        allow_message_expectations_on_nil
      end

      it "updates the query string with the given parameter value" do
        update_url_parms("?type=list").should eq("?type=list")
      end
    end

    context "when the given parameters do not exist in the request query string" do
      before do
        get("/vm/show_list/100")
        Object.any_instance.stub(:query_string).and_return(@request.query_string)
        Object.any_instance.stub(:path_info).and_return(@request.path_info)
        allow_message_expectations_on_nil
      end

      it "adds the params in the query string" do
        update_url_parms("?refresh=y&type=list").should eq("?refresh=y&type=list")
      end
    end

    context "when the request query string has a few specific params to be retained" do
      before do
        get("/vm/show_list/100", "bc=VMs+running+on+2014-08-25&menu_click=Display-VMs-on_2-6-5"\
          "&sb_controller=host")
        Object.any_instance.stub(:query_string).and_return(@request.query_string)
        Object.any_instance.stub(:path_info).and_return(@request.path_info)
        allow_message_expectations_on_nil
      end

      it "retains the specific parameters and adds the new one" do
        update_url_parms("?type=list").should eq("?bc=VMs+running+on+2014-08-25&menu_click=Display-VMs-on_2-6-5"\
          "&sb_controller=host&type=list")
      end
    end

    context "when the request query string has a few specific params to be excluded" do
      before do
        get("/vm/show_list/100", "page=1")
        Object.any_instance.stub(:query_string).and_return(@request.query_string)
        Object.any_instance.stub(:path_info).and_return(@request.path_info)
        allow_message_expectations_on_nil
      end

      it "excludes specific parameters and adds the new one" do
        update_url_parms("?type=list").should eq("?type=list")
      end
    end
  end
end
