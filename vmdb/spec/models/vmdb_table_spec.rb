require "spec_helper"

describe VmdbTable do
  context "#capture_metrics" do
    before(:each) do
      MiqDatabase.seed
      VmdbDatabase.seed
      # works with VmdbTableEvm, VmdbIndex(often not present), but not VmdbTableText
      @table = VmdbTable.where(:type => 'VmdbTableEvm').first
      @table.capture_metrics
    end

    it "populates vmdb_metrics columns" do
      metrics = @table.vmdb_metrics
      metrics.length.should == 0

      @table.capture_metrics
      metrics = @table.vmdb_metrics
      metrics.length.should_not == 0

      metric = metrics.first
      columns = %w{ size rows pages percent_bloat wasted_bytes otta table_scans sequential_rows_read
          index_scans index_rows_fetched rows_inserted rows_updated rows_deleted rows_hot_updated rows_live
          rows_dead timestamp
      }
      columns.each do |column|
        metric.send(column).should_not be_nil
      end
    end
  end

  context "#seed_indexes" do
    before(:each) do
      @db = VmdbDatabase.seed_self
      @vmdb_table = FactoryGirl.create(:vmdb_table, :vmdb_database => @db, :name => 'foo')
    end

    it "adds new indexes" do
      index_names = ['flintstones']
      index_results = index_names.collect do |i|
        index = mock('sql_index')
        index.stub(:name).and_return(i)
        index
      end
      @vmdb_table.stub(:sql_indexes).and_return(index_results)
      @vmdb_table.seed_indexes
      @vmdb_table.vmdb_indexes.collect(&:name).should == index_names
    end

    it "removes deleted indexes" do
      index_names = ['flintstones']
      index_names.each { |i| FactoryGirl.create(:vmdb_index, :vmdb_table => @vmdb_table, :name => i) }
      @vmdb_table.reload
      @vmdb_table.vmdb_indexes.collect(&:name).should == index_names

      @vmdb_table.stub(:sql_indexes).and_return([])
      @vmdb_table.seed_indexes
      @vmdb_table.reload
      @vmdb_table.vmdb_indexes.collect(&:name).should == []
    end

    it "finds existing indexes" do
      index_names = ['flintstones']
      index_results = index_names.collect do |i|
        index = mock('sql_index')
        index.stub(:name).and_return(i)
        index
      end
      index_names.each { |i| FactoryGirl.create(:vmdb_index, :vmdb_table => @vmdb_table, :name => i) }
      @vmdb_table.stub(:sql_indexes).and_return(index_results)
      @vmdb_table.seed_indexes
      @vmdb_table.reload
      @vmdb_table.vmdb_indexes.collect(&:name).should == index_names
    end
  end


  pending("New model-based-rewrite") do
    before(:each) do
      VmdbTable.registered.clear
      VmdbTable.atStartup
      MiqDatabase.seed
      @db = MiqDatabase.first
      @test_tables = %w(vdi_desktop_pools_vdi_users ui_tasks miq_regions miq_databases)
      @unpopulated_tables = %w{hosts vms}
      @populated_tables = %w(miq_regions miq_databases)
    end

    after(:each) do
      VmdbTable.registered.clear
    end

    context "#new" do
      it "will raise error on invalid name" do
        lambda { VmdbTable.new(:name => "miq_databases123") }.should raise_error(StandardError)
      end

      it "will raise error for already registered table" do
        VmdbTable.new(:name => "miq_databases")
        lambda { VmdbTable.new(:name => "miq_databases") }.should raise_error(StandardError)
      end

      it "will register table" do
        VmdbTable.new(:name => "miq_databases")
        VmdbTable.should be_registered("miq_databases")
      end

      it "will assign ids in table alphabetical order" do
        tables = @test_tables.collect { |t| VmdbTable.new(:name => t) }
        tables.sort_by(&:id).collect(&:name).should == @test_tables.sort
      end
    end

    it "#id" do
      t = VmdbTable.new(:name => "miq_databases")
      t.id.should be_kind_of Integer
    end

    it "#miq_database" do
      t = VmdbTable.new(:name => "miq_databases")
      t.miq_database.should    == @db
      t.miq_database_id.should == @db.id
    end

    context "#description" do
      it "will be delay loaded" do
        t = VmdbTable.new(:name => "ui_tasks")
        t.read_attribute(:description).should be_nil
        t.description.should == "Ui Tasks"
      end

      it "will be obtained from ui_lookup" do
        VmdbTable.new(:name => "ems_events").description.should == "Management Events"
      end
    end

    context "#record_count" do
      it "will handle tables with models" do
        VmdbTable.new(:name => "miq_databases").record_count.should == 1
      end

      it "will handle tables without models" do
        VmdbTable.new(:name => "vdi_desktop_pools_vdi_users").record_count.should >= 0
      end
    end

    context "#model_name" do
      it "will handle tables with models" do
        VmdbTable.new(:name => "miq_databases").model_name.should == "MiqDatabase"
      end

      it "will handle tables without models" do
        VmdbTable.new(:name => "vdi_desktop_pools_vdi_users").model_name.should == "VdiDesktopPoolsVdiUser"
      end
    end

    context "#model" do
      it "will handle tables with models" do
        VmdbTable.new(:name => "miq_databases").model.should == MiqDatabase
      end

      it "will handle tables without models" do
        VmdbTable.new(:name => "vdi_desktop_pools_vdi_users").model.should be_nil
      end
    end

    context "#export" do
      it "will handle tables without models" do
        lambda { VmdbTable.new(:name => "vdi_desktop_pools_vdi_users").export }.should_not raise_error
      end

      it "will return nil if no data in tables" do
        YAML.should_receive(:dump).never
        VmdbTable.new(:name => "vms").export.should be_nil
      end

      it "will return yaml if data in tables" do
        YAML.stub(:dump).once
        dest_zip = VmdbTable.new(:name => "miq_databases").export
        File.basename(dest_zip).should == "miq_databases.yml"
      end

      context "with non-exportable table" do
        it "will return nil" do
          VmdbTable.should_receive(:select_all_for_export).never
          table = VmdbTable.new(:name => "states")
          table.export.should be_nil
        end

        it "with :force => true will return yaml" do
          YAML.stub(:dump).once
          table = VmdbTable.new(:name => "states")
          table.stub(:select_all_for_export).and_return([1,2,3])
          dest_zip = table.export(:force => true)
          File.basename(dest_zip).should == "states.yml"
        end
      end
    end

    context ".export_all_by_id" do
      it "will return nil if no data in tables" do
        ids = VmdbTable.find_all_by_name(@unpopulated_tables).collect(&:id)

        YAML.should_receive(:dump).never
        VmdbTable.export_all_by_id(ids).should be_nil
      end

      it "will export selected tables" do
        ids = VmdbTable.find_all_by_name(@populated_tables).collect(&:id)

        VmdbTable.any_instance.should_receive(:export).times(ids.length)
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

        File.exist?(dest_zip).should be_true
        File.zero?(dest_zip).should  be_false
        File.exist?(yaml_file).should be_false
      ensure
        File.delete(dest_zip) rescue nil
        File.delete(yaml_file) rescue nil
      end
    end

    context ".export_queue" do
      before(:each) do
        MiqRegion.seed
        EvmSpecHelper.create_guid_miq_server_zone
        @ids = VmdbTable.find_all_by_name(@populated_tables).collect(&:id)
        @dest_zip = File.join(VmdbTable.export_output_dir, "evm_export.zip")
      end

      after(:each) do
        File.delete(@dest_zip) rescue nil
      end

      it "with a single id" do
        task_id = VmdbTable.export_queue(@ids.first, :userid => "admin", :action => "Export Tables")
        task_id.should be_kind_of(Integer)

        q = MiqQueue.first(:conditions => { :class_name  => "VmdbTable", :method_name => "export_all_by_id" })
        q.should_not be_nil

        q.delivered(*q.deliver)
        task = MiqTask.find_by_id(task_id)
        File.open(@dest_zip, "w") { |f| f.write task.task_results }
        Zip::ZipFile.open(@dest_zip) do |z|
          z.file.exists?("#{@populated_tables.first}.yml").should be_true
        end
      end

      it "with multiple ids" do
        taskid = VmdbTable.export_queue(@ids, :userid => "admin", :action => "Export Tables")
        taskid.should be_kind_of(Integer)

        q = MiqQueue.first(:conditions => { :class_name  => "VmdbTable", :method_name => "export_all_by_id" })
        q.should_not be_nil

        q.delivered(*q.deliver)
        task = MiqTask.find_by_id(taskid)
        File.open(@dest_zip, "w") { |f| f.write task.task_results }
        Zip::ZipFile.open(@dest_zip) do |z|
          @populated_tables.each do |t|
            z.file.exists?("#{t}.yml").should be_true
          end
        end
      end
    end

    context ".find" do
      context "first" do
        it "without conditions" do
          t = VmdbTable.vmdb_table_names.first
          VmdbTable.find(:first).name.should == t
          VmdbTable.first.name.should        == t
        end

        it "with conditions" do
          t = VmdbTable.vmdb_table_names.second
          VmdbTable.find(:first, :conditions => {:id => [2, 3]}).name.should == t
          VmdbTable.first(:conditions => {:id => [2, 3]}).name.should        == t
        end
      end

      context "last" do
        it "without conditions" do
          t = VmdbTable.vmdb_table_names.last
          VmdbTable.find(:last).name.should == t
          VmdbTable.last.name.should        == t
        end

        it "with conditions" do
          t = VmdbTable.vmdb_table_names.third
          VmdbTable.find(:last, :conditions => {:id => [2, 3]}).name.should == t
          VmdbTable.last(:conditions => {:id => [2, 3]}).name.should        == t
        end
      end

      context "all" do
        it "without conditions" do
          t = VmdbTable.vmdb_table_names
          VmdbTable.find(:all).collect(&:name).should == t
          VmdbTable.all.collect(&:name).should        == t
        end

        context "with conditions" do
          it "of an array of ids" do
            t = VmdbTable.vmdb_table_names[0, 2]
            VmdbTable.find(:all, :conditions => {:id => [1,2]}).collect(&:name).should == t
            VmdbTable.all(:conditions => {:id => [1,2]}).collect(&:name).should        == t
          end

          it "of a single id" do
            t = [VmdbTable.vmdb_table_names.second]
            VmdbTable.find(:all, :conditions => {:id => 2}).collect(&:name).should == t
            VmdbTable.all(:conditions => {:id => 2}).collect(&:name).should        == t
          end

          it "of an array of invalid ids" do
            VmdbTable.find(:all, :conditions => {:id => [650, 651]}).collect(&:name).should be_empty
            VmdbTable.all(:conditions => {:id => [650, 651]}).collect(&:name).should        be_empty
          end

          it "of an array of both invalid and valid ids" do
            t = [VmdbTable.vmdb_table_names.first]
            VmdbTable.find(:all, :conditions => {:id => [650, 1]}).collect(&:name).should == t
            VmdbTable.all(:conditions => {:id => [650, 1]}).collect(&:name).should        == t
          end

          it "of a single invalid id" do
            VmdbTable.find(:all, :conditions => {:id => 650}).should be_empty
            VmdbTable.all(:conditions => {:id => 650}).should        be_empty
          end
        end
      end
    end

    context ".find_by_id" do
      it "without options" do
        VmdbTable.find_by_id(1).name.should == VmdbTable.vmdb_table_names.first
      end

      it "with options" do
        VmdbTable.find_by_id(1, :include => {}).name.should == VmdbTable.vmdb_table_names.first
      end
    end

    context ".find_all_by_id" do
      context "with multiple params" do
        it "without options" do
          VmdbTable.find_all_by_id(1, 2, 3).collect(&:name).should == VmdbTable.vmdb_table_names[0, 3]
        end

        it "with options" do
          VmdbTable.find_all_by_id(1, 2, 3, :include => {}).collect(&:name).should == VmdbTable.vmdb_table_names[0, 3]
        end
      end

      context "with single array param" do
        it "without options" do
          VmdbTable.find_all_by_id([1, 2, 3]).collect(&:name).should == VmdbTable.vmdb_table_names[0, 3]
        end

        it "with options" do
          VmdbTable.find_all_by_id([1, 2, 3], :include => {}).collect(&:name).should == VmdbTable.vmdb_table_names[0, 3]
        end
      end
    end

    context ".find_by_name" do
      it "will find by name" do
        VmdbTable.find_by_name('miq_databases').name.should == 'miq_databases'
      end

      it "on first request will register the object" do
        prior_count = VmdbTable.registered.length
        VmdbTable.find_by_name('miq_databases')
        VmdbTable.registered.length.should == prior_count + 1
      end

      it "on susequent request will return the registered object" do
        obj = VmdbTable.find_by_name('miq_databases')

        prior_count = VmdbTable.registered.length
        VmdbTable.find_by_name('miq_databases').should equal obj
        VmdbTable.registered.length.should == prior_count
      end
    end

    context ".find_all_by_name" do
      it "with multiple params" do
        VmdbTable.find_all_by_name('miq_databases', 'miq_regions').collect(&:name).should == ['miq_databases', 'miq_regions']
      end

      it "with single array param" do
        VmdbTable.find_all_by_name(['miq_databases', 'miq_regions']).collect(&:name).should == ['miq_databases', 'miq_regions']
      end
    end

  end

end
