require 'timecop'

describe "MiqAeStateMachine" do
  before do
    TestClass = Class.new do
      include MiqAeEngine::MiqAeStateMachine
      def initialize(workspace)
        @workspace = workspace
      end

      def get_value(_f, type)
        @workspace.root[type]
      end
    end
  end

  after do
    Object.send(:remove_const, :TestClass)
  end

  let(:workspace) { double("MiqAeEngine::MiqAeWorkspaceRuntime", :root => options) }
  let(:test_class) { TestClass.new(workspace) }

  describe "#enforce_max_retries" do
    context "retries exceeded" do
      let(:options) { {'ae_state_retries' => 3} }

      it "should raise error" do
        expect { test_class.enforce_max_retries('max_retries' => 2) }
          .to raise_error(RuntimeError, /number of retries.*exceeded maximum/)
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
            expect { obj.enforce_max_time('max_time' => 2) }
              .to raise_error(RuntimeError, /time in state.*exceeded maximum/)
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
          expect { obj.enforce_max_time('max_time' => '6.seconds') }.to_not raise_error
        end
      end
    end
  end

  describe "#process_state_relationship" do
    context "method" do
      let(:options) { {:aetype_relationship => "Method::my_method"} }
      it "check it calls method" do
        obj = test_class
        expect(obj).to receive(:process_method_raw).with('my_method').once.and_return({})
        expect(obj).to receive(:enforce_state_maxima).with(any_args).once.and_return({})
        obj.process_state_relationship({'name' => 'a'}, "abc", nil)
      end
    end

    context "relationship" do
      let(:options) { {:aetype_relationship => "my_relations"} }
      it "check it calls relationship" do
        obj = test_class
        obj.instance_variable_set(:@rels, 'a' => "test")
        expect(obj).to receive(:process_relationship_raw).with('my_relations', 'abc', nil, 'a', nil).once.and_return({})
        expect(obj).to receive(:enforce_state_maxima).with(any_args).once.and_return({})
        obj.process_state_relationship({'name' => 'a'}, "abc", nil)
      end
    end
  end
end
