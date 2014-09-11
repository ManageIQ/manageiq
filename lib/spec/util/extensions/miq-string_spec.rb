require "spec_helper"

$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. .. util extensions})))
require 'miq-string'

describe String do
  context '1.9' do
    it "Array('str') does not warn" do
      Kernel.should_receive(:warn).never
      Array('somestring')
    end
  end

  it '#ord' do
    "test".ord.should == 116
    "t".ord.should == 116
    lambda { "".ord }.should raise_error(ArgumentError)
  end
end
