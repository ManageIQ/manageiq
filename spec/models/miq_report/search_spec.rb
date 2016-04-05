describe MiqReport do
  context "::Search" do
    before(:each) do
      @miq_report = MiqReport.new(:db => "Vm")
    end

    context "#get_order_info" do
      it "works when there is no sortby specified" do
        apply_sortby_in_search, order = @miq_report.get_order_info
        expect(apply_sortby_in_search).to be_truthy
        expect(order).to be_nil
      end

      it "works when there is a column specified as string in sortby" do
        @miq_report.sortby = "name"
        apply_sortby_in_search, order = @miq_report.get_order_info
        expect(apply_sortby_in_search).to be_truthy
        expect(order).to eq("LOWER(vms.name)")
      end

      it "works when there is a column specified as array in sortby" do
        @miq_report.sortby = ["name"]
        apply_sortby_in_search, order = @miq_report.get_order_info
        expect(apply_sortby_in_search).to be_truthy
        expect(order).to eq("LOWER(vms.name)")
      end

      context "works when there are columns from other tables specified in sortby" do
        it "works with association where table_name can be guessed at" do
          @miq_report.sortby = ["name", "operating_system.product_name"]
          apply_sortby_in_search, order = @miq_report.get_order_info
          expect(apply_sortby_in_search).to be_truthy
          expect(order).to eq("LOWER(vms.name),LOWER(operating_systems.product_name)")
        end

        it "works with association where table_name can not be guessed at" do
          @miq_report.sortby = ["name", "linux_initprocesses.name", "evm_owner.name"]
          apply_sortby_in_search, order = @miq_report.get_order_info
          expect(apply_sortby_in_search).to be_truthy
          expect(order).to eq("LOWER(vms.name),LOWER(system_services.name),LOWER(users.name)")
        end
      end
    end
  end

  context "paged_view_search" do
    # is this still needed?
    it "should not call get_cached_page to load cached results if target class does not respond to id" do
      report = MiqReport.new(
        :name      => "VmdbDatabaseSetting",
        :title     => "VmdbDatabaseSetting",
        :db        => "VmdbDatabaseSetting",
        :cols      => ["name", "description", "value", "minimum_value", "maximum_value", "unit"],
        :col_order => ["name", "description", "value", "minimum_value", "maximum_value", "unit"],
        :headers   => ["Name", "Description", "Value", "Minimum", "Maximum", "Unit"],
        :order     => "Ascending",
        :sortby    => ["name"],
        :group     => "n"
      )
      options = {
        :per_page     => 20,
        :page         => 1,
        :targets_hash => true,
        :userid       => "admin"
      }

      expect(report).to_not receive(:get_cached_page)

      results, attrs = report.paged_view_search(options)
      expect(results.length).to eq(20)
    end
  end
end
