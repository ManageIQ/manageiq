RSpec.describe AutomationWorker do
  describe "kubernetes worker deployment" do
    let(:test_deployment) do
      {
        :metadata => {
          :name      => "test",
          :labels    => {:app => "manageiq"},
          :namespace => "manageiq",
        },
        :spec     => {
          :selector => {:matchLabels => {:name => "test"}},
          :template => {
            :metadata => {:name => "test", :labels => {:name => "test", :app => "manageiq"}},
            :spec     => {
              :containers => [{
                :name => "test",
                :env  => []
              }]
            }
          }
        }
      }
    end

    it "#configure_worker_deplyoment adds a node selector based on the zone name" do
      EvmSpecHelper.local_miq_server

      worker = described_class.new
      worker.configure_worker_deployment(test_deployment)

      expect(test_deployment.dig(:spec, :template, :spec, :nodeSelector)).to eq("manageiq/zone-#{MiqServer.my_zone}".tr(" ", "-") => "true")
      expect(test_deployment.dig(:spec, :template, :spec, :serviceAccountName)).to eq("manageiq-automation")
    end
  end
end
