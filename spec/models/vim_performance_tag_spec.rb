RSpec.describe VimPerformanceTag do
  before do
    @server = EvmSpecHelper.local_miq_server
    @ems    = FactoryBot.create(:ems_vmware, :zone => @server.zone)

    allow(Classification).to receive(:category_names_for_perf_by_tag).and_return(["environment"])
    @classification_entries = ["prod", "dev", "test"]
  end

  context "with a small environment and tagged VMs" do
    before do
      @prod = "environment/prod"
      @dev  = "environment/dev"
      @test = "environment/test"

      @vms  = []
      @vms << FactoryBot.create(:vm_vmware, :name => "prod")
      @vms << FactoryBot.create(:vm_vmware, :name => "dev")
      @vms << FactoryBot.create(:vm_vmware, :name => "test")
      @vms << FactoryBot.create(:vm_vmware, :name => "none")

      @host = FactoryBot.create(:host, :vms => @vms, :vmm_vendor => 'vmware', :vmm_product => "ESX", :type => "ManageIQ::Providers::Vmware::InfraManager::HostEsx")
      @host = Host.find_by(:id => @host.id)
    end

    context "with Vm hourly performances" do
      before do
        case_sets = {
          :host => {
            "2010-04-13T21:00:00Z" => 1100.0,
            "2010-04-14T18:00:00Z" => 1111.0,
            "2010-04-14T19:00:00Z" => 1211.0,
            "2010-04-14T20:00:00Z" => 1411.0,
            "2010-04-14T21:00:00Z" => 1811.0,
            "2010-04-14T22:00:00Z" => 1151.0,
            "2010-04-15T21:00:00Z" => 1100.0,
          },
          :prod => {
            "2010-04-13T21:00:00Z" => 2100.0,
            "2010-04-14T18:00:00Z" => 2122.0,
            "2010-04-14T19:00:00Z" => 2222.0,
            "2010-04-14T20:00:00Z" => 2422.0,
            "2010-04-14T21:00:00Z" => 2822.0,
            "2010-04-14T22:00:00Z" => 2152.0,
            "2010-04-15T21:00:00Z" => 2100.0,
          },
          :dev  => {
            "2010-04-13T21:00:00Z" => 3100.0,
            "2010-04-14T18:00:00Z" => 3133.0,
            "2010-04-14T19:00:00Z" => 3233.0,
            "2010-04-14T20:00:00Z" => 3433.0,
            "2010-04-14T21:00:00Z" => 3833.0,
            "2010-04-14T22:00:00Z" => 3153.0,
            "2010-04-15T21:00:00Z" => 3100.0,
          },
          :test => {
            "2010-04-13T21:00:00Z" => 4100.0,
            "2010-04-14T18:00:00Z" => 4144.0,
            "2010-04-14T19:00:00Z" => 4244.0,
            "2010-04-14T20:00:00Z" => 4444.0,
            "2010-04-14T21:00:00Z" => 4844.0,
            "2010-04-14T22:00:00Z" => 4154.0,
            "2010-04-15T21:00:00Z" => 4100.0,
          },
          :none => {
            "2010-04-13T21:00:00Z" => 5100.0,
            "2010-04-14T18:00:00Z" => 5155.0,
            "2010-04-14T19:00:00Z" => 5255.0,
            "2010-04-14T20:00:00Z" => 5455.0,
            "2010-04-14T21:00:00Z" => 5855.0,
            "2010-04-14T22:00:00Z" => 5155.0,
            "2010-04-15T21:00:00Z" => 5100.0,
          }
        }

        @timestamps = [
          "2010-04-13T21:00:00Z",
          "2010-04-14T18:00:00Z",
          "2010-04-14T19:00:00Z",
          "2010-04-14T20:00:00Z",
          "2010-04-14T21:00:00Z",
          "2010-04-14T22:00:00Z",
          "2010-04-15T21:00:00Z",
        ]
        @precomputed = {}
        @timestamps.each do |ts|
          h = {}
          (@classification_entries + [:none]).each { |e| h[e.to_sym] = case_sets[e.to_sym][ts] }
          @precomputed[ts] = h
        end

        @vms.each do |vm|
          case_sets[vm.name.to_sym].each do |timestamp, value|
            if vm.name == "none"
              perf = FactoryBot.create(:metric_rollup_vm_hr,
                                        :timestamp                 => timestamp,
                                        :cpu_usagemhz_rate_average => value
                                       )
            else
              tag = "environment/#{vm.name}"
              perf = FactoryBot.create(:metric_rollup_vm_hr,
                                        :timestamp                 => timestamp,
                                        :cpu_usagemhz_rate_average => value,
                                        :tag_names                 => tag
                                       )
            end
            vm.metric_rollups << perf
          end
          vm.save!
        end

        case_sets[:host].each do |timestamp, value|
          perf = FactoryBot.create(:metric_rollup_host_hr,
                                    :timestamp                 => timestamp,
                                    :cpu_usagemhz_rate_average => value
                                   )
          @host.metric_rollups << perf
        end
        @host.save!
      end

      it "#find_and_group_by_tags" do
        where_clause = ["resource_type = ? and resource_id = ?", @host.class.base_class.name, @host.id]
        results, group_by_tag_cols, group_by_tags =
          VimPerformanceTag.find_and_group_by_tags(:cat_model    => "Vm",
                                                   :category     => "environment",
                                                   :where_clause => where_clause)

        classification_entries_with_none = @classification_entries + ["_none_"]

        classification_entries_with_none.each do |entry|
          expect(group_by_tags).to include(entry)
          VimPerformanceTagValue::TAG_COLS[:default].each do |column|
            expect(group_by_tag_cols).to include("#{column}_#{entry}")
          end
        end

        expect(results.length).to eq(@timestamps.length)

        results.each do |t|
          ts = t.timestamp.iso8601.to_s
          @classification_entries.each do |entry|
            expect(@precomputed[ts][entry.to_sym]).to eq(t.send("cpu_usagemhz_rate_average_#{entry}"))
          end
          expect(@precomputed[ts][:none]).to eq(t.send("cpu_usagemhz_rate_average__none_"))
        end
      end
    end
  end
end
