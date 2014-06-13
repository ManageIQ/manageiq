require "spec_helper"

$:.push(File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'util')))
require 'vmdb-logger'

describe VMDBLogger do
  it ".contents with no log returns empty string" do
    File.stub(:file? => false)
    VMDBLogger.contents("mylog.log").should == ""
  end

  it ".contents with empty log returns empty string" do   
    require 'miq-system'
    MiqSystem.stub(:tail => "")

    File.stub(:file? => true)
    VMDBLogger.contents("mylog.log").should == ""
  end

  context "with evm log snippet with invalid utf8 byte sequence data" do
    before(:each) do
      @log = File.expand_path(File.join(File.dirname(__FILE__), "data/redundant_utf8_byte_sequence.log") )
    end

    context "accessing the invalid data directly" do
      before(:each) do
        @data = File.read(@log)
      end

      it "should have content with the invalid utf8 lines" do
        @data.should_not be_nil
        @data.kind_of?(String).should be_true
      end

      it "should unpack raw data as UTF-8 characters and raise ArgumentError" do
        lambda { @data.unpack("U*") }.should raise_error(ArgumentError)
      end
    end

    context "using VMDBLogger with no width" do
      before(:each) do
        logger = VMDBLogger.new(@log)
        @contents = logger.contents(nil, 1000)
      end

      it "should have content but without the invalid utf8 lines" do
        @contents.should_not be_nil
        @contents.kind_of?(String).should be_true
      end

      it "should unpack logger.consents as UTF-8 characters and raise nothing" do
        lambda { @contents.unpack("U*") }.should_not raise_error
      end
    end

    context "using VMDBLogger with a provided width" do
      before(:each) do
        logger = VMDBLogger.new(@log)
        @contents = logger.contents(120, 5000)
      end

      it "should have content but without the invalid utf8 lines" do
        @contents.should_not be_nil
        @contents.kind_of?(String).should be_true
      end

      it "should unpack logger.consents as UTF-8 characters and raise nothing" do
        lambda { @contents.unpack("U*") }.should_not raise_error
      end
    end

    context "using VMDBLogger no limit on lines read" do
      before(:each) do
        logger = VMDBLogger.new(@log)
        @contents = logger.contents(120, nil)
      end

      it "should have content but without the invalid utf8 lines" do
        @contents.should_not be_nil
        @contents.kind_of?(String).should be_true
      end

      it "should unpack logger.consents as UTF-8 characters and raise nothing" do
        lambda { @contents.unpack("U*") }.should_not raise_error
      end
    end

    context "encoding" do
      it "with ascii file" do
        log = File.expand_path(File.join(File.dirname(__FILE__), "data/miq_ascii.log") )
        VMDBLogger.new(log).contents.encoding.name.should == "UTF-8"
        VMDBLogger.new(log).contents(100, nil).encoding.name.should == "UTF-8"
      end

      it "with utf-8 file" do
        log = File.expand_path(File.join(File.dirname(__FILE__), "data/miq_utf8.log") )
        VMDBLogger.new(log).contents.encoding.name.should == "UTF-8"
        VMDBLogger.new(log).contents(100, nil).encoding.name.should == "UTF-8"
      end
    end
  end
end
