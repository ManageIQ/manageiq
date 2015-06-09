require "spec_helper"

describe MiqWidget do
  before(:each) do
    guid = MiqUUID.new_guid
    MiqServer.stub(:my_guid => guid)
    FactoryGirl.create(:miq_server, :zone => FactoryGirl.create(:zone), :guid => guid, :status => "started")
    MiqServer.my_server(true)

    MiqRegion.seed
  end

  context "setup" do
    before(:each) do
      MiqReport.seed_report("Vendor and Guest OS")

      @idents1 = ["dashboard_admin"]
      @role1   = FactoryGirl.create(:miq_user_role, :name => "Role1", :miq_product_features => MiqProductFeature.find_all_by_identifier(@idents1))
      @group1  = FactoryGirl.create(:miq_group, :miq_user_role => @role1)
      @user1   = FactoryGirl.create(:user, :miq_groups => [@group1], :name => "Administrator", :userid => "admin")

      @idents2 = ["everything"]
      @role2   = FactoryGirl.create(:miq_user_role, :name => "Role2", :miq_product_features => MiqProductFeature.find_all_by_identifier(@idents2))
      @group2  = FactoryGirl.create(:miq_group, :description => "Group2", :miq_user_role => @role2)
      @user2   = FactoryGirl.create(:user, :userid => "user2", :miq_groups => [@group2])

      @widget_report_vendor_and_guest_os = MiqWidget.sync_from_hash(YAML.load('
        description: report_vendor_and_guest_os
        title: Vendor and Guest OS
        content_type: report
        options:
          :col_order:
            - name
            - vendor
          :row_count: 10
        visibility:
          :roles:
          - _ALL_
        resource_name: Vendor and Guest OS
        resource_type: MiqReport
        enabled: true
        read_only: true
      '))

      @widget_chart_vendor_and_guest_os = MiqWidget.sync_from_hash(YAML.load('
        description: chart_vendor_and_guest_os
        title: Vendor and Guest OS Chart
        content_type: chart
        options:
        visibility:
          :roles:
          - _ALL_
        resource_name: Vendor and Guest OS
        resource_type: MiqReport
        enabled: true
        read_only: true
      '))
    end

    context "#queue_generate_content_for_users_or_group" do
      before(:each) do
        @widget = @widget_report_vendor_and_guest_os
        @queue_conditions = {
          :method_name  => "generate_content",
          :role         => "reporting",
          :queue_name   => "reporting",
          :class_name   => @widget.class.name,
          :instance_id  => @widget.id,
          :msg_timeout  => 3600
        }.freeze
      end

      it "admin user" do
        @widget.queue_generate_content_for_users_or_group(@user1)
        MiqQueue.exists?(@queue_conditions).should be_true
      end

      it "array of users" do
        @widget.queue_generate_content_for_users_or_group([@user1, @user2])
        MiqQueue.exists?(@queue_conditions).should be_true
      end

      it "with a task" do
        @widget.miq_task = MiqTask.new
        @widget.queue_generate_content_for_users_or_group("admin")
        MiqQueue.exists?({:method_name => "generate_content"}.merge(@queue_conditions)).should be_true
      end
    end

    context "#grouped_subscribers" do
      it "returns empty array when widget has no subscribers" do
        @widget_report_vendor_and_guest_os.grouped_subscribers.should be_kind_of(Hash)
        @widget_report_vendor_and_guest_os.grouped_subscribers.should be_empty
      end

      it "returns non-empty array when widget has subscribers" do
        ws = FactoryGirl.create(:miq_widget_set, :name => "Home", :userid => @user1.userid, :group_id => @group1.id)
        @widget_report_vendor_and_guest_os.make_memberof(ws)

        user_temp = add_user("test", @group1)
        ws_temp   = add_dashboard_for_user("Home", user_temp.userid, @group1.id)
        @widget_report_vendor_and_guest_os.make_memberof(ws_temp)
        result = @widget_report_vendor_and_guest_os.grouped_subscribers

        result.size.should eq(1)
        result[@group1].should match_array([@user1, user_temp])
      end

      it "ignores the legacy format admin|db_name" do
        ws = FactoryGirl.create(:miq_widget_set, :name => "#{@user1.userid}|Home")
        @widget_report_vendor_and_guest_os.make_memberof(ws)
        @widget_report_vendor_and_guest_os.grouped_subscribers.should be_kind_of(Hash)
        @widget_report_vendor_and_guest_os.grouped_subscribers.should be_empty
      end

      it "with multiple groups and users" do
        ws = FactoryGirl.create(:miq_widget_set, :name => "Home", :userid => @user1.userid, :group_id => @group1.id)
        @widget_report_vendor_and_guest_os.make_memberof(ws)

        users = []
        (1..3).each do |i|
          user_i = add_user("user_#{i}", @group2)
          ws_i   = add_dashboard_for_user("Home", user_i.userid, @group2.id)
          @widget_report_vendor_and_guest_os.make_memberof(ws_i)
          users << user_i
        end

        result = @widget_report_vendor_and_guest_os.grouped_subscribers

        result.size.should eq(2)
        result[@group1].should eq([@user1])
        result[@group2].should match_array(users)
      end

      def add_user(userid, group)
        FactoryGirl.create(:user, :miq_groups => [group], :name => userid, :userid => userid)
      end

      def add_dashboard_for_user(db_name, userid, group)
        FactoryGirl.create(:miq_widget_set, :name => db_name, :userid => userid, :group_id => group)
      end
    end

    context "#contents_for_user" do
      it "user owned" do
        content = FactoryGirl.create(:miq_widget_content,
                                     :miq_widget   => @widget_report_vendor_and_guest_os,
                                     :user_id       => @user1.id,
                                     :miq_group_id => @user1.current_group_id,
                                     :timezone     => "UTC",
                                    )
        @widget_report_vendor_and_guest_os.contents_for_user(@user1).should == content
      end

      it "owned by miq_group and in user's timezone" do
        @user1.settings.store_path(:display, :timezone, "Eastern Time (US & Canada)")
        content = FactoryGirl.create(:miq_widget_content,
                                     :miq_widget   => @widget_report_vendor_and_guest_os,
                                     :miq_group_id => @group1.id,
                                     :timezone     => "Eastern Time (US & Canada)"
                                    )
        @widget_report_vendor_and_guest_os.contents_for_user(@user1).should == content
      end

      it "owned by miq_group and not in user's timezone" do
        @user1.settings.store_path(:display, :timezone, "Eastern Time (US & Canada)")
        content = FactoryGirl.create(:miq_widget_content,
                                     :miq_widget   => @widget_report_vendor_and_guest_os,
                                     :miq_group_id => @group1.id,
                                     :timezone     => "UTC"
                                    )
        @widget_report_vendor_and_guest_os.contents_for_user(@user1).should be_nil
      end

      it "both user and miq_group owned" do
        content1 = FactoryGirl.create(:miq_widget_content,
                                      :miq_widget   => @widget_report_vendor_and_guest_os,
                                      :miq_group_id => @group1.id,
                                      :timezone     => "Eastern Time (US & Canada)"
                                     )
        content2 = FactoryGirl.create(:miq_widget_content,
                                      :miq_widget   => @widget_report_vendor_and_guest_os,
                                      :miq_group_id => @group1.id,
                                      :user_id      => @user1.id,
                                      :timezone     => "UTC"
                                     )
        @widget_report_vendor_and_guest_os.contents_for_user(@user1).should == content2
      end
    end

    context ".available_for_user" do
      subject { MiqWidget.available_for_user(@user) }

      it "by role" do
        @widget_report_vendor_and_guest_os.update_attributes(:visibility => {:roles => "Role2"})
        expect(MiqWidget.available_for_user(@user1).count).to eq(1)
        expect(MiqWidget.available_for_user(@user2).count).to eq(2)
      end

      it "by group" do
        @widget_report_vendor_and_guest_os.update_attributes(:visibility => {:groups => "Group2"})
        expect(MiqWidget.available_for_user(@user1).count).to eq(1)
        expect(MiqWidget.available_for_user(@user2).count).to eq(2)
      end
    end
  end

  context "#queue_generate_content" do
    before(:each) do
      MiqReport.seed_report("Top CPU Consumers weekly")

      role1 = FactoryGirl.create(:miq_user_role, :name => 'EvmRole-support')
      group1 = FactoryGirl.create(:miq_group, :description => "EvmGroup-support", :miq_user_role => role1)
      user1  = FactoryGirl.create(:user, :userid => 'user1', :miq_groups => [group1])

      @user2  = FactoryGirl.create(:user_admin)
      @group2 = @user2.current_group

      attrs = YAML.load('
        description: report_top_cpu_consumers_weekly
        title: Top CPU Consumers (weekly)
        content_type: report
        options:
          :col_order:
            - resource_name
            - ems_cluster.name
            - cpu_usage_rate_average__avg
          :row_count: 10
        visibility:
          :roles:
          - EvmRole-super_administrator
          - EvmRole-administrator
        user_id:
        resource_name: Top CPU Consumers (weekly)
        resource_type: MiqReport
        miq_schedule_options:
          :run_at:
            :interval:
              :value: "1"
              :unit: hourly
        enabled: true
        read_only: true
      ')

      ws1 = FactoryGirl.create(:miq_widget_set, :name => "default", :userid => "user1", :group_id => group1.id)
      ws2 = FactoryGirl.create(:miq_widget_set, :name => "default", :userid => "admin", :group_id => @group2.id)
      @widget = MiqWidget.sync_from_hash(attrs)
      ws1.add_member(@widget)
      ws2.add_member(@widget)

      @q_options = {:queue_name   => "reporting",
        :role         => "reporting",
        :class_name   => @widget.class.name,
        :instance_id  => @widget.id,
        :msg_timeout  => 3600
      }
    end

    it "for groups without visibility" do
      @widget.should_receive(:queue_generate_content_for_users_or_group).once
      @widget.queue_generate_content
    end

    it "for a group with visibility" do
      @widget.visibility[:roles] << "EvmRole-support"
      @widget.should_receive(:queue_generate_content_for_users_or_group).twice
      @widget.queue_generate_content
    end

    it "for all groups with visibility to all" do
      @widget.visibility[:roles] = "_ALL_"
      @widget.should_receive(:queue_generate_content_for_users_or_group).twice
      @widget.queue_generate_content
    end

    it "creates a new task when previous task is finished" do
      @widget.queue_generate_content
      MiqTask.first.state_finished
      message = MiqQueue.find(:first, :conditions => @q_options)
      message.update_attribute(:state, MiqQueue::STATE_ERROR)

      @widget.queue_generate_content
      MiqQueue.count(:conditions => @q_options).should == 2
      MiqTask.count.should == 2
    end

    it "does nothing if an active task's messages have not yet run" do
      @widget.queue_generate_content
      MiqQueue.count(:conditions => @q_options).should == 1
      MiqTask.first.state_active

      @widget.queue_generate_content
      MiqQueue.count(:conditions => @q_options).should == 1
      MiqTask.count.should == 1
    end

    it "times out active tasks without queue messages" do
      @widget.queue_generate_content
      task = MiqTask.first
      task.state_active

      message = MiqQueue.find(:first, :conditions => @q_options)
      message.destroy
      MiqQueue.count.should == 0

      @widget.queue_generate_content

      task.reload
      task.state.should == MiqTask::STATE_FINISHED
      task.status.should == MiqTask::STATUS_TIMEOUT
      MiqTask.count.should == 2
      MiqQueue.count.should == 1
    end

    it "times out active tasks with a finished message" do
      @widget.queue_generate_content
      task = MiqTask.first
      task.state_active

      message = MiqQueue.find(:first, :conditions => @q_options)
      message.update_attribute(:state, MiqQueue::STATE_ERROR)
      MiqQueue.count.should == 1

      @widget.queue_generate_content

      task.reload
      task.state.should == MiqTask::STATE_FINISHED
      task.status.should == MiqTask::STATUS_TIMEOUT
      MiqTask.count.should == 2
      MiqQueue.count.should == 2
    end

    it "finished task should not be timed out" do
      @widget.queue_generate_content
      q = MiqQueue.first
      status, message, result = q.deliver
      q.delivered(status, message, result)

      task = MiqTask.first
      task.status.should eq(MiqTask::STATUS_OK)

      @widget.queue_generate_content
      MiqQueue.first.deliver

      task.reload
      task.status.should     eq(MiqTask::STATUS_OK)
      task.status.should_not eq(MiqTask::STATUS_TIMEOUT)
    end

    it "finished task should not be re-used" do
      @widget.queue_generate_content
      q = MiqQueue.first
      status, message, result = q.deliver
      q.delivered(status, message, result)

      task = MiqTask.first
      task.pct_complete.should eq(100)

      @widget.visibility[:roles] = "_ALL_"
      new_group = FactoryGirl.create(:miq_group, :miq_user_role => FactoryGirl.create(:miq_user_role))
      new_user  = FactoryGirl.create(:user, :userid => "test task", :miq_groups => [new_group])

      @widget.create_initial_content_for_user(new_user)
      q = MiqQueue.first
      status, message, result = q.deliver
      q.delivered(status, message, result)

      task.reload
      task.state.should eq(MiqTask::STATE_FINISHED)
      task.pct_complete.should be <= 100

    end

    it "with single group" do
      @widget.queue_generate_content
      MiqQueue.count(:conditions => @q_options).should == 1
    end

    it "with multiple groups" do
      @widget.visibility[:roles] = "_ALL_"
      @widget.queue_generate_content
      MiqQueue.count(:conditions => @q_options).should == 2
    end

    it "with multiple timezones in one group" do
      user_est =  FactoryGirl.create(:user, :userid => 'user_est', :miq_groups => [@group2], :settings => {:display => {:timezone => "Eastern Time (US & Canada)"}})
      user_est.get_timezone.should == "Eastern Time (US & Canada)"
      ws = FactoryGirl.create(:miq_widget_set, :name => "default", :userid => "user_est", :group_id => @group2.id)
      ws.add_member(@widget)

      MiqWidget.any_instance.should_receive(:generate_content).with("MiqGroup", @group2.name, nil, ["Eastern Time (US & Canada)", "UTC"])
      @widget.queue_generate_content
      MiqQueue.count(:conditions => @q_options).should == 1

      MiqQueue.first.deliver
    end

    it "with report_sync" do
      VMDB::Config.any_instance.stub(:config).and_return({:product => {:report_sync => true}})

      user_est =  FactoryGirl.create(:user, :userid => 'user_est', :miq_groups => [@group2], :settings => {:display => {:timezone => "Eastern Time (US & Canada)"}})
      user_est.get_timezone.should == "Eastern Time (US & Canada)"
      ws = FactoryGirl.create(:miq_widget_set, :name => "default", :userid => "user_est", :group_id => @group2.id)
      ws.add_member(@widget)

      MiqWidget.any_instance.should_receive(:generate_content).with("MiqGroup", @group2.name, nil, ["Eastern Time (US & Canada)", "UTC"])
      @widget.queue_generate_content
      MiqQueue.count(:conditions => @q_options).should == 0
    end

    context "user's group specified in MiqWidgetSet" do
      it "single" do
        @widget.should_receive(:generate_content_options).once
        @widget.queue_generate_content
      end

      it "multiple" do
        @widget.visibility[:roles] = "_ALL_"
        new_role1 = FactoryGirl.create(:miq_user_role, :name => 'EvmRole-Operator')
        new_group1 = FactoryGirl.create(:miq_group, :description => "EvmGroup-operator", :miq_user_role => new_role1)
        new_ws1 = FactoryGirl.create(:miq_widget_set,
                                     :name     => "default",
                                     :userid   => "admin",
                                     :group_id => new_group1.id)
        new_ws1.add_member(@widget)

        new_role2 = FactoryGirl.create(:miq_user_role, :name => 'EvmRole-Approver')
        new_group2 = FactoryGirl.create(:miq_group, :description => "EvmGroup-approver", :miq_user_role => new_role2)
        new_ws2 = FactoryGirl.create(:miq_widget_set,
                                     :name     => "default",
                                     :userid   => "admin",
                                     :group_id => new_group2.id)
        new_ws2.add_member(@widget)

        call_count = 0
        @widget.stub(:generate_content_options) { |_, arg2| call_count += 1 if arg2 == [@user2] }
        @widget.queue_generate_content
        call_count.should == 3
      end

      it "none" do
        @widget.visibility[:roles] = "_ALL_"
        MiqWidgetSet.destroy_all
        user = FactoryGirl.create(:user, :userid => 'alone', :miq_groups => [@group2])
        ws = FactoryGirl.create(:miq_widget_set, :name => "default", :userid => user.userid)
        ws.add_member(@widget)

        @widget.should_receive(:generate_content_options).never
        @widget.queue_generate_content
      end
    end
  end

  context "#generate_content_options" do
    let(:widget) { described_class.new }
    let(:content_option_generator) { auto_loaded_instance_double("MiqWidget::ContentOptionGenerator") }
    let(:group) { "group" }
    let(:users) { "users" }

    before do
      MiqWidget::ContentOptionGenerator.stub(:new).and_return(content_option_generator)
      content_option_generator.stub(:generate).with(group, users).and_return("content options")
    end

    it "returns the content options" do
      widget.generate_content_options(group, users).should == "content options"
    end
  end

  context "#generate_content" do
    let(:widget) { described_class.new(:miq_task => miq_task) }
    let(:content_generator) { auto_loaded_instance_double("MiqWidget::ContentGenerator") }
    let(:klass) { "klass" }
    let(:userids) { "userids" }
    let(:timezones) { "timezones" }
    let(:group_description) { "group_description" }

    before do
      MiqWidget::ContentGenerator.stub(:new).and_return(content_generator)
      content_generator.stub(:generate).with(widget, klass, group_description, nil, timezones).and_return("widget content")
    end

    shared_examples_for "MiqWidget#generate_content that delegates to a MiqWidget::ContentGenerator" do
      it "returns the widget content" do
        widget.generate_content(klass, group_description, nil, timezones).should == "widget content"
      end
    end

    context "when there is an miq_task on the widget" do
      let(:miq_task) { MiqTask.new }

      it_behaves_like "MiqWidget#generate_content that delegates to a MiqWidget::ContentGenerator"

      it "calls state_active on the task" do
        miq_task.should_receive(:state_active)
        widget.generate_content(klass, group_description, nil, timezones)
      end
    end

    context "when there is not an miq_task on the widget" do
      let(:miq_task) { nil }

      it_behaves_like "MiqWidget#generate_content that delegates to a MiqWidget::ContentGenerator"

      it "does not attempt to call state_active on nil" do
        expect { widget.generate_content(klass, group_description, nil, timezones) }.to_not raise_error
      end
    end
  end

  context "# base model" do
    it "should default to enabled" do
      MiqWidget.new.enabled?.should be_true
    end

    it "should not default to read-only" do
      MiqWidget.new.read_only?.should be_false
    end
  end

  context "#create_initial_content_for_user" do
    before do
      self_service_role  = FactoryGirl.create(:miq_user_role, :settings => {:restrictions => {:vms => :user}})
      self_service_group = FactoryGirl.create(:miq_group, :miq_user_role => self_service_role)
      @user              = FactoryGirl.create(:user, :miq_groups => [self_service_group])
      @widget            = FactoryGirl.create(:miq_widget)
    end

    it "with single user" do
      lambda { @widget.create_initial_content_for_user(@user) }.should_not raise_error
    end
  end

  context "multiple groups" do
    let(:widget) { MiqWidget.find_by_description("chart_vendor_and_guest_os") }

    before do
      MiqReport.seed_report("Vendor and Guest OS")
      MiqWidget.seed_widget("chart_vendor_and_guest_os")

      @role   = FactoryGirl.create(:miq_user_role)
      @group  = FactoryGirl.create(:miq_group, :miq_user_role => @role)
      @user1  = FactoryGirl.create(:user,
                                   :userid     => "user1",
                                   :settings   => {:display => {:timezone => "Eastern Time (US & Canada)"}},
                                   :miq_groups => [@group])
      @user2  = FactoryGirl.create(:user,
                                   :userid     => "user2",
                                   :settings   => {:display => {:timezone => "Pacific Time (US & Canada)"}},
                                   :miq_groups => [@group])

      @ws1 = FactoryGirl.create(:miq_widget_set,
                                :name     => "HOME",
                                :userid   => @user1.userid,
                                :group_id => @group.id
                               )
      @ws2 = FactoryGirl.create(:miq_widget_set,
                                :name     => "HOME",
                                :userid   => @user2.userid,
                                :group_id => @group.id
                               )
    end

    context "for non-self service user" do
      before do
        widget.make_memberof(@ws1)
        widget.make_memberof(@ws2)
        widget.queue_generate_content
      end

      it "queued based on group/TZs of User's in the group" do
        MiqQueue.count.should eq(1)
      end

      it "contents created for each timezone of the group" do
        MiqQueue.first.deliver
        MiqWidgetContent.count.should eq(2)
        MiqWidgetContent.all.each do |content|
          content.user_id.should be_nil
          content.miq_group_id.should eq(@group.id)
          [@user1.get_timezone, @user2.get_timezone].should include(content.timezone)
        end
      end

      it "when changing to self service group" do
        MiqQueue.first.deliver
        MiqWidgetContent.all.each do |content|
          content.user_id.should be_nil
        end
        MiqQueue.destroy_all

        @role.update_attributes(:settings => {:restrictions => {:vms => :user_or_group}})
        widget.queue_generate_content
        MiqQueue.first.deliver

        MiqWidgetContent.count.should eq(2)
        MiqWidgetContent.all.each do |content|
          content.user_id.should_not be_nil
        end
      end
    end

    context "for self service user" do
      before do
        @role.update_attributes(:settings => {:restrictions => {:vms => :user}})
        widget.make_memberof(@ws1)
        widget.make_memberof(@ws2)
        widget.queue_generate_content
      end

      it "queued based on group/user" do
        MiqQueue.count.should eq(1)
      end

      it "contents created per group/user" do
        MiqQueue.first.deliver
        MiqWidgetContent.all.each do |content|
          content.user_id.should_not be_nil
          [@user1.id, @user2.id].should include(content.user_id)
          content.miq_group_id.should eq(@group.id)
          [@user1.get_timezone, @user2.get_timezone].should include(content.timezone)
        end
      end
    end

    context "for non-current self service group" do
      before do
        @role.update_attributes(:settings => {:restrictions => {:vms => :user_or_group}})
        @group2 = FactoryGirl.create(:miq_group, :miq_user_role => @role)
        @ws3    = FactoryGirl.create(:miq_widget_set,
                                     :name     => "HOME",
                                     :userid   => @user1.userid,
                                     :group_id => @group2.id
                                    )
        widget.make_memberof(@ws3)

        @user1.miq_groups = [@group, @group2]
        @user1.save

        @winos_pruduct_name = 'Windows 7 Enterprise'
        7.times do |i|
          vm = FactoryGirl.build(:vm_vmware,
                                 :name             => "vm_win_#{i}",
                                 :vendor           => "vmware",
                                 :operating_system => FactoryGirl.create(:operating_system,
                                                                         :product_name => @winos_pruduct_name,
                                                                         :name         => 'my_pc'),
                                )
          vm.miq_group_id = @group2.id
          vm.save
        end

        @rhos_product_name = 'Red Hat Enterprise Linux 6 (64-bit)'
        3.times do |i|
          vm = FactoryGirl.build(:vm_redhat,
                                 :name             => "vm_rh_#{i}",
                                 :vendor           => "redhat",
                                 :operating_system => FactoryGirl.create(:operating_system,
                                                                         :product_name => @rhos_product_name,
                                                                         :name         => 'my_linux'),
                                )
          vm.miq_group_id = @group.id
          vm.save
        end

        widget.queue_generate_content
      end

      it "widget generation got queued" do
        MiqQueue.count.should eq(1)
      end

      it "wdiget content" do
        MiqQueue.all.each(&:deliver)

        MiqWidgetContent.count.should eq(1)
        MiqWidgetContent.all.each do |content|
          content.contents.should     include(@winos_pruduct_name)
          content.contents.should_not include(@rhos_product_name)
          content.miq_report_result.html_rows.last.should include("All Rows | Count: #{Vm.where(:miq_group_id => @group2.id).count}")
        end
      end

      it "when group is deleted" do
        MiqQueue.all.each(&:deliver)
        MiqWidgetContent.count.should eq(1)

        @group2.users.destroy_all
        @group2.destroy
        MiqWidgetContent.count.should eq(0)
      end

      it "when user is deleted" do
        MiqQueue.all.each(&:deliver)
        MiqWidgetContent.count.should eq(1)

        @user1.destroy
        MiqWidgetContent.count.should eq(0)
      end
    end
  end
end
