RSpec.describe MiqWidget do
  context ".import_from_hash" do
    before do
      @user       = FactoryBot.create(:user_admin)
      @old_report = FactoryBot.create(:miq_report,
                                       :name      => "Test Report",
                                       :rpt_type  => "Custom",
                                       :tz        => "Eastern Time (US & Canada)",
                                       :col_order => ["name", "boot_time", "disks_aligned"],
                                       :cols      => ["name", "boot_time", "disks_aligned"]
                                      )
      @old_widget = FactoryBot.create(:miq_widget,
                                       :title      => "Test Widget",
                                       :visibility => {:roles => ["_ALL_"]},
                                       :resource   => @old_report
                                      )

      widget_string = MiqWidget.export_to_yaml([@old_widget.id], MiqWidget)
      @new_widget = YAML.load(widget_string).first["MiqWidget"]

      @options = {
        :overwrite => true,
        :userid    => @user.userid
      }
    end

    subject { MiqWidget.import_from_hash(@new_widget, @options) }

    context "new widget" do
      before { @old_widget.destroy }

      context "with new report" do
        before { @old_report.destroy }

        it "init status" do
          expect(MiqWidget.count).to eq(0)
          expect(MiqReport.count).to eq(0)
        end

        it "import" do
          @options[:save] = true
          subject
          expect(MiqWidget.count).to eq(1)
          expect(MiqReport.count).to eq(1)
        end
      end

      context "with existing report" do
        before { @old_report.update(:tz => "UTC") }

        it "init status" do
          expect(MiqWidget.count).to eq(0)
          expect(MiqReport.count).to eq(1)
        end

        it "import" do
          @options[:save] = true
          subject

          expect(MiqWidget.count).to eq(1)
          expect(MiqReport.count).to eq(1)
          expect(MiqReport.first.tz).to eq("UTC")
        end
      end
    end

    context "existing widget" do
      before do
        @old_widget.update(:visibility => {:roles => ["EvmRole-support"]})
        @old_report.update(:tz => "UTC")
      end

      context "with new report" do
        before { @old_report.destroy }

        it "init status" do
          expect(MiqWidget.count).to eq(1)
          expect(MiqReport.count).to eq(0)
        end

        it "import" do
          @options[:save] = true
          subject

          expect(MiqWidget.count).to eq(1)
          expect(MiqWidget.first.visibility).to eq(:roles => ["_ALL_"])
          expect(MiqReport.count).to eq(1)
        end
      end

      context "with existing report" do
        it "init status" do
          expect(MiqWidget.count).to eq(1)
          expect(MiqReport.count).to eq(1)
        end

        it "import" do
          @options[:save] = true
          subject

          expect(MiqWidget.count).to eq(1)
          expect(MiqWidget.first.visibility).to eq(:roles => ["_ALL_"])
          expect(MiqReport.count).to eq(1)
          expect(MiqReport.first.tz).to eq("UTC")
        end
      end
    end
  end
end
