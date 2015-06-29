require "spec_helper"

$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. .. util extensions})))
require 'miq-object'

describe Object do
  context "#deep_send" do
    it "with string" do
      10.deep_send("to_s").should == "10"
      10.deep_send("to_s.length").should == 2
      10.deep_send("to_s.length.to_s").should == "2"
      [].deep_send("first.length").should be_nil
    end

    it "with array of strings" do
      10.deep_send(["to_s"]).should == "10"
      10.deep_send(["to_s", "length"]).should == 2
      10.deep_send(["to_s", "length", "to_s"]).should == "2"
      10.deep_send(["to_s", "length.to_s"]).should == "2"
      10.deep_send(["to_s.length", "to_s.length"]).should == 1
      [].deep_send(["first", "length"]).should be_nil
    end

    it "with direct strings" do
      10.deep_send("to_s").should == "10"
      10.deep_send("to_s", "length").should == 2
      10.deep_send("to_s", "length", "to_s").should == "2"
      10.deep_send("to_s", "length.to_s").should == "2"
      10.deep_send("to_s.length", "to_s.length").should == 1
      [].deep_send("first", "length").should be_nil
    end

    it "with array of symbols" do
      10.deep_send([:to_s]).should == "10"
      10.deep_send([:to_s, :length]).should == 2
      10.deep_send([:to_s, :length, "to_s"]).should == "2"
      [].deep_send([:first, :length]).should be_nil
    end

    it "with direct symbols" do
      10.deep_send(:to_s).should == "10"
      10.deep_send(:to_s, :length).should == 2
      10.deep_send(:to_s, :length, "to_s").should == "2"
      [].deep_send(:first, :length).should be_nil
    end

    it "with invalid" do
      lambda { 10.deep_send }.should raise_error(ArgumentError)
      lambda { 10.deep_send(nil) }.should raise_error(ArgumentError)
      lambda { 10.deep_send("") }.should raise_error(ArgumentError)
    end

    it "does not damage args" do
      args = ["to_s", "length", "to_s"]
      10.deep_send(args)
      args.should == ["to_s", "length", "to_s"]

      args = ["to_s", "length", "to_s"]
      10.deep_send(*args)
      args.should == ["to_s", "length", "to_s"]
    end
  end
end
