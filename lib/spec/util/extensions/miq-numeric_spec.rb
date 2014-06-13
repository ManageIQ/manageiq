require "spec_helper"

$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. .. util extensions})))
require 'miq-numeric'

describe Numeric do
  it "#apply_min_max" do
    8.apply_min_max(nil,nil).should == 8
    8.apply_min_max(3,nil).should   == 8
    8.apply_min_max(13,nil).should  == 13
    8.apply_min_max(nil,6).should   == 6
    8.apply_min_max(13,16).should   == 13
    20.apply_min_max(13,16).should  == 16

    8.0.apply_min_max(nil,nil).should    == 8.0
    8.0.apply_min_max(3.0,nil).should    == 8.0
    8.0.apply_min_max(13.0,nil).should   == 13.0
    8.0.apply_min_max(nil,6.0).should    == 6.0
    8.0.apply_min_max(13.0,16.0).should  == 13.0
    20.0.apply_min_max(13.0,16.0).should == 16.0
  end
end
