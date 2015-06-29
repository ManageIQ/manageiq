require "spec_helper"

$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. discovery})))
require 'PortScan'

require 'ostruct'
require 'benchmark'

describe PortScanner do
  before(:each) do
    @ost = OpenStruct.new
    @ost.ipaddr = "192.168.252.2" # yoda (ESX)
  end

  context ".portOpen" do
    it "with an open port" do
      TCPSocket.should_receive(:open).and_return(StringIO.new)
      described_class.portOpen(@ost, 903).should be_true
    end

    it "with a closed port" do
      TCPSocket.should_receive(:open).and_raise(Timeout::Error)
      described_class.portOpen(@ost, 904).should be_false
    end

    it "with a changed timeout value" do
      @ost.timeout = 0.001
      TCPSocket.stub(:open) { sleep 1 }
      ts = Benchmark.realtime do
        described_class.portOpen(@ost, 123).should be_false
      end
      ts.should < 0.5
    end
  end

  context ".scanPortArray" do
    before(:each) do
      described_class.stub(:portOpen).with(@ost, 902).and_return(true)
      described_class.stub(:portOpen).with(@ost, 903).and_return(true)
      described_class.stub(:portOpen).with(@ost, 904).and_return(false)
      described_class.stub(:portOpen).with(@ost, 905).and_return(false)
    end

    it("with all open ports")  { described_class.scanPortArray(@ost, [902, 903]).should == [902, 903] }
    it("with some open ports") { described_class.scanPortArray(@ost, [903, 904]).should == [903] }
    it("with no open ports")   { described_class.scanPortArray(@ost, [904, 905]).should == [] }
  end

  context ".scanPortRange" do
    before(:each) do
      described_class.stub(:portOpen).with(@ost, 902).and_return(true)
      described_class.stub(:portOpen).with(@ost, 903).and_return(true)
      described_class.stub(:portOpen).with(@ost, 904).and_return(false)
      described_class.stub(:portOpen).with(@ost, 905).and_return(false)
    end

    it("with all open ports")  { described_class.scanPortRange(@ost, 902, 903).should == [902, 903] }
    it("with some open ports") { described_class.scanPortRange(@ost, 903, 904).should == [903] }
    it("with no open ports")   { described_class.scanPortRange(@ost, 904, 905).should == [] }
  end
end
