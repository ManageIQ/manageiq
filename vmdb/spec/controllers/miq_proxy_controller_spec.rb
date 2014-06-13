require "spec_helper"

describe MiqProxyController do

  context "#tasks_condition" do
    subject { controller.send(:tasks_condition, @opts) }
    before do
      MiqRegion.seed
      @user = FactoryGirl.create(:user, :userid => 'admin')
      controller.stub(:session => @user)
    end

    describe "My VM Analysis Tasks" do
      before do
        controller.instance_variable_set(:@tabform, "tasks_1")
        @opts = { :ok=>true,
                  :queued=>true,
                  :error=>true,
                  :warn=>true,
                  :running=>true,
                  :states=>[["Initializing", "initializing"],
                            ["Waiting to Start", "waiting_to_start"],
                            ["Cancelling", "cancelling"],
                            ["Aborting", "aborting"],
                            ["Finished", "finished"],
                            ["Snapshot Create", "snapshot_create"],
                            ["Scanning", "scanning"],
                            ["Snapshot Delete", "snapshot_delete"],
                            ["Synchronizing", "synchronizing"],
                            ["Deploy Smartproxy", "deploy_smartproxy"]],
                  :state_choice=>"all",
                  :zone=>"<all>",
                  :time_period=>0
                }
      end

      it "all defaults" do
        query = "userid=? AND "\
                "((state=? OR state=?) OR "\
                "(state=? AND status=?) OR "\
                "(state=? AND status=?) OR "\
                "(state=? AND status=?) OR "\
                "(state!=? AND state!=? AND state!=?)) AND "\
                "updated_on>=? AND "\
                "updated_on<=?"
        expected = [ query,
                    "admin",
                    "waiting_to_start", "Queued",
                    "finished", "ok",
                    "finished", "error",
                    "finished", "warn",
                    "finished", "waiting_to_start", "queued"]
        expected += get_time_period(@opts[:time_period])
        subject.should == expected
      end

      it "Zone: default, Time period: 1 Day Ago, status:  Ok, State:  Finished" do
        set_opts(:queued=>nil, :error=>nil, :warn=>nil, :running=>nil, :state_choice=>"finished", :zone=>"default", :time_period=>1)

        query = "userid=? AND "\
                "((state=? AND status=?)) AND "\
                "updated_on>=? AND "\
                "updated_on<=? AND "\
                "zone=? AND "\
                "state=?"
        expected = [query,
                "admin",
                "finished", "ok"]
        expected += get_time_period(@opts[:time_period]) << "default" << "finished"
        subject.should == expected
      end

      it "zone: default, Time period: 6 Days Ago, status: Error and Warn, State: All " do
        set_opts(:ok=>nil, :queued=>nil, :error=>"1", :warn=>"1", :running=>nil, :zone=>"default", :time_period=>6)

        query = "userid=? AND ("\
                "(state=? AND status=?) OR "\
                "(state=? AND status=?)) AND "\
                "updated_on>=? AND "\
                "updated_on<=? AND "\
                "zone=?"
        expected = [ query,
                    "admin",
                    "finished", "error",
                    "finished", "warn"]
        expected += get_time_period(@opts[:time_period]) << "default"
        subject.should == expected

      end

      it "zone: <All Zones>, Time period: Last 24, Status: Queued, Running, Ok, Error and Warn, State: Aborting" do
        set_opts( :state_choice=>"aborting" )

        query = "userid=? AND "\
                "((state=? OR state=?) OR "\
                "(state=? AND status=?) OR "\
                "(state=? AND status=?) OR "\
                "(state=? AND status=?) OR "\
                "(state!=? AND state!=? AND state!=?)) AND "\
                "updated_on>=? AND "\
                "updated_on<=? AND "\
                "state=?"
        expected = [ query,
              "admin",
              "waiting_to_start", "Queued",
              "finished", "ok",
              "finished", "error",
              "finished", "warn",
              "finished", "waiting_to_start", "queued"]

        expected += get_time_period(@opts[:time_period]) << "aborting"
        subject.should == expected
      end

      it "zone: <All Zones>, Time period: Last 24, Status: none, State: All" do
        set_opts( :ok=>nil, :queued=>nil, :error=>nil, :warn=>nil, :running=>nil)

        query = "userid=? AND "\
                "(status!=? AND status!=? AND status!=? AND state!=? AND state!=?) AND "\
                "updated_on>=? AND "\
                "updated_on<=?"

        expected = [ query,
                    "admin",
                    "ok", "error", "warn", "finished", "waiting_to_start"]

        expected += get_time_period(@opts[:time_period])
        subject.should == expected
      end

      it "zone: <All Zones>, Time period: Last 24, Status: none, State: Aborting" do
        set_opts( :ok=>nil, :queued=>nil, :error=>nil, :warn=>nil, :running=>nil, :state_choice=>"aborting")

        query = "userid=? AND "\
                "(status!=? AND status!=? AND status!=? AND state!=? AND state!=?) "\
                "AND updated_on>=? AND "\
                "updated_on<=? AND "\
                "state=?"

        expected = [ query,
                      "admin",
                      "ok", "error", "warn", "finished", "waiting_to_start"]

        expected += get_time_period(@opts[:time_period]) << "aborting"
        subject.should == expected
      end

      it "zone: default, Time period: 1 Day Ago, Status: none, State: Waiting to Start" do
        set_opts(:ok=>nil, :queued=>nil, :error=>nil, :warn=>nil, :running=>nil, :state_choice=>"waiting_to_start", :zone=>"default", :time_period=>1)

        query = "userid=? AND "\
                "(status!=? AND status!=? AND status!=? AND state!=? AND state!=?) AND "\
                "updated_on>=? AND "\
                "updated_on<=? AND "\
                "zone=? AND "\
                "state=?"
        expected = [ query,
                      "admin",
                      "ok", "error", "warn", "finished", "waiting_to_start"]

        expected += get_time_period(@opts[:time_period]) << "default" << "waiting_to_start"
        subject.should == expected
      end

      it "zone: default, Time period: 4 Days Ago, Status: Queued and Running, State: Synchronizing" do
        set_opts(:ok=>nil, :queued=>"1", :error=>nil, :warn=>nil, :running=>"1", :state_choice=>"synchronizing", :zone=>"default", :time_period=>4)

        query = "userid=? AND "\
                "((state=? OR state=?) OR "\
                "(state!=? AND state!=? AND state!=?)) AND "\
                "updated_on>=? AND "\
                "updated_on<=? AND "\
                "zone=? AND "\
                "state=?"
        expected = [ query,
                      "admin",
                      "waiting_to_start", "Queued",
                      "finished", "waiting_to_start", "queued"]

        expected += get_time_period(@opts[:time_period]) << "default" << "synchronizing"
        subject.should == expected
      end

      it "zone: default, Time period: 4 Days Ago, Status: Queued and Running, State: Snapshot Delete" do
        set_opts(:ok=>nil, :queued=>"1", :error=>nil, :warn=>nil, :running=>"1", :state_choice=>"snapshot_delete", :zone=>"default", :time_period=>4)

        query = "userid=? AND "\
                "((state=? OR state=?) OR "\
                "(state!=? AND state!=? AND state!=?)) AND "\
                "updated_on>=? AND "\
                "updated_on<=? AND "\
                "zone=? AND "\
                "state=?"
        expected = [ query,
                      "admin",
                      "waiting_to_start", "Queued",
                      "finished", "waiting_to_start", "queued"]

        expected += get_time_period(@opts[:time_period]) << "default" << "snapshot_delete"
        subject.should == expected
      end

    end

    describe "My Other UI Tasks" do
      before do
        controller.instance_variable_set(:@tabform, "tasks_2")
        @opts = {:ok=>true,
                :queued=>true,
                :error=>true,
                :warn=>true,
                :running=>true,
                :states=>[["Initialized", "Initialized"],
                          ["Queued", "Queued"],
                          ["Active", "Active"],
                          ["Finished", "Finished"]
                         ],
                :state_choice=>"all",
                :time_period=>0
                }
      end

      it "all defaults" do
        query = 'userid=? AND ('\
                '(state=? OR state=?) OR '\
                '(state=? AND status=?) OR '\
                '(state=? AND status=?) OR '\
                '(state=? AND status=?) OR '\
                '(state!=? AND state!=? AND state!=?)) AND '\
                'updated_on>=? AND '\
                'updated_on<=?'
        expected = [query,
                 "admin",
                 "waiting_to_start", "Queued",
                 "Finished", "Ok",
                 "Finished", "Error",
                 "Finished", "Warn",
                 "Finished", "waiting_to_start", "Queued"
                 ]
        expected += get_time_period(@opts[:time_period])
        subject.should == expected
      end

      it "Time period: 6 Days ago, status: queued and running, state: initialized" do
        set_opts(:ok=>nil, :error=>nil, :warn=>nil,  :state_choice=>"Initialized", :time_period=>6)

        query = "userid=? AND ("\
                "(state=? OR state=?) OR "\
                "(state!=? AND state!=? AND state!=?)) AND "\
                "updated_on>=? AND "\
                "updated_on<=? AND "\
                "state=?"
        expected = [ query,
             "admin",
             "waiting_to_start", "Queued",
             "Finished", "waiting_to_start", "Queued"]
        expected += get_time_period(@opts[:time_period]) << "Initialized"
        subject.should == expected
      end

      it "Time period: 6 Days Ago, status: queued and running, state: active" do
        set_opts(:ok=>nil, :error=>nil, :warn=>nil, :state_choice=>"Active", :time_period=>6)

        query = "userid=? AND "\
                "((state=? OR state=?) OR "\
                "(state!=? AND state!=? AND state!=?)) AND "\
                "updated_on>=? AND "\
                "updated_on<=? AND "\
                "state=?"
        expected = [ query,
                    "admin",
                    "waiting_to_start", "Queued",
                    "Finished", "waiting_to_start", "Queued"]
        expected += get_time_period(@opts[:time_period]) << "Active"
        subject.should == expected
      end

      it "Time period: 6 Days Ago, status: queued and running, state: finished" do
        set_opts(:ok=>nil, :error=>nil, :warn=>nil, :state_choice=>"Finished", :time_period=>6)

        query = "userid=? AND "\
                "((state=? OR state=?) OR "\
                "(state!=? AND state!=? AND state!=?)) AND "\
                "updated_on>=? AND "\
                "updated_on<=? AND "\
                "state=?"
        expected = [ query,
                    "admin",
                    "waiting_to_start", "Queued",
                    "Finished", "waiting_to_start", "Queued"]

        expected += get_time_period(@opts[:time_period]) << "Finished"
        subject.should == expected
      end

      it "Time period: 6 Days Ago, status: ok, state: queued" do
        set_opts( :ok=>"1", :queued=>nil, :error=>nil, :warn=>nil, :running=>nil, :state_choice=>"Queued", :time_period=>6)

        query = "userid=? AND "\
                "((state=? AND status=?)) AND "\
                "updated_on>=? AND "\
                "updated_on<=? AND "\
                "state=?"

        expected = [ query,
                      "admin",
                      "Finished", "Ok"]

        expected += get_time_period(@opts[:time_period]) << "Queued"
        subject.should == expected
      end

      it "Time period: 6 Days Ago, status: ok and warn, state: queued" do
        set_opts( :ok=>"1", :queued=>nil, :error=>nil, :warn=>"1", :running=>nil, :state_choice=>"Queued", :time_period=>6)

        query = "userid=? AND "\
                "((state=? AND status=?) OR "\
                "(state=? AND status=?)) AND "\
                "updated_on>=? AND "\
                "updated_on<=? AND "\
                "state=?"
        expected = [ query,
                    "admin",
                    "Finished", "Ok",
                    "Finished", "Warn"]

        expected += get_time_period(@opts[:time_period]) << "Queued"
        subject.should == expected
      end

      it "Time period: 6 Days Ago, status: ok and warn and error, state: queued" do
        set_opts( :ok=>"1", :queued=>nil, :error=>"1", :warn=>"1", :running=>nil, :state_choice=>"Queued", :time_period=>6)

        query = "userid=? AND "\
                "((state=? AND status=?) OR "\
                "(state=? AND status=?) OR "\
                "(state=? AND status=?)) AND "\
                "updated_on>=? AND "\
                "updated_on<=? AND "\
                "state=?"
        expected = [ query,
                    "admin",
                    "Finished", "Ok",
                    "Finished", "Error",
                    "Finished", "Warn"]

        expected += get_time_period(@opts[:time_period]) << "Queued"
        subject.should == expected
      end

      it "Time Period: Last 24, Status: none checked, State: All" do
        set_opts(:ok=>nil, :queued=>nil, :error=>nil, :warn=>nil, :running=>nil)

        query = "userid=? AND "\
                "(status!=? AND status!=? AND status!=? AND state!=? AND state!=?) AND "\
                "updated_on>=? AND "\
                "updated_on<=?"
        expected = [ query, "admin", "Ok", "Error", "Warn", "Finished", "Queued"]
        expected += get_time_period(@opts[:time_period])

        subject.should == expected
      end

      it "Time Period: Last 24, Status: none checked, State: Active" do
        set_opts(:ok=>nil, :queued=>nil, :error=>nil, :warn=>nil, :running=>nil, :state_choice=>"Active")

        query = "userid=? AND "\
                "(status!=? AND status!=? AND status!=? AND state!=? AND state!=?) AND "\
                "updated_on>=? AND "\
                "updated_on<=? AND "\
                "state=?"
        expected = [ query, "admin", "Ok", "Error", "Warn", "Finished", "Queued"]
        expected += get_time_period(@opts[:time_period]) << "Active"

        subject.should == expected
      end

      it "Time Period: 1 Day Ago, Status: none checked, State: Finished" do
        set_opts(:ok=>nil, :queued=>nil, :error=>nil, :warn=>nil, :running=>nil, :state_choice=>"Finished", :time_period=>1)

        query = "userid=? AND "\
                "(status!=? AND status!=? AND status!=? AND state!=? AND state!=?) AND "\
                "updated_on>=? AND "\
                "updated_on<=? AND "\
                "state=?"
        expected = [ query, "admin", "Ok", "Error", "Warn", "Finished", "Queued"]
        expected += get_time_period(@opts[:time_period]) << "Finished"

        subject.should == expected
      end

      it "Time Period: 2 Day Ago, Status: none checked, State: Initialized" do
        set_opts(:ok=>nil, :queued=>nil, :error=>nil, :warn=>nil, :running=>nil, :state_choice=>"Initialized", :time_period=>2)

        query = "userid=? AND "\
                "(status!=? AND status!=? AND status!=? AND state!=? AND state!=?) AND "\
                "updated_on>=? AND "\
                "updated_on<=? AND "\
                "state=?"
        expected = [ query, "admin", "Ok", "Error", "Warn", "Finished", "Queued"]
        expected += get_time_period(@opts[:time_period]) << "Initialized"

        subject.should == expected
      end

      it "Time Period: 3 Day Ago, Status: none checked, State: Queued" do
        set_opts(:ok=>nil, :queued=>nil, :error=>nil, :warn=>nil, :running=>nil, :state_choice=>"Queued", :time_period=>3)

        query = "userid=? AND "\
                "(status!=? AND status!=? AND status!=? AND state!=? AND state!=?) AND "\
                "updated_on>=? AND "\
                "updated_on<=? AND "\
                "state=?"
        expected = [ query, "admin", "Ok", "Error", "Warn", "Finished", "Queued"]
        expected += get_time_period(@opts[:time_period]) << "Queued"

        subject.should == expected
      end
    end

    describe "All VM Analysis Tasks" do
      before do
        controller.instance_variable_set(:@tabform, "tasks_3")
        @opts = {:ok=>true,
                  :queued=>true,
                  :error=>true,
                  :warn=>true, :running=>true,
                  :states=>[["Initializing", "initializing"],
                            ["Waiting to Start", "waiting_to_start"],
                            ["Cancelling", "cancelling"],
                            ["Aborting", "aborting"],
                            ["Finished", "finished"],
                            ["Snapshot Create", "snapshot_create"],
                            ["Scanning", "scanning"],
                            ["Snapshot Delete", "snapshot_delete"],
                            ["Synchronizing", "synchronizing"],
                            ["Deploy Smartproxy", "deploy_smartproxy"]
                           ],
                  :state_choice=>"all",
                  :zone=>"<all>",
                  :user_choice=>"all",
                  :time_period=>0
                }
      end

      it "all defaults" do
        query = "((state=? OR state=?) OR "\
                "(state=? AND status=?) OR "\
                "(state=? AND status=?) OR "\
                "(state=? AND status=?) OR "\
                "(state!=? AND state!=? AND state!=?)) AND "\
                "updated_on>=? AND "\
                "updated_on<=?"
        expected = [query,
                    "waiting_to_start", "Queued",
                    "finished", "ok",
                    "finished", "error",
                    "finished", "warn",
                    "finished", "waiting_to_start", "queued"
                    ]
        expected += get_time_period(@opts[:time_period])
        subject.should == expected
      end

      it "zone: default, user: all, Time  period: 6 Days Ago, status: queued and running, state: all" do
        set_opts( :ok=>nil, :queued=>"1", :error=>nil, :warn=>nil, :zone=>"default", :time_period=>6)

        query = "((state=? OR state=?) OR "\
                "(state!=? AND state!=? AND state!=?)) AND "\
                "updated_on>=? AND "\
                "updated_on<=? AND "\
                "zone=?"
        expected = [ query,
                 "waiting_to_start", "Queued",
                 "finished", "waiting_to_start", "queued"]
        expected += get_time_period(@opts[:time_period]) << "default"
        subject.should == expected
      end

      it "zone: default, user: all, Time period: 6 Days Ago, status: queued and running, state: snapshot create" do
        set_opts(:ok=>nil, :queued=>"1", :error=>nil, :warn=>nil, :state_choice=>"snapshot_create", :zone=>"default", :time_period=>6)

        query = "((state=? OR state=?) OR "\
                "(state!=? AND state!=? AND state!=?)) AND "\
                "updated_on>=? AND "\
                "updated_on<=? AND "\
                "zone=? AND "\
                "state=?"
        expected = [ query,
                 "waiting_to_start", "Queued",
                 "finished", "waiting_to_start", "queued"]
        expected += get_time_period(@opts[:time_period]) << "default" << "snapshot_create"
        subject.should == expected
      end

      it "zone: default, user: all, Time period: 6 Days Ago, status: queued and running and ok, state: snapshot create" do
        set_opts(:ok=>"1", :queued=>"1", :error=>nil, :warn=>nil, :state_choice=>"snapshot_create", :zone=>"default", :time_period=>6)

        query = "((state=? OR state=?) OR "\
                "(state=? AND status=?) OR "\
                "(state!=? AND state!=? AND state!=?)) AND "\
                "updated_on>=? AND "\
                "updated_on<=? AND "\
                "zone=? AND "\
                "state=?"
        expected = [ query,
                    "waiting_to_start", "Queued",
                    "finished", "ok",
                    "finished", "waiting_to_start", "queued"]
        expected += get_time_period(@opts[:time_period]) << "default" << "snapshot_create"
        subject.should == expected
      end

      it "zone: <All Zones>, Time period: Last 24, Status: none checked, State: Snapshot Create" do
        set_opts(:ok=>nil, :queued=>nil, :error=>nil, :warn=>nil, :running=>nil, :state_choice=>"snapshot_create")

        query = "(status!=? AND status!=? AND status!=? AND state!=? AND state!=?) AND "\
                "updated_on>=? AND "\
                "updated_on<=? AND "\
                "state=?"
        expected = [ query,
                "ok", "error", "warn", "finished", "waiting_to_start"]

        expected += get_time_period(@opts[:time_period]) << "snapshot_create"
        subject.should == expected
      end

      it "zone: <All Zones>, Time period: 2 Days Ago, Status: none checked, State: Scanning" do
        set_opts(:ok=>nil, :queued=>nil, :error=>nil, :warn=>nil, :running=>nil, :state_choice=>"scanning", :time_period=>2)

        query = "(status!=? AND status!=? AND status!=? AND state!=? AND state!=?) AND "\
                "updated_on>=? AND "\
                "updated_on<=? AND "\
                "state=?"
        expected = [ query, "ok", "error", "warn", "finished", "waiting_to_start"]

        expected += get_time_period(@opts[:time_period]) << "scanning"
        subject.should == expected
      end

      it "zone: <All Zones>, Time period: 3 Days Ago, Status: none checked, State: Initializing" do
        set_opts(:ok=>nil, :queued=>nil, :error=>nil, :warn=>nil, :running=>nil, :state_choice=>"initializing", :time_period=>3)

        query = "(status!=? AND status!=? AND status!=? AND state!=? AND state!=?) AND "\
                "updated_on>=? AND "\
                "updated_on<=? AND "\
                "state=?"
        expected = [ query, "ok", "error", "warn", "finished", "waiting_to_start"]

        expected += get_time_period(@opts[:time_period]) << "initializing"
        subject.should == expected
      end

      it "zone: <All Zones>, Time period: 4 Days Ago, Status: none checked, State: Finished" do
        set_opts(:ok=>nil, :queued=>nil, :error=>nil, :warn=>nil, :running=>nil, :state_choice=>"finished", :time_period=>4)

        query = "(status!=? AND status!=? AND status!=? AND state!=? AND state!=?) AND "\
                "updated_on>=? AND "\
                "updated_on<=? AND "\
                "state=?"
        expected = [ query, "ok", "error", "warn", "finished", "waiting_to_start"]
        expected += get_time_period(@opts[:time_period]) << "finished"

        subject.should == expected
      end

      it "zone: <All Zones>, Time period: 5 Days Ago, Status: none checked, State: Deploy Smartproxy" do
        set_opts(:ok=>nil, :queued=>nil, :error=>nil, :warn=>nil, :running=>nil, :state_choice=>"deploy_smartproxy", :time_period=>5)

        query = "(status!=? AND status!=? AND status!=? AND state!=? AND state!=?) AND "\
                "updated_on>=? AND "\
                "updated_on<=? AND "\
                "state=?"
        expected = [ query, "ok", "error", "warn", "finished", "waiting_to_start"]
        expected += get_time_period(@opts[:time_period]) << "deploy_smartproxy"

        subject.should == expected
      end

      it "zone: <All Zones>, Time period: 6 Days Ago, Status: Ok, Error and Warn, State: Cancelling" do
        set_opts(:ok=>"1", :queued=>nil, :error=>"1", :warn=>"1", :running=>nil, :state_choice=>"cancelling", :time_period=>6)

        query = "((state=? AND status=?) OR "\
                "(state=? AND status=?) OR "\
                "(state=? AND status=?)) AND "\
                "updated_on>=? AND "\
                "updated_on<=? AND "\
                "state=?"
        expected = [ query, "finished", "ok", "finished", "error", "finished", "warn"]
        expected += get_time_period(@opts[:time_period]) << "cancelling"

        subject.should == expected
      end
    end

    describe "All Other Tasks" do
      before do
        controller.instance_variable_set(:@tabform, "tasks_4")

        @opts = {:ok=>true,
                 :queued=>true,
                 :error=>true,
                 :warn=>true,
                 :running=>true,
                 :states=>[["Initialized", "Initialized"],
                            ["Queued", "Queued"],
                            ["Active", "Active"],
                            ["Finished", "Finished"]],
                 :state_choice=>"all",
                 :user_choice=>"all",
                 :time_period=>0}
      end

      it "all defaults" do
        query = "((state=? OR state=?) OR "\
                "(state=? AND status=?) OR "\
                "(state=? AND status=?) OR "\
                "(state=? AND status=?) OR "\
                "(state!=? AND state!=? AND state!=?)) AND "\
                "updated_on>=? AND "\
                "updated_on<=?"
        expected = [query,
                     "waiting_to_start", "Queued",
                     "Finished", "Ok",
                     "Finished", "Error",
                     "Finished", "Warn",
                     "Finished", "waiting_to_start", "Queued"
                    ]
        expected += get_time_period(@opts[:time_period])
        subject.should == expected
      end

      it "user: all, Time period: 1 Day Ago, status: queued, running, ok, error and warn, state: active" do
        set_opts(:state_choice=>"Active", :time_period=>1)

        query = "((state=? OR state=?) OR "\
                "(state=? AND status=?) OR "\
                "(state=? AND status=?) OR "\
                "(state=? AND status=?) OR "\
                "(state!=? AND state!=? AND state!=?)) AND "\
                "updated_on>=? AND "\
                "updated_on<=? AND "\
                "state=?"
        expected = [ query,
                 "waiting_to_start", "Queued",
                 "Finished", "Ok",
                 "Finished", "Error",
                 "Finished", "Warn",
                 "Finished", "waiting_to_start", "Queued"]

        expected += get_time_period(@opts[:time_period]) << "Active"
        subject.should == expected
      end

      it "user: all, Time period: 1 Day Ago, status: queued, running, ok, error and warn, state: finished" do
        set_opts( :state_choice=>"Finished", :time_period=>1)

        query = "((state=? OR state=?) OR "\
                "(state=? AND status=?) OR "\
                "(state=? AND status=?) OR "\
                "(state=? AND status=?) OR "\
                "(state!=? AND state!=? AND state!=?)) AND "\
                "updated_on>=? AND "\
                "updated_on<=? AND "\
                "state=?"
        expected = [ query,
                 "waiting_to_start", "Queued",
                 "Finished", "Ok",
                 "Finished", "Error",
                 "Finished", "Warn",
                 "Finished", "waiting_to_start", "Queued"]

        expected += get_time_period(@opts[:time_period]) <<  "Finished"
        subject.should == expected
      end

      it "user: all, Time period: 1 Day Ago, status: queued, running, ok, error and warn, state: initialized" do
        set_opts(:state_choice=>"Initialized", :time_period=>1)

        query = "((state=? OR state=?) OR "\
                "(state=? AND status=?) OR "\
                "(state=? AND status=?) OR "\
                "(state=? AND status=?) OR "\
                "(state!=? AND state!=? AND state!=?)) AND "\
                "updated_on>=? AND "\
                "updated_on<=? AND state=?"
        expected = [ query,
                 "waiting_to_start", "Queued",
                 "Finished", "Ok",
                 "Finished", "Error",
                 "Finished", "Warn",
                 "Finished", "waiting_to_start", "Queued"]

        expected += get_time_period(@opts[:time_period]) << "Initialized"
        subject.should == expected
      end

      it "user: all, Time period: 1 Day Ago, status: queued, running, ok, error and warn, state: queued" do
        set_opts(:state_choice=>"Queued", :time_period=>1)

        query = "((state=? OR state=?) OR "\
                "(state=? AND status=?) OR "\
                "(state=? AND status=?) OR "\
                "(state=? AND status=?) OR "\
                "(state!=? AND state!=? AND state!=?)) AND "\
                "updated_on>=? AND "\
                "updated_on<=? AND "\
                "state=?"
        expected = [ query,
                     "waiting_to_start", "Queued",
                     "Finished", "Ok",
                     "Finished", "Error",
                     "Finished", "Warn",
                     "Finished", "waiting_to_start", "Queued"]

        expected += get_time_period(@opts[:time_period]) << "Queued"
        subject.should == expected
      end

      it "User: All Users, Time Period: Last 24, Status: none checked, State: All" do
        set_opts(:ok=>nil, :queued=>nil, :error=>nil, :warn=>nil, :running=>nil)

        query = "(status!=? AND status!=? AND status!=? AND state!=? AND state!=?) AND " \
                "updated_on>=? AND " \
                "updated_on<=?"
        expected = [ query, "Ok", "Error", "Warn", "Finished", "Queued"]
        expected += get_time_period(@opts[:time_period])

        subject.should == expected
      end

      it "User: system, Time Period: 1 Day Ago, Status: none checked, State: Active" do
        set_opts(:ok=>nil, :queued=>nil, :error=>nil, :warn=>nil, :running=>nil, :state_choice=>"Active", :user_choice=>"system", :time_period=>1)

        query = "userid=? AND "\
                "(status!=? AND status!=? AND status!=? AND state!=? AND state!=?) AND "\
                "updated_on>=? AND "\
                "updated_on<=? AND "\
                "state=?"
        expected = [ query, "system", "Ok", "Error", "Warn", "Finished", "Queued"]
        expected += get_time_period(@opts[:time_period]) << "Active"

        subject.should == expected
      end

      it "User: system, Time Period: 2 Day Ago, Status: Queued, State: Finished" do
        set_opts(:ok=>nil, :queued=>"1", :error=>nil, :warn=>nil, :running=>nil, :state_choice=>"Finished", :user_choice=>"system", :time_period=>2)

        query = "userid=? AND "\
                "((state=? OR state=?)) AND "\
                "updated_on>=? AND "\
                "updated_on<=? AND "\
                "state=?"
        expected = [ query, "system", "waiting_to_start", "Queued"]
        expected += get_time_period(@opts[:time_period]) << "Finished"

        subject.should == expected
      end

      it "User: system, Time Period: 3 Day Ago, Status: Running, State: Initialized" do
        set_opts(:ok=>nil, :queued=>nil, :error=>nil, :warn=>nil, :running=>"1", :state_choice=>"Initialized", :user_choice=>"system", :time_period=>3)

        query = "userid=? AND "\
                "((state!=? AND state!=? AND state!=?)) AND "\
                "updated_on>=? AND "\
                "updated_on<=? AND "\
                "state=?"
        expected = [ query, "system", "Finished", "waiting_to_start", "Queued"]
        expected += get_time_period(@opts[:time_period]) << "Initialized"
        subject.should == expected
      end

    end

    def get_time_period(period)
      t = format_timezone(period.to_i != 0 ? period.days.ago : Time.now, Time.zone, "raw")
      ret = []
      ret << t.beginning_of_day << t.end_of_day
    end

    def set_opts(hsh)
      hsh.each_pair { |k,v| @opts[k] = v }
    end
  end

  context "#button" do
    it "when VM Right Size Recommendations is pressed" do
      controller.instance_variable_set(:@_params, {:pressed => "vm_right_size"})
      controller.should_receive(:vm_right_size)
      controller.button
      controller.send(:flash_errors?).should_not be_true
    end

    it "when VM Migrate is pressed" do
      controller.instance_variable_set(:@_params, {:pressed => "vm_migrate"})
      controller.instance_variable_set(:@refresh_partial,"layouts/gtl")
      controller.should_receive(:prov_redirect).with("migrate")
      controller.should_receive(:render)
      controller.button
      controller.send(:flash_errors?).should_not be_true
    end

    it "when VM Retire is pressed" do
      controller.instance_variable_set(:@_params, {:pressed => "vm_retire"})
      controller.should_receive(:retirevms).once
      controller.button
      controller.send(:flash_errors?).should_not be_true
    end

    it "when VM Manage Policies is pressed" do
      controller.instance_variable_set(:@_params, {:pressed => "vm_protect"})
      controller.should_receive(:assign_policies).with(VmOrTemplate)
      controller.button
      controller.send(:flash_errors?).should_not be_true
    end

    it "when MiqTemplate Manage Policies is pressed" do
      controller.instance_variable_set(:@_params, {:pressed => "miq_template_protect"})
      controller.should_receive(:assign_policies).with(VmOrTemplate)
      controller.button
      controller.send(:flash_errors?).should_not be_true
    end

    it "when VM Tag is pressed" do
      controller.instance_variable_set(:@_params, {:pressed => "vm_tag"})
      controller.should_receive(:tag).with(VmOrTemplate)
      controller.button
      controller.send(:flash_errors?).should_not be_true
    end

    it "when MiqTemplate Tag is pressed" do
      controller.instance_variable_set(:@_params, {:pressed => "miq_template_tag"})
      controller.should_receive(:tag).with(VmOrTemplate)
      controller.button
      controller.send(:flash_errors?).should_not be_true
    end
  end
end
