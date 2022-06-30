RSpec.describe MiqSchedule::Filters do
  let(:method)      { "scan" }
  let(:schedule)    { FactoryBot.create(:miq_schedule, :sched_action => {:method => method}) }
  let(:value)       { nil }
  let(:other_value) { nil }

  let(:filter_type) { "Base" }

  before { EvmSpecHelper.local_miq_server }

  subject do
    schedule.build_hash_filter_expression(value, other_value, filter_type)
  end

  context "with Storage resource_type" do
    before do
      schedule.update(:resource_type => "Storage")
    end

    let(:expected_expression) { {"IS NOT NULL" => {"field" => "Storage-name"}} }

    it "builds expression" do
      expect(subject).to eq(expected_expression)
    end

    context "filter typ is ExtManagementSystem" do
      let(:value)               { "XXX" }
      let(:filter_type)         { "ExtManagementSystem" }

      let(:expected_expression) do
        {"CONTAINS" => {"field" => "Storage.ext_management_systems-name", "value" => value}}
      end

      it "builds expression" do
        expect(subject).to eq(expected_expression)
      end
    end

    context "filter typ is Host" do
      let(:value)               { "XXX" }
      let(:filter_type)         { "Host" }

      let(:expected_expression) do
        {"CONTAINS" => {"field" => "Storage.hosts-name", "value" => value}}
      end

      it "builds expression" do
        expect(subject).to eq(expected_expression)
      end
    end

    context "filter typ is Storage" do
      let(:value)               { "XXX" }
      let(:filter_type)         { "Storage" }

      let(:expected_expression) do
        {"=" => {"field" => "Storage-name", "value" => value}}
      end

      it "builds expression" do
        expect(subject).to eq(expected_expression)
      end
    end
  end

  context "with ContainerImage and ContainerImageCheckCompliance" do
    %w[ContainerImage ContainerImageCheckCompliance].each do |resource_type|
      before do
        schedule.update(:resource_type => resource_type)
      end

      let(:expected_expression) do
        {"IS NOT NULL" => {"field" => "ContainerImage-name"}}
      end

      it "builds expression" do
        expect(subject).to eq(expected_expression)
      end

      context "filter typ is ExtManagementSystem" do
        let(:value)               { "XXX" }
        let(:filter_type)         { "ExtManagementSystem" }

        let(:expected_expression) do
          {"=" => {"field" => "ContainerImage.ext_management_system-name", "value" => value}}
        end

        it "builds expression" do
          expect(subject).to eq(expected_expression)
        end
      end

      context "filter typ is ContainerImage" do
        let(:value)               { "XXX" }
        let(:filter_type)         { "ContainerImage" }

        let(:expected_expression) do
          {"=" => {"field" => "ContainerImage-name", "value" => value}}
        end

        it "builds expression" do
          expect(subject).to eq(expected_expression)
        end
      end
    end
  end

  context "with Host resource_type" do
    before do
      schedule.update(:resource_type => "Host")
    end

    let(:expected_expression) { {"IS NOT NULL" => {"field" => "Host-name"}} }

    it "builds expression" do
      expect(subject).to eq(expected_expression)
    end

    context "filter typ is Cluster" do
      let(:value)               { "XXX" }
      let(:other_value)         { "YYY" }
      let(:filter_type)         { "EmsCluster" }

      let(:expected_expression) do
        {"AND" => [
          {"=" => {"field" => "Host-v_owning_cluster", "value" => value}},
          {"=" => {"field" => "Host-v_owning_datacenter", "value" => other_value}}
        ]}
      end

      it "builds expression" do
        expect(subject).to eq(expected_expression)
      end
    end

    context "filter typ is ExtManagementSystem" do
      let(:value)               { "XXX" }
      let(:filter_type)         { "ExtManagementSystem" }

      let(:expected_expression) do
        {"=" => {"field" => "Host.ext_management_system-name", "value" => value}}
      end

      it "builds expression" do
        expect(subject).to eq(expected_expression)
      end
    end

    context "filter typ is Host" do
      let(:value)               { "XXX" }
      let(:filter_type)         { "Host" }

      let(:expected_expression) do
        {"=" => {"field" => "Host-name", "value" => value}}
      end

      it "builds expression" do
        expect(subject).to eq(expected_expression)
      end
    end
  end

  %w[Vm MiqTemplate].each do |resource_type|
    context "with #{resource_type} resource_type (SmartState Analysis)" do
      before do
        schedule.update(:resource_type => resource_type)
      end

      let(:expected_expression) { {"IS NOT NULL" => {"field" => "#{resource_type}-name"}} }

      it "builds expression" do
        expect(subject).to eq(expected_expression)
      end

      context "filter typ is Cluster" do
        let(:value)               { "XXX" }
        let(:other_value)         { "YYY" }
        let(:filter_type)         { "EmsCluster" }

        let(:expected_expression) do
          {"AND" => [
            {"=" => {"field" => "#{resource_type}-v_owning_cluster", "value" => value}},
            {"=" => {"field" => "#{resource_type}-v_owning_datacenter", "value" => other_value}}
          ]}
        end

        it "builds expression" do
          expect(subject).to eq(expected_expression)
        end
      end

      context "filter typ is ExtManagementSystem" do
        let(:value)               { "XXX" }
        let(:other_value)         { "YYY" }
        let(:filter_type)         { "ExtManagementSystem" }

        let(:expected_expression) do
          {"=" => {"field" => "#{resource_type}.ext_management_system-name", "value" => value}}
        end

        it "builds expression" do
          expect(subject).to eq(expected_expression)
        end
      end
    end
  end

  context "with EmsCluster resource_type" do
    before do
      schedule.update(:resource_type => "EmsCluster")
    end

    let(:expected_expression) { {"IS NOT NULL" => {"field" => "EmsCluster-name"}} }

    it "builds expression" do
      expect(subject).to eq(expected_expression)
    end

    context "filter typ is Cluster" do
      let(:value)               { "XXX" }
      let(:other_value)         { "YYY" }
      let(:filter_type)         { "EmsCluster" }

      let(:expected_expression) do
        {"AND" => [
          {"=" => {"field" => "EmsCluster-name", "value" => value}},
          {"=" => {"field" => "EmsCluster-v_parent_datacenter", "value" => other_value}}
        ]}
      end

      it "builds expression" do
        expect(subject).to eq(expected_expression)
      end
    end

    context "filter typ is ExtManagementSystem" do
      let(:value)               { "XXX" }
      let(:filter_type)         { "ExtManagementSystem" }

      let(:expected_expression) do
        {"=" => {"field" => "EmsCluster.ext_management_system-name", "value" => value}}
      end

      it "builds expression" do
        expect(subject).to eq(expected_expression)
      end
    end
  end

  context "with check_compliance resource_type" do
    before do
      schedule.update(:resource_type => "Vm")
    end

    let(:method)              { "check_compliance" }
    let(:expected_expression) { {"IS NOT NULL" => {"field" => "#{schedule.resource_type}-name"}} }

    it "builds expression" do
      expect(subject).to eq(expected_expression)
    end

    context "filter typ is Cluster" do
      let(:value)               { "XXX" }
      let(:other_value)         { "YYY" }
      let(:filter_type)         { "EmsCluster" }

      let(:expected_expression) do
        {"AND" => [
          {"=" => {"field" => "#{schedule.resource_type}-v_owning_cluster", "value" => value}},
          {"=" => {"field" => "#{schedule.resource_type}-v_owning_datacenter", "value" => other_value}}
        ]}
      end

      it "builds expression" do
        expect(subject).to eq(expected_expression)
      end
    end

    context "filter typ is ExtManagementSystem" do
      let(:value)               { "XXX" }
      let(:filter_type)         { "ExtManagementSystem" }

      let(:expected_expression) do
        {"=" => {"field" => "Vm.ext_management_system-name", "value" => value}}
      end

      it "builds expression" do
        expect(subject).to eq(expected_expression)
      end
    end

    context "filter typ is Host" do
      let(:value)               { "XXX" }
      let(:filter_type)         { "Host" }

      let(:expected_expression) do
        {"=" => {"field" => "Host-name", "value" => value}}
      end

      it "builds expression" do
        expect(subject).to eq(expected_expression)
      end
    end

    context "filter typ is Vm" do
      let(:value)               { "XXX" }
      let(:filter_type)         { "Vm" }

      let(:expected_expression) do
        {"=" => {"field" => "Vm-name", "value" => value}}
      end

      it "builds expression" do
        expect(subject).to eq(expected_expression)
      end
    end
  end
end
