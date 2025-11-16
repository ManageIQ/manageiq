RSpec.describe GenericObject do
  let(:go_object_name) { "load_balancer_1" }
  let(:max_number)     { 100 }
  let(:server_name)    { "test_server" }
  let(:data_read)      { 345.67 }
  let(:s_time)         { Time.now.utc }
  let(:vm1)            { FactoryBot.create(:vm_vmware) }
  let(:user)           { FactoryBot.create(:user_with_group) }

  let(:definition) do
    FactoryBot.create(
      :generic_object_definition,
      :name       => "test_definition",
      :properties => {
        :attributes   => {
          :flag       => "boolean",
          :data_read  => "float",
          :max_number => "integer",
          :server     => "string",
          :s_time     => "datetime"
        },
        :associations => {"vms" => "Vm", "hosts" => "Host"},
        :methods      => %w[my_host  some_method]
      }
    )
  end

  let(:go) do
    FactoryBot.create(
      :generic_object,
      :generic_object_definition => definition,
      :name                      => go_object_name,
      :flag                      => true,
      :data_read                 => data_read,
      :max_number                => max_number,
      :server                    => server_name,
      :s_time                    => s_time
    )
  end

  it "should ensure presence of name" do
    o = GenericObject.new(:generic_object_definition => definition, :name => nil)
    expect(o).not_to be_valid
  end

  describe "#create" do
    it "creates a generic object without definition and properties" do
      expect(GenericObject.create).to be_a_kind_of(GenericObject)
    end

    it "creates a generic object with both definition and properties" do
      expect(GenericObject.create(:max_number => max_number, :generic_object_definition => definition)).to be_a_kind_of(GenericObject)
    end

    it "raises an error when create a generic object with properties but no definition" do
      expect { GenericObject.create(:max_number => max_number) }.to raise_error(ActiveModel::UnknownAttributeError)
    end
  end

  describe "property attributes" do
    context "with generic_object_definition" do
      it "can be accessed as an attribute" do
        expect(go.generic_object_definition).to eq(definition)
        expect(go.name).to                      eq(go_object_name)
        expect(go.flag).to                      eq(true)
        expect(go.data_read).to                 eq(data_read)
        expect(go.max_number).to                eq(max_number)
        expect(go.server).to                    eq(server_name)
        expect(go.s_time).to                    be_within(0.001).of s_time
      end

      it "can be set as an attribute" do
        go.max_number = max_number + 100
        go.save!
        expect(go.reload.max_number).to eq(max_number + 100)
      end

      it "can't set undefined property attribute" do
        expect { go.some_thing = 'not_defined' }.to raise_error(NoMethodError)
      end

      it "sets defined property attribute" do
        go.property_attributes = {
          :data_read  => data_read + 100.50,
          :flag       => false,
          :max_number => max_number + 100,
          :server     => "#{server_name}_2",
          :s_time     => s_time - 2.days
        }
        go.save!

        expect(go.property_attributes['s_time']).to be_within(0.001).of(s_time - 2.days)
        expect(go.property_attributes).to include(
          "flag"       => false,
          "data_read"  => data_read + 100.50,
          "max_number" => max_number + 100,
          "server"     => "#{server_name}_2"
        )
      end

      it "raises an error if any property attribute is not defined" do
        expect { go.property_attributes = {:max_number => max_number + 100, :bad => ''} }.to raise_error(ActiveModel::UnknownAttributeError)
      end
    end

    context "without generic_object_definition" do
      let(:empty_go) { FactoryBot.build(:generic_object) }

      it "raises an error when set a property attribute" do
        expect { empty_go.max_number = max_number }.to raise_error(NoMethodError)
      end

      it "raises an error when set property attributes" do
        expect { empty_go.property_attributes = {:max_number => max_number} }.to raise_error(RuntimeError)
      end

      it "riases an error when set property associations" do
        expect { empty_go.property_attributes = {:vms => [vm1]} }.to raise_error(RuntimeError)
      end
    end
  end

  describe 'property associations' do
    let(:vm2) { FactoryBot.create(:vm_vmware) }
    let(:go_assoc) do
      FactoryBot.create(
        :generic_object,
        :generic_object_definition => definition,
        :name                      => 'go_assoc',
        :vms                       => [vm1, vm2]
      )
    end

    it 'saves object id in DB' do
      expect(go_assoc.read_attribute(:properties)["vms"]).to match_array([vm1.id, vm2.id])
    end

    it 'returns object' do
      expect(go_assoc.vms.first).to be_kind_of(Vm)
    end

    it 'can be accessed as an attribute' do
      expect(go_assoc.vms.count).to eq(2)
    end

    it 'skips invalid object when saving to DB' do
      go_assoc.vms = [vm1, vm2, FactoryBot.create(:host)]
      go_assoc.save!

      expect(go_assoc.reload.vms.count).to eq(2)
    end

    it 'skips non-existing object when retrieving from DB' do
      vm2.destroy
      expect(go_assoc.vms.count).to eq(1)
    end

    it 'skips duplicate object' do
      go_assoc.vms = [vm1, vm1]
      go_assoc.save!
      expect(go_assoc.vms.count).to eq(1)
    end

    it 'method returns all associations' do
      host = FactoryBot.create(:host)
      go_assoc.hosts = [host]

      result = go_assoc.property_associations
      expect(result["vms"]).to match_array([vm1, vm2])
      expect(result["hosts"]).to match_array([host])
    end
  end

  describe 'property methods' do
    let(:ws)   { double("MiqAeWorkspaceRuntime", :root => {"method_result" => "some_return_value"}) }

    before { go.ae_user_identity(user) }

    it 'sends defined method to automate' do
      expect(MiqAeEngine).to receive(:deliver).and_return(ws)
      go.my_host
    end

    it 'raises an error for undefined method' do
      expect { go.not_defined_method }.to raise_error(NoMethodError)
    end

    it 'requires a user id' do
      options = {
        :user_id      => user.id,
        :miq_group_id => user.current_group.id,
        :tenant_id    => user.current_tenant.id
      }
      expect(MiqAeEngine).to receive(:deliver).with(hash_including(options)).and_return(ws)
      go.my_host
    end

    context 'passes parameters to automate' do
      let(:attrs) { {:method_name => 'my_host'} }

      it 'multiple parameters' do
        options = {:attrs => attrs.merge(:param_1      => 'param1',
                                         :param_1_type => "String",
                                         :param_2      => 'param2',
                                         :param_2_type => "String")}
        expect(MiqAeEngine).to receive(:deliver).with(hash_including(options)).and_return(ws)
        go.my_host('param1', 'param2')
      end

      it 'no parameter' do
        expect(MiqAeEngine).to receive(:deliver).with(hash_including(:attrs => attrs)).and_return(ws)
        go.my_host
      end

      it 'one array parameter' do
        options = {:attrs => attrs.merge(:param_1 => %w[p1 p2], :param_1_type => "Array")}
        expect(MiqAeEngine).to receive(:deliver).with(hash_including(options)).and_return(ws)
        go.my_host(%w[p1 p2])
      end

      it 'one hash parameter' do
        options = {:attrs => attrs.merge(:param_1 => {:p1 => 1, :p2 => 2}, :param_1_type => "Hash")}
        expect(MiqAeEngine).to receive(:deliver).with(hash_including(options)).and_return(ws)
        go.my_host(:p1 => 1, :p2 => 2)
      end
    end

    it 'returns value from automate' do
      allow(MiqAeEngine).to receive(:deliver).and_return(ws)
      expect(go.my_host).to eq("some_return_value")
    end
  end

  describe 'property methods without user set' do
    it 'will set the current user' do
      workspace = double("MiqAeWorkspaceRuntime", :root => {"method_result" => "result"})

      options = {
        :user_id      => user.id,
        :miq_group_id => user.current_group.id,
        :tenant_id    => user.current_tenant.id
      }
      expect(MiqAeEngine).to receive(:deliver).with(hash_including(options)).and_return(workspace)
      User.with_user_group(user, user.current_group) { go.my_host }
    end
  end

  describe '#delete_property' do
    it 'an attriute' do
      max = go.max_number
      expect(go.delete_property("max_number")).to eq(max)
      expect(go.max_number).to be_nil
    end

    it 'an association' do
      vm2 = FactoryBot.create(:vm_vmware)
      go.vms = [vm1, vm2]
      expect(go.delete_property("vms")).to match_array([vm1, vm2])
      expect(go.vms).to be_empty
    end

    it 'a method' do
      expect { go.delete_property("my_host") }.to raise_error(RuntimeError)
    end

    it 'an invalid property name' do
      expect { go.delete_property("some_attribute_not_defined") }.to raise_error(RuntimeError)
    end
  end

  describe '#add_to_property_association' do
    let(:new_vm) { FactoryBot.create(:vm_vmware) }
    subject { go.add_to_property_association("vms", vm1) }

    it 'adds objects into association' do
      subject
      expect(go.vms.count).to eq(1)

      go.add_to_property_association(:vms, [new_vm])
      expect(go.vms.count).to eq(2)
    end

    it 'does not add duplicate object' do
      subject
      expect(go.vms.count).to eq(1)

      subject
      expect(go.vms.count).to eq(1)
    end

    it 'does not add object from different class' do
      go.add_to_property_association("vms", FactoryBot.create(:host))
      expect(go.vms.count).to eq(0)
    end

    it 'does not accept object id' do
      go.add_to_property_association(:vms, new_vm.id)
      expect(go.vms.count).to eq(0)
    end
  end

  describe '#delete_from_property_association' do
    before { go.add_to_property_association("vms", [vm1]) }
    let(:new_vm) { FactoryBot.create(:vm_vmware) }

    it 'deletes objects from association' do
      result = go.delete_from_property_association(:vms, [vm1])
      expect(go.vms.count).to eq(0)
      expect(result).to match_array([vm1])
    end

    it 'does not delete object that is not in association' do
      expect(go.vms.count).to eq(1)
      result = go.delete_from_property_association(:vms, [new_vm])
      expect(go.vms).to match_array([vm1])
      expect(result).to be_nil
    end

    it 'does not delete object from different class' do
      result = go.delete_from_property_association(:vms, [FactoryBot.create(:host)])
      expect(go.vms).to match_array([vm1])
      expect(result).to be_nil
    end

    it 'does not accept object id' do
      expect(go.delete_from_property_association(:vms, vm1.id)).to be_nil
    end
  end

  describe '#add_to_service' do
    let(:service) { FactoryBot.create(:service) }

    it 'associates the generic object to the service' do
      go.add_to_service(service)
      expect(service.reload.generic_objects).to include(go)
    end

    it 'can associate to multiple services' do
      go.add_to_service(FactoryBot.create(:service))
      go.add_to_service(service)
      expect(service.reload.generic_objects).to include(go)
    end
  end

  describe '#remove_from_service' do
    let(:service) { FactoryBot.create(:service) }

    it 'removes the generic object from the service' do
      go.add_to_service(service)
      expect(service.generic_objects).to include(go)

      go.remove_from_service(service)
      expect(service.generic_objects).to be_blank
    end

    it 'removes the generic object from all related services before destroy' do
      go.add_to_service(service)
      expect(service.generic_objects).to include(go)

      go.destroy
      expect(service.generic_objects).to be_blank
    end
  end

  context "custom buttons" do
    describe "#custom_actions" do
      it "returns list of custom actions retrived from linked GenericObjectDefinition" do
        expect(definition).to receive(:custom_actions).with(go)
        go.custom_actions
      end
    end

    describe "#custom_action_buttons" do
      it "returns list of custom action buttons retrived from linked GenericObjectDefinition" do
        expect(definition).to receive(:custom_action_buttons).with(go)
        go.custom_action_buttons
      end
    end

    describe '#custom_button_events' do
      let(:cb_event) { FactoryBot.create(:custom_button_event, :target => go) }

      it 'returns list of custom button events' do
        expect(go.custom_button_events).to match_array([cb_event])
      end
    end
  end

  describe 'attribute constraint validation' do
    let(:definition_with_constraints) do
      FactoryBot.create(
        :generic_object_definition,
        :name       => 'product_definition',
        :properties => {
          :attributes            => {
            :product_name => :string,
            :sku          => :string,
            :email        => :string,
            :status       => :string,
            :priority     => :integer,
            :quantity     => :integer,
            :price        => :float,
            :discount     => :float,
            :is_active    => :boolean,
            :description  => :string
          },
          :attribute_constraints => {
            :product_name => {:required => true, :min_length => 3, :max_length => 50},
            :sku          => {:required => true, :format => /\A[A-Z]{3}-\d{6}\z/},
            :email        => {:format => /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i},
            :status       => {:required => true, :enum => ['active', 'inactive', 'pending']},
            :priority     => {:enum => [1, 2, 3, 4, 5]},
            :quantity     => {:min => 0, :max => 1000},
            :price        => {:required => true, :min => 0.0, :max => 99999.99},
            :discount     => {:min => 0.0, :max => 100.0},
            :is_active    => {:required => true},
            :description  => {:max_length => 500}
          },
          :associations          => {},
          :methods               => []
        }
      )
    end

    context 'required constraint' do
      it 'validates required string attribute is present' do
        obj = GenericObject.new(
          :generic_object_definition => definition_with_constraints,
          :name                      => 'TestObject',
          :product_name              => 'Product1',
          :sku                       => 'ABC-123456',
          :status                    => 'active',
          :price                     => 100.0,
          :is_active                 => true
        )
        expect(obj).to be_valid
      end

      it 'fails validation when required string attribute is nil' do
        obj = GenericObject.new(
          :generic_object_definition => definition_with_constraints,
          :name                      => 'TestObject',
          :product_name              => nil,
          :sku                       => 'ABC-123456',
          :status                    => 'active',
          :price                     => 100.0,
          :is_active                 => true
        )
        expect(obj).not_to be_valid
        expect(obj.errors[:properties]).to include("attribute 'product_name' is required")
      end

      it 'fails validation when required string attribute is empty' do
        obj = GenericObject.new(
          :generic_object_definition => definition_with_constraints,
          :name                      => 'TestObject',
          :product_name              => '  ',
          :sku                       => 'ABC-123456',
          :status                    => 'active',
          :price                     => 100.0,
          :is_active                 => true
        )
        expect(obj).not_to be_valid
        expect(obj.errors[:properties]).to include("attribute 'product_name' is required")
      end

      it 'fails validation when required boolean attribute is nil' do
        obj = GenericObject.new(
          :generic_object_definition => definition_with_constraints,
          :name                      => 'TestObject',
          :product_name              => 'Product1',
          :sku                       => 'ABC-123456',
          :status                    => 'active',
          :price                     => 100.0,
          :is_active                 => nil
        )
        expect(obj).not_to be_valid
        expect(obj.errors[:properties]).to include("attribute 'is_active' is required")
      end
    end

    context 'min/max constraint' do
      it 'validates integer within range' do
        obj = GenericObject.new(
          :generic_object_definition => definition_with_constraints,
          :name                      => 'TestObject',
          :product_name              => 'Product1',
          :sku                       => 'ABC-123456',
          :status                    => 'active',
          :price                     => 100.0,
          :is_active                 => true,
          :quantity                  => 500
        )
        expect(obj).to be_valid
      end

      it 'fails validation when integer is below minimum' do
        obj = GenericObject.new(
          :generic_object_definition => definition_with_constraints,
          :name                      => 'TestObject',
          :product_name              => 'Product1',
          :sku                       => 'ABC-123456',
          :status                    => 'active',
          :price                     => 100.0,
          :is_active                 => true,
          :quantity                  => -1
        )
        expect(obj).not_to be_valid
        expect(obj.errors[:properties]).to include("attribute 'quantity' must be greater than or equal to 0")
      end

      it 'fails validation when integer is above maximum' do
        obj = GenericObject.new(
          :generic_object_definition => definition_with_constraints,
          :name                      => 'TestObject',
          :product_name              => 'Product1',
          :sku                       => 'ABC-123456',
          :status                    => 'active',
          :price                     => 100.0,
          :is_active                 => true,
          :quantity                  => 1001
        )
        expect(obj).not_to be_valid
        expect(obj.errors[:properties]).to include("attribute 'quantity' must be less than or equal to 1000")
      end

      it 'validates float within range' do
        obj = GenericObject.new(
          :generic_object_definition => definition_with_constraints,
          :name                      => 'TestObject',
          :product_name              => 'Product1',
          :sku                       => 'ABC-123456',
          :status                    => 'active',
          :price                     => 100.0,
          :is_active                 => true,
          :discount                  => 50.0
        )
        expect(obj).to be_valid
      end

      it 'fails validation when float is below minimum' do
        obj = GenericObject.new(
          :generic_object_definition => definition_with_constraints,
          :name                      => 'TestObject',
          :product_name              => 'Product1',
          :sku                       => 'ABC-123456',
          :status                    => 'active',
          :price                     => -1.0,
          :is_active                 => true
        )
        expect(obj).not_to be_valid
        expect(obj.errors[:properties]).to include("attribute 'price' must be greater than or equal to 0.0")
      end

      it 'fails validation when float is above maximum' do
        obj = GenericObject.new(
          :generic_object_definition => definition_with_constraints,
          :name                      => 'TestObject',
          :product_name              => 'Product1',
          :sku                       => 'ABC-123456',
          :status                    => 'active',
          :price                     => 100000.0,
          :is_active                 => true
        )
        expect(obj).not_to be_valid
        expect(obj.errors[:properties]).to include("attribute 'price' must be less than or equal to 99999.99")
      end
    end

    context 'min_length/max_length constraint' do
      it 'validates string within length range' do
        obj = GenericObject.new(
          :generic_object_definition => definition_with_constraints,
          :name                      => 'TestObject',
          :product_name              => 'Product1',
          :sku                       => 'ABC-123456',
          :status                    => 'active',
          :price                     => 100.0,
          :is_active                 => true
        )
        expect(obj).to be_valid
      end

      it 'fails validation when string is too short' do
        obj = GenericObject.new(
          :generic_object_definition => definition_with_constraints,
          :name                      => 'TestObject',
          :product_name              => 'AB',
          :sku                       => 'ABC-123456',
          :status                    => 'active',
          :price                     => 100.0,
          :is_active                 => true
        )
        expect(obj).not_to be_valid
        expect(obj.errors[:properties]).to include("attribute 'product_name' must be at least 3 characters long")
      end

      it 'fails validation when string is too long' do
        obj = GenericObject.new(
          :generic_object_definition => definition_with_constraints,
          :name                      => 'TestObject',
          :product_name              => 'A' * 51,
          :sku                       => 'ABC-123456',
          :status                    => 'active',
          :price                     => 100.0,
          :is_active                 => true
        )
        expect(obj).not_to be_valid
        expect(obj.errors[:properties]).to include("attribute 'product_name' must be at most 50 characters long")
      end

      it 'validates max_length only constraint' do
        obj = GenericObject.new(
          :generic_object_definition => definition_with_constraints,
          :name                      => 'TestObject',
          :product_name              => 'Product1',
          :sku                       => 'ABC-123456',
          :status                    => 'active',
          :price                     => 100.0,
          :is_active                 => true,
          :description               => 'A' * 500
        )
        expect(obj).to be_valid
      end

      it 'fails validation when string exceeds max_length' do
        obj = GenericObject.new(
          :generic_object_definition => definition_with_constraints,
          :name                      => 'TestObject',
          :product_name              => 'Product1',
          :sku                       => 'ABC-123456',
          :status                    => 'active',
          :price                     => 100.0,
          :is_active                 => true,
          :description               => 'A' * 501
        )
        expect(obj).not_to be_valid
        expect(obj.errors[:properties]).to include("attribute 'description' must be at most 500 characters long")
      end
    end

    context 'enum constraint' do
      it 'validates string value in enum' do
        obj = GenericObject.new(
          :generic_object_definition => definition_with_constraints,
          :name                      => 'TestObject',
          :product_name              => 'Product1',
          :sku                       => 'ABC-123456',
          :status                    => 'active',
          :price                     => 100.0,
          :is_active                 => true
        )
        expect(obj).to be_valid
      end

      it 'fails validation when string value not in enum' do
        obj = GenericObject.new(
          :generic_object_definition => definition_with_constraints,
          :name                      => 'TestObject',
          :product_name              => 'Product1',
          :sku                       => 'ABC-123456',
          :status                    => 'deleted',
          :price                     => 100.0,
          :is_active                 => true
        )
        expect(obj).not_to be_valid
        expect(obj.errors[:properties]).to include("attribute 'status' must be one of: active, inactive, pending")
      end

      it 'validates integer value in enum' do
        obj = GenericObject.new(
          :generic_object_definition => definition_with_constraints,
          :name                      => 'TestObject',
          :product_name              => 'Product1',
          :sku                       => 'ABC-123456',
          :status                    => 'active',
          :price                     => 100.0,
          :is_active                 => true,
          :priority                  => 3
        )
        expect(obj).to be_valid
      end

      it 'fails validation when integer value not in enum' do
        obj = GenericObject.new(
          :generic_object_definition => definition_with_constraints,
          :name                      => 'TestObject',
          :product_name              => 'Product1',
          :sku                       => 'ABC-123456',
          :status                    => 'active',
          :price                     => 100.0,
          :is_active                 => true,
          :priority                  => 10
        )
        expect(obj).not_to be_valid
        expect(obj.errors[:properties]).to include("attribute 'priority' must be one of: 1, 2, 3, 4, 5")
      end
    end

    context 'format constraint' do
      it 'validates string matching format' do
        obj = GenericObject.new(
          :generic_object_definition => definition_with_constraints,
          :name                      => 'TestObject',
          :product_name              => 'Product1',
          :sku                       => 'ABC-123456',
          :status                    => 'active',
          :price                     => 100.0,
          :is_active                 => true,
          :email                     => 'test@example.com'
        )
        expect(obj).to be_valid
      end

      it 'fails validation when string does not match format' do
        obj = GenericObject.new(
          :generic_object_definition => definition_with_constraints,
          :name                      => 'TestObject',
          :product_name              => 'Product1',
          :sku                       => 'invalid-sku',
          :status                    => 'active',
          :price                     => 100.0,
          :is_active                 => true
        )
        expect(obj).not_to be_valid
        expect(obj.errors[:properties]).to include("attribute 'sku' format is invalid")
      end

      it 'fails validation when email format is invalid' do
        obj = GenericObject.new(
          :generic_object_definition => definition_with_constraints,
          :name                      => 'TestObject',
          :product_name              => 'Product1',
          :sku                       => 'ABC-123456',
          :status                    => 'active',
          :price                     => 100.0,
          :is_active                 => true,
          :email                     => 'invalid-email'
        )
        expect(obj).not_to be_valid
        expect(obj.errors[:properties]).to include("attribute 'email' format is invalid")
      end
    end

    context 'multiple constraint violations' do
      it 'reports all validation errors' do
        obj = GenericObject.new(
          :generic_object_definition => definition_with_constraints,
          :name                      => 'TestObject',
          :product_name              => 'AB',
          :sku                       => 'invalid',
          :status                    => 'deleted',
          :price                     => -10.0,
          :is_active                 => nil
        )
        expect(obj).not_to be_valid
        expect(obj.errors[:properties].size).to be >= 5
      end
    end

    context 'updating existing object' do
      it 'validates constraints on update' do
        obj = GenericObject.create!(
          :generic_object_definition => definition_with_constraints,
          :name                      => 'TestObject',
          :product_name              => 'Product1',
          :sku                       => 'ABC-123456',
          :status                    => 'active',
          :price                     => 100.0,
          :is_active                 => true
        )

        obj.price = -50.0
        expect(obj).not_to be_valid
        expect(obj.errors[:properties]).to include("attribute 'price' must be greater than or equal to 0.0")
      end
    end

    context 'without constraints' do
      it 'does not validate when no constraints are defined' do
        obj = GenericObject.new(
          :generic_object_definition => definition,
          :name                      => 'Test',
          :max_number                => -100
        )
        expect(obj).to be_valid
      end
    end

    context 'default value constraint' do
      let(:definition_with_defaults) do
        FactoryBot.create(
          :generic_object_definition,
          :name       => 'product_with_defaults',
          :properties => {
            :attributes            => {
              :status      => :string,
              :priority    => :integer,
              :discount    => :float,
              :is_active   => :boolean,
              :description => :string
            },
            :attribute_constraints => {
              :status      => {:default => 'pending', :enum => ['pending', 'active', 'inactive']},
              :priority    => {:default => 3},
              :discount    => {:default => 0.0},
              :is_active   => {:default => true},
              :description => {:default => 'No description'}
            },
            :associations          => {},
            :methods               => []
          }
        )
      end

      it 'applies default value for string attribute when not provided' do
        obj = GenericObject.create!(
          :generic_object_definition => definition_with_defaults,
          :name                      => 'TestObject'
        )
        expect(obj.status).to eq('pending')
      end

      it 'applies default value for integer attribute when not provided' do
        obj = GenericObject.create!(
          :generic_object_definition => definition_with_defaults,
          :name                      => 'TestObject'
        )
        expect(obj.priority).to eq(3)
      end

      it 'applies default value for float attribute when not provided' do
        obj = GenericObject.create!(
          :generic_object_definition => definition_with_defaults,
          :name                      => 'TestObject'
        )
        expect(obj.discount).to eq(0.0)
      end

      it 'applies default value for boolean attribute when not provided' do
        obj = GenericObject.create!(
          :generic_object_definition => definition_with_defaults,
          :name                      => 'TestObject'
        )
        expect(obj.is_active).to eq(true)
      end

      it 'does not override explicitly provided value with default' do
        obj = GenericObject.create!(
          :generic_object_definition => definition_with_defaults,
          :name                      => 'TestObject',
          :status                    => 'active',
          :priority                  => 5,
          :discount                  => 10.0,
          :is_active                 => false
        )
        expect(obj.status).to eq('active')
        expect(obj.priority).to eq(5)
        expect(obj.discount).to eq(10.0)
        expect(obj.is_active).to eq(false)
      end

      it 'applies multiple default values at once' do
        obj = GenericObject.create!(
          :generic_object_definition => definition_with_defaults,
          :name                      => 'TestObject'
        )
        expect(obj.status).to eq('pending')
        expect(obj.priority).to eq(3)
        expect(obj.discount).to eq(0.0)
        expect(obj.is_active).to eq(true)
        expect(obj.description).to eq('No description')
      end

      it 'applies default value on update when attribute is nil' do
        obj = GenericObject.create!(
          :generic_object_definition => definition_with_defaults,
          :name                      => 'TestObject',
          :status                    => 'active'
        )
        expect(obj.status).to eq('active')
        
        obj.status = nil
        obj.save!
        expect(obj.reload.status).to eq('pending')
      end

      it 'validates default value against other constraints' do
        obj = GenericObject.create!(
          :generic_object_definition => definition_with_defaults,
          :name                      => 'TestObject'
        )
        # Default status is 'pending' which is in the enum
        expect(obj).to be_valid
        expect(obj.status).to eq('pending')
      end
    end
  end
end
