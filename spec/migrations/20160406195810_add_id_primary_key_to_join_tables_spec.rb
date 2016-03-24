require_migration

describe AddIdPrimaryKeyToJoinTables do
  let(:connection)  { described_class.connection }
  let(:region_stub) { migration_stub(:MiqRegion) }

  migration_context :up do
    context "on a replication target" do
      let(:remote_region_id)          { ApplicationRecord.my_region_number + 1 }
      let(:remote_region_range_start) { ApplicationRecord.region_to_range(remote_region_id).begin }
      let(:my_region_id)          { ApplicationRecord.my_region_number }
      let(:my_region_range_start) { ApplicationRecord.region_to_range(my_region_id).begin }

      before do
        region_stub.create!(:id => my_region_range_start, :region => my_region_id)
        region_stub.create!(:id => remote_region_range_start, :region => remote_region_id)
      end

      it "removes rows from remote regions" do
        described_class::JOIN_TABLES.each do |table|
          connection.select_value <<-SQL
            INSERT INTO #{table} VALUES (#{my_region_range_start}, #{my_region_range_start + 1})
          SQL

          connection.select_value <<-SQL
            INSERT INTO #{table} VALUES (#{remote_region_range_start}, #{remote_region_range_start + 1})
          SQL
        end

        migrate

        described_class::JOIN_TABLES.each do |table|
          connection.select_all("SELECT * FROM #{table}").each do |row|
            row.each do |k, v|
              expect(ApplicationRecord.id_in_current_region?(v)).to be(true), <<-EOS.lstrip
                #{k} value (#{v}) in table #{table} is not in the correct region
              EOS
            end
          end
        end
      end
    end

    it "assigns an id in the correct range" do
      described_class::JOIN_TABLES.each_with_index do |table, i|
        connection.select_value <<-SQL
          INSERT INTO #{table} VALUES (#{i}, #{i + 1})
        SQL
      end

      migrate

      described_class::JOIN_TABLES.each do |table|
        expect(connection.primary_keys(table)).to eq(["id"])

        connection.select_all("SELECT * FROM #{table}").each do |row|
          expect(ApplicationRecord.id_in_current_region?(row["id"])).to be true
        end
      end
    end
  end

  migration_context :down do
    it "recreates the composite primary key" do
      migrate

      described_class::JOIN_TABLES.each do |table|
        expect(connection.primary_keys(table).count).to eq(2)
      end
    end
  end
end
