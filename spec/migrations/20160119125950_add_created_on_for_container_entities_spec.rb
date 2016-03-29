require_migration

describe AddCreatedOnForContainerEntities do
  CONTAINER_TABLES = described_class::CONTAINER_MODELS.collect { |m| m.table_name.to_sym }

  CONTAINER_TABLES.each { |table| let("#{table}_stub") { migration_stub(table.to_s.classify.to_sym) } }

  let(:mock_timestamp) { Time.zone.parse('2016-03-09 12:00:38.711120') }
  let(:mock_name)      { "Name_1" }

  migration_context :up do
    it "populates new column created_on and ems_created_on with value from creation_timestamp" do
      records = {}

      CONTAINER_TABLES.each do |table|
        records[table] = send("#{table}_stub").create!(:name => mock_name, :creation_timestamp => mock_timestamp)
      end

      migrate

      CONTAINER_TABLES.each do |table|
        expect(records[table].reload.created_on).to eq(mock_timestamp)
        expect(records[table].reload.ems_created_on).to eq(mock_timestamp)
      end
    end
  end

  migration_context :down do
    it "renames ems_created_on back to creation_timestamp and it has same value as ems_created_on" do
      records = {}

      CONTAINER_TABLES.each do |table|
        records[table] = send("#{table}_stub").create!(:name => mock_name, :ems_created_on => mock_timestamp)
      end

      migrate

      CONTAINER_TABLES.each do |table|
        expect(records[table].reload.creation_timestamp).to eq(mock_timestamp)
      end
    end
  end
end
