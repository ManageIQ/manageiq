describe MiqQueueLogFilterer do
  # Allow for adding to the registery in the specs without messing this up
  # elsewhere in the suite.
  around do |example|
    old_filter_registry = described_class.filter_registry.dup

    example.run

    described_class.instance_variable_set(:@filter_registry, old_filter_registry)
  end

  describe ".register_filter" do
    it "adds a filter_method for a given class_name and method_name" do
      class_name    = "Foo"
      method_name   = "bar"
      filter_method = "filter_args_for_bar"

      expect(described_class.filter_registry[class_name]).to be_nil

      described_class.register_filter(class_name, method_name, filter_method)

      expect(described_class.filter_registry[class_name]).to eq("bar" => "filter_args_for_bar")
    end
  end

  describe ".inspect_args_for" do
    let(:msg_args)  { ["some", "args"] }
    let(:queue_msg) { MiqQueue.new(:class_name => "Foo", :method_name => "bar", :args => msg_args) }
    let(:foo_klass) do
      Class.new do
        def self.filter_args_for_bar(_args)
          "[FILTERED]"
        end
      end
    end

    before do
      Object.const_set(:Foo, foo_klass)
    end

    after do
      Object.send(:remove_const, :Foo)
    end

    context "without a filter" do
      it "returns the raw args" do
        result = described_class.inspect_args_for(queue_msg)
        expect(result).to eq('["some", "args"]')
      end
    end

    context "with a filter registered" do
      before do
        described_class.register_filter("Foo", "bar", "filter_args_for_bar")
      end

      it "returns the raw args" do
        result = described_class.inspect_args_for(queue_msg)
        expect(result).to eq('"[FILTERED]"')
      end
    end
  end
end
