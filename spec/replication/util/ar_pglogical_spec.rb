describe "ar_pglogical extension" do
  let(:connection) { ActiveRecord::Base.connection }

  before do
    skip "pglogical must be installed" unless connection.pglogical.installed?
  end

  describe "#enable" do
    it "enables the pglogical extension" do
      connection.pglogical.enable
      expect(connection.extensions).to include("pglogical")
    end
  end

  describe "#enabled?" do
    it "detects that the extensions are not enabled" do
      expect(connection.pglogical.enabled?).to be false
    end
  end

  context "with the extensions enabled" do
    let(:node_name) { "test-node" }
    let(:node_dsn)  { "host=host.example.com dbname=vmdb_test" }

    before do
      connection.pglogical.enable
    end

    describe "#enabled?" do
      it "detects that the extensions are enabled" do
        expect(connection.pglogical.enabled?).to be true
      end
    end

    describe "#disable" do
      it "disables the pglogical extension" do
        connection.pglogical.disable
        expect(connection.extensions).not_to include("pglogical")
      end
    end

    describe "#node_create" do
      it "creates a node" do
        connection.pglogical.node_create(node_name, node_dsn)
        res = connection.exec_query(<<-SQL).first
        SELECT node_name, if_dsn
        FROM pglogical.node JOIN pglogical.node_interface
          ON node_id = if_nodeid
        LIMIT 1
        SQL
        expect(res["node_name"]).to eq(node_name)
        expect(res["if_dsn"]).to eq(node_dsn)
      end
    end

    context "with a node" do
      before do
        connection.pglogical.node_create(node_name, node_dsn)
      end

      describe "#nodes" do
        it "lists the node's names and connection strings" do
          expected = {
            "name"        => node_name,
            "conn_string" => node_dsn
          }
          expect(connection.pglogical.nodes.first).to eq(expected)
        end
      end

      describe "#node_drop" do
        it "removes a node" do
          connection.pglogical.node_drop(node_name)
          res = connection.exec_query(<<-SQL)
          SELECT node_name
          FROM pglogical.node
          SQL
          expect(res.rows.flatten).not_to include(node_name)
        end
      end

      describe "#node_dsn_update" do
        let(:new_dsn) { "host='newhost.example.com' dbname='vmdb_test' user='root'" }

        it "sets the dsn" do
          expect(connection.pglogical.node_dsn_update(node_name, new_dsn)).to be true
          dsn = connection.exec_query(<<-SQL).first["if_dsn"]
            SELECT if_dsn
            FROM pglogical.node_interface if
            JOIN pglogical.node node ON
              if.if_nodeid = node.node_id
            WHERE node.node_name = '#{node_name}'
          SQL

          expect(dsn).to eq(new_dsn)
        end
      end

      describe "#replication_set_create" do
        it "creates a replication set" do
          rep_insert = true
          rep_update = true
          rep_delete = true
          rep_trunc  = false
          connection.pglogical.replication_set_create("test-set", rep_insert,
                                                      rep_update, rep_delete, rep_trunc)
          res = connection.exec_query(<<-SQL)
          SELECT *
          FROM pglogical.replication_set
          WHERE set_name = 'test-set'
          SQL

          expect(res.count).to eq(1)
          row = res.first
          expect(row["replicate_insert"]).to be true
          expect(row["replicate_update"]).to be true
          expect(row["replicate_delete"]).to be true
          expect(row["replicate_truncate"]).to be false
        end
      end

      context "with a replication set" do
        let(:set_name) { "test-set" }

        before do
          connection.pglogical.replication_set_create(set_name)
        end

        describe "#replication_sets" do
          it "lists the set names" do
            expected = ["default", "default_insert_only", "ddl_sql", set_name]
            expect(connection.pglogical.replication_sets).to match_array(expected)
          end
        end

        describe "#replication_set_alter" do
          it "alters the replication set" do
            connection.pglogical.replication_set_alter(set_name, true, true,
                                                       false, false)
            row = connection.exec_query(<<-SQL).first
            SELECT *
            FROM pglogical.replication_set
            WHERE set_name = '#{set_name}'
            SQL
            expect(row["replicate_insert"]).to be true
            expect(row["replicate_update"]).to be true
            expect(row["replicate_delete"]).to be false
            expect(row["replicate_truncate"]).to be false
          end
        end

        describe "#replication_set_drop" do
          it "removes a replication set" do
            connection.pglogical.replication_set_drop(set_name)
            res = connection.exec_query(<<-SQL)
            SELECT *
            FROM pglogical.replication_set
            WHERE set_name = '#{set_name}'
            SQL

            expect(res.count).to eq(0)
          end
        end

        describe "#replication_set_*_table" do
          it "adds and removes a table to/from the set" do
            # create a test table
            connection.exec_query(<<-SQL)
              CREATE TABLE test (id INTEGER PRIMARY KEY)
            SQL

            connection.pglogical.replication_set_add_table(set_name, "test")

            res = connection.exec_query(<<-SQL)
              SELECT *
              FROM pglogical.tables
              WHERE relname = 'test'
            SQL

            expect(res.first["set_name"]).to eq(set_name)

            connection.pglogical.replication_set_remove_table(set_name, "test")

            res = connection.exec_query(<<-SQL)
              SELECT *
              FROM pglogical.tables
              WHERE relname = 'test'
            SQL

            expect(res.first["set_name"]).to be nil
          end
        end

        describe "#replication_set_add_all_tables" do
          it "adds all the tables in a schema" do
            schema_name = "test_schema"
            connection.exec_query("CREATE SCHEMA #{schema_name}")
            connection.exec_query(<<-SQL)
              CREATE TABLE #{schema_name}.test1 (id INTEGER PRIMARY KEY)
            SQL
            connection.exec_query(<<-SQL)
              CREATE TABLE #{schema_name}.test2 (id INTEGER PRIMARY KEY)
            SQL

            connection.pglogical.replication_set_add_all_tables(set_name, [schema_name])

            set_tables = connection.exec_query(<<-SQL).rows.flatten
              SELECT relname
              FROM pglogical.tables
              WHERE set_name = '#{set_name}'
            SQL
            expect(set_tables).to include("test1")
            expect(set_tables).to include("test2")
          end
        end

        describe "#tables_in_replication_set" do
          it "lists the tables in the set" do
            # create a test table
            connection.exec_query(<<-SQL)
              CREATE TABLE test (id INTEGER PRIMARY KEY)
            SQL

            connection.pglogical.replication_set_add_table(set_name, "test")

            expect(connection.pglogical.tables_in_replication_set(set_name)).to eq(["test"])
          end
        end

        describe "#with_replication_set_lock" do
          it "takes a lock on the replication set table" do
            connection.pglogical.with_replication_set_lock(set_name) do
              result = connection.exec_query(<<-SQL)
                SELECT 1
                FROM pg_locks JOIN pg_class
                  ON pg_locks.relation = pg_class.oid
                WHERE
                  pg_class.relname = 'replication_set' AND
                  pg_locks.mode = 'RowShareLock'
              SQL
              expect(result.count).to eq(1)
            end
          end
        end
      end
    end
  end
end
