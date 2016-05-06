describe MiqReport::ImportExport do
  before do
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
        :user      => @user
      }
    end

    subject { MiqReport.import_from_hash(@new_report, @options) }

    context "new report" do
      before { @old_report.destroy }

      it "preview" do
        _, result = subject

        expect(result[:status]).to eq(:add)
        expect(MiqReport.count).to eq(0)
      end

      it "import" do
        @options[:save] = true
        _, result = subject
        expect(result[:status]).to eq(:add)
        expect(MiqReport.count).to eq(1)
      end
    end

    context "existing report" do
      before { @old_report.update_attributes(:tz => "UTC") }

      context "overwrite" do
        it "preview" do
          _, result = subject
          expect(result[:status]).to eq(:update)
          expect(MiqReport.first.tz).to eq("UTC")
        end

        it "import" do
          @options[:save] = true
          _, result = subject
          expect(result[:status]).to eq(:update)
          expect(MiqReport.first.tz).to eq("Eastern Time (US & Canada)")
        end
      end

      context "no overwrite" do
        before { @options[:overwrite] = false }

        it "preview" do
          _, result = subject
          expect(result[:status]).to eq(:keep)
          expect(MiqReport.first.tz).to eq("UTC")
        end

        it "import" do
          @options[:save] = true
          _, result = subject
          expect(result[:status]).to eq(:keep)
          expect(MiqReport.first.tz).to eq("UTC")
        end
      end
    end

    context "legacy report" do
      it "import" do
        @new_report = @new_report["MiqReport"]

        _, result = subject
        expect(result[:status]).to eq(:update)
      end
    end
  end

  context ".view_yaml_filename" do
    let(:feature) { MiqProductFeature.find_all_by_identifier("vm_infra_explorer") }
    let(:user)    { FactoryGirl.create(:user, :features => feature) }

    before do
      EvmSpecHelper.seed_specific_product_features("vm_infra_explorer", "host_edit")
    end

    it "should return restricted view yaml for restricted user" do
      user.current_group.miq_user_role.update_attributes(:settings => {:restrictions => {:vms => :user_or_group}})
      expect(MiqReport.view_yaml_filename(VmCloud.name, user, {})).to include("Vm__restricted.yaml")
    end

    it "should return VmCloud view yaml for non-restricted user" do
      user.current_group.miq_user_role.update_attributes(:settings => {})
      expect(MiqReport.view_yaml_filename(VmCloud.name, user, {})).to include("ManageIQ_Providers_CloudManager_Vm.yaml")
    end
  end
end
