RSpec.describe MiqReport::ImportExport do
  before do
    @some_user = FactoryGirl.create(:user)
    @some_group = FactoryGirl.create(:miq_group)
    @old_report = FactoryBot.create(:miq_report,
                                    :name         => "Test Report",
                                    :rpt_type     => "Custom",
                                    :tz           => "Eastern Time (US & Canada)",
                                    :col_order    => %w(name boot_time disks_aligned),
                                    :cols         => %w(name boot_time disks_aligned),
                                    :db_options   => {:rpt_type => "ChargebackContainerProject"},
                                    "include"     => {"columns" => %w(col1 col2)},
                                    :user_id      => @some_user.id,
                                    :miq_group_id => @some_group.id)
  end

  context ".import_from_hash" do
    before do
      @user_admin = FactoryBot.create(:user_admin)
      report_string = MiqReport.export_to_yaml([@old_report.id], MiqReport)
      @new_report   = YAML.load(report_string).first
      @from_json    = JSON.parse(@new_report.to_json)
      @options      = {
        :overwrite => true,
        :user      => @user_admin
      }
    end

    subject { MiqReport.import_from_hash(@new_report, @options) }

    context "importing report" do
      context ":preserve_owner is true" do
        before do
          @options[:preserve_owner] = true
          @new_report["MiqReport"]["menu_name"] = "New Test Report"
        end

        it "preserves user_id when 'userid' is present in saved report and user exists" do
          imported_report, _ = subject
          expect(imported_report["user_id"]).to eq(@some_user.id)
        end

        it "does not preserve user_id when 'userid' is present in saved report but user does not exist" do
          @some_user.delete
          imported_report, _ = subject
          expect(imported_report["user_id"]).to be nil
        end

        it "preserves miq_group_id when 'group_description' is present in saved report and group exist" do
          imported_report, _ = subject
          expect(imported_report["miq_group_id"]).to eq(@some_group.id)
        end

        it "does not preserve miq_group_id when 'group_description' is present in saved report but group does not exist" do
          @some_group.delete
          imported_report, _ = subject
          expect(imported_report["miq_group_id"]).to be nil
        end

        it "raises error if neither preserved group or preserved user exist" do
          @some_group.delete
          @some_user.delete
          expect { _imported_report, _ = subject }.to raise_error("Neither user or group to be preserved during import were found")
        end
      end

      context ":preserve_owner is false" do
        it "overrides group and users" do
          @options[:preserve_owner] = false
          imported_report, _ = subject
          expect(imported_report["miq_group_id"]).to eq(@user_admin.current_group_id)
          expect(imported_report["user_id"]).to eq(@user_admin.id)
        end
      end
    end

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

    context "keys symbolizing" do
      let(:report) do
        @options[:save] = true
        MiqReport.import_from_hash(@from_json, @options)
        MiqReport.last
      end

      it "imports from json and preserves symbolized keys in `db_options` section " do
        expect(report.db_options[:rpt_type]).to_not be_nil
      end

      it "keeps string keys in 'include:' section" do
        expect(report["include"]["columns"]).to_not be_nil
      end
    end

    context "existing report" do
      before { @old_report.update(:tz => "UTC") }

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
    let(:user)    { FactoryBot.create(:user, :features => feature) }

    before do
      EvmSpecHelper.seed_specific_product_features("vm_infra_explorer", "host_edit")
    end

    it "should return restricted view yaml for restricted user" do
      user.current_group.miq_user_role.update(:settings => {:restrictions => {:vms => :user_or_group}})
      expect(MiqReport.view_yaml_filename(VmCloud.name, user, {})).to include("Vm__restricted.yaml")
    end

    it "should return VmCloud view yaml for non-restricted user" do
      user.current_group.miq_user_role.update(:settings => {})
      expect(MiqReport.view_yaml_filename(VmCloud.name, user, {})).to include("ManageIQ_Providers_CloudManager_Vm.yaml")
    end
  end

  context ".load_from_view_options" do
    let(:current_user) { FactoryBot.create(:user_admin) }

    before do
      EvmSpecHelper.seed_specific_product_features("vm_infra_explorer", "host_edit")
    end

    it "saves filename in extras" do
      view = MiqReport.load_from_view_options(VmCloud.name, current_user)
      expect(view.extras[:filename]).to eq("ManageIQ_Providers_CloudManager_Vm")
    end
  end

  context ".load_from_filename" do
    let(:current_user) { FactoryBot.create(:user_admin) }

    before do
      EvmSpecHelper.seed_specific_product_features("vm_infra_explorer", "host_edit")
    end

    it "saves filename in extras" do
      filename = MiqReport.view_yaml_filename(VmCloud.name, current_user, {})
      view = MiqReport.load_from_filename(filename, {})
      expect(view.extras[:filename]).to eq("ManageIQ_Providers_CloudManager_Vm")
    end
  end
end
