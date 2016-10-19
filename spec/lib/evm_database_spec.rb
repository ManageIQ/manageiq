describe EvmDatabase do
  subject { described_class }
  context "#local?" do
    ["localhost", "127.0.0.1", "", nil].each do |host|
      it "should know #{host} is local" do
        expect(subject).to receive(:host).at_least(:once).and_return(host)
        expect(subject).to be_local
      end
    end

    it "should know otherhost is not local" do
      expect(subject).to receive(:host).twice.and_return("otherhost")
      expect(subject).not_to be_local
    end
  end

  context "#seed_primordial" do
    it "populates seeds" do
      described_class::PRIMORDIAL_CLASSES.each { |klass| expect(klass.constantize).to receive(:seed) }
      described_class.seed_primordial
    end
  end

  describe ".find_seedable_model_class_names" do
    it "returns ordered classes first" do
      stub_const("EvmDatabase::ORDERED_CLASSES", %w(a z))
      stub_const("EvmDatabase::RAILS_ENGINE_MODEL_CLASS_NAMES", [])
      expect(described_class).to receive(:find_seedable_model_class_names).and_return(%w(a c z))
      expect(described_class.seedable_model_class_names).to eq(%w(a z c))
    end
  end

  context "schema checking" do
    def stub_test_database(db_hash)
      conn = double(:connection, :raw_connection => double(:raw_conn, :conninfo_hash => {:host => "192.168.1.2"}))
      allow(conn).to receive(:tables).and_return(db_hash.keys)
      db_hash.each do |table, col_names|
        col_objs = col_names.map { |c| double(:name => c) }
        allow(conn).to receive(:columns).with(table).and_return(col_objs)
      end
      conn
    end

    def stub_expected_schema(schema_hash)
      allow(subject).to receive(:expected_schema).and_return(schema_hash)
    end

    describe ".write_expected_schema" do
      it "writes the correct schema" do
        test_db =
          {
            "table1" => %w(id data),
            "table2" => %w(id uuid)
          }
        conn = stub_test_database(test_db)
        expected_contents = "---\ntable1:\n- id\n- data\ntable2:\n- id\n- uuid\n"

        expect(File).to receive(:write).with(subject::SCHEMA_FILE, expected_contents)
        subject.write_expected_schema(conn)
      end
    end

    describe ".check_schema" do
      it "returns nil when everything is in sync" do
        current_db =
          {
            "table1" => %w(id data),
            "table2" => %w(id uuid)
          }
        conn = stub_test_database(current_db)
        stub_expected_schema(current_db)

        expect(subject.check_schema(conn)).to be nil
      end

      context "returns an error when" do
        it "a table is missing from the schema" do
          expected_db =
            {
              "table1" => %w(id data),
              "table2" => %w(id uuid)
            }
          current_db = {"table2" => %w(id uuid)}
          conn = stub_test_database(current_db)
          stub_expected_schema(expected_db)

          expect(subject.check_schema(conn)).to match(/Schema validation failed for host 192\.168\.1\.2:\.*/)
        end

        it "an extra table is in the schema" do
          expected_db =
            {
              "table1" => %w(id data),
              "table2" => %w(id uuid)
            }
          current_db = expected_db.merge("table3" => ["id"])
          conn = stub_test_database(current_db)
          stub_expected_schema(expected_db)

          expect(subject.check_schema(conn)).to match(/Schema validation failed for host 192\.168\.1\.2:.*/)
        end

        it "the expected tables are out of order" do
          expected_db =
            {
              "table2" => %w(id uuid),
              "table1" => %w(id data)
            }
          current_db =
            {
              "table1" => %w(id data),
              "table2" => %w(id uuid)
            }
          conn = stub_test_database(current_db)
          stub_expected_schema(expected_db)

          expect(subject.check_schema(conn)).to match(/Schema validation failed for host 192\.168\.1\.2:.*/)
        end

        it "the columns in a table are out of order" do
          expected_db =
            {
              "table1" => %w(id data),
              "table2" => %w(id uuid)
            }
          current_db =
            {
              "table1" => %w(data id),
              "table2" => %w(id uuid)
            }
          conn = stub_test_database(current_db)
          stub_expected_schema(expected_db)

          expect(subject.check_schema(conn)).to match(/Schema validation failed for host 192\.168\.1\.2:.*/)
        end

        it "a table has an extra column" do
          expected_db =
            {
              "table1" => %w(id data),
              "table2" => %w(id uuid)
            }
          current_db =
            {
              "table1" => %w(id data new_data),
              "table2" => %w(id uuid)
            }
          conn = stub_test_database(current_db)
          stub_expected_schema(expected_db)

          expect(subject.check_schema(conn)).to match(/Schema validation failed for host 192\.168\.1\.2:.*/)
        end

        it "a table is missing a column" do
          expected_db =
            {
              "table1" => %w(id data),
              "table2" => %w(id uuid)
            }
          current_db =
            {
              "table1" => ["id"],
              "table2" => %w(id uuid)
            }
          conn = stub_test_database(current_db)
          stub_expected_schema(expected_db)

          expect(subject.check_schema(conn)).to match(/Schema validation failed for host 192\.168\.1\.2:.*/)
        end
      end
    end

    describe ".raise_failover_executed_event" do
      it "adds to queue request to raise 'evm_evrequest'" do
        EvmSpecHelper.create_guid_miq_server_zone
        described_class.raise_failover_executed_event
        record = MiqQueue.last
        expect(record.class_name). to eq "MiqEvent"
        expect(record.method_name).to eq "raise_evm_event"
        expect(record.args[1]).to eq "db_failover_executed"
      end
    end
  end
end
