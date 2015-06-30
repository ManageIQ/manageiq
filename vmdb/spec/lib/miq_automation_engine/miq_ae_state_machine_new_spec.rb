require 'spec_helper'
require 'timecop'

describe "MiqAeStateMachine" do
  before do
    DummyWorkspace = Class.new do
      def initialize(options = {})
        @options = options
      end

      def root
        @options
      end
    end

    TestClass = Class.new do
      include MiqAeEngine::MiqAeStateMachine
      def initialize(options = {})
        @workspace = DummyWorkspace.new(options)
      end
    end
  end

  after do
    Object.send(:remove_const, :TestClass)
    Object.send(:remove_const, :DummyWorkspace)
  end

  context "enforce_max_retries" do
    it "exceeds retry count" do
      obj = TestClass.new('ae_state_retries' => 3)
      expect { obj.enforce_max_retries('max_retries' => 2) }.to raise_error
    end

    it "missing max_retries" do
      obj = TestClass.new
      obj.enforce_max_retries({})
    end

    it "max_retries within limits" do
      obj = TestClass.new('ae_state_retries' => 2)
      obj.enforce_max_retries('max_retries' => 4)
    end
  end

  context "enforce_max_time" do
    it "exceeds retry time" do
      Timecop.freeze
      obj = TestClass.new('ae_state_started' => Time.zone.now.utc.to_s)
      Timecop.travel(5) do
        expect { obj.enforce_max_time('max_time' => 2) }.to raise_error
      end
    end

    it "missing max_time" do
      obj = TestClass.new
      obj.enforce_max_time({})
    end

    it "max_time within limits" do
      Timecop.freeze
      obj = TestClass.new('ae_state_started' => Time.zone.now.utc.to_s)
      Timecop.travel(5) do
        obj.enforce_max_time('max_time' => '6.seconds')
      end
    end
  end
end
