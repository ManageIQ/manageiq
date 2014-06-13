require "spec_helper"
require 'util/miq_logger_processor'

describe MiqLoggerProcessor do
  MLP_DATA_DIR = File.expand_path(File.join(File.dirname(__FILE__), 'data'))

  EXPECTED_LINE_PARTS = [
    [
      "[----] I, [2011-02-07T17:30:59.744697 #14909:15aee2c37f0c]  INFO -- : MIQ(SQLServer.apply_connection_config) trans_isolation_level: [], lock_timeout: []\r\n",
      "2011-02-07T17:30:59.744697",
      "14909",
      "15aee2c37f0c",
      "INFO",
      nil,
      "MIQ(SQLServer.apply_connection_config) trans_isolation_level: [], lock_timeout: []",
    ],
    [
      "[----] I, [2011-02-07T17:31:05.282104 #4909:03941abd4fe]  INFO -- : MIQ(EmsRefreshWorker) ID [108482], PID [14909], GUID [0461c4a4-32e0-11e0-89ad-0050569a00bb], Zone [WB], Active Roles\r\n",
      "2011-02-07T17:31:05.282104",
      "4909",
      "03941abd4fe",
      "INFO",
      nil,
      "MIQ(EmsRefreshWorker) ID [108482], PID [14909], GUID [0461c4a4-32e0-11e0-89ad-0050569a00bb], Zone [WB], Active Roles",
    ],
    [
      "[----] I, [2011-02-07T17:31:05.282996 #14909:15aee2c37f0c]  INFO -- :   :cpu_usage_threshold: 100\r\nthis\r\nis a\r\nmultiline\r\n",
      "2011-02-07T17:31:05.282996",
      "14909",
      "15aee2c37f0c",
      "INFO",
      nil,
      "  :cpu_usage_threshold: 100\r\nthis\r\nis a\r\nmultiline",
    ],
    [
      "[----] I, [2011-02-07T07:49:16.719656 #23130:15c945a976fc]  INFO -- : Q-task_id([1753657a-3288-11e0-bd88-0050569a00ba]) MIQ(MiqQueue.get)        Message id: [18261690] stale, retrying...\r\n",
      "2011-02-07T07:49:16.719656",
      "23130",
      "15c945a976fc",
      "INFO",
      "1753657a-3288-11e0-bd88-0050569a00ba",
      "MIQ(MiqQueue.get)        Message id: [18261690] stale, retrying...",
    ],
    [
      "[----] I, [2011-02-07T10:41:37.668866 #29614:15a82de14700]  INFO -- : Q-task_id([job_dispatcher]) MIQ(MiqQueue.get)        Message id: [18261690] stale, retrying...\r\n",
      "2011-02-07T10:41:37.668866",
      "29614",
      "15a82de14700",
      "INFO",
      "job_dispatcher",
      "MIQ(MiqQueue.get)        Message id: [18261690] stale, retrying...",
    ],
    [
      "[1234] I, [2011-02-07T17:30:59.744697 #14909:15aee2c37f0c]  INFO -- : MIQ(SQLServer.apply_connection_config) trans_isolation_level: [], lock_timeout: []\r\n",
      "2011-02-07T17:30:59.744697",
      "14909",
      "15aee2c37f0c",
      "INFO",
      nil,
      "MIQ(SQLServer.apply_connection_config) trans_isolation_level: [], lock_timeout: []",
    ],
  ]

  EXPECTED_RAW_LINES = EXPECTED_LINE_PARTS.collect(&:first)

  before(:each) do
    @lp = MiqLoggerProcessor.new(File.join(MLP_DATA_DIR, 'miq_logger_processor.log'))
  end

  context "reading raw lines" do
    before(:each) { @lines = @lp.to_a }

    it "will read the correct number of lines" do
      @lines.length.should == EXPECTED_RAW_LINES.length
    end

    it "will read the correct number of lines when called twice" do
      @lines = @lp.to_a
      @lines.length.should == EXPECTED_RAW_LINES.length
    end

    it "will read regular lines correctly" do
      @lines[0].should == EXPECTED_RAW_LINES[0]
    end

    it "will read lines with shortened pid/tid correctly" do
      @lines[1].should == EXPECTED_RAW_LINES[1]
    end

    it "will read multi-line lines correctly" do
      @lines[2].should == EXPECTED_RAW_LINES[2]
    end

    it "will read Q-task_id lines correctly" do
      @lines[3].should == EXPECTED_RAW_LINES[3]
    end

    it "will read Q-task_id lines that do not have GUIDs correctly" do
      @lines[4].should == EXPECTED_RAW_LINES[4]
    end

    it "will read lines with a numeric starting message correctly" do
      @lines[5].should == EXPECTED_RAW_LINES[5]
    end
  end

  shared_examples_for "all line processors" do
    it "will read regular lines correctly" do
      @lines[0].should == EXPECTED_LINE_PARTS[0]
    end

    it "will read lines with shortened pid/tid correctly" do
      @lines[1].should == EXPECTED_LINE_PARTS[1]
    end

    it "will read multi-line lines correctly" do
      @lines[2].should == EXPECTED_LINE_PARTS[2]
    end

    it "will read Q-task_id lines correctly" do
      @lines[3].should == EXPECTED_LINE_PARTS[3]
    end

    it "will read Q-task_id lines that do not have GUIDs correctly" do
      @lines[4].should == EXPECTED_LINE_PARTS[4]
    end

    it "will read lines with a numeric starting message correctly" do
      @lines[5].should == EXPECTED_LINE_PARTS[5]
    end
  end

  [:split, :to_a, :parts].each do |method_name|
    context "calling #{method_name} on successive lines" do
      before(:each) do
        @lines = @lp.collect { |line| [line, *line.send(method_name)] }
      end

      it_should_behave_like "all line processors"
    end
  end

  context "calling instance methods on successive lines" do
    before(:each) do
      @lines = @lp.collect { |line| [line, *MiqLoggerLine::PARTS.collect { |p| line.send(p) }] }
    end

    it_should_behave_like "all line processors"
  end
end
