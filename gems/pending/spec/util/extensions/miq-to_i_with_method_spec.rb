require "spec_helper"
require 'util/extensions/miq-to_i_with_method'
require 'active_support/core_ext/numeric'

describe "to_i_with_method" do
  it 'String#to_i_with_method' do
    expect("20".to_i_with_method).to eq(20)
    expect("20.percent".to_i_with_method).to eq(20)
    expect("20.bytes".to_i_with_method).to eq(20.bytes)
    expect("20.megabytes".to_i_with_method).to eq(20971520)
    expect("20.5.megabytes".to_i_with_method).to eq(20.5.megabytes)
    expect("123abc".to_i_with_method).to eq(123)
    expect("2.51234.megabytes".to_i_with_method).to eq(2634379)
    expect("2,000.megabytes".to_i_with_method).to eq(2097152000)
  end

  it 'String#to_f_with_method' do
    expect("20".to_f_with_method).to eq(20.0)
    expect("20.percent".to_f_with_method).to eq(20.0)
    expect("20.1.percent".to_f_with_method).to eq(20.1)
    expect("20.bytes".to_f_with_method).to eq(20.0.bytes.to_f)
    expect("2.51234.megabytes".to_f_with_method).to eq(2634379.42784)
    expect("20.5.megabytes".to_f_with_method).to eq(20.5.megabytes.to_f)
    expect("123abc".to_f_with_method).to eq(123.0)
    expect("2,000.megabytes".to_f_with_method).to eq(2097152000.0)
  end

  it 'String#number_with_method?' do
    expect("20".number_with_method?).to              be_falsey
    expect("20.percent".number_with_method?).to      be_truthy
    expect("20.1.percent".number_with_method?).to    be_truthy
    expect("123abc".number_with_method?).to          be_falsey
    expect("2,000.megabytes".number_with_method?).to be_truthy
  end

  it('Integer#to_i_with_method')   { expect(20.to_i_with_method).to eq(20) }
  it('Integer#to_f_with_method')   { expect(20.to_f_with_method).to eq(20.0) }
  it('Integer#number_with_method') { expect(20.number_with_method?).to be_falsey }

  it('Float#to_i_with_method')   { expect(20.0.to_i_with_method).to eq(20) }
  it('Float#to_f_with_method')   { expect(20.0.to_f_with_method).to eq(20.0) }
  it('Float#number_with_method') { expect(20.0.number_with_method?).to be_falsey }

  it('NilClass#to_i_with_method')   { expect(nil.to_i_with_method).to eq(0) }
  it('NilClass#to_f_with_method')   { expect(nil.to_f_with_method).to eq(0) }
  it('NilClass#number_with_method') { expect(nil.number_with_method?).to be_falsey }
end
