RSpec.describe ConfigurationManagementMixin do
  let(:miq_server) { FactoryBot.create(:miq_server, :zone => zone, :status => "started") }
  let(:region)     { FactoryBot.create(:miq_region, :region => ApplicationRecord.my_region_number) }
  let(:settings)   { {:some_test_setting => {:setting => {:deeper => 1}, :other => 2}} }
  let(:zone)       { FactoryBot.create(:zone) }

  [:miq_server, :region, :zone].each do |i|
    context "On a #{i.capitalize}" do
      subject { send(i) }

      describe "#settings_for_resource" do
        it "returns the resource's settings" do
          stub_settings(settings)
          expect(subject.settings_for_resource.to_hash).to eq(settings)
        end
      end

      describe "#add_settings_for_resource" do
        it "sets the specified settings" do
          expect(subject).to receive(:reload_all_server_settings)

          subject.add_settings_for_resource(settings)

          expect(Vmdb::Settings.for_resource(subject).some_test_setting.setting.deeper).to eq(1)
        end
      end

      describe "#remove_settings_path_for_resource" do
        it "removes the specified setting record and all children" do
          expect(subject).to receive(:reload_all_server_settings).twice

          subject.add_settings_for_resource(settings)

          expect(Vmdb::Settings.for_resource(subject).some_test_setting.setting.deeper).to eq(1)

          subject.remove_settings_path_for_resource(:some_test_setting, :setting)

          expect(Vmdb::Settings.for_resource(subject).some_test_setting.to_h).to eq(:other => 2)
        end
      end

      describe "#reload_all_server_settings" do
        it "queues #reload_settings for the started servers" do
          started_server = miq_server

          # the first id from a region other than ours
          remote_region_number = ApplicationRecord.my_region_number + 1
          external_region_id   = ApplicationRecord.region_to_range(remote_region_number).first

          FactoryBot.create(:miq_server, :status => "started", :id => external_region_id)
          FactoryBot.create(:miq_server, :status => "stopped")

          subject.reload_all_server_settings

          expect(MiqQueue.count).to eq(1)
          message = MiqQueue.first
          expect(message.instance_id).to eq(started_server.id)
          expect(message.method_name).to eq("reload_settings")
        end
      end
    end
  end
end
