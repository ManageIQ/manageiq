require "spec_helper"

describe MiqWidget do
  context ".import_from_hash" do
    before do
      @user       = FactoryGirl.create(:user_admin)
      @old_report = FactoryGirl.create(:miq_report, 
                                       :name      => "Test Report",
                                       :rpt_type  => "Custom",
                                       :tz        => "Eastern Time (US & Canada)",
                                       :col_order => ["name", "boot_time", "disks_aligned"],
                                       :cols      => ["name", "boot_time", "disks_aligned"]
      )
      @old_widget = FactoryGirl.create(:miq_widget, 
                                       :title      => "Test Widget", 
                                       :visibility => { :roles => ["_ALL_"] },
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
          MiqWidget.count.should == 0
          MiqReport.count.should == 0
        end

        it "preview" do
          subject
          MiqWidget.count.should == 0
          MiqReport.count.should == 0
        end

        it "import" do
          @options[:save] = true
          subject
          MiqWidget.count.should == 1
          MiqReport.count.should == 1
        end
      end

      context "with existing report" do
        before { @old_report.update_attributes(:tz => "UTC") }

        it "init status" do
          MiqWidget.count.should == 0
          MiqReport.count.should == 1
        end

        context "overwrite" do
          it "preview" do
            w, status = subject
            rep_status = status[:children]

            MiqWidget.count.should == 0
            MiqReport.count.should == 1
            MiqReport.first.tz.should == "UTC"
            rep_status[:status].should == :update
          end

          it "import" do
            @options[:save] = true
            w, status = subject
            rep_status = status[:children]

            MiqWidget.count.should == 1
            MiqReport.count.should == 1
            MiqReport.first.tz.should == "Eastern Time (US & Canada)"
            rep_status[:status].should == :update
          end
        end

        context "not overwrite" do
          before { @options[:overwrite] = false }

          it "preview" do
            w, status = subject
            rep_status = status[:children]

            MiqWidget.count.should == 0
            MiqReport.count.should == 1
            MiqReport.first.tz.should == "UTC"
            rep_status[:status].should == :keep
          end

          it "import" do
            @options[:save] = true
            w, status = subject
            rep_status = status[:children]

            MiqWidget.count.should == 1
            MiqReport.count.should == 1
            MiqReport.first.tz.should == "UTC"
            rep_status[:status].should == :keep
          end
        end
      end
    end

    context "existing widget" do
      before do
        @old_widget.update_attributes(:visibility => { :roles => ["EvmRole-support"] })
        @old_report.update_attributes(:tz => "UTC")
      end

      context "with new report" do
        before { @old_report.destroy }

        it "init status" do
          MiqWidget.count.should == 1
          MiqReport.count.should == 0
        end

        context "overwrite" do
          it "preview" do
            w, status = subject
            rep_status = status[:children]

            MiqWidget.count.should == 1
            MiqWidget.first.visibility.should == { :roles => ["EvmRole-support"]}
            status[:status].should == :update
            MiqReport.count.should == 0
            rep_status[:status].should == :add
          end

          it "import" do
            @options[:save] = true
            w, status = subject
            rep_status = status[:children]

            MiqWidget.count.should == 1
            MiqWidget.first.visibility.should == { :roles => ["_ALL_"] }
            status[:status].should == :update
            MiqReport.count.should == 1
            rep_status[:status].should == :add
          end
        end

        context "no overwrite" do
          before { @options[:overwrite] = false }

          it "preview" do
            w, status = subject
            rep_status = status[:children]

            MiqWidget.count.should == 1
            MiqWidget.first.visibility.should == { :roles => ["EvmRole-support"]}
            status[:status].should == :keep
            MiqReport.count.should == 0
            rep_status[:status].should == :add
          end

          it "import" do
            @options[:save] = true
            w, status = subject
            rep_status = status[:children]

            MiqWidget.count.should == 1
            MiqWidget.first.visibility.should == { :roles => ["EvmRole-support"]}
            status[:status].should == :keep
            MiqReport.count.should == 1
            rep_status[:status].should == :add
          end
        end
      end

      context "with existing report" do
        it "init status" do
          MiqWidget.count.should == 1
          MiqReport.count.should == 1
        end

        context "overwrite" do
          it "preview" do
            w, status = subject
            rep_status = status[:children]

            MiqWidget.count.should == 1
            MiqWidget.first.visibility.should == { :roles => ["EvmRole-support"]}
            status[:status].should == :update
            MiqReport.count.should == 1
            MiqReport.first.tz.should == "UTC"
            rep_status[:status].should == :update
          end

          it "import" do
            @options[:save] = true
            w, status = subject
            rep_status = status[:children]

            MiqWidget.count.should == 1
            MiqWidget.first.visibility.should == { :roles => ["_ALL_"] }
            status[:status].should == :update
            MiqReport.count.should == 1
            MiqReport.first.tz.should == "Eastern Time (US & Canada)"
            rep_status[:status].should == :update
          end
        end

        context "no overwrite" do
          before { @options[:overwrite] = false }
          it "preview" do
            w, status = subject
            rep_status = status[:children]

            MiqWidget.count.should == 1
            MiqWidget.first.visibility.should == { :roles => ["EvmRole-support"]}
            status[:status].should == :keep
            MiqReport.count.should == 1
            MiqReport.first.tz.should == "UTC"
            rep_status[:status].should == :keep
          end

          it "import" do
            @options[:save] = true
            w, status = subject
            rep_status = status[:children]

            MiqWidget.count.should == 1
            MiqWidget.first.visibility.should == { :roles => ["EvmRole-support"]}
            status[:status].should == :keep
            MiqReport.count.should == 1
            MiqReport.first.tz.should == "UTC"
            rep_status[:status].should == :keep
          end
        end
      end
    end

    context "rss feed" do
      context "internal" do
        before do
          @new_widget = YAML.load("
            - MiqWidget:
                description: rss test
                title: rss test
                content_type: rss
                resource_id: 5
                resource_type: RssFeed
                enabled: true
                MiqReportContent:
                - RssFeed:
                    name: host_alert_event
                    link: /alert/rss?feed=host_alert_event"
           ).first["MiqWidget"]
        end

        context "with new rss feed" do
          it "init status" do
            expect(MiqWidget.count).to eq(1)
            expect(RssFeed.count).to eq(0)
          end

          it "preview" do
            subject
            expect(MiqWidget.count).to eq(1)
            expect(RssFeed.count).to eq(0)
          end

          it "import" do
            @options[:save] = true
            subject
            expect(MiqWidget.count).to eq(2)
            expect(RssFeed.count).to eq(1)
          end
        end
      end

      context "external" do
        before do
          @new_widget = YAML.load("
            - MiqWidget:
                description: National Vulnerability Database
                title: National Vulnerability Database
                content_type: rss
                options:
                  :row_count: 5
                  :url: https://nvd.nist.gov/download/nvd-rss-analyzed.xml
                resource_id:
                resource_type:"
           ).first["MiqWidget"]
        end

        context "with new rss feed" do
          it "init status" do
            expect(MiqWidget.count).to eq(1)
            expect(RssFeed.count).to eq(0)
          end

          it "preview" do
            subject
            expect(MiqWidget.count).to eq(1)
            expect(RssFeed.count).to eq(0)
          end

          it "import" do
            @options[:save] = true
            subject
            expect(MiqWidget.count).to eq(2)
            expect(RssFeed.count).to eq(0)
          end
        end
      end
    end
  end
end
