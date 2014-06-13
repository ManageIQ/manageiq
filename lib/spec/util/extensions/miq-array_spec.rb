require "spec_helper"

$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. .. util extensions})))
require 'miq-string'
require 'miq-array'

describe NilClass do
  it '#to_miq_a' do
    nil.to_miq_a.should == []
  end
end

describe Hash do
  it '#to_miq_a' do
    {}.to_miq_a.should == [{}]
  end
end

describe String do
  context "#to_miq_a" do
    it 'normal' do
      "onetwo".to_miq_a.should == ["onetwo"]
    end

    it 'with an empty string' do
      "".to_miq_a.should == []
    end

    it 'with newlines' do
      "one\ntwo".to_miq_a.should == ["one\n", "two"]
    end
  end
end

describe Array do
  it "#to_miq_a" do
    [].to_miq_a.should == []
    [[]].to_miq_a.should == [[]]
  end
end
