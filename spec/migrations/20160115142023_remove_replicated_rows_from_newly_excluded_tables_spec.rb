require_migration

describe RemoveReplicatedRowsFromNewlyExcludedTables do
  let(:event_def_stub) { migration_stub(:MiqEventDefinition) }
  let(:scan_item_stub) { migration_stub(:ScanItem) }
  let(:conf_stub)      { migration_stub(:Configuration) }

  migration_context :up do
    before do
      allow(ApplicationRecord).to receive(:my_region_number).and_return(99)
    end

    it "removes the rows from the tables" do
      event_def_stub.create!(:id => 99_000_000_000_005)
      event_def_stub.create!(:id => 5)
      event_def_stub.create!(:id => 1_000_000_000_005)

      scan_item_stub.create!(:id => 99_000_000_000_005)
      scan_item_stub.create!(:id => 5)
      scan_item_stub.create!(:id => 1_000_000_000_005)

      migrate

      expect(event_def_stub.count).to eq 1
      expect(event_def_stub.first.id).to eq 99_000_000_000_005

      expect(scan_item_stub.count).to eq 1
      expect(scan_item_stub.first.id).to eq 99_000_000_000_005
    end

    it "adds newly excluded tables to the replication worker configuration" do
      empty_settings = {
        :workers => {
          :worker_base => {
            :replication_worker => {
              :replication => {
                :exclude_tables => []
              }
            }
          }
        }
      }
      config = conf_stub.create!(:typ => "vmdb", :settings => empty_settings)

      migrate

      config.reload
      excludes = config.settings[:workers][:worker_base][:replication_worker][:replication][:exclude_tables]
      expect(excludes).to include(event_def_stub.table_name)
      expect(excludes).to include(scan_item_stub.table_name)
    end

    it "adds newly excluded tables with datatype of keys as string " do
      empty_settings = {
          "workers" => {
              "worker_base" => {
                  :replication_worker => {
                      :replication => {
                          :exclude_tables => []
                      }
                  }
              }
          }
      }
      config = conf_stub.create!(:typ => "vmdb", :settings => empty_settings)

      migrate

      config.reload
      excludes = config.settings[:workers][:worker_base][:replication_worker][:replication][:exclude_tables]
      expect(excludes).to include(event_def_stub.table_name)
      expect(excludes).to include(scan_item_stub.table_name)
    end

  end
end
