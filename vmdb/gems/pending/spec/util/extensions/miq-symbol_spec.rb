require "spec_helper"

$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. .. util extensions})))
require 'miq-symbol'

describe Symbol do
  it "#to_i" do
    :"1".to_i.should     == 1
    :"-1".to_i.should    == -1
    :test.to_i.should    == 0
    :test1.to_i.should   == 0
    :"1test".to_i.should == 1
  end
end
