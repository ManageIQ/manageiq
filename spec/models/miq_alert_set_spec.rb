RSpec.describe MiqAlertSet do
  context ".seed" do
    it "should create the prometheus profiles" do
      expect(MiqAlertSet.count).to eq(0)
      described_class.seed
      expect(MiqAlertSet.count).to eq(2)
      provider_profile = MiqAlertSet.find_by(:guid => "a16fcf51-e2ae-492d-af37-19de881476ad")
      expect(provider_profile).to have_attributes(:mode => "ExtManagementSystem")
      expect(provider_profile.miq_alerts.count).to eq(1)
      expect(provider_profile.miq_alerts.first).to have_attributes(
        :guid               => "ea3acd49-9516-4fde-b828-bf68d254c0cf",
        :db                 => "ExtManagementSystem",
        :responds_to_events => "datawarehouse_alert",
      )
      node_profile = MiqAlertSet.find_by(:guid => "ff0fb114-be03-4685-bebb-b6ae8f13d7ad")
      expect(node_profile).to have_attributes(:mode => "ContainerNode")
      expect(node_profile.miq_alerts.count).to eq(1)
      expect(node_profile.miq_alerts.first).to have_attributes(
        :guid               => "efe9d4f0-9c6f-4c67-80b1-05cd83223349",
        :db                 => "ContainerNode",
        :responds_to_events => "datawarehouse_alert",
      )
    end

    it "should not explode if the seed file is missing" do
      fixture_file = ApplicationRecord::FIXTURE_DIR.join("miq_alert_sets.yml")
      expect { without_file(fixture_file) { described_class.seed } }.to_not raise_exception
    end
  end

  def without_file(fname)
    # Note: can the file you are moving cause sporadic failures in other threads?
    raise "no block given" unless block_given?
    raise "fname is blank" if fname.blank?
    tempf = Tempfile.new("temporary_backup")
    begin
      FileUtils.mv(fname, tempf.path)
      yield
    ensure
      FileUtils.mv(tempf.path, fname) if File.exist?(tempf.path)
      tempf.close
      tempf.unlink
    end
  end
end
