require "spec_helper"

describe MiqReport::ImportExport do
  before do
    MiqRegion.seed

    @user       = FactoryGirl.create(:user_admin)
    @old_report = FactoryGirl.create(:miq_report, 
                                     :name      => "Test Report",
                                     :rpt_type  => "Custom",
                                     :tz        => "Eastern Time (US & Canada)",
                                     :col_order => ["name", "boot_time", "disks_aligned"],
                                     :cols      => ["name", "boot_time", "disks_aligned"]
    )
  end

  context ".import_from_hash" do
    before do
      report_string = MiqReport.export_to_yaml([@old_report.id], MiqReport)
      @new_report   = YAML.load(report_string).first
      @options      = {
        :overwrite => true,
        :userid    => @user.userid
      }
    end

    subject { MiqReport.import_from_hash(@new_report, @options) }

    context "new report" do
      before { @old_report.destroy }

      it "preview" do
        _, result = subject

        result[:status].should == :add
        MiqReport.count.should == 0
      end

      it "import" do
        @options[:save] = true
        _, result = subject
        result[:status].should == :add
        MiqReport.count.should == 1
      end
    end

    context "existing report" do
      before { @old_report.update_attributes(:tz => "UTC") }

      context "overwrite" do
        it "preview" do
          _, result = subject
          result[:status].should == :update
          MiqReport.first.tz.should == "UTC"
        end

        it "import" do
          @options[:save] = true
          _, result = subject
          result[:status].should == :update
          MiqReport.first.tz.should == "Eastern Time (US & Canada)"
        end
      end

      context "no overwrite" do
        before { @options[:overwrite] = false }

        it "preview" do
          _, result = subject
          result[:status].should == :keep
          MiqReport.first.tz.should == "UTC"
        end

        it "import" do
          @options[:save] = true
          _, result = subject
          result[:status].should == :keep
          MiqReport.first.tz.should == "UTC"
        end
      end
    end

    context "legacy report" do
      it "import" do
        @new_report = @new_report["MiqReport"]

        _, result = subject
        result[:status].should == :update
      end
    end
  end
end
