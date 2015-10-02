require "spec_helper"
require 'util/extensions/miq-symbol'

describe Symbol do
  it "#to_i" do
    :"1".to_i.should == 1
    :"-1".to_i.should == -1
    :test.to_i.should == 0
    :test1.to_i.should == 0
    :"1test".to_i.should == 1
  end
end
