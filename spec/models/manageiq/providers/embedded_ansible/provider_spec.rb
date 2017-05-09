describe ManageIQ::Providers::EmbeddedAnsible::Provider do
  subject { FactoryGirl.create(:provider_embedded_ansible) }

  let(:miq_server) { FactoryGirl.create(:miq_server) }

  before do
    FactoryGirl.create(:server_role, :name => 'embedded_ansible', :max_concurrent => 0)
    server_role = miq_server.assign_role('embedded_ansible')
    miq_server.assigned_server_roles.where(:server_role_id => server_role.id).first.update_attributes(:active => true)
  end

  it_behaves_like 'ansible provider'

  context "DefaultAnsibleObjects concern" do
    context "with no attributes" do
      %w(organization credential inventory host).each do |obj_name|
        it "#default_#{obj_name} returns nil" do
          expect(subject.public_send("default_#{obj_name}")).to be_nil
        end

        it "#default_#{obj_name}= creates a new custom attribute" do
          subject.public_send("default_#{obj_name}=", obj_name.length)
          expect(subject.default_ansible_objects.find_by(:name => obj_name).value.to_i).to eq(obj_name.length)
        end
      end
    end

    context "with attributes saved" do
      before do
        %w(organization credential inventory host).each do |obj_name|
          subject.default_ansible_objects.create(:name => obj_name, :value => obj_name.length)
        end
      end

      %w(organization credential inventory host).each do |obj_name|
        it "#default_#{obj_name} returns the saved value" do
          expect(subject.public_send("default_#{obj_name}")).to eq(obj_name.length)
        end

        it "#default_#{obj_name}= doesn't create a second object if we pass the same value" do
          subject.public_send("default_#{obj_name}=", obj_name.length)
          expect(subject.default_ansible_objects.where(:name => obj_name).count).to eq(1)
        end
      end
    end

    context "Embedded Ansible role" do
      it "disabled #raw_connect" do
        miq_server.active_roles.delete_all
        expect { described_class.raw_connect('a', 'b', 'c', 'd') }.to raise_exception(StandardError, 'Embedded ansible is disabled')
      end

      it "enabled #raw_connect" do
        expect(described_class.raw_connect('a', 'b', 'c', 'd')).to be_truthy
      end
    end
  end
end
