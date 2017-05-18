require_migration

RSpec.describe SetServiceDisplayAndRetiredToFalse do
  migration_context :up do
    it "sets any null display values to false" do
      service = migration_stub(:Service).create!(:display => nil)

      migrate

      expect(service.reload.display).to be(false)
    end

    it "sets any null retired values to false" do
      service = migration_stub(:Service).create!(:retired => nil)

      migrate

      expect(service.reload.retired).to be(false)
    end
  end

  migration_context :down do
    it "leaves false display values as false" do
      service = migration_stub(:Service).create!(:display => false)

      migrate

      expect(service.reload.display).to be(false)
    end

    it "leaves false retired values as false" do
      service = migration_stub(:Service).create!(:retired => false)

      migrate

      expect(service.reload.retired).to be(false)
    end
  end
end
