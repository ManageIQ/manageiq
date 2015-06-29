require 'spec_helper'
require 'timecop'

describe "MiqAeStateMachine" do
  before do
    class DummyWorkspace
      def initialize(options = {})
        @options = options
      end

      def root
        @options
      end
    end

    class TestClass
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
  end

  context "enforce_max_time" do
    it "exceeds retry time" do
      obj = TestClass.new('ae_state_started' => Time.zone.now)
      Timecop.travel(5) do
        expect { obj.enforce_max_time('max_time' => 2) }.to raise_error
      end
    end

    it "missing max_time" do
      obj = TestClass.new
      obj.enforce_max_time({})
    end
  end
end
