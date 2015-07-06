require "spec_helper"

$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. .. util extensions})))
require 'miq-to_i_with_method'

require 'active_support/core_ext/numeric'

describe "to_i_with_method" do
  it 'String#to_i_with_method' do
    "20".to_i_with_method.should                == 20
    "20.percent".to_i_with_method.should        == 20
    "20.bytes".to_i_with_method.should          == 20.bytes
    "20.megabytes".to_i_with_method.should      == 20971520
    "20.5.megabytes".to_i_with_method.should    == 20.5.megabytes
    "123abc".to_i_with_method.should            == 123
    "2.51234.megabytes".to_i_with_method.should == 2634379
    "2,000.megabytes".to_i_with_method.should   == 2097152000
  end

  it 'String#to_f_with_method' do
    "20".to_f_with_method.should                == 20.0
    "20.percent".to_f_with_method.should        == 20.0
    "20.1.percent".to_f_with_method.should      == 20.1
    "20.bytes".to_f_with_method.should          == 20.0.bytes.to_f
    "2.51234.megabytes".to_f_with_method.should == 2634379.42784
    "20.5.megabytes".to_f_with_method.should    == 20.5.megabytes.to_f
    "123abc".to_f_with_method.should            == 123.0
    "2,000.megabytes".to_f_with_method.should   == 2097152000.0
  end

  it 'String#number_with_method?' do
    "20".number_with_method?.should              be_false
    "20.percent".number_with_method?.should      be_true
    "20.1.percent".number_with_method?.should    be_true
    "123abc".number_with_method?.should          be_false
    "2,000.megabytes".number_with_method?.should be_true
  end

  it('Integer#to_i_with_method')   { 20.to_i_with_method.should    == 20 }
  it('Integer#to_f_with_method')   { 20.to_f_with_method.should    == 20.0 }
  it('Integer#number_with_method') { 20.number_with_method?.should be_false }

  it('Float#to_i_with_method')   { 20.0.to_i_with_method.should    == 20 }
  it('Float#to_f_with_method')   { 20.0.to_f_with_method.should    == 20.0 }
  it('Float#number_with_method') { 20.0.number_with_method?.should be_false }

  it('NilClass#to_i_with_method')   { nil.to_i_with_method.should    == 0 }
  it('NilClass#to_f_with_method')   { nil.to_f_with_method.should    == 0 }
  it('NilClass#number_with_method') { nil.number_with_method?.should be_false }
end
