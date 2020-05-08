RSpec.describe MiqReport do
  include Spec::Support::ArelHelper

  context "::Search" do
    before do
      @miq_report = MiqReport.new(:db => "Vm")
    end

    context "#get_order_info" do
      it "works when there is no sortby specified" do
        order = @miq_report.get_order_info
        expect(order).to be_truthy
        expect(order).to be_blank
      end

      it "works when there is a column specified as string in sortby" do
        @miq_report.sortby = "name"
        order = @miq_report.get_order_info
        expect(order).to be_truthy
        expect(stringify_arel(order)).to eq(["LOWER(\"vms\".\"name\")"])
      end

      it "works when there is a column specified as array in sortby" do
        @miq_report.sortby = ["name"]
        order = @miq_report.get_order_info
        expect(order).to be_truthy
        expect(stringify_arel(order)).to eq(["LOWER(\"vms\".\"name\")"])
      end

      it "detects a virtual association (and that it can't be sorted)" do
        @miq_report.sortby = ["parent_resource_pool.name"]
        order = @miq_report.get_order_info
        expect(order).to be_falsy
      end

      it "detects a sortable virtual column" do
        @miq_report.sortby = ["archived"]
        order = @miq_report.get_order_info
        expect(order).to be_truthy
        expect(stringify_arel(order).join(",")).to match(/ems_id.*null/i)
      end

      it "detects a sortable virtual column in a list" do
        @miq_report.sortby = %w(name archived id)
        order = @miq_report.get_order_info
        expect(order).to be_truthy
        expect(stringify_arel(order).join(",")).to match(/name.*ems_id.*null.*id/i)
      end

      it "detects an unsortable virtual column" do
        @miq_report.sortby = ["is_evm_appliance"]
        order = @miq_report.get_order_info
        expect(order).to be_falsy
      end

      it "detects an unsortable virtual column in a list" do
        @miq_report.sortby = %w(name is_evm_appliance id)
        order = @miq_report.get_order_info
        expect(order).to be_falsy
      end

      context "works when there are columns from other tables specified in sortby" do
        it "works with association where table_name can be guessed at" do
          @miq_report.sortby = ["name", "operating_system.product_name"]
          order = @miq_report.get_order_info
          expect(order).to be_truthy
          expect(stringify_arel(order)).to eq(%w{LOWER("vms"."name") LOWER("operating_systems"."product_name")})
        end

        it "works with association where table_name can not be guessed" do
          @miq_report.sortby = ["name", "linux_initprocesses.name", "evm_owner.name"]
          order = @miq_report.get_order_info
          expect(order).to be_truthy
          expect(stringify_arel(order)).to eq(%w{LOWER("vms"."name") LOWER("system_services"."name") LOWER("users"."name")})
        end
      end

      it "adds ascending" do
        @miq_report.sortby = ["name", "evm_owner.name"]
        @miq_report.order = "Ascending"
        order = @miq_report.get_order_info
        expect(stringify_arel(order)).to eq(['LOWER("vms"."name") ASC', 'LOWER("users"."name") ASC'])
      end

      it "adds descending" do
        @miq_report.sortby = ["name", "evm_owner.name"]
        @miq_report.order = "Descending"
        order = @miq_report.get_order_info
        expect(stringify_arel(order)).to eq(['LOWER("vms"."name") DESC', 'LOWER("users"."name") DESC'])
      end
    end

    it "is not sortable for a complex virtual column" do
      @miq_report.sortby = ["is_evm_appliance"]
      order = @miq_report.get_order_info
      expect(order).to be_falsy
      expect(order).to be_nil
    end

    it "is sortable for a simple virtual column" do
      @miq_report.sortby = ["archived"]
      order = @miq_report.get_order_info
      expect(order).to be_truthy
      expect(stringify_arel(order).join(",")).to match(/"vms"."ems_id"/)
    end

    it "is sortable for a virtual column that is in another table" do
      @miq_report.sortby = ["hardware.v_pct_used_disk_space"]
      order = @miq_report.get_order_info
      expect(order).to be_truthy
      expect(stringify_arel(order).join(",")).to match(/disk_free_space/)
    end
  end
end
