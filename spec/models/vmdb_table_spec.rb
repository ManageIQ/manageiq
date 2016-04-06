describe VmdbTable do
  context "#seed_indexes" do
    before(:each) do
      @db = VmdbDatabase.seed_self
      @vmdb_table = FactoryGirl.create(:vmdb_table, :vmdb_database => @db, :name => 'foo')
    end

    it "adds new indexes" do
      index_names = ['flintstones']
      index_results = index_names.collect do |i|
        index = double('sql_index')
        allow(index).to receive(:name).and_return(i)
        index
      end
      allow(@vmdb_table).to receive(:sql_indexes).and_return(index_results)
      @vmdb_table.seed_indexes
      expect(@vmdb_table.vmdb_indexes.collect(&:name)).to eq(index_names)
    end

    it "removes deleted indexes" do
      index_names = ['flintstones']
      index_names.each { |i| FactoryGirl.create(:vmdb_index, :vmdb_table => @vmdb_table, :name => i) }
      @vmdb_table.reload
      expect(@vmdb_table.vmdb_indexes.collect(&:name)).to eq(index_names)

      allow(@vmdb_table).to receive(:sql_indexes).and_return([])
      @vmdb_table.seed_indexes
      @vmdb_table.reload
      expect(@vmdb_table.vmdb_indexes.collect(&:name)).to eq([])
    end

    it "finds existing indexes" do
      index_names = ['flintstones']
      index_results = index_names.collect do |i|
        index = double('sql_index')
        allow(index).to receive(:name).and_return(i)
        index
      end
      index_names.each { |i| FactoryGirl.create(:vmdb_index, :vmdb_table => @vmdb_table, :name => i) }
      allow(@vmdb_table).to receive(:sql_indexes).and_return(index_results)
      @vmdb_table.seed_indexes
      @vmdb_table.reload
      expect(@vmdb_table.vmdb_indexes.collect(&:name)).to eq(index_names)
    end
  end

  skip("New model-based-rewrite") do
    before(:each) do
      VmdbTable.registered.clear
      VmdbTable.atStartup
      MiqDatabase.seed
      @db = MiqDatabase.first
      @test_tables = %w(schema_migrations ui_tasks miq_regions miq_databases)
      @unpopulated_tables = %w(hosts vms)
      @populated_tables = %w(miq_regions miq_databases)
    end

    after(:each) do
      VmdbTable.registered.clear
    end

    context "#new" do
      it "will raise error on invalid name" do
        expect { VmdbTable.new(:name => "miq_databases123") }.to raise_error(StandardError)
      end

      it "will raise error for already registered table" do
        VmdbTable.new(:name => "miq_databases")
        expect { VmdbTable.new(:name => "miq_databases") }.to raise_error(StandardError)
      end

      it "will register table" do
        VmdbTable.new(:name => "miq_databases")
        expect(VmdbTable).to be_registered("miq_databases")
      end

      it "will assign ids in table alphabetical order" do
        tables = @test_tables.collect { |t| VmdbTable.new(:name => t) }
        expect(tables.sort_by(&:id).collect(&:name)).to eq(@test_tables.sort)
      end
    end

    it "#id" do
      t = VmdbTable.new(:name => "miq_databases")
      t.id.should be_kind_of Integer
    end

    it "#miq_database" do
      t = VmdbTable.new(:name => "miq_databases")
      t.miq_database.should == @db
      t.miq_database_id.should == @db.id
    end

    context "#description" do
      it "will be delay loaded" do
        t = VmdbTable.new(:name => "ui_tasks")
        expect(t.read_attribute(:description)).to be_nil
        expect(t.description).to eq("Ui Tasks")
      end

      it "will be obtained from ui_lookup" do
        expect(VmdbTable.new(:name => "ems_events").description).to eq("Management Events")
      end
    end

    context "#record_count" do
      it "will handle tables with models" do
        expect(VmdbTable.new(:name => "miq_databases").record_count).to eq(1)
      end
    end

    context "#model_name" do
      it "will handle tables with models" do
        expect(VmdbTable.new(:name => "miq_databases").model_name).to eq("MiqDatabase")
      end
    end

    context "#model" do
      it "will handle tables with models" do
        expect(VmdbTable.new(:name => "miq_databases").model).to eq(MiqDatabase)
      end
    end

    context "#export" do
      it "will return nil if no data in tables" do
        expect(YAML).to receive(:dump).never
        expect(VmdbTable.new(:name => "vms").export).to be_nil
      end

      it "will return yaml if data in tables" do
        allow(YAML).to receive(:dump).once
        dest_zip = VmdbTable.new(:name => "miq_databases").export
        expect(File.basename(dest_zip)).to eq("miq_databases.yml")
      end

      context "with non-exportable table" do
        it "will return nil" do
          expect(VmdbTable).to receive(:select_all_for_export).never
          table = VmdbTable.new(:name => "states")
          expect(table.export).to be_nil
        end

        it "with :force => true will return yaml" do
          allow(YAML).to receive(:dump).once
          table = VmdbTable.new(:name => "states")
          allow(table).to receive(:select_all_for_export).and_return([1, 2, 3])
          dest_zip = table.export(:force => true)
          expect(File.basename(dest_zip)).to eq("states.yml")
        end
      end
    end

    context ".export_all_by_id" do
      it "will return nil if no data in tables" do
        ids = VmdbTable.find_all_by_name(@unpopulated_tables).collect(&:id)

        expect(YAML).to receive(:dump).never
        expect(VmdbTable.export_all_by_id(ids)).to be_nil
      end

      it "will export selected tables" do
        ids = VmdbTable.find_all_by_name(@populated_tables).collect(&:id)

        expect_any_instance_of(VmdbTable).to receive(:export).times(ids.length)
        VmdbTable.export_all_by_id(ids)
      end
    end

    it ".export_all_by_name" do
      VmdbTable.any_instance.should_receive(:export).times(@populated_tables.length)
      VmdbTable.export_all_by_name(@populated_tables)
    end

    it ".export_all" do
      VmdbTable.any_instance.should_receive(:export).times(VmdbTable.vmdb_table_names.length)
      VmdbTable.export_all
    end

    it ".zip_export" do
      yaml_file = File.join(VmdbTable.export_output_dir, "users.yml")
      File.open(yaml_file, "w") do |f|
        f.write(<<-EOF)
