require_migration

describe SetVisibleToTrueForCustomAttributes do
  let(:custom_attribute_stub) { migration_stub(:CustomAttribute) }

  migration_context :up do
    it "sets display to true" do
      ca = custom_attribute_stub.create!(:name => 'example', :value => 'foo')

      migrate

      expect(ca.reload.visible).to be(true)
    end
  end
end
