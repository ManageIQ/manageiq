require 'spec_helper'
require 'timecop'


describe "MiqAeStateMachine" do
  before do
    TestClass = Class.new do
      include MiqAeEngine::MiqAeStateMachine
      def initialize(workspace)
        @workspace = workspace
      end
    end
  end

  after do
    Object.send(:remove_const, :TestClass)
  end

  let(:workspace) { instance_double("MiqAeEngine::MiqAeWorkspace", :root => options) }
  let(:test_class) { TestClass.new(workspace) }

  describe "#enforce_max_retries" do
    context "retries exceeded" do
      let(:options) { {'ae_state_retries' => 3} }

      it "should raise error" do
        expect { test_class.enforce_max_retries('max_retries' => 2) }.to raise_error
      end
    end

    context "retries empty" do
      let(:options) { {} }

      it "should not raise error" do
        expect { test_class.enforce_max_retries({}) }.to_not raise_error
      end
    end

    context "retries within limits" do
      let(:options) { {'ae_state_retries' => 2} }

      it "should not raise error" do
        expect { test_class.enforce_max_retries('max_retries' => 4) }.to_not raise_error
      end
    end
  end

  describe "#enforce_max_time" do
    context "time exceeded" do
      let(:options) { {'ae_state_started' => Time.zone.now.utc.to_s} }

      it "should raise error" do
        Timecop.freeze do
          obj = test_class
          Timecop.travel(5) do
            expect { obj.enforce_max_time('max_time' => 2) }.to raise_error
          end
        end
      end
    end

    context "time empty" do
      let(:options) { {} }
      it "should not raise error" do
        expect { test_class.enforce_max_time({}) }.to_not raise_error
      end
    end

    context "time within limits" do
      let(:options) { {'ae_state_started' => Time.zone.now.utc.to_s} }

      it "should not raise error" do
        Timecop.freeze do
          obj = test_class
          Timecop.travel(5) do
            expect { obj.enforce_max_time('max_time' => '6.seconds') }.to_not raise_error
          end
        end
      end
    end
  end
end
