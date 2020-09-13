RSpec.describe MiqWidget do
  before do
    EvmSpecHelper.local_miq_server
  end

  context ".seed" do
    before { MiqReport.seed }
    include_examples ".seed called multiple times"
  end

  context "setup" do
    before do
      MiqReport.seed_report("Vendor and Guest OS")

      feature1 = MiqProductFeature.find_all_by_identifier("dashboard_admin")
      @user1   = FactoryBot.create(:user, :role => "role1", :features => feature1)
      @group1  = @user1.current_group

      feature2 = MiqProductFeature.find_all_by_identifier("everything")
      @role2   = FactoryBot.create(:miq_user_role, :name => "Role2", :features => feature2)
      @group2  = FactoryBot.create(:miq_group, :description => "Group2", :miq_user_role => @role2)
      @user2   = FactoryBot.create(:user, :miq_groups => [@group2])

      @widget_report_vendor_and_guest_os = MiqWidget.sync_from_hash(YAML.load('
        description: report_vendor_and_guest_os
        title: Vendor and Guest OS
        content_type: report
        options:
          :col_order:
            - name
            - vendor_display
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

    describe "#filter_for_schedule" do
      it "returns Hash object representing valid MiqExpression" do
        exp = MiqExpression.new(@widget_chart_vendor_and_guest_os.filter_for_schedule)
        expect(exp.valid?).to be_truthy
      end
    end

    it "doesn't access database when unchanged model is saved" do
      m = FactoryBot.create(:miq_widget)
      expect { m.valid? }.not_to make_database_queries
    end

    describe "#sync_schedule" do
      let(:schedule) do
        filter = @widget_chart_vendor_and_guest_os.filter_for_schedule
        FactoryBot.create(:miq_schedule, :filter => MiqExpression.new(filter), :resource_type => "MiqWidget",
                          :name => @widget_chart_vendor_and_guest_os.name)
      end

      it "uses existing schedule if link between widget and schedule broken" do
        expect(@widget_chart_vendor_and_guest_os.miq_schedule).to be_nil
        @widget_chart_vendor_and_guest_os.sync_schedule(:run_at => schedule.run_at)

        expect(MiqSchedule.count).to eq(1)
        expect(@widget_chart_vendor_and_guest_os.miq_schedule.id).to eq(schedule.id)
      end

      it "rename existing scheduler by adding timestamp to name if existing scheduler use different filter" do
        schedule.update(:filter => MiqExpression.new("=" => {"field" => "MiqWidget-id", "value" => 9999}))

        time_now = Time.now.utc
        Timecop.freeze(time_now) { @widget_chart_vendor_and_guest_os.sync_schedule(:run_at => schedule.run_at) }
        schedule.reload

        expect(MiqSchedule.count).to eq(2)
        expect(schedule.name.end_with?(time_now.to_s)).to be_truthy
      end
    end

    context "#queue_generate_content_for_users_or_group" do
      before do
        @widget = @widget_report_vendor_and_guest_os
        @queue_conditions = {
          :method_name => "generate_content",
          :role        => "reporting",
          :queue_name  => "reporting",
          :class_name  => @widget.class.name,
          :instance_id => @widget.id,
          :msg_timeout => 3600
        }.freeze
      end

      it "admin user" do
        @widget.queue_generate_content_for_users_or_group(@user1.userid)
        expect(MiqQueue.exists?(@queue_conditions)).to be_truthy
      end

      it "array of users" do
        @widget.queue_generate_content_for_users_or_group([@user1.userid, @user2.userid])
        expect(MiqQueue.exists?(@queue_conditions)).to be_truthy
      end

      it "with a task" do
        @widget.miq_task = MiqTask.new
        @widget.queue_generate_content_for_users_or_group(@user1.userid)
        expect(MiqQueue.exists?({:method_name => "generate_content"}.merge(@queue_conditions))).to be_truthy
      end
    end

    context "#grouped_subscribers" do
      it "returns empty array when widget has no subscribers" do
        expect(@widget_report_vendor_and_guest_os.grouped_subscribers).to be_kind_of(Hash)
        expect(@widget_report_vendor_and_guest_os.grouped_subscribers).to be_empty
      end

      it "ignores the legacy format admin|db_name" do
        ws = FactoryBot.create(:miq_widget_set, :name => "#{@user1.userid}|Home")
        @widget_report_vendor_and_guest_os.make_memberof(ws)
        expect(@widget_report_vendor_and_guest_os.grouped_subscribers).to be_kind_of(Hash)
        expect(@widget_report_vendor_and_guest_os.grouped_subscribers).to be_empty
      end

      context 'with subscribers' do
        before do
          ws = FactoryBot.create(:miq_widget_set, :name => "Home", :userid => @user1.userid, :group_id => @group1.id)
          @widget_report_vendor_and_guest_os.make_memberof(ws)
        end

        it "returns non-empty array when widget has subscribers" do
          user_temp = add_user(@group1)
          ws_temp   = add_dashboard_for_user("Home", user_temp.userid, @group1.id)
          @widget_report_vendor_and_guest_os.make_memberof(ws_temp)
          result = @widget_report_vendor_and_guest_os.grouped_subscribers

          expect(result.size).to eq(1)
          expect(result[@group1]).to match_array([@user1, user_temp])
        end

        it "with multiple groups and users" do
          users = []
          (1..3).each do |_i|
            user_i = add_user(@group2)
            ws_i   = add_dashboard_for_user("Home", user_i.userid, @group2.id)
            @widget_report_vendor_and_guest_os.make_memberof(ws_i)
            users << user_i
          end

          result = @widget_report_vendor_and_guest_os.grouped_subscribers

          expect(result.size).to eq(2)
          expect(result[@group1]).to eq([@user1])
          expect(result[@group2]).to match_array(users)
        end

        it 'ignores the user that does not exist any more' do
          user_temp = add_user(@group1)
          ws_temp   = add_dashboard_for_user("Home", user_temp.userid, @group1.id)
          @widget_report_vendor_and_guest_os.make_memberof(ws_temp)

          user_temp.delete
          result = @widget_report_vendor_and_guest_os.grouped_subscribers

          expect(result.size).to eq(1)
          expect(result[@group1]).to match_array([@user1])
        end

        it 'ignores the group that has no members' do
          @user1.delete
          result = @widget_report_vendor_and_guest_os.grouped_subscribers
          expect(result.size).to eq(0)
        end

        it 'only returns groups in the current region' do
          groups = MiqGroup.where(:id => [@group1, @group2])
          expect(MiqGroup).to receive(:in_my_region).and_return(groups)
          allow(groups).to receive(:where).and_return(groups)
          @widget_report_vendor_and_guest_os.grouped_subscribers
        end
      end

      def add_user(group)
        FactoryBot.create(:user, :miq_groups => [group])
      end

      def add_dashboard_for_user(db_name, userid, group)
        FactoryBot.create(:miq_widget_set, :name => db_name, :userid => userid, :group_id => group)
      end
    end

    context "#contents_for_user" do
      it "returns user owned widget contents in UTC timezone if user's timezone not specified" do
        content = FactoryBot.create(:miq_widget_content,
                                     :miq_widget   => @widget_report_vendor_and_guest_os,
                                     :user_id      => @user1.id,
                                     :miq_group_id => @user1.current_group_id,
                                     :timezone     => "UTC",
                                    )
        expect(@widget_report_vendor_and_guest_os.contents_for_user(@user1)).to eq(content)
      end

      it "returns widget contents in user's timezone when content from different timezone also available" do
        @user1.settings.store_path(:display, :timezone, "Eastern Time (US & Canada)")
        FactoryBot.create(:miq_widget_content,
                          :miq_widget   => @widget_report_vendor_and_guest_os,
                          :miq_group_id => @group1.id,
                          :timezone     => "UTC")
        content_user_timezone = FactoryBot.create(:miq_widget_content,
                                                  :miq_widget   => @widget_report_vendor_and_guest_os,
                                                  :miq_group_id => @group1.id,
                                                  :timezone     => "Eastern Time (US & Canada)")
        expect(@widget_report_vendor_and_guest_os.contents_for_user(@user1)).to eq(content_user_timezone)
      end

      it "returns widget contents if only content available is not in user's timezone" do
        @user1.settings.store_path(:display, :timezone, "Eastern Time (US & Canada)")
        content_utc = FactoryBot.create(:miq_widget_content,
                                        :miq_widget   => @widget_report_vendor_and_guest_os,
                                        :miq_group_id => @group1.id,
                                        :timezone     => "UTC")
        expect(@widget_report_vendor_and_guest_os.contents_for_user(@user1)).to eq(content_utc)
      end

      it "both user and miq_group owned" do
        FactoryBot.create(:miq_widget_content,
                                      :miq_widget   => @widget_report_vendor_and_guest_os,
                                      :miq_group_id => @group1.id,
                                      :timezone     => "Eastern Time (US & Canada)"
                                     )
        content2 = FactoryBot.create(:miq_widget_content,
                                      :miq_widget   => @widget_report_vendor_and_guest_os,
                                      :miq_group_id => @group1.id,
                                      :user_id      => @user1.id,
                                      :timezone     => "UTC"
                                     )
        expect(@widget_report_vendor_and_guest_os.contents_for_user(@user1)).to eq(content2)
      end
    end

    context ".available_for_user" do
      subject { MiqWidget.available_for_user(@user) }

      it "by role" do
        @widget_report_vendor_and_guest_os.update(:visibility => {:roles => @group2.miq_user_role.name})
        expect(MiqWidget.available_for_user(@user1).count).to eq(1)
        expect(MiqWidget.available_for_user(@user2).count).to eq(2)
      end

      it "by group" do
        @widget_report_vendor_and_guest_os.update(:visibility => {:groups => @group2.description})
        expect(MiqWidget.available_for_user(@user1).count).to eq(1)
        expect(MiqWidget.available_for_user(@user2).count).to eq(2)
      end
    end
  end

  context "#queue_generate_content" do
    before do
      MiqReport.seed_report("Top CPU Consumers weekly")

      role1 = FactoryBot.create(:miq_user_role, :name => 'EvmRole-support')
      group1 = FactoryBot.create(:miq_group, :description => "EvmGroup-support", :miq_user_role => role1)
      user1  = FactoryBot.create(:user, :miq_groups => [group1])

      @user2  = FactoryBot.create(:user_admin)
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

      ws1 = FactoryBot.create(:miq_widget_set, :name => "default", :userid => user1.userid, :group_id => group1.id)
      ws2 = FactoryBot.create(:miq_widget_set, :name => "default", :userid => @user2.userid, :group_id => @group2.id)
      @widget = MiqWidget.sync_from_hash(attrs)
      ws1.add_member(@widget)
      ws2.add_member(@widget)

      @q_options = {:queue_name  => "reporting",
                    :role        => "reporting",
                    :zone        => nil,
                    :class_name  => @widget.class.name,
                    :instance_id => @widget.id,
                    :msg_timeout => 3600
      }
    end

    it "skips task creation and records warn message if MiqTask for generating widget content exists and not finished" do
      MiqTask.create(:name => "Generate Widget: '#{@widget.title}'", :state => "Queued", :status => "Ok", :userid => "system")
      expect($log).to receive(:warn).with(skip_message(@widget))
      @widget.queue_generate_content
    end

    it "returns MiqTask id if successful and not records warn message" do
      expect($log).not_to receive(:warn).with(skip_message(@widget))
      return_value = @widget.queue_generate_content
      expect(return_value).to equal(MiqTask.where(:name => "Generate Widget: '#{@widget.title}'",
                                                  :id   => @widget.reload.miq_task_id).first.id)
    end

    it "for groups without visibility" do
      expect(@widget).to receive(:queue_generate_content_for_users_or_group).once
      @widget.queue_generate_content
    end

    it "for a group with visibility" do
      @widget.visibility[:roles] << "EvmRole-support"
      expect(@widget).to receive(:queue_generate_content_for_users_or_group).twice
      @widget.queue_generate_content
    end

    it "for all groups with visibility to all" do
      @widget.visibility[:roles] = "_ALL_"
      expect(@widget).to receive(:queue_generate_content_for_users_or_group).twice
      @widget.queue_generate_content
    end

    it "does not generate content if visibility set to group only and there are no users in that group" do
      @widget.visibility.delete(:roles)
      @widget.visibility[:groups] = @group2.description
      @user2.delete

      expect(@widget).not_to receive(:queue_generate_content_for_users_or_group)
      @widget.queue_generate_content
    end

    it "does not generate content if content_type of widget is 'menu'" do
      @widget.update(:content_type => "menu")
      expect(@widget).not_to receive(:queue_generate_content_for_users_or_group)
      @widget.queue_generate_content
    end

    it "generate content if visibility set to group only with users in that group" do
      @widget.visibility.delete(:roles)
      @widget.visibility[:groups] = @group2.description

      expect(@widget).to receive(:queue_generate_content_for_users_or_group).once
      @widget.queue_generate_content
    end

    it "creates a new task when previous task is finished" do
      @widget.queue_generate_content
      MiqTask.first.state_finished
      message = MiqQueue.where(@q_options).first
      message.update_attribute(:state, MiqQueue::STATE_ERROR)

      @widget.queue_generate_content
      expect(MiqQueue.where(@q_options).count).to eq(2)
      expect(MiqTask.count).to eq(2)
    end

    it "does nothing if an active task's messages have not yet run" do
      @widget.queue_generate_content
      expect(MiqQueue.where(@q_options).count).to eq(1)
      MiqTask.first.state_active

      @widget.queue_generate_content
      expect(MiqQueue.where(@q_options).count).to eq(1)
      expect(MiqTask.count).to eq(1)
    end

    it "times out active tasks without queue messages" do
      @widget.queue_generate_content
      task = MiqTask.first
      task.state_active

      message = MiqQueue.where(@q_options).first
      message.destroy
      expect(MiqQueue.count).to eq(0)

      @widget.queue_generate_content

      task.reload
      expect(task.state).to eq(MiqTask::STATE_FINISHED)
      expect(task.status).to eq(MiqTask::STATUS_TIMEOUT)
      expect(MiqTask.count).to eq(2)
      expect(MiqQueue.count).to eq(1)
    end

    it "times out active tasks with a finished message" do
      @widget.queue_generate_content
      task = MiqTask.first
      task.state_active

      message = MiqQueue.where(@q_options).first
      message.update_attribute(:state, MiqQueue::STATE_ERROR)
      expect(MiqQueue.count).to eq(1)

      @widget.queue_generate_content

      task.reload
      expect(task.state).to eq(MiqTask::STATE_FINISHED)
      expect(task.status).to eq(MiqTask::STATUS_TIMEOUT)
      expect(MiqTask.count).to eq(2)
      expect(MiqQueue.count).to eq(2)
    end

    it "finished task should not be timed out" do
      @widget.queue_generate_content
      q = MiqQueue.first
      status, message, result = q.deliver
      q.delivered(status, message, result)

      task = MiqTask.first
      expect(task.status).to eq(MiqTask::STATUS_OK)

      @widget.queue_generate_content
      MiqQueue.first.deliver

      task.reload
      expect(task.status).to     eq(MiqTask::STATUS_OK)
      expect(task.status).not_to eq(MiqTask::STATUS_TIMEOUT)
    end

    it "finished task should not be re-used" do
      @widget.queue_generate_content
      q = MiqQueue.first
      status, message, result = q.deliver
      q.delivered(status, message, result)

      task = MiqTask.first
      expect(task.pct_complete).to eq(100)

      @widget.visibility[:roles] = "_ALL_"
      new_user  = FactoryBot.create(:user, :userid => "test task", :role => "random")

      @widget.create_initial_content_for_user(new_user)
      q = MiqQueue.first
      status, message, result = q.deliver
      q.delivered(status, message, result)

      task.reload
      expect(task.state).to eq(MiqTask::STATE_FINISHED)
      expect(task.pct_complete).to be <= 100
    end

    it "with single group" do
      @widget.queue_generate_content
      expect(MiqQueue.where(@q_options).count).to eq(1)
    end

    it "with multiple groups" do
      @widget.visibility[:roles] = "_ALL_"
      @widget.queue_generate_content
      expect(MiqQueue.where(@q_options).count).to eq(2)
    end

    it "with multiple timezones in one group" do
      user_est =  FactoryBot.create(:user, :userid => 'user_est', :miq_groups => [@group2], :settings => {:display => {:timezone => "Eastern Time (US & Canada)"}})
      expect(user_est.get_timezone).to eq("Eastern Time (US & Canada)")
      ws = FactoryBot.create(:miq_widget_set, :name => "default", :userid => "user_est", :group_id => @group2.id)
      ws.add_member(@widget)

      expect_any_instance_of(MiqWidget).to receive(:generate_content).with("MiqGroup", @group2.name, nil, ["Eastern Time (US & Canada)", "UTC"])
      @widget.queue_generate_content
      expect(MiqQueue.where(@q_options).count).to eq(1)

      MiqQueue.first.deliver
    end

    it "with report_sync" do
      user_est =  FactoryBot.create(:user, :userid => 'user_est', :miq_groups => [@group2], :settings => {:display => {:timezone => "Eastern Time (US & Canada)"}})
      expect(user_est.get_timezone).to eq("Eastern Time (US & Canada)")
      ws = FactoryBot.create(:miq_widget_set, :name => "default", :userid => "user_est", :group_id => @group2.id)
      ws.add_member(@widget)

      expect_any_instance_of(MiqWidget).to receive(:generate_content).with("MiqGroup", @group2.name, nil,
                                                                           ["Eastern Time (US & Canada)"])

      stub_settings(:server  => {:timezone => "Eastern Time (US & Canada)"},
                    :product => {:report_sync => true})
      @widget.queue_generate_content
      expect(MiqQueue.where(@q_options).count).to eq(0)
    end

    context "user's group specified in MiqWidgetSet" do
      it "single" do
        expect(@widget).to receive(:generate_content_options).once
        @widget.queue_generate_content
      end

      it "multiple" do
        @widget.visibility[:roles] = "_ALL_"
        new_group1 = FactoryBot.create(:miq_group, :role => "operator")
        new_ws1 = FactoryBot.create(:miq_widget_set,
                                     :name     => "default",
                                     :userid   => @user2.userid,
                                     :group_id => new_group1.id)
        new_ws1.add_member(@widget)

        new_group2 = FactoryBot.create(:miq_group, :role => "approver")
        new_ws2 = FactoryBot.create(:miq_widget_set,
                                     :name     => "default",
                                     :userid   => @user2.userid,
                                     :group_id => new_group2.id)
        new_ws2.add_member(@widget)

        call_count = 0
        allow(@widget).to receive(:generate_content_options) { |_, arg2| call_count += 1 if arg2 == [@user2] }
        @widget.queue_generate_content
        expect(call_count).to eq(3)
      end

      it "none" do
        @widget.visibility[:roles] = "_ALL_"
        MiqWidgetSet.destroy_all
        user = FactoryBot.create(:user, :userid => 'alone', :miq_groups => [@group2])
        ws = FactoryBot.create(:miq_widget_set, :name => "default", :userid => user.userid)
        ws.add_member(@widget)

        expect(@widget).to receive(:generate_content_options).never
        @widget.queue_generate_content
      end
    end
  end

  context "#generate_content_options" do
    let(:widget) { described_class.new }
    let(:content_option_generator) { double("MiqWidget::ContentOptionGenerator") }
    let(:group) { "group" }
    let(:users) { "users" }

    before do
      allow(MiqWidget::ContentOptionGenerator).to receive(:new).and_return(content_option_generator)
      allow(content_option_generator).to receive(:generate).with(group, users, true).and_return("content options")
    end

    it "returns the content options" do
      expect(widget.generate_content_options(group, users)).to eq("content options")
    end
  end

  context "#generate_content" do
    let(:widget) { described_class.new(:miq_task => miq_task, :content_type => "report", :title => "title", :description => "foo") }
    let(:content_generator) { double("MiqWidget::ContentGenerator") }
    let(:klass) { "klass" }
    let(:userids) { "userids" }
    let(:timezones) { "timezones" }
    let(:group_description) { "group_description" }

    before do
      allow(MiqWidget::ContentGenerator).to receive(:new).and_return(content_generator)
      allow(content_generator).to receive(:generate).with(widget, klass, group_description, nil, timezones).and_return("widget content")
    end

    shared_examples_for "MiqWidget#generate_content that delegates to a MiqWidget::ContentGenerator" do
      it "returns the widget content" do
        expect(widget.generate_content(klass, group_description, nil, timezones)).to eq("widget content")
      end
    end

    context "when there is an miq_task on the widget" do
      let(:miq_task) { MiqTask.new }

      it_behaves_like "MiqWidget#generate_content that delegates to a MiqWidget::ContentGenerator"

      it "calls state_active on the task" do
        expect(miq_task).to receive(:state_active)
        widget.generate_content(klass, group_description, nil, timezones)
      end
    end

    context "when there is not an miq_task on the widget" do
      let(:miq_task) { nil }

      it_behaves_like "MiqWidget#generate_content that delegates to a MiqWidget::ContentGenerator"

      it "does not attempt to call state_active on nil" do
        expect { widget.generate_content(klass, group_description, nil, timezones) }.to_not raise_error
      end

      it "does not generate content if content_type of widget is 'menu'" do
        widget.update(:content_type => "menu")
        expect(content_generator).not_to receive(:generate)
        widget.generate_content(klass, group_description, nil, timezones)
      end

      it "does not generate content if content_type of widget is not 'menu'" do
        expect(content_generator).to receive(:generate)
        widget.generate_content(klass, group_description, nil, timezones)
      end
    end
  end

  context "# base model" do
    it "should default to enabled" do
      expect(MiqWidget.new.enabled?).to be_truthy
    end

    it "should not default to read-only" do
      expect(MiqWidget.new.read_only?).to be_falsey
    end
  end

  context "#create_initial_content_for_user" do
    before do
      self_service_role  = FactoryBot.create(:miq_user_role, :settings => {:restrictions => {:vms => :user}})
      self_service_group = FactoryBot.create(:miq_group, :miq_user_role => self_service_role)
      @user              = FactoryBot.create(:user, :miq_groups => [self_service_group])
      @widget            = FactoryBot.create(:miq_widget)
    end

    it "with single user" do
      expect { @widget.create_initial_content_for_user(@user) }.not_to raise_error
    end

    it "skips task creation and record warn message if MiqTask for generating widget content exists and not finished" do
      MiqTask.create(:name => "Generate Widget: '#{@widget.title}'", :state => "Queued", :status => "Ok", :userid => @user.userid)
      allow(@widget).to receive(:contents_for_user).and_return(nil)
      expect($log).to receive(:warn).with(skip_message(@widget))
      @widget.create_initial_content_for_user(@user)
    end
  end

  context "multiple groups" do
    let(:widget) { MiqWidget.find_by(:description => "chart_vendor_and_guest_os") }

    before do
      MiqReport.seed_report("Vendor and Guest OS")
      MiqWidget.seed_widget("chart_vendor_and_guest_os")

      # tests are written for timezone_matters = true
      widget.options[:timezone_matters] = true if widget.options
      @role   = FactoryBot.create(:miq_user_role)
      @group  = FactoryBot.create(:miq_group, :miq_user_role => @role)
      @user1  = FactoryBot.create(:user,
                                   :settings   => {:display => {:timezone => "Eastern Time (US & Canada)"}},
                                   :miq_groups => [@group])
      @user2  = FactoryBot.create(:user,
                                   :settings   => {:display => {:timezone => "Pacific Time (US & Canada)"}},
                                   :miq_groups => [@group])

      @ws1 = FactoryBot.create(:miq_widget_set,
                                :name     => "HOME",
                                :userid   => @user1.userid,
                                :group_id => @group.id
                               )
      @ws2 = FactoryBot.create(:miq_widget_set,
                                :name     => "HOME",
                                :userid   => @user2.userid,
                                :group_id => @group.id
                               )
    end

    context "for non-self service user" do
      before do
        widget.make_memberof(@ws1)
        widget.make_memberof(@ws2)
      end

      it "queued based on group/TZs of User's in the group" do
        widget.queue_generate_content
        expect(MiqQueue.count).to eq(1)
      end

      it "contents created for each timezone of the group" do
        widget.queue_generate_content
        MiqQueue.first.deliver
        expect(MiqWidgetContent.count).to eq(2)
        MiqWidgetContent.all.each do |content|
          expect(content.user_id).to be_nil
          expect(content.miq_group_id).to eq(@group.id)
          expect([@user1.get_timezone, @user2.get_timezone]).to include(content.timezone)
        end
      end

      it "contents created for one timezone per group with timezone_matters = false" do
        widget.options = {:timezone_matters => false }
        widget.queue_generate_content
        MiqQueue.first.deliver
        expect(MiqWidgetContent.count).to eq(1)
        MiqWidgetContent.all.each do |content|
          expect(content.user_id).to be_nil
          expect(content.miq_group_id).to eq(@group.id)
          expect(content.timezone).to eq("UTC")
        end
      end

      it "when changing to self service group" do
        widget.queue_generate_content
        MiqQueue.first.deliver
        MiqWidgetContent.all.each do |content|
          expect(content.user_id).to be_nil
        end
        MiqQueue.destroy_all

        @role.update(:settings => {:restrictions => {:vms => :user_or_group}})
        widget.queue_generate_content
        MiqQueue.first.deliver

        expect(MiqWidgetContent.count).to eq(2)
        MiqWidgetContent.all.each do |content|
          expect(content.user_id).not_to be_nil
        end
      end
    end

    context "for self service user" do
      before do
        @role.update(:settings => {:restrictions => {:vms => :user}})
        widget.make_memberof(@ws1)
        widget.make_memberof(@ws2)
        widget.queue_generate_content
      end

      it "queued based on group/user" do
        expect(MiqQueue.count).to eq(1)
      end

      it "contents created per group/user" do
        MiqQueue.first.deliver
        MiqWidgetContent.all.each do |content|
          expect(content.user_id).not_to be_nil
          expect([@user1.id, @user2.id]).to include(content.user_id)
          expect(content.miq_group_id).to eq(@group.id)
          expect([@user1.get_timezone, @user2.get_timezone]).to include(content.timezone)
        end
      end
    end

    context "for non-current self service group" do
      before do
        @role.update(:settings => {:restrictions => {:vms => :user_or_group}})
        @group2 = FactoryBot.create(:miq_group, :miq_user_role => @role)
        @ws3    = FactoryBot.create(:miq_widget_set,
                                     :name     => "HOME",
                                     :userid   => @user1.userid,
                                     :group_id => @group2.id
                                    )
        widget.make_memberof(@ws3)

        @user1.miq_groups = [@group, @group2]
        @user1.save

        @winos_pruduct_name = 'Windows 7 Enterprise'
        7.times do |i|
          vm = FactoryBot.build(:vm_vmware,
                                 :name             => "vm_win_#{i}",
                                 :vendor           => "vmware",
                                 :operating_system => FactoryBot.create(:operating_system,
                                                                         :product_name => @winos_pruduct_name,
                                                                         :name         => 'my_pc'),
                                )
          vm.miq_group_id = @group2.id
          vm.save
        end

        @rhos_product_name = 'Red Hat Enterprise Linux 6 (64-bit)'
        3.times do |i|
          vm = FactoryBot.build(:vm_redhat,
                                 :name             => "vm_rh_#{i}",
                                 :vendor           => "redhat",
                                 :operating_system => FactoryBot.create(:operating_system,
                                                                         :product_name => @rhos_product_name,
                                                                         :name         => 'my_linux'),
                                )
          vm.miq_group_id = @group.id
          vm.save
        end

        widget.queue_generate_content
      end

      it "widget generation got queued" do
        expect(MiqQueue.count).to eq(1)
      end

      it "wdiget content" do
        MiqQueue.all.each(&:deliver)

        expect(MiqWidgetContent.count).to eq(1)
        MiqWidgetContent.all.each do |content|
          expect(content.contents).to     include(@winos_pruduct_name)
          expect(content.contents).not_to include(@rhos_product_name)
          expect(content.miq_report_result.html_rows.last).to include("All Rows | Count: #{Vm.where(:miq_group_id => @group2.id).count}")
        end
      end

      it "when group is deleted" do
        MiqQueue.all.each(&:deliver)
        expect(MiqWidgetContent.count).to eq(1)

        @group2.users.destroy_all
        @group2.destroy
        expect(MiqWidgetContent.count).to eq(0)
      end

      it "when user is deleted" do
        MiqQueue.all.each(&:deliver)
        expect(MiqWidgetContent.count).to eq(1)

        @user1.destroy
        expect(MiqWidgetContent.count).to eq(0)
      end
    end
  end

  describe "#queued_at" do
    it "is nil when no task" do
      widget = FactoryBot.build(:miq_widget)
      expect(widget.queued_at).to be_nil
    end

    it "uses task value" do
      dt = Time.now.utc
      widget = FactoryBot.build(:miq_widget, :miq_task => FactoryBot.build(:miq_task, :created_on => dt))
      expect(widget.queued_at).to eq(dt)
    end
  end

  describe "#status_message" do
    it "is nil when no task" do
      widget = FactoryBot.build(:miq_widget)
      expect(widget.status_message).to eq("Unknown")
    end

    it "uses task value" do
      widget = FactoryBot.build(:miq_widget, :miq_task => FactoryBot.build(:miq_task, :message => "message"))
      expect(widget.status_message).to eq("message")
    end
  end
end

RSpec::Matchers.define :skip_message do |widget|
  match { |actual| actual.include?("Skipping task creation for widget content generation. Task with name \"Generate Widget: '#{widget.title}' already exists\"") }
end
