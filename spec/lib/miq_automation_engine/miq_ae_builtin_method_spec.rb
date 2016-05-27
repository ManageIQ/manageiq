module MiqAeBuiltinMethodSpec
  include MiqAeEngine

  describe MiqAeBuiltinMethod do
    context 'on stock class' do
      it 'corresponds when comparing builtins and builtin?' do
        described_class.builtins.each do |builtin|
          expect(described_class.builtin?(builtin)).to be_truthy
          expect(described_class.builtins.size).not_to be(0)
        end
      end
    end

    context 'on fresh class' do
      before(:each) do
        # Wipe builtins so the class is fresh to be used
        described_class.instance_exec { @builtins = nil }
      end

      after(:each) do
        # Wipe builtins so the class is fresh to be used
        described_class.instance_exec { @builtins = nil }
      end

      it 'is present when defined' do
        described_class.builtin :foo do
        end

        expect(described_class.builtin?(:foo)).to be_truthy
        expect(described_class.builtins.size).to eq(1)
      end

      it 'raises an exception when unknown builtin invoked' do
        described_class.builtin :foo do
        end

        expect { described_class.invoke_builtin(:oops, nil, nil) }.to raise_error(MiqAeException::MethodNotFound)
      end

      it 'invokes builtin with no params' do
        described_class.builtin :foo do
          true
        end

        expect(described_class.invoke_builtin(:foo, nil, nil)).to be_truthy
      end

      it 'invokes builtin with only obj param' do
        described_class.builtin :foo do |obj|
          obj
        end

        expect(described_class.invoke_builtin(:foo, 1, nil)).to be(1)
      end

      it 'invokes builtin with only legacy inputs param' do
        described_class.builtin :foo do |inputs|
          inputs
        end

        test_inputs = {:a => 1, :b => 2}
        expect(described_class.invoke_builtin(:foo, nil, test_inputs)).to be(test_inputs)
      end

      it 'invokes builtin with only input params' do
        described_class.builtin :foo do |x, y, z|
          [x, y, z]
        end

        test_inputs = {"x" => 1, "y" => 2, "z" => 3}
        test_values = [1, 2, 3]
        expect(described_class.invoke_builtin(:foo, nil, test_inputs)).to eq(test_values)
      end

      it 'input params not present replaced by nil' do
        described_class.builtin :foo do |x, y, z|
          [x, y, z]
        end

        test_inputs = {"x" => 1, "y" => 2}
        test_values = [1, 2, nil]
        expect(described_class.invoke_builtin(:foo, nil, test_inputs)).to eq(test_values)
      end

      it 'invokes builtin with all possible parameters' do
        described_class.builtin :foo do |obj, inputs, x, y, z|
          [obj, inputs, x, y, z]
        end
        test_inputs = {"x" => 1, "y" => 2}
        test_values = [10, test_inputs, 1, 2, nil]
        expect(described_class.invoke_builtin(:foo, 10, test_inputs)).to eq(test_values)
      end
    end
  end
end
