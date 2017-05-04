require_migration

describe AddEmbeddedMethodsToMiqAeMethod do
  let(:miq_ae_method_stub) { migration_stub(:MiqAeMethod) }

  migration_context :up do
    it "adds embedded_methods and sets it to []" do
      miq_ae_method_stub.create!(:name => 'method1', :class_id => 10)
      miq_ae_method_stub.create!(:name => 'method2', :class_id => 10)

      migrate

      expect(miq_ae_method_stub.count).to eq(2)
      expect(miq_ae_method_stub.first.embedded_methods).to eq([])
    end
  end
end