---
- region: "10"
  name: Administrator
  lastlogon: 2011-04-29 20:03:23.228455
  created_on: 2011-01-11 15:33:23.707317
  lastlogoff:
  updated_on: 2011-04-29 20:03:23.231662
  icon:
  id: "10000000000001"
  userid: admin
  last_name:
  miq_group_id: "10000000000001"
  filters:
  settings: |+
    --- {}
  ui_task_set_id: "10000000000004"
  first_name:
  email:
EOF
      end

      begin
        dest_zip = VmdbTable.zip_export([yaml_file])

        File.exist?(dest_zip).should be_truthy
        File.zero?(dest_zip).should  be_falsey
        File.exist?(yaml_file).should be_falsey
      ensure
        File.delete(dest_zip) rescue nil
        File.delete(yaml_file) rescue nil
      end
    end

    context ".export_queue" do
      before(:each) do
        EvmSpecHelper.create_guid_miq_server_zone
        @ids = VmdbTable.find_all_by_name(@populated_tables).collect(&:id)
        @dest_zip = File.join(VmdbTable.export_output_dir, "evm_export.zip")
      end

      after(:each) do
        File.delete(@dest_zip) rescue nil
      end

      it "with a single id" do
        task_id = VmdbTable.export_queue(@ids.first, :userid => "admin", :action => "Export Tables")
        expect(task_id).to be_kind_of(Integer)

        q = MiqQueue.find_by(:class_name => "VmdbTable", :method_name => "export_all_by_id")
        expect(q).not_to be_nil

        q.delivered(*q.deliver)
        task = MiqTask.find_by_id(task_id)
        File.open(@dest_zip, "w") { |f| f.write task.task_results }
        Zip::ZipFile.open(@dest_zip) do |z|
          expect(z.file.exists?("#{@populated_tables.first}.yml")).to be_truthy
        end
      end

      it "with multiple ids" do
        taskid = VmdbTable.export_queue(@ids, :userid => "admin", :action => "Export Tables")
        expect(taskid).to be_kind_of(Integer)

        q = MiqQueue.find_by(:class_name => "VmdbTable", :method_name => "export_all_by_id")
        expect(q).not_to be_nil

        q.delivered(*q.deliver)
        task = MiqTask.find_by_id(taskid)
        File.open(@dest_zip, "w") { |f| f.write task.task_results }
        Zip::ZipFile.open(@dest_zip) do |z|
          @populated_tables.each do |t|
            expect(z.file.exists?("#{t}.yml")).to be_truthy
          end
        end
      end
    end

    context ".find" do
      context "first" do
        it "without conditions" do
          t = VmdbTable.vmdb_table_names.first
          expect(VmdbTable.first.name).to eq(t)
        end

        it "with conditions" do
          t = VmdbTable.vmdb_table_names.second
          expect(VmdbTable.where(:id => [2, 3]).first.name).to eq(t)
        end
      end

      context "last" do
        it "without conditions" do
          t = VmdbTable.vmdb_table_names.last
          expect(VmdbTable.last.name).to eq(t)
        end

        it "with conditions" do
          t = VmdbTable.vmdb_table_names.third
          expect(VmdbTable.where(:id => [2, 3]).last.name).to eq(t)
        end
      end

      context "all" do
        it "without conditions" do
          t = VmdbTable.vmdb_table_names
          expect(VmdbTable.all.collect(&:name)).to eq(t)
        end
      end

      context ".where" do
        it "without conditions" do
          t = VmdbTable.vmdb_table_names
          expect(VmdbTable.where({}).collect(&:name)).to eq(t)
        end

        context "with conditions" do
          it "of an array of ids" do
            t = VmdbTable.vmdb_table_names[0, 2]
            expect(VmdbTable.where(:id => [1, 2]).collect(&:name)).to eq(t)
          end

          it "of a single id" do
            t = [VmdbTable.vmdb_table_names.second]
            expect(VmdbTable.where(:id => 1).collect(&:name)).to eq(t)
          end

          it "of an array of invalid ids" do
            expect(VmdbTable.where(:id => [650, 651])).to be_empty
          end

          it "of an array of both invalid and valid ids" do
            t = [VmdbTable.vmdb_table_names.first]
            expect(VmdbTable.where(:id => [650, 1]).collect(&:name)).to eq(t)
          end

          it "of a single invalid id" do
            expect(VmdbTable.where(:id => 650)).to be_empty
          end
        end
      end
    end

    context ".find_by_id" do
      it "without options" do
        expect(VmdbTable.find_by_id(1).name).to eq(VmdbTable.vmdb_table_names.first)
      end

      it "with options" do
        expect(VmdbTable.find_by_id(1, :include => {}).name).to eq(VmdbTable.vmdb_table_names.first)
      end
    end

    context ".find_all_by_id" do
      context "with multiple params" do
        it "without options" do
          expect(VmdbTable.find_all_by_id(1, 2, 3).collect(&:name)).to eq(VmdbTable.vmdb_table_names[0, 3])
        end

        it "with options" do
          expect(VmdbTable.find_all_by_id(1, 2, 3, :include => {}).collect(&:name)).to eq(VmdbTable.vmdb_table_names[0, 3])
        end
      end

      context "with single array param" do
        it "without options" do
          expect(VmdbTable.find_all_by_id([1, 2, 3]).collect(&:name)).to eq(VmdbTable.vmdb_table_names[0, 3])
        end

        it "with options" do
          expect(VmdbTable.find_all_by_id([1, 2, 3], :include => {}).collect(&:name)).to eq(VmdbTable.vmdb_table_names[0, 3])
        end
      end
    end

    context ".find_by_name" do
      it "will find by name" do
        expect(VmdbTable.find_by_name('miq_databases').name).to eq('miq_databases')
      end

      it "on first request will register the object" do
        prior_count = VmdbTable.registered.length
        VmdbTable.find_by_name('miq_databases')
        expect(VmdbTable.registered.length).to eq(prior_count + 1)
      end

      it "on susequent request will return the registered object" do
        obj = VmdbTable.find_by_name('miq_databases')

        prior_count = VmdbTable.registered.length
        expect(VmdbTable.find_by_name('miq_databases')).to equal obj
        expect(VmdbTable.registered.length).to eq(prior_count)
      end
    end

    context ".find_all_by_name" do
      it "with multiple params" do
        expect(VmdbTable.find_all_by_name('miq_databases', 'miq_regions').collect(&:name)).to eq(['miq_databases', 'miq_regions'])
      end

      it "with single array param" do
        expect(VmdbTable.find_all_by_name(['miq_databases', 'miq_regions']).collect(&:name)).to eq(['miq_databases', 'miq_regions'])
      end
    end
  end
end
