RSpec.describe Metric::Statistic do
  context ".calculate_stat_columns" do
    let(:ems_openshift) do
      FactoryBot.create(:ems_openshift, :hostname => 't', :port => 8443, :name => 't')
    end

    let(:project) do
      FactoryBot.create(:container_project, :name => "project")
    end

    hour = Time.parse(Metric::Helper.nearest_hourly_timestamp(Time.now)).utc

    let(:c1) { FactoryBot.create(:container_group, :ems_created_on => hour - 10.minutes) }
    let(:c2) { FactoryBot.create(:container_group, :ems_created_on => hour - 50.minutes) }
    let(:c3) { FactoryBot.create(:container_group, :ems_created_on => hour - 120.minutes) }
    let(:c4) { FactoryBot.create(:container_group, :ems_created_on => hour + 1.minute) }

    let(:c5) { FactoryBot.create(:container_group, :deleted_on => hour - 10.minutes) }
    let(:c6) { FactoryBot.create(:container_group, :deleted_on => hour - 50.minutes) }
    let(:c7) { FactoryBot.create(:container_group, :deleted_on => hour - 120.minutes) }
    let(:c8) { FactoryBot.create(:container_group, :deleted_on => hour + 1.minute) }

    let(:c9) { FactoryBot.create(:container_image, :registered_on => hour - 10.minutes) }
    let(:c10) { FactoryBot.create(:container_image, :registered_on => hour - 50.minutes) }
    let(:c11) { FactoryBot.create(:container_image, :registered_on => hour - 120.minutes) }
    let(:c12) { FactoryBot.create(:container_image, :registered_on => hour + 1.minute) }

    it "count created container groups in a provider" do
      ems_openshift.container_groups << [c1, c2, c3, c4, c5, c6, c7, c8]
      derived_columns = described_class.calculate_stat_columns(ems_openshift, hour)

      expect(derived_columns[:stat_container_group_create_rate]).to eq(2)
    end

    it "count deleted container groups in a provider" do
      ems_openshift.container_groups << [c1, c2, c3, c4, c5, c6, c7, c8]
      derived_columns = described_class.calculate_stat_columns(ems_openshift, hour)

      expect(derived_columns[:stat_container_group_delete_rate]).to eq(2)
    end

    it "count new registered container images in a provider" do
      ems_openshift.container_images << [c9, c10, c11, c12]
      derived_columns = described_class.calculate_stat_columns(ems_openshift, hour)

      expect(derived_columns[:stat_container_image_registration_rate]).to eq(2)
    end

    it "count created container groups in a project" do
      project.container_groups << [c1, c2, c3, c4, c5, c6, c7, c8]
      derived_columns = described_class.calculate_stat_columns(project, hour)

      expect(derived_columns[:stat_container_group_create_rate]).to eq(2)
    end

    it "count deleted container groups in a project" do
      project.container_groups << [c1, c2, c3, c4, c5, c6, c7, c8]
      derived_columns = described_class.calculate_stat_columns(project, hour)

      expect(derived_columns[:stat_container_group_delete_rate]).to eq(2)
    end
  end
end
