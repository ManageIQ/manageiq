require "spec_helper"

describe MiqReport do
  context "::Search" do
    before(:each) do
      @miq_report = MiqReport.new(:db => "Vm")
    end

    context "#get_order_info" do
      it "works when there is no sortby specified" do
        apply_sortby_in_search, order = @miq_report.get_order_info
        apply_sortby_in_search.should be_true
        order.should be_nil
      end

      it "works when there is a column specified as string in sortby" do
        @miq_report.sortby = "name"
        apply_sortby_in_search, order = @miq_report.get_order_info
        apply_sortby_in_search.should be_true
        order.should == "LOWER(vms.name)"
      end

      it "works when there is a column specified as array in sortby" do
        @miq_report.sortby = ["name"]
        apply_sortby_in_search, order = @miq_report.get_order_info
        apply_sortby_in_search.should be_true
        order.should == "LOWER(vms.name)"
      end

      context "works when there are columns from other tables specified in sortby" do
        it "works with association where table_name can be guessed at" do
          @miq_report.sortby = ["name", "operating_system.product_name"]
          apply_sortby_in_search, order = @miq_report.get_order_info
          apply_sortby_in_search.should be_true
          order.should == "LOWER(vms.name),LOWER(operating_systems.product_name)"
        end

        it "works with association where table_name can not be guessed at" do
          @miq_report.sortby = ["name", "linux_initprocesses.name", "evm_owner.name"]
          apply_sortby_in_search, order = @miq_report.get_order_info
          apply_sortby_in_search.should be_true
          order.should == "LOWER(vms.name),LOWER(system_services.name),LOWER(users.name)"
        end
      end

    end
  end
end
