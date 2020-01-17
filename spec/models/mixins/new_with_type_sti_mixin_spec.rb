RSpec.describe NewWithTypeStiMixin do
  context ".new" do
    it "without type" do
      expect(Host.new.class).to eq(Host)
      expect(ManageIQ::Providers::Redhat::InfraManager::Host.new.class).to eq(ManageIQ::Providers::Redhat::InfraManager::Host)
      expect(ManageIQ::Providers::Vmware::InfraManager::Host.new.class).to eq(ManageIQ::Providers::Vmware::InfraManager::Host)
      expect(ManageIQ::Providers::Vmware::InfraManager::HostEsx.new.class).to eq(ManageIQ::Providers::Vmware::InfraManager::HostEsx)
    end

    it "with type" do
      expect(Host.new(:type => "Host").class).to eq(Host)
      expect(Host.new(:type => "ManageIQ::Providers::Redhat::InfraManager::Host").class).to eq(ManageIQ::Providers::Redhat::InfraManager::Host)
      expect(Host.new(:type => "ManageIQ::Providers::Vmware::InfraManager::Host").class).to eq(ManageIQ::Providers::Vmware::InfraManager::Host)
      expect(Host.new(:type => "ManageIQ::Providers::Vmware::InfraManager::HostEsx").class).to eq(ManageIQ::Providers::Vmware::InfraManager::HostEsx)
      expect(ManageIQ::Providers::Vmware::InfraManager::Host.new(:type  => "ManageIQ::Providers::Vmware::InfraManager::HostEsx").class).to eq(ManageIQ::Providers::Vmware::InfraManager::HostEsx)

      expect(Host.new("type" => "Host").class).to eq(Host)
      expect(Host.new("type" => "ManageIQ::Providers::Redhat::InfraManager::Host").class).to eq(ManageIQ::Providers::Redhat::InfraManager::Host)
      expect(Host.new("type" => "ManageIQ::Providers::Vmware::InfraManager::Host").class).to eq(ManageIQ::Providers::Vmware::InfraManager::Host)
      expect(Host.new("type" => "ManageIQ::Providers::Vmware::InfraManager::HostEsx").class).to eq(ManageIQ::Providers::Vmware::InfraManager::HostEsx)
      expect(ManageIQ::Providers::Vmware::InfraManager::Host.new("type" => "ManageIQ::Providers::Vmware::InfraManager::HostEsx").class).to eq(ManageIQ::Providers::Vmware::InfraManager::HostEsx)
    end

    context "with invalid type" do
      it "that doesn't exist" do
        expect { Host.new(:type  => "Xxx") }.to raise_error(NameError)
        expect { Host.new("type" => "Xxx") }.to raise_error(NameError)
      end

      it "that isn't a subclass" do
        expect { Host.new(:type  => "ManageIQ::Providers::Vmware::InfraManager::Vm") }
          .to raise_error(RuntimeError, /Vm is not a subclass of Host/)
        expect { Host.new("type" => "ManageIQ::Providers::Vmware::InfraManager::Vm") }
          .to raise_error(RuntimeError, /Vm is not a subclass of Host/)

        expect { ManageIQ::Providers::Vmware::InfraManager::Host.new(:type  => "Host") }
          .to raise_error(RuntimeError, /Host is not a subclass of ManageIQ::Providers::.*/)
        expect { ManageIQ::Providers::Vmware::InfraManager::Host.new("type" => "Host") }
          .to raise_error(RuntimeError, /Host is not a subclass of ManageIQ::Providers::.*/)

        expect do
          ManageIQ::Providers::Vmware::InfraManager::Host
            .new(:type => "ManageIQ::Providers::Redhat::InfraManager::Host")
        end.to raise_error(RuntimeError, /ManageIQ.*Redhat.*is not a subclass of ManageIQ.*Vmware.*/)

        expect do
          ManageIQ::Providers::Vmware::InfraManager::Host
            .new("type" => "ManageIQ::Providers::Redhat::InfraManager::Host")
        end.to raise_error(RuntimeError, /ManageIQ.*Redhat.*is not a subclass of ManageIQ.*Vmware.*/)
      end
    end
  end
end
