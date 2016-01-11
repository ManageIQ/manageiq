# encoding: utf-8

require "spec_helper"
require 'util/system/evm_watchdog'

describe EvmWatchdog do
  before(:each) do
    allow(EvmWatchdog).to receive(:`).and_raise("Shell access via backtick is unavailable in unit tests.")
  end

  it ".read_pid_file" do
    pid_contents = StringIO.new("10041")
    expect(described_class.read_pid_file(pid_contents)).to eq("10041")
  end

  it ".get_ps_pids" do
    allow(described_class).to receive_messages(:ps_for_process => "10041\n26726\n26729\n")
    expect(described_class.get_ps_pids("some_running_process")).to eq([10041, 26726, 26729])
  end

  context ".check_evm" do
    it "No Pid File. (EVM normal stopped state)" do
      allow(described_class).to receive_messages(:read_pid_file => nil, :get_ps_pids => nil)
      described_class.check_evm
    end

    it "Empty Pid File." do
      allow(described_class).to receive_messages(:read_pid_file => "", :get_ps_pids => nil)
      expect(described_class).to receive(:log_info).with(a_string_including "empty PID file")
      described_class.check_evm
    end

    it "Pid File Includes 'no_db' and db is down." do
      allow(described_class).to receive_messages(:read_pid_file => "no_db", :get_ps_pids => nil, :get_db_state => "")
      described_class.check_evm
    end

    it "Pid File Includes 'no_db' and db is up." do
      allow(described_class).to receive_messages(:read_pid_file => "no_db", :get_ps_pids => nil, :get_db_state => "something")
      expect(described_class).to receive(:log_info).with(a_string_including "database is now available")
      expect(described_class).to receive(:start_evm).once
      described_class.check_evm
    end

    it "Pid File Includes unexpected text." do
      allow(described_class).to receive_messages(:read_pid_file => "oranges", :get_ps_pids => nil)
      expect(described_class).to receive(:log_info).with(a_string_including "non-numeric PID file")
      described_class.check_evm
    end

    it "Pid running. (EVM normal running state)" do
      allow(described_class).to receive_messages(:read_pid_file => "12345", :get_ps_pids => [42, 12345, 9876])
      described_class.check_evm
    end

    it "Pid not running, DB down." do
      allow(described_class).to receive_messages(:read_pid_file => "12345", :get_ps_pids => [42, 9876], :get_db_state => "")
      expect(described_class).to receive(:log_info).with(a_string_including "database is down")
      described_class.check_evm
    end

    ['started', 'starting'].each do |state|
      it "Pid not running, DB up, state '#{state}'." do
        allow(described_class).to receive_messages(:read_pid_file => "12345", :get_ps_pids => [42, 9876], :get_db_state => state)
        expect(described_class).to receive(:log_info).with(a_string_including "is no longer running")
        expect(described_class).to receive(:start_evm).once
        described_class.check_evm
      end
    end

    it "Pid not running, DB up, any other state." do
      allow(described_class).to receive_messages(:read_pid_file => "12345", :get_ps_pids => [42, 9876], :get_db_state => "killed")
      expect(described_class).to receive(:log_info).with(a_string_including "server state should be")
      described_class.check_evm
    end
  end
end
