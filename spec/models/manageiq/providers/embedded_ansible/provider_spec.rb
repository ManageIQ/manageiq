require 'support/ansible_shared/provider'

describe ManageIQ::Providers::EmbeddedAnsible::Provider do
  it_behaves_like 'ansible provider'

  subject { FactoryGirl.build(:provider_embedded_ansible) }

  context "DefaultAnsibleObjects concern" do
    before do
      subject.save
    end

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
  end
end
