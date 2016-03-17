require_migration

describe AddDeprecatedToVms do
  let(:vm_stub) { migration_stub(:Vm) }

  migration_context :up do
    it "sets the type column" do
      vm = vm_stub.create!(:name => "Vm")

      migrate

      expect(vm.reload).to have_attributes(:deprecated => false)
    end
  end
end
