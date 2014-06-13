require "spec_helper"

$:.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. .. util extensions})))
require 'miq-string'

describe String do
  context '1.9' do
    it "Array('str') does not warn" do
      Kernel.should_receive(:warn).never
      Array('somestring')
    end

    context 'Enumerable' do
      it 'included' do
        String.include?(Enumerable).should be_true
      end

      it '#any? warns' do
        Kernel.should_receive(:warn).once
        "one\ntwo".any? { |str| str == 'two'}.should be_true
      end

      context '#to_a' do
        it 'defined' do
          String.method_defined?(:to_a).should be_true
        end

        it 'does not respond' do
          String.respond_to?(:to_a).should_not be_true
        end

        it 'warns' do
          Kernel.should_receive(:warn).once
          "one\ntwo".to_a.should == ["one\n", 'two']
        end
      end
    end

    context '#each' do
      it 'defined' do
        String.method_defined?(:each).should be_true
      end

      it 'does not respond' do
        String.respond_to?(:each).should_not be_true
      end

      it 'calls each_line and warns' do
        str = 'one\ntwo'
        str.should_receive(:each_line).once
        Kernel.should_receive(:warn).once
        str.each { |s| s }
      end
    end
  end

  it '#<<(exception)' do
    Kernel.should_receive(:warn).once
    str = ""
    str << StandardError.new("test")
    str.should == "test"
  end

  it '#concat(exception)' do
    Kernel.should_receive(:warn).once
    str = ""
    str.concat(StandardError.new("test"))
    str.should == "test"
  end

  it '#+(exception)' do
    Kernel.should_receive(:warn).once
    str = ""
    (str + StandardError.new("test")).should == "test"
    str.should == ""
  end

  it '#ord' do
    "test".ord.should == 116
    "t".ord.should == 116
    lambda { "".ord }.should raise_error(ArgumentError)
  end
end
