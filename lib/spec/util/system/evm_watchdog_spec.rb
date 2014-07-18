# encoding: utf-8


require "spec_helper"

$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. .. util system})))
require 'evm_watchdog'

describe EvmWatchdog do
  before(:each) do
    EvmWatchdog.stub(:`).and_raise("Shell access via backtick is unavailable in unit tests.")
  end

  it ".read_pid_file" do
    pid_contents = StringIO.new("10041")
    described_class.read_pid_file(pid_contents).should == "10041"
  end

  it ".get_ps_pids" do
    described_class.stub(:ps_for_process => "10041\n26726\n26729\n")
    described_class.get_ps_pids("some_running_process").should == [10041, 26726, 26729]
  end

  context ".check_evm" do

    it "No Pid File. (EVM normal stopped state)" do
      described_class.stub(:read_pid_file => nil, :get_ps_pids => nil)
      described_class.check_evm
    end

    it "Empty Pid File." do
      described_class.stub(:read_pid_file => "", :get_ps_pids => nil)
      described_class.should_receive(:log_info).with { |msg| msg.include?("empty PID file") }
      described_class.check_evm
    end

    it "Pid File Includes 'no_db' and db is down." do
      described_class.stub(:read_pid_file => "no_db", :get_ps_pids => nil, :get_db_state => "")
      described_class.check_evm
    end

    it "Pid File Includes 'no_db' and db is up." do
      described_class.stub(:read_pid_file => "no_db", :get_ps_pids => nil, :get_db_state => "something")
      described_class.should_receive(:log_info).with { |msg| msg.include?("database is now available") }
      described_class.should_receive(:start_evm).once
      described_class.check_evm
    end

    it "Pid File Includes unexpected text." do
      described_class.stub(:read_pid_file => "oranges", :get_ps_pids => nil)
      described_class.should_receive(:log_info).with { |msg| msg.include?("non-numeric PID file") }
      described_class.check_evm
    end

    it "Pid running. (EVM normal running state)" do
      described_class.stub(:read_pid_file => "12345", :get_ps_pids => [42, 12345, 9876])
      described_class.check_evm
    end

    it "Pid not running, DB down." do
      described_class.stub(:read_pid_file => "12345", :get_ps_pids => [42, 9876], :get_db_state => "")
      described_class.should_receive(:log_info).with { |msg| msg.include?("database is down") }
      described_class.check_evm
    end

    ['started', 'starting'].each do |state|
      it "Pid not running, DB up, state '#{state}'." do
        described_class.stub(:read_pid_file => "12345", :get_ps_pids => [42, 9876], :get_db_state => state)
        described_class.should_receive(:log_info).with { |msg| msg.include?("is no longer running") }
        described_class.should_receive(:start_evm).once
        described_class.check_evm
      end
    end

    it "Pid not running, DB up, any other state." do
      described_class.stub(:read_pid_file => "12345", :get_ps_pids => [42, 9876], :get_db_state => "killed")
      described_class.should_receive(:log_info).with { |msg| msg.include?("server state should be") }
      described_class.check_evm
    end
  end

end
