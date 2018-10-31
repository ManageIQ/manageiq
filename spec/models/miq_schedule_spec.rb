describe MiqSchedule do
  before { EvmSpecHelper.create_guid_miq_server_zone }
  context 'with schedule infrastructure and valid run_ats' do
    before do
      @valid_run_ats =  [{:start_time => "2010-07-08 04:10:00 Z", :interval => {:unit => "daily", :value => "1"}},
                         {:start_time => "2010-07-08 04:10:00 Z", :interval => {:unit => "once"}}]
    end

    it "hourly schedule" do
      run_at = {:interval => {:value => "1", :unit => "hourly"}, :start_time => "2012-03-10 01:35:00 Z", :tz => "Central Time (US & Canada)"}

      hourly_schedule = FactoryGirl.create(:miq_schedule_validation, :run_at => run_at)
      current = Time.parse("Sat March 10 3:00:00 -0600 2012") # CST
      Timecop.travel(current) do
        time = hourly_schedule.next_interval_time
        expect(time.zone).to eq("CST")
        expect(time.hour).to eq(3)
        expect(time.min).to eq(35)
        expect(time.month).to eq(3)
        expect(time.day).to eq(10)
        expect(time.year).to eq(2012)
      end
    end

    it "hourly schedule, going from CST -> CDT" do
      run_at = {:interval => {:value => "1", :unit => "hourly"}, :start_time => "2012-03-11 01:35:00 Z", :tz => "Central Time (US & Canada)"}

      hourly_schedule = FactoryGirl.create(:miq_schedule_validation, :run_at => run_at)
      current = Time.parse("Sun March 11 3:00:00 -0500 2012") # CDT
      Timecop.travel(current) do
        time = hourly_schedule.next_interval_time
        expect(time.zone).to eq("CDT")
        expect(time.hour).to eq(3)
        expect(time.min).to eq(35)
        expect(time.month).to eq(3)
        expect(time.day).to eq(11)
        expect(time.year).to eq(2012)
      end
    end

    it "next_interval_time for start of every month" do
      start_time = Time.parse("2012-01-01 08:30:00 Z")
      start_of_every_month = FactoryGirl.create(:miq_schedule_validation, :run_at => {:start_time => start_time, :interval => {:unit => "monthly", :value => "1"}})
      Timecop.travel(start_of_every_month.run_at[:start_time] - 5.minutes) do
        time = start_of_every_month.next_interval_time
        expect(time.month).to eq(start_time.month)
        expect(time.day).to eq(start_time.day)
      end

      Timecop.travel(start_of_every_month.run_at[:start_time] + 5.minutes) do
        time = start_of_every_month.next_interval_time
        expect(time.month).to eq((start_time + 1.month).month)
        expect(time.day).to eq(start_time.day)
      end
    end

    it "next_interval_time for start of every month for a very old start time" do
      start_of_every_month = FactoryGirl.create(:miq_schedule_validation, :run_at => {:start_time => "2005-01-01 08:30:00 Z", :interval => {:unit => "monthly", :value => "1"}})
      Timecop.travel(Time.parse("2013-01-01 08:31:00 UTC")) do
        time = start_of_every_month.next_interval_time
        expect(time.month).to eq(2)
        expect(time.day).to eq(1)
        expect(time.year).to eq(2013)
      end
    end

    it "next_interval_time for end of every month" do
      end_of_every_month = FactoryGirl.create(:miq_schedule_validation, :run_at => {:start_time => "2012-01-31 08:30:00 Z", :interval => {:unit => "monthly", :value => "1"}})
      Timecop.travel(end_of_every_month.run_at[:start_time] - 5.minutes) do
        time = end_of_every_month.next_interval_time
        expect(time.month).to eq(1)
        expect(time.day).to eq(31)
      end

      Timecop.travel(end_of_every_month.run_at[:start_time] + 5.minutes) do
        time = end_of_every_month.next_interval_time
        expect(time.month).to eq(2)
        expect(time.day).to eq(29)
      end
    end

    it "next_interval_time for end of every month for a very old start time" do
      end_of_every_month = FactoryGirl.create(:miq_schedule_validation, :run_at => {:start_time => "2005-01-31 08:30:00 Z", :interval => {:unit => "monthly", :value => "1"}})
      Timecop.travel(Time.parse("2013-01-31 08:31:00 UTC")) do
        time = end_of_every_month.next_interval_time
        expect(time.month).to eq(2)
        expect(time.day).to eq(28)
        expect(time.year).to eq(2013)
      end
    end

    it "next_interval_time for the 30th of every month" do
      end_of_every_month = FactoryGirl.create(:miq_schedule_validation, :run_at => {:start_time => "2012-01-30 08:30:00 Z", :interval => {:unit => "monthly", :value => "1"}})
      Timecop.travel(end_of_every_month.run_at[:start_time] - 5.minutes) do
        time = end_of_every_month.next_interval_time
        expect(time.month).to eq(1)
        expect(time.day).to eq(30)
      end

      Timecop.travel(end_of_every_month.run_at[:start_time] + 5.minutes) do
        time = end_of_every_month.next_interval_time
        expect(time.month).to eq(2)
        expect(time.day).to eq(29)
      end
    end

    it "next_interval_time for start of every two months" do
      start_of_every_two_months = FactoryGirl.create(:miq_schedule_validation, :run_at => {:start_time => "2012-01-01 08:30:00 Z", :interval => {:unit => "monthly", :value => "2"}})
      Timecop.travel(start_of_every_two_months.run_at[:start_time] + 5.minutes) do
        time = start_of_every_two_months.next_interval_time
        expect(time.month).to eq(3)
        expect(time.day).to eq(1)
      end
    end

    it "next_interval_time for end of every two months" do
      end_of_every_two_months = FactoryGirl.create(:miq_schedule_validation, :run_at => {:start_time => "2012-01-31 08:30:00 Z", :interval => {:unit => "monthly", :value => "2"}})
      Timecop.travel(end_of_every_two_months.run_at[:start_time] + 5.minutes) do
        time = end_of_every_two_months.next_interval_time
        expect(time.month).to eq(3)
        expect(time.day).to eq(31)
      end
    end

    context "with valid schedules" do
      before do
        @valid_schedules = []

        @valid_run_ats.each do |run_at|
          @valid_schedules << FactoryGirl.create(:miq_schedule_validation, :run_at => run_at)
        end
        @first = @valid_schedules.first
      end

      it "should be invalid with run_at missing" do
        @first.run_at = nil
        expect(@first.valid?).not_to be_truthy
      end

      it "should be invalid with run_at :start_time missing" do
        @first.run_at = {:interval => {:unit => "daily", :value => "1"}}
        expect(@first.valid?).not_to be_truthy
      end

      it "should be invalid with run_at :interval missing" do
        @first.run_at = {:start_time => "2010-07-08 04:10:00 Z"}
        expect(@first.valid?).not_to be_truthy
      end

      it "should be invalid with run_at :interval :unit missing" do
        @first.run_at = {:start_time => "2010-07-08 04:10:00 Z", :interval => {:value => "1"}}
        expect(@first.valid?).not_to be_truthy
      end

      it "should be invalid with run_at :interval :value missing" do
        @first.run_at = {:start_time => "2010-07-08 04:10:00 Z", :interval => {:unit => "daily"}}
        expect(@first.valid?).not_to be_truthy
      end

      it "should be valid with a valid run_at daily" do
        @first.run_at = {:start_time => "2010-07-08 04:10:00 Z", :interval => {:unit => "daily", :value => "1"}}
        expect(@first.valid?).to be_truthy
      end

      it "should be valid with a valid run_at once" do
        @first.run_at = {:start_time => "2010-07-08 04:10:00 Z", :interval => {:unit => "once"}}
        expect(@first.valid?).to be_truthy
      end

      context "at 1 AM EST create start_time and tz based on Eastern Time" do
        before do
          @start = Time.parse("Sun March 10 01:00:00 -0500 2010")
          Timecop.travel(@start + 10.minutes)
          @east_tz = "Eastern Time (US & Canada)"
          @first.update_attribute(:run_at, :start_time => @start.dup.utc, :interval => {:unit => "daily", :value => "1"}, :tz => @east_tz)
        end

        after do
          Timecop.return
        end

        it "should have start_time with start hour of 1 AM in Eastern Time" do
          expect(@first.run_at[:start_time].in_time_zone(@east_tz).hour).to eq(1)
        end

        it "should have next_interval_time hour of 1 AM in Eastern Time " do
          expect(@first.next_interval_time.in_time_zone(@east_tz).hour).to eq(1)
        end

        context "after jumping to 1 AM EDT" do
          before do
            @start = Time.parse("Sun March 15 01:00:00 -0400 2010")
            Timecop.travel(@start + 10.minutes)
          end

          after do
            Timecop.return
          end

          it "should have start_time with start hour of 1 AM in Eastern Time" do
            expect(@first.run_at[:start_time].in_time_zone(@east_tz).hour).to eq(1)
          end

          it "should have next_interval_time hour of 1 AM in Eastern Time" do
            expect(@first.next_interval_time.in_time_zone(@east_tz).hour).to eq(1)
          end
        end
      end

      context "at 1 AM EDT create start_time and tz based on Eastern Time" do
        before do
          @start = Time.parse("Sun October 6 01:00:00 -0400 2010")
          @east_tz = "Eastern Time (US & Canada)"
          Timecop.travel(@start + 10.minutes)
          @first.update_attribute(:run_at, :start_time => @start.dup.utc, :interval => {:unit => "daily", :value => "1"}, :tz => @east_tz)
        end

        after do
          Timecop.return
        end

        it "should have start_time with start hour of 1 AM in Eastern Time" do
          expect(@first.run_at[:start_time].in_time_zone(@east_tz).hour).to eq(1)
        end

        it "should have next_interval_time hour of 1 AM in Eastern Time " do
          expect(@first.next_interval_time.in_time_zone(@east_tz).hour).to eq(1)
        end

        context "after jumping to 1 AM EST" do
          before do
            @start = Time.parse("Sun November 7 01:00:00 -0500 2010")
            Timecop.travel(@start + 10.minutes)
          end

          after do
            Timecop.return
          end

          it "should have start_time with start hour of 1 AM in Eastern Time" do
            expect(@first.run_at[:start_time].in_time_zone(@east_tz).hour).to eq(1)
          end

          it "should have next_interval_time hour of 1 AM in Eastern Time" do
            expect(@first.next_interval_time.in_time_zone(@east_tz).hour).to eq(1)
          end
        end
      end

      context "at 1 AM EST create start_time and tz based on UTC" do
        before do
          @start = Time.parse("Sun March 10 01:00:00 -0500 2010")
          @east_tz = "Eastern Time (US & Canada)"
          @utc_tz  = "UTC"
          Timecop.travel(@start + 10.minutes)
          @first.update_attribute(:run_at, :start_time => @start.dup.utc, :interval => {:unit => "daily", :value => "1"})
        end

        after do
          Timecop.return
        end

        it "should have start_time with start hour of 1 AM in Eastern Time" do
          expect(@first.run_at[:start_time].in_time_zone(@east_tz).hour).to eq(1)
        end

        it "should have next_interval_time hour of 1 AM in Eastern Time " do
          expect(@first.next_interval_time.in_time_zone(@east_tz).hour).to eq(1)
        end

        it "should have start_time with start hour of 6 AM in UTC" do
          expect(@first.run_at[:start_time].in_time_zone(@utc_tz).hour).to eq(6)
        end

        it "should have next_interval_time hour of 6 AM in UTC" do
          expect(@first.next_interval_time.in_time_zone(@utc_tz).hour).to eq(6)
        end

        context "after jumping to 1 AM EDT" do
          before do
            @start = Time.parse("Sun March 15 01:00:00 -0400 2010")
            Timecop.travel(@start + 10.minutes)
          end

          after do
            Timecop.return
          end

          it "should have start_time with start hour of 1 AM in Eastern Time" do
            expect(@first.run_at[:start_time].in_time_zone(@east_tz).hour).to eq(1)
          end

          it "should have next_interval_time hour of 2 AM in Eastern Time " do
            expect(@first.next_interval_time.in_time_zone(@east_tz).hour).to eq(2)
          end

          it "should have start_time with start hour of 6 AM in UTC" do
            expect(@first.run_at[:start_time].in_time_zone(@utc_tz).hour).to eq(6)
          end

          it "should have next_interval_time hour of 6 AM in UTC" do
            expect(@first.next_interval_time.in_time_zone(@utc_tz).hour).to eq(6)
          end
        end
      end

      context "at 1 AM AKDT create start_time and tz based on Alaska time and interval every 3 days" do
        before do
          @east_tz = "Eastern Time (US & Canada)"
          @ak_tz = "Alaska"
          @utc_tz  = "UTC"
          # Tue, 06 Oct 2010 01:00:00 AKDT -08:00
          @ak_time = Time.parse("Sun October 6 01:00:00 -0800 2010")
          Timecop.travel(@ak_time + 10.minutes)
          @first.update_attribute(:run_at, :start_time => @ak_time.dup.utc, :interval => {:unit => "daily", :value => "3"}, :tz => @ak_tz)
        end

        after do
          Timecop.return
        end

        it "should have start_time with start hour of 1 AM in Alaska Time" do
          expect(@first.run_at[:start_time].in_time_zone(@ak_tz).hour).to eq(1)
        end

        it "should have next_interval_time hour of 1 AM in Alaska Time " do
          expect(@first.next_interval_time.in_time_zone(@ak_tz).hour).to eq(1)
        end

        it "should have start_time with start hour of 5 AM in Eastern Time" do
          expect(@first.run_at[:start_time].in_time_zone(@east_tz).hour).to eq(5)
        end

        it "should have next_interval_time hour of 5 AM in Eastern Time " do
          expect(@first.next_interval_time.in_time_zone(@east_tz).hour).to eq(5)
        end

        it "should have next_interval_time in 3 days" do
          expect(@first.next_interval_time.in_time_zone(@ak_tz)).to eq(Time.parse("Fri October 9 01:00:00 -0800 2010").in_time_zone(@ak_tz))
        end

        context "after jumping to EST" do
          before do
            @start = Time.parse("Sun November 7 01:00:00 -0500 2010")
            Timecop.travel(@start + 10.minutes)
          end

          after do
            Timecop.return
          end

          it "should have start_time with start hour of 1 AM in Alaska Time" do
            expect(@first.run_at[:start_time].in_time_zone(@ak_tz).hour).to eq(1)
          end

          it "should have next_interval_time hour of 1 AM in Alaska Time " do
            expect(@first.next_interval_time.in_time_zone(@ak_tz).hour).to eq(1)
          end

          it "should have start_time with start hour of 5 AM in Eastern Time" do
            expect(@first.run_at[:start_time].in_time_zone(@east_tz).hour).to eq(5)
          end

          it "should have next_interval_time hour of 5 AM in Eastern Time " do
            expect(@first.next_interval_time.in_time_zone(@east_tz).hour).to eq(5)
          end
        end
      end

      context "with Time.now stubbed as 'Jan 1 2011' at 6 am UTC" do
        before do
          @now = Time.parse("2011-01-01 06:00:00 Z")
          Timecop.travel(@now)
        end

        after do
          Timecop.return
        end

        context "with no last run time" do
          before do
            @first.update_attribute(:last_run_on, nil)
          end

          it "should return next interval 'today at 8am UTC' in localtime if start_time is in the past at '8am UTC' with interval daily 1" do
            @first.update_attribute(:run_at, :start_time => '2010-12-02 08:00:00 Z', :interval => {:unit => "daily", :value => "1"})
            expected = Time.parse('2011-01-01 08:00:00 Z').localtime
            expect(@first.next_interval_time).to eq(expected)
          end

          it "should return next interval 'tomorrow at 5am UTC' in localtime if start_time is in the past at '5am UTC' with interval daily 1" do
            @first.update_attribute(:run_at, :start_time => '2010-12-02 05:00:00 Z', :interval => {:unit => "daily", :value => "1"})
            expected = Time.parse('2011-01-02 05:00:00 Z').localtime
            expect(@first.next_interval_time).to eq(expected)
          end

          it "should return next interval 'today at 7am UTC' in localtime if start_time is in the past at '8am UTC' with interval hourly 1" do
            @first.update_attribute(:run_at, :start_time => '2010-12-02 08:00:00 Z', :interval => {:unit => "hourly", :value => "1"})
            expected = Time.parse('2011-01-01 07:00:00 Z').localtime
            expect(@first.next_interval_time).to eq(expected)
          end

          it "should return next interval 'at the future date' in localtime if start_time is in the future with interval daily 1" do
            @first.update_attribute(:run_at, :start_time => '2011-01-25 05:00:00 Z', :interval => {:unit => "daily", :value => "1"})
            expected = Time.parse('2011-01-25 05:00:00 Z').localtime
            expect(@first.next_interval_time).to eq(expected)
          end

          it "should return next interval 'at the future date' in localtime if start_time is in the future with interval hourly 1" do
            @first.update_attribute(:run_at, :start_time => '2011-01-25 05:00:00 Z', :interval => {:unit => "hourly", :value => "1"})
            expected = Time.parse('2011-01-25 05:00:00 Z').localtime
            expect(@first.next_interval_time).to eq(expected)
          end
        end

        context "with last run time 20 minutes ago" do
          before do
            time = @now - 20.minutes
            @first.update_attribute(:last_run_on, time)
          end

          it "should return next interval 'today at 8am UTC' in localtime if start_time is in the past at '8am UTC' with interval daily 1" do
            @first.update_attribute(:run_at, :start_time => '2010-12-02 08:00:00 Z', :interval => {:unit => "daily", :value => "1"})
            expected = Time.parse('2011-01-01 08:00:00 Z').localtime
            expect(@first.next_interval_time).to eq(expected)
          end

          it "should return next interval 'tomorrow at 5am UTC' in localtime if start_time is in the past at '5am UTC' with interval daily 1" do
            @first.update_attribute(:run_at, :start_time => '2010-12-02 05:00:00 Z', :interval => {:unit => "daily", :value => "1"})
            expected = Time.parse('2011-01-02 05:00:00 Z').localtime
            expect(@first.next_interval_time).to eq(expected)
          end

          it "should return next interval 'today at 8am UTC' in localtime if start_time is in the past at '8am UTC' with interval daily 5" do
            @first.update_attribute(:run_at, :start_time => '2010-12-02 08:00:00 Z', :interval => {:unit => "daily", :value => "5"})
            expected = Time.parse('2011-01-01 08:00:00 Z').localtime
            expect(@first.next_interval_time).to eq(expected)
          end

          it "should return next interval 'in 5 days at 5am UTC' in localtime if start_time is in the past at '5am UTC' with interval daily 5" do
            @first.update_attribute(:run_at, :start_time => '2010-12-02 05:00:00 Z', :interval => {:unit => "daily", :value => "5"})
            expected = Time.parse('2011-01-06 05:00:00 Z').localtime
            expect(@first.next_interval_time).to eq(expected)
          end

          it "should return next interval 'today at 7am UTC' in localtime if start_time is in the past at '8am UTC' with interval hourly 1" do
            @first.update_attribute(:run_at, :start_time => '2010-12-02 08:00:00 Z', :interval => {:unit => "hourly", :value => "1"})
            expected = Time.parse('2011-01-01 07:00:00 Z').localtime
            expect(@first.next_interval_time).to eq(expected)
          end

          it "should return next interval 'today at 8am UTC' in localtime if start_time is in the past at '8am UTC' with interval hourly 5" do
            @first.update_attribute(:run_at, :start_time => '2010-12-02 08:00:00 Z', :interval => {:unit => "hourly", :value => "5"})
            expected = Time.parse('2011-01-01 08:00:00 Z').localtime
            expect(@first.next_interval_time).to eq(expected)
          end

          it "should return next interval 'today at 10am UTC' in localtime if start_time is in the past at '5am UTC' with interval hourly 5" do
            @first.update_attribute(:run_at, :start_time => '2010-12-02 05:00:00 Z', :interval => {:unit => "hourly", :value => "5"})
            expected = Time.parse('2011-01-01 10:00:00 Z').localtime
            expect(@first.next_interval_time).to eq(expected)
          end

          it "should return next interval 'at the future date' in localtime if start_time is in the future with interval daily 1" do
            @first.update_attribute(:run_at, :start_time => '2011-01-25 05:00:00 Z', :interval => {:unit => "daily", :value => "1"})
            expected = Time.parse('2011-01-25 05:00:00 Z').localtime
            expect(@first.next_interval_time).to eq(expected)
          end

          it "should return next interval 'at the future date' in localtime if start_time is in the future with interval hourly 1" do
            @first.update_attribute(:run_at, :start_time => '2011-01-25 05:00:00 Z', :interval => {:unit => "hourly", :value => "1"})
            expected = Time.parse('2011-01-25 05:00:00 Z').localtime
            expect(@first.next_interval_time).to eq(expected)
          end
        end
      end
    end

    context "valid db_gc unsaved schedule, run_adhoc_db_gc" do
      before do
        @task_id = MiqSchedule.run_adhoc_db_gc(:userid => "admin", :aggressive => true)
        @gc_message = MiqQueue.where(:class_name => "DatabaseBackup", :method_name => "gc", :role => "database_operations").first

        @region = FactoryGirl.create(:miq_region)
        allow(MiqRegion).to receive(:my_region).and_return(@region)
      end

      it "should create 1 miq task" do
        tasks = MiqTask.where(:name => "Database GC", :userid => "admin")
        expect(tasks.length).to eq(1)
        expect(tasks.first.id).to eq(@task_id)
      end

      it "should create one gc queue message for the database role" do
        expect(MiqQueue.where(:class_name => "DatabaseBackup", :method_name => "gc", :role => "database_operations").count).to eq(1)
      end

      context "deliver DatabaseBackup.gc message" do
        before do
          # stub out the actual backup behavior
          allow(PostgresAdmin).to receive(:gc)

          @status, message, result = @gc_message.deliver
          @gc_message.delivered(@status, message, result)
        end

        it "should have queue message ok, and task is Ok and Finished" do
          expect(@status).to eq("ok")
          expect(MiqTask.where(:state => "Finished", :status => "Ok").count).to eq(1)
        end
      end
    end

    context "valid action_automation_request" do
      let(:admin) { FactoryGirl.create(:user_miq_request_approver) }
      let(:automate_sched) do
        MiqSchedule.create(:name          => "test_method", :resource_type => "AutomationRequest",
                           :userid        => admin.userid, :enabled => true,
                           :run_at        => {:interval   => {:value => "1", :unit => "daily"},
                                              :start_time => 2.hours.from_now.utc.to_i},
                           :sched_action  => {:method => "automation_request"},
                           :filter        => {:uri_parts  => {:namespace => 'ss',
                                                              :instance  => 'vv',
                                                              :message   => 'mm'},
                                              :parameters => {"param" => "8"}})
      end

      it "should create a request from a scheduled task" do
        expect(AutomationRequest).to receive(:create_from_scheduled_task).once
        automate_sched.run_automation_request
      end

      it "should create 1 automation request" do
        automate_sched.action_automation_request(AutomationRequest, '')
        expect(AutomationRequest.where(:description => "Automation Task", :userid => admin.userid).count).to eq(1)
      end
    end

    context "valid schedules for db_backup" do
      let(:file_depot) { FactoryGirl.create(:file_depot_ftp_with_authentication) }
      before do
        @valid_schedules = []
        @valid_run_ats.each do |run_at|
          @valid_schedules << FactoryGirl.create(:miq_schedule_validation, :run_at => run_at, :file_depot => file_depot, :sched_action => {:method => "db_backup"}, :resource_type => "DatabaseBackup")
        end
        @schedule = @valid_schedules.first
      end

      context "calling run adhoc_db_backup" do
        before do
          @task_id = @schedule.run_adhoc_db_backup
          @backup_message = MiqQueue.where(:class_name => "DatabaseBackup", :method_name => "backup", :role => "database_operations").first

          @region = FactoryGirl.create(:miq_region)
          allow(MiqRegion).to receive(:my_region).and_return(@region)
        end

        it "should create no database backups" do
          expect(DatabaseBackup.count).to eq(0)
          expect(@region.database_backups.count).to eq(0)
        end

        it "should create 1 miq task" do
          tasks = MiqTask.where(:name => "Database backup", :userid => @schedule.userid)
          expect(tasks.length).to eq(1)
          expect(tasks.first.id).to eq(@task_id)
        end

        it "should create one backup queue message for our db backup instance for the database role" do
          expect(MiqQueue.where(:class_name => "DatabaseBackup", :method_name => "backup", :role => "database_operations").count).to eq(1)
        end

        it "sets backup tasks's timeout to ::Settings.task.active_task_timeout" do
          expect(@backup_message.msg_timeout).to eq ::Settings.task.active_task_timeout.to_i_with_method
        end
      end

      context "calling queue scheduled work via a db_backup schedule firing" do
        before do
          MiqSchedule.queue_scheduled_work(@schedule.id, nil, Time.now.utc.to_i, nil)
          @invoke_actions_message = MiqQueue.where(:class_name => "MiqSchedule", :instance_id => @schedule.id, :method_name => "invoke_actions").first
        end

        it "should create an invoke_actions queue message" do
          expect(@invoke_actions_message).not_to be_nil
        end

        it "should have no other DatabaseBackups" do
          expect(DatabaseBackup.count).to eq(0)
        end

        context "deliver invoke actions message" do
          before do
            status, message, result = @invoke_actions_message.deliver
            @invoke_actions_message.delivered(status, message, result)
            @backup_message = MiqQueue.where(:class_name => "DatabaseBackup", :method_name => "backup", :role => "database_operations").first

            @region = FactoryGirl.create(:miq_region)
            allow(MiqRegion).to receive(:my_region).and_return(@region)
          end

          it "should create no database backups" do
            expect(DatabaseBackup.count).to eq(0)
            expect(@region.database_backups.count).to eq(0)
          end

          it "should create 1 miq task" do
            expect(MiqTask.where(:name => "Database backup", :userid => @schedule.userid).count).to eq(1)
          end

          it "should create one backup queue message for our db backup instance for the database role" do
            expect(MiqQueue.where(:class_name => "DatabaseBackup", :method_name => "backup", :role => "database_operations").count).to eq(1)
          end

          context "_backup is stubbed" do
            before do
              # stub out the actual backup behavior
              allow_any_instance_of(DatabaseBackup).to receive(:_backup)
            end

            context "deliver DatabaseBackup.backup message" do
              before do
                @status, message, result = @backup_message.deliver
                @backup_message.delivered(@status, message, result)
              end

              it "should create 1 database backup, queue message is ok, and task is Ok and Finished" do
                expect(@status).to eq("ok")
                expect(@region.database_backups.count).to eq(1)
                expect(MiqTask.where(:state => "Finished", :status => "Ok").count).to eq(1)
              end
            end

            context "deliver DatabaseBackup.backup message with adhoc true" do
              before do
                @schedule.update_attribute(:adhoc, true)
                @schedule_id = @schedule.id
                @status, message, result = @backup_message.deliver
                @backup_message.delivered(@status, message, result)
              end

              it "should delete the adhoc schedule" do
                expect(MiqSchedule.exists?(@schedule_id)).not_to be_truthy
              end
            end

            context "deliver DatabaseBackup.backup message with adhoc false" do
              before do
                @schedule.update_attribute(:adhoc, false)
                @schedule_id = @schedule.id
                @status, message, result = @backup_message.deliver
                @backup_message.delivered(@status, message, result)
              end

              it "should not delete the schedule" do
                expect(MiqSchedule.exists?(@schedule_id)).to be_truthy
              end
            end
          end
        end
      end

      it "should have valid depots" do
        @valid_schedules.each { |sch| expect(sch.valid?).to be_truthy }
      end

      it "should return the expected FileDepot subclass" do
        @valid_schedules.each { |sch| expect(sch.file_depot).to be_kind_of(FileDepotFtp) }
      end
    end
  end

  context "#verify_file_depot" do
    let(:params) { {:uri_prefix => "ftp", :uri => "ftp://ftp.example.com", :name => "Test Backup Depot", :username => "user", :password => "password"} }

    it "builds a file_depot of the correct type and validates it, does not save" do
      expect_any_instance_of(FileDepotFtp).to receive(:verify_credentials).and_return(true)

      MiqSchedule.new.verify_file_depot(params)

      expect(Authentication.count).to eq(0)
      expect(FileDepot.count).to      eq(0)
      expect(MiqSchedule.count).to    eq(0)
    end

    it "saves the file_depot when params[:save] is passed in, does not validate" do
      MiqSchedule.new.verify_file_depot(params.merge(:save => true))

      expect(Authentication.count).to eq(1)
      expect(FileDepot.count).to      eq(1)
      expect(MiqSchedule.count).to    eq(0)
    end
  end

  describe ".updated_since" do
    it "fetches records" do
      FactoryGirl.create(:miq_schedule, :updated_at => 1.year.ago)
      s = FactoryGirl.create(:miq_schedule, :updated_at => 1.day.ago)
      expect(MiqSchedule.updated_since(1.month.ago)).to eq([s])
    end
  end

  context ".queue_scheduled_work" do
    it "When action exists" do
      schedule = FactoryGirl.create(:miq_schedule, :sched_action => {:method => "scan"})
      MiqSchedule.queue_scheduled_work(schedule.id, nil, "abc", nil)

      expect(MiqQueue.first).to have_attributes(
        :class_name  => "MiqSchedule",
        :instance_id => schedule.id,
        :method_name => "invoke_actions",
        :args        => ["action_scan", "abc"],
        :msg_timeout => 1200
      )
    end

    context "no action method" do
      it "no resource" do
        schedule = FactoryGirl.create(:miq_schedule, :sched_action => {:method => "test_method"})

        expect($log).to receive(:warn) do |message|
          expect(message).to include("no such action: [test_method], aborting schedule")
        end

        MiqSchedule.queue_scheduled_work(schedule.id, nil, "abc", nil)
      end

      context "resource exists" do
        let(:resource) { FactoryGirl.create(:host) }

        before do
          allow(Host).to receive(:find_by).with(:id => resource.id).and_return(resource)
        end

        it "and does not respond to the method" do
          schedule = FactoryGirl.create(:miq_schedule, :resource => resource, :sched_action => {:method => "test_method"})

          expect($log).to receive(:warn) do |message|
            expect(message).to include("no such action: [test_method], aborting schedule")
          end

          MiqSchedule.queue_scheduled_work(schedule.id, nil, "abc", nil)
        end

        it "and responds to the method" do
          schedule = FactoryGirl.create(:miq_schedule, :resource => resource, :sched_action => {:method => "name"})

          expect_any_instance_of(Host).to receive("name").once

          MiqSchedule.queue_scheduled_work(schedule.id, nil, "abc", nil)
        end

        it "and responds to the method with arguments" do
          schedule = FactoryGirl.create(:miq_schedule, :resource => resource, :sched_action => {:method => "name", :args => ["abc", 123, :a => 1]})

          expect_any_instance_of(Host).to receive("name").once.with("abc", 123, :a => 1)

          MiqSchedule.queue_scheduled_work(schedule.id, nil, "abc", nil)
        end
      end
    end
  end
end
