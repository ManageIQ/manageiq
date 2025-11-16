RSpec.describe GenericObjectDefinition do
  let(:definition) do
    FactoryBot.create(
      :generic_object_definition,
      :name       => "test_definition",
      :properties => {
        :attributes => {
          :data_read  => "float",
          :flag       => "boolean",
          :max_number => "integer",
          :server     => "string",
          :s_time     => "datetime"
        }
      }
    )
  end
  let(:objects) { FactoryBot.create_list(:generic_object, 2, :generic_object_definition => definition) }

  it "doesn't access database when unchanged model is saved" do
    m = FactoryBot.create(:generic_object_definition)
    expect { m.valid? }.not_to make_database_queries
  end

  it 'requires name attribute present' do
    expect(described_class.new).not_to be_valid
  end

  it 'requires name attribute to be unique' do
    described_class.create!(:name => 'myclass')
    expect(described_class.new(:name => 'myclass')).not_to be_valid
  end

  it 'raises an error if any property attribute is not of a recognized type' do
    testdef = described_class.new(:name => 'test', :properties => {:attributes => {'myattr' => :strange_type}})
    expect { testdef.save! }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it 'raises an error if any property association is not of valid model' do
    testdef = described_class.new(:name => 'test', :properties => {:associations => {'vms' => :strang_model}})
    expect { testdef.save! }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it 'raises an error if any property association is not a reportable model' do
    testdef = described_class.new(:name => 'test', :properties => {:associations => {'folders' => :ems_folder}})
    expect { testdef.save! }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it 'property name is unique among attributes, associations and methods' do
    testdef = described_class.new(
      :name       => 'test',
      :properties => {
        :attributes   => {:vms => "float", 'server' => 'localhost'},
        :associations => {'vms' => :vm, 'hosts' => :host},
        :methods      => [:hosts, :some_method]
      }
    )
    expect { testdef.save! }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it 'has property attributes in hash' do
    expect(definition.properties[:attributes]).to be_kind_of(Hash)
  end

  it 'has property associations in hash' do
    expect(definition.properties[:associations]).to be_kind_of(Hash)
  end

  it 'has property methods in array' do
    expect(definition.properties[:methods]).to be_kind_of(Array)
  end

  it 'supports attributes, associations, methods only' do
    testdef = described_class.new(
      :name       => 'test',
      :properties => {
        :some_feature => {:vms => "float", 'server' => 'localhost'}
      }
    )

    expect { testdef.save! }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it 'accepts GenericObject as an association' do
    testdef = described_class.create(:name => 'test', :properties => {:associations => {'balancers' => :generic_object}})
    expect(testdef.properties[:associations]).to include('balancers' => 'GenericObject')
  end

  describe '#destroy' do
    let(:generic_object) do
      FactoryBot.build(:generic_object, :generic_object_definition => definition, :name => 'test')
    end

    it 'raises an error if the definition is in use' do
      generic_object.save!
      expect { definition.destroy! }.to raise_error(ActiveRecord::RecordNotDestroyed)
    end
  end

  describe '#create_object' do
    it 'creates a generic object' do
      obj = definition.create_object(:name => 'test', :max_number => 100)
      expect(obj).to be_a_kind_of(GenericObject)
      expect(obj.generic_object_definition).to eq(definition)
      expect(obj.max_number).to eq(100)
    end
  end

  describe '#add_property_attribute' do
    let(:definition) do
      FactoryBot.create(:generic_object_definition,
                         :name       => 'test',
                         :properties => {:attributes => {:status => "string"}})
    end

    it 'adds a new attribute' do
      expect(definition.properties[:attributes].size).to eq(1)

      definition.add_property_attribute(:location, "string")
      expect(definition.properties[:attributes].size).to eq(2)
    end

    it 'does nothing for an existing attribute with same data type' do
      definition.add_property_attribute(:status, "string")
      expect(definition.properties[:attributes].size).to eq(1)
      expect(definition.properties[:attributes]).to include("status" => :string)
    end

    it 'updates an existing attribute with different data type' do
      definition.add_property_attribute(:status, "integer")
      expect(definition.properties[:attributes].size).to eq(1)
      expect(definition.properties[:attributes]).to include("status" => :integer)
    end
  end

  describe '#delete_property_attribute' do
    let(:definition) do
      FactoryBot.create(:generic_object_definition,
                         :name       => 'test',
                         :properties => {:attributes => {:status => "string"}})
    end

    it 'does nothing for non-existing attribute' do
      definition.delete_property_attribute("not_existing_attribute")
      expect(definition.properties[:attributes].size).to eq(1)
    end

    it 'deletes an existing attribute' do
      definition.delete_property_attribute("status")
      expect(definition.properties[:attributes].size).to eq(0)
    end

    it 'deletes the attribute from associated generic objects' do
      go = definition.create_object(:name => 'test_object', :status => 'ok')
      definition.delete_property_attribute("status")
      expect(go.reload.property_attributes.size).to eq(0)
    end
  end

  describe '#add_property_method' do
    let(:definition) do
      FactoryBot.create(:generic_object_definition,
                         :name       => 'test',
                         :properties => {:methods => %w[method1]})
    end

    it 'adds a new method' do
      definition.add_property_method("add_vms")
      expect(definition.properties).to include(:methods => %w[method1 add_vms])
    end

    it 'does nothing for existing method' do
      expect { definition.add_property_method("method1") }.to make_database_queries(:count => 4..8)
      expect(definition.properties).to include(:methods => %w[method1])
    end
  end

  describe '#delete_property_method' do
    let(:definition) do
      FactoryBot.create(:generic_object_definition,
                         :name       => 'test',
                         :properties => {:methods => %w[method1]})
    end

    it 'deletes an existing method' do
      definition.delete_property_method(:method1)
      expect(definition.properties).to include(:methods => [])
    end

    it 'does nothing for non-existing method' do
      definition.delete_property_method(:method2)
      expect(definition.properties).to include(:methods => %w[method1])
    end
  end

  describe '#add_property_association' do
    let(:definition) do
      FactoryBot.create(:generic_object_definition,
                         :name       => 'test',
                         :properties => {:associations => {:vms => 'Vm'}})
    end

    it 'adds a new association' do
      definition.add_property_association(:hosts, 'host')
      expect(definition.properties[:associations]).to include('hosts' => 'Host')
    end

    it 'does nothing for the association with the same class' do
      definition.add_property_association(:vms, 'vm')
      expect(definition.properties[:associations]).to include('vms' => 'Vm')
    end

    it 'updates the association with different class' do
      definition.add_property_association(:vms, 'zone')
      expect(definition.properties[:associations]).to include('vms' => 'Zone')
    end

    it 'accepts GenericObject as the association' do
      definition.add_property_association(:balancers, 'generic_object')
      expect(definition.properties[:associations]).to include('balancers' => 'GenericObject')
    end

    it 'raises an error if the association is not a reportable model' do
      expect { definition.add_property_association(:folders, 'ems_folder') }.to raise_error(RuntimeError, "invalid model for association: [EmsFolder]")
    end
  end

  describe '#delete_property_association' do
    let(:definition) do
      FactoryBot.create(:generic_object_definition,
                         :name       => 'test',
                         :properties => {:associations => {:vms => 'Vm'}})
    end

    it 'deletes an existing association' do
      definition.delete_property_association("vms")
      expect(definition.properties).to include(:associations => {})
    end

    it 'does nothing for non-existing association' do
      definition.delete_property_association(:host)
      expect(definition.properties).to include(:associations => {'vms' => 'Vm'})
    end

    it 'deletes the association from associated generic objects' do
      vm = FactoryBot.create(:vm)
      go = FactoryBot.create(:generic_object, :name => 'test', :generic_object_definition => definition)
      go.add_to_property_association('vms', vm)
      expect(go.vms.size).to eq(1)

      definition.delete_property_association(:vms)
      expect(go.reload.send(:properties)["vms"]).to be_nil
    end
  end

  describe '#find_objects' do
    before do
      @g1 = definition.create_object(:name => 'test', :uid => '1', :max_number => 10, :flag => true)
      @g2 = definition.create_object(:name => 'test2', :uid => '2', :max_number => 10, :flag => false)
    end

    subject { definition.find_objects(@options) }

    it 'finds multiple objects' do
      @options = {:max_number => 10}
      expect(subject.size).to eq(2)
    end

    it 'finds by AR attributes in GenericObject' do
      @options = {:name => "test2", :uid => 2}
      expect(subject.first).to eq(@g2)
    end

    it 'finds by property attributes' do
      @options = {:max_number => 10, :flag => true}
      expect(subject.first).to eq(@g1)
    end

    it 'finds by both AR attributes and property attributes' do
      @options = {:max_number => 10, :uid => 2}
      expect(subject.first).to eq(@g2)
    end

    it 'raises an error with undefined attributes' do
      @options = {:max_number => 10, :attr1 => true, :attr2 => 1}
      expect { subject }.to raise_error(RuntimeError, "[attr1, attr2]: not searchable for Generic Object of #{definition.name}")
    end

    it 'finds by associations' do
      vms = FactoryBot.create_list(:vm_vmware, 3)
      definition.add_property_association(:vms, 'vm')
      @g1.vms = vms
      @g1.save!

      @options = {:vms => [vms[0].id, vms[1].id]}
      expect(subject.size).to eq(1)
      expect(subject.first).to eq(@g1)
    end
  end

  describe "#custom_actions" do
    it "returns the custom actions in a hash grouped by buttons and button groups" do
      FactoryBot.create(:custom_button, :name => "generic_no_group", :applies_to_class => "GenericObject")
      generic_group = FactoryBot.create(:custom_button, :name => "generic_group", :applies_to_class => "GenericObject")
      FactoryBot.create(:custom_button_set, :name => "generic_group_set", :set_data => {:button_order => [generic_group.id]})

      FactoryBot.create(
        :custom_button,
        :name             => "assigned_no_group",
        :applies_to_class => "GenericObjectDefinition",
        :applies_to_id    => definition.id
      )
      assigned_group = FactoryBot.create(
        :custom_button,
        :name             => "assigned_group",
        :applies_to_class => "GenericObjectDefinition",
        :applies_to_id    => definition.id
      )
      assigned_group_set = FactoryBot.create(:custom_button_set, :name => "assigned_group_set", :set_data => {:button_order => [assigned_group.id]})
      definition.update(:custom_button_sets => [assigned_group_set])

      expected = {
        :buttons       => a_collection_containing_exactly(
          a_hash_including("name" => "generic_no_group"),
          a_hash_including("name" => "assigned_no_group")
        ),
        :button_groups => a_collection_containing_exactly(
          a_hash_including(
            "name"   => "assigned_group_set",
            :buttons => [a_hash_including("name" => "assigned_group")]
          ),
          a_hash_including(
            "name"   => "generic_group_set",
            :buttons => [a_hash_including("name" => "generic_group")]
          )
        )
      }
      expect(definition.custom_actions).to match(expected)
    end

    context "expression evaluation" do
      let(:generic) { FactoryBot.build(:generic_object, :generic_object_definition => definition, :name => 'hello') }
      let(:true_expression_on_definition) do
        MiqExpression.new("=" => {"field" => "GenericObjectDefinition-name", "value" => "test_definition"})
      end
      let(:false_expression_on_definition) do
        MiqExpression.new("=" => {"field" => "GenericObjectDefinition-name", "value" => "not_test_definition"})
      end
      let(:true_expression_on_generic) do
        MiqExpression.new("=" => {"field" => "GenericObject-name", "value" => "hello"})
      end
      let(:false_expression_on_generic) do
        MiqExpression.new("=" => {"field" => "GenericObject-name", "value" => "not_hello"})
      end

      before do
        FactoryBot.create(:custom_button,
                           :name                  => "visible button on Generic Object",
                           :applies_to_class      => "GenericObject",
                           :visibility_expression => true_expression_on_generic)
        FactoryBot.create(:custom_button,
                           :name                  => "hidden button on Generic Object",
                           :applies_to_class      => "GenericObject",
                           :visibility_expression => false_expression_on_generic)
        FactoryBot.create(:custom_button,
                           :name                  => "visible button on Generic Object Definition",
                           :applies_to_class      => "GenericObjectDefinition",
                           :applies_to_id         => definition.id,
                           :visibility_expression => true_expression_on_definition)
        FactoryBot.create(:custom_button,
                           :name                  => "hidden button on Generic Object Definition",
                           :applies_to_class      => "GenericObjectDefinition",
                           :applies_to_id         => definition.id,
                           :visibility_expression => false_expression_on_definition)
      end

      it "uses appropriate object: parameter, which is GenericObject or definition for expression evaluation" do
        expected = {
          :buttons       => a_collection_containing_exactly(
            a_hash_including("name" => "visible button on Generic Object"),
            a_hash_including("name" => "visible button on Generic Object Definition")
          ),
          :button_groups => []
        }
        expect(definition.custom_actions(generic)).to match(expected)
      end

      it "uses GenericObjectDefinition object to evaluate expressionif if no parameter passed" do
        expected = {
          :buttons       => [
            a_hash_including("name" => "visible button on Generic Object Definition")
          ],
          :button_groups => []
        }
        expect(definition.custom_actions).to match(expected)
      end
    end
  end

  describe '#generic_objects_count' do
    before  { objects }
    subject { definition }
    it_behaves_like "sql friendly virtual_attribute", :generic_objects_count, 2
  end

  shared_examples 'AR attribute allowing letters' do |hash|
    it 'allows letters' do
      expect(described_class.new(:name => 'test', :properties => hash)).to be_valid
    end
  end

  shared_examples 'AR attribute allowing numbers' do |hash|
    it 'allows numbers' do
      expect(described_class.new(:name => 'test', :properties => hash)).to be_valid
    end
  end

  shared_examples 'AR attribute allowing _' do |hash|
    it 'allows _' do
      expect(described_class.new(:name => 'test', :properties => hash)).to be_valid
    end
  end

  shared_examples 'AR attribute starting with letters only' do |hash|
    it 'starts with letter only' do
      testdef = described_class.new(:name => 'test', :properties => hash)
      expect { testdef.save! }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  shared_examples 'AR attribute allowing letters, numbers and _ only' do |hash|
    it 'allows not other characters' do
      testdef = described_class.new(:name => 'test', :properties => hash)
      expect { testdef.save! }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  context 'property attribute name' do
    it_behaves_like 'AR attribute allowing letters', :attributes => {'address' => :string}
    it_behaves_like 'AR attribute allowing numbers', :attributes => {'address2' => :string}
    it_behaves_like 'AR attribute allowing _', :attributes => {'my_address' => :string}
    it_behaves_like 'AR attribute starting with letters only', :attributes => {'1st_vm' => "string"}
    it_behaves_like 'AR attribute starting with letters only', :attributes => {'_vm' => "string"}
    it_behaves_like 'AR attribute allowing letters, numbers and _ only', :attributes => {'my-vm' => "string"}
    it_behaves_like 'AR attribute allowing letters, numbers and _ only', :attributes => {'my_vm!' => "string"}
  end

  context 'property association name' do
    it_behaves_like 'AR attribute allowing letters', :associations => {'vms' => :Vm}
    it_behaves_like 'AR attribute allowing numbers', :associations => {'vms2' => :Vm}
    it_behaves_like 'AR attribute allowing _', :associations => {'my_vms' => "Vm"}
    it_behaves_like 'AR attribute starting with letters only', :associations => {'1st_vm' => "Vm"}
    it_behaves_like 'AR attribute starting with letters only', :associations => {'_vm' => "Vm"}
    it_behaves_like 'AR attribute allowing letters, numbers and _ only', :associations => {'active-vms' => "Vm"}
    it_behaves_like 'AR attribute allowing letters, numbers and _ only', :associations => {'active_vms!' => "Vm"}
  end

  context 'property method name' do
    it_behaves_like 'AR attribute allowing letters', :methods => ['vms']
    it_behaves_like 'AR attribute allowing numbers', :methods => ['vms2']
    it_behaves_like 'AR attribute allowing _', :methods => ['active_vms']
    it_behaves_like 'AR attribute starting with letters only', :methods => ['1st_vm']
    it_behaves_like 'AR attribute starting with letters only', :methods => ['_vm']
    it_behaves_like 'AR attribute allowing letters, numbers and _ only', :methods => ['active-vms']
    it_behaves_like 'AR attribute allowing letters, numbers and _ only', :methods => ['active@vms']

    subject { described_class.new(:name => 'test', :properties => {:methods => @attrs}) }

    it 'allows ending with ?' do
      @attrs = ['active_vm?']
      expect(subject).to be_valid
    end

    it 'allows ending with !' do
      @attrs = ['rename_vm!']
      expect(subject).to be_valid
    end
  end

  describe 'attribute_constraints' do
    context 'validation' do
      it 'accepts valid constraints for string attributes' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:name => :string},
            :attribute_constraints => {:name => {:required => true, :min_length => 3, :max_length => 50}}
          }
        )
        expect(testdef).to be_valid
      end

      it 'accepts valid constraints for integer attributes' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:age => :integer},
            :attribute_constraints => {:age => {:required => true, :min => 0, :max => 120}}
          }
        )
        expect(testdef).to be_valid
      end

      it 'accepts valid constraints for float attributes' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:price => :float},
            :attribute_constraints => {:price => {:min => 0.0, :max => 999.99}}
          }
        )
        expect(testdef).to be_valid
      end

      it 'accepts valid enum constraint for string attributes' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:status => :string},
            :attribute_constraints => {:status => {:enum => %w[active inactive pending]}}
          }
        )
        expect(testdef).to be_valid
      end

      it 'accepts valid enum constraint for integer attributes' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:priority => :integer},
            :attribute_constraints => {:priority => {:enum => [1, 2, 3, 4, 5]}}
          }
        )
        expect(testdef).to be_valid
      end

      it 'accepts valid format constraint for string attributes' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:email => :string},
            :attribute_constraints => {:email => {:format => /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i}}
          }
        )
        expect(testdef).to be_valid
      end

      it 'accepts format constraint as string regex' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:code => :string},
            :attribute_constraints => {:code => {:format => '\A[A-Z]{3}\d{3}\z'}}
          }
        )
        expect(testdef).to be_valid
      end

      it 'rejects constraint for non-existent attribute' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:name => :string},
            :attribute_constraints => {:age => {:required => true}}
          }
        )
        expect { testdef.save! }.to raise_error(ActiveRecord::RecordInvalid, /constraint defined for non-existent attribute/)
      end

      it 'rejects non-hash constraints' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:name => :string},
            :attribute_constraints => {:name => "invalid"}
          }
        )
        expect { testdef.save! }.to raise_error(ActiveRecord::RecordInvalid, /constraints for attribute .* must be a hash/)
      end

      it 'rejects invalid constraint type' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:name => :string},
            :attribute_constraints => {:name => {:invalid_constraint => true}}
          }
        )
        expect { testdef.save! }.to raise_error(ActiveRecord::RecordInvalid, /invalid constraint type/)
      end

      it 'rejects constraint not applicable to attribute type' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:flag => :boolean},
            :attribute_constraints => {:flag => {:min_length => 5}}
          }
        )
        expect { testdef.save! }.to raise_error(ActiveRecord::RecordInvalid, /constraint .* is not applicable to attribute type/)
      end

      it 'rejects non-boolean value for required constraint' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:name => :string},
            :attribute_constraints => {:name => {:required => "yes"}}
          }
        )
        expect { testdef.save! }.to raise_error(ActiveRecord::RecordInvalid, /constraint 'required' must be true or false/)
      end

      it 'rejects non-integer value for min constraint on integer attribute' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:age => :integer},
            :attribute_constraints => {:age => {:min => "zero"}}
          }
        )
        expect { testdef.save! }.to raise_error(ActiveRecord::RecordInvalid, /constraint 'min' must be an integer/)
      end

      it 'rejects non-numeric value for min constraint on float attribute' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:price => :float},
            :attribute_constraints => {:price => {:min => "zero"}}
          }
        )
        expect { testdef.save! }.to raise_error(ActiveRecord::RecordInvalid, /constraint 'min' must be a number/)
      end

      it 'rejects non-positive integer for min_length constraint' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:name => :string},
            :attribute_constraints => {:name => {:min_length => -1}}
          }
        )
        expect { testdef.save! }.to raise_error(ActiveRecord::RecordInvalid, /constraint 'min_length' must be a positive integer/)
      end

      it 'rejects non-array value for enum constraint' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:status => :string},
            :attribute_constraints => {:status => {:enum => "active"}}
          }
        )
        expect { testdef.save! }.to raise_error(ActiveRecord::RecordInvalid, /constraint 'enum' must be a non-empty array/)
      end

      it 'rejects empty array for enum constraint' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:status => :string},
            :attribute_constraints => {:status => {:enum => []}}
          }
        )
        expect { testdef.save! }.to raise_error(ActiveRecord::RecordInvalid, /constraint 'enum' must be a non-empty array/)
      end

      it 'rejects enum constraint with nil values' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:status => :string},
            :attribute_constraints => {:status => {:enum => ['active', nil, 'inactive']}}
          }
        )
        expect { testdef.save! }.to raise_error(ActiveRecord::RecordInvalid, /constraint 'enum' must not contain nil values/)
      end

      it 'rejects enum constraint with duplicate values' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:status => :string},
            :attribute_constraints => {:status => {:enum => ['active', 'inactive', 'active']}}
          }
        )
        expect { testdef.save! }.to raise_error(ActiveRecord::RecordInvalid, /constraint 'enum' contains duplicate values/)
      end

      it 'rejects enum constraint with wrong type values for integer attribute' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:priority => :integer},
            :attribute_constraints => {:priority => {:enum => [1, "2", 3]}}
          }
        )
        expect { testdef.save! }.to raise_error(ActiveRecord::RecordInvalid, /constraint 'enum' values must be integers/)
      end

      it 'rejects enum constraint with wrong type values for string attribute' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:status => :string},
            :attribute_constraints => {:status => {:enum => ['active', 123, 'inactive']}}
          }
        )
        expect { testdef.save! }.to raise_error(ActiveRecord::RecordInvalid, /constraint 'enum' values must be strings/)
      end

      it 'rejects invalid regex for format constraint' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:code => :string},
            :attribute_constraints => {:code => {:format => '[invalid('}}
          }
        )
        expect { testdef.save! }.to raise_error(ActiveRecord::RecordInvalid, /constraint 'format' must be a valid regular expression/)
      end
    end

    context 'normalization' do
      it 'normalizes attribute constraint keys to strings' do
        testdef = described_class.create!(
          :name       => 'test',
          :properties => {
            :attributes            => {:name => :string},
            :attribute_constraints => {:name => {:required => true}}
          }
        )
        expect(testdef.properties[:attribute_constraints]).to have_key('name')
      end
    end

    describe '#add_property_attribute' do
      let(:definition) do
        FactoryBot.create(:generic_object_definition,
                          :name       => 'test',
                          :properties => {:attributes => {:status => "string"}})
      end

      it 'adds attribute with constraints' do
        definition.add_property_attribute(:priority, "integer", {:min => 1, :max => 5})
        expect(definition.properties[:attributes]).to include("priority" => :integer)
        expect(definition.properties[:attribute_constraints]).to include("priority" => {:min => 1, :max => 5})
      end

      it 'adds attribute without constraints when not provided' do
        definition.add_property_attribute(:name, "string")
        expect(definition.properties[:attributes]).to include("name" => :string)
        expect(definition.properties[:attribute_constraints]).not_to have_key("name")
      end

      it 'adds attribute without constraints when empty hash provided' do
        definition.add_property_attribute(:name, "string", {})
        expect(definition.properties[:attributes]).to include("name" => :string)
        expect(definition.properties[:attribute_constraints]).not_to have_key("name")
      end
    end

    describe '#delete_property_attribute' do
      let(:definition) do
        FactoryBot.create(:generic_object_definition,
                          :name       => 'test',
                          :properties => {
                            :attributes            => {:status => "string", :priority => "integer"},
                            :attribute_constraints => {:status => {:required => true}, :priority => {:min => 1, :max => 5}}
                          })
      end

      it 'deletes attribute and its constraints' do
        definition.delete_property_attribute("status")
        expect(definition.properties[:attributes]).not_to have_key("status")
        expect(definition.properties[:attribute_constraints]).not_to have_key("status")
      end

      it 'keeps other attributes and their constraints' do
        definition.delete_property_attribute("status")
        expect(definition.properties[:attributes]).to include("priority" => :integer)
        expect(definition.properties[:attribute_constraints]).to include("priority" => {:min => 1, :max => 5})
      end
    end

    describe '#add_property_attribute_constraint' do
      let(:definition) do
        FactoryBot.create(:generic_object_definition,
                          :name       => 'test',
                          :properties => {:attributes => {:name => "string"}})
      end

      it 'adds constraint to existing attribute' do
        definition.add_property_attribute_constraint(:name, {:required => true, :min_length => 3})
        expect(definition.properties[:attribute_constraints]).to include("name" => {:required => true, :min_length => 3})
      end

      it 'raises error for non-existent attribute' do
        expect { definition.add_property_attribute_constraint(:age, {:min => 0}) }.to raise_error(/attribute .* is not defined/)
      end
    end

    describe '#delete_property_attribute_constraint' do
      let(:definition) do
        FactoryBot.create(:generic_object_definition,
                          :name       => 'test',
                          :properties => {
                            :attributes            => {:name => "string"},
                            :attribute_constraints => {:name => {:required => true, :min_length => 3}}
                          })
      end

      it 'deletes constraint for attribute' do
        definition.delete_property_attribute_constraint("name")
        expect(definition.properties[:attribute_constraints]).not_to have_key("name")
      end

      it 'does nothing for non-existent constraint' do
        definition.delete_property_attribute_constraint("age")
        expect(definition.properties[:attribute_constraints]).to include("name" => {:required => true, :min_length => 3})
      end
    end

    describe '#property_attribute_constraints' do
      let(:definition) do
        FactoryBot.create(:generic_object_definition,
                          :name       => 'test',
                          :properties => {
                            :attributes            => {:name => "string", :age => "integer"},
                            :attribute_constraints => {:name => {:required => true}, :age => {:min => 0, :max => 120}}
                          })
      end

      it 'returns attribute constraints hash' do
        expect(definition.property_attribute_constraints).to be_a(Hash)
        expect(definition.property_attribute_constraints).to include("name" => {:required => true})
        expect(definition.property_attribute_constraints).to include("age" => {:min => 0, :max => 120})
      end
    end

    describe 'default properties' do
      it 'initializes attribute_constraints as empty hash' do
        testdef = described_class.create!(:name => 'test')
        expect(testdef.properties[:attribute_constraints]).to eq({})
      end
    end

    context 'default value constraint' do
      it 'accepts default value for string attribute' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:status => :string},
            :attribute_constraints => {:status => {:default => 'pending'}}
          }
        )
        expect(testdef).to be_valid
      end

      it 'accepts default value for integer attribute' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:priority => :integer},
            :attribute_constraints => {:priority => {:default => 1}}
          }
        )
        expect(testdef).to be_valid
      end

      it 'accepts default value for float attribute' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:price => :float},
            :attribute_constraints => {:price => {:default => 0.0}}
          }
        )
        expect(testdef).to be_valid
      end

      it 'accepts default value for boolean attribute' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:active => :boolean},
            :attribute_constraints => {:active => {:default => false}}
          }
        )
        expect(testdef).to be_valid
      end

      it 'rejects non-string default value for string attribute' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:status => :string},
            :attribute_constraints => {:status => {:default => 123}}
          }
        )
        expect { testdef.save! }.to raise_error(ActiveRecord::RecordInvalid, /default value for attribute .* must be a string/)
      end

      it 'rejects non-integer default value for integer attribute' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:priority => :integer},
            :attribute_constraints => {:priority => {:default => "one"}}
          }
        )
        expect { testdef.save! }.to raise_error(ActiveRecord::RecordInvalid, /default value for attribute .* must be an integer/)
      end

      it 'rejects non-numeric default value for float attribute' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:price => :float},
            :attribute_constraints => {:price => {:default => "zero"}}
          }
        )
        expect { testdef.save! }.to raise_error(ActiveRecord::RecordInvalid, /default value for attribute .* must be a number/)
      end

      it 'rejects non-boolean default value for boolean attribute' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:active => :boolean},
            :attribute_constraints => {:active => {:default => "yes"}}
          }
        )
        expect { testdef.save! }.to raise_error(ActiveRecord::RecordInvalid, /default value for attribute .* must be a boolean/)
      end

      it 'accepts default value with other constraints' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:status => :string},
            :attribute_constraints => {:status => {:default => 'pending', :enum => ['pending', 'active', 'inactive']}}
          }
        )
        expect(testdef).to be_valid
      end
    end

    context 'Hash attribute type' do
      it 'accepts hash attribute type' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {:attributes => {:config => :hash}}
        )
        expect(testdef).to be_valid
      end

      it 'accepts hash with required_keys constraint' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:config => :hash},
            :attribute_constraints => {:config => {:required_keys => ['theme', 'language']}}
          }
        )
        expect(testdef).to be_valid
      end

      it 'accepts hash with allowed_keys constraint' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:config => :hash},
            :attribute_constraints => {:config => {:allowed_keys => ['theme', 'language', 'timezone']}}
          }
        )
        expect(testdef).to be_valid
      end

      it 'accepts hash with both required_keys and allowed_keys constraints' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:config => :hash},
            :attribute_constraints => {:config => {:required_keys => ['theme'], :allowed_keys => ['theme', 'language', 'timezone']}}
          }
        )
        expect(testdef).to be_valid
      end

      it 'accepts hash default value' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:config => :hash},
            :attribute_constraints => {:config => {:default => {'theme' => 'light'}}}
          }
        )
        expect(testdef).to be_valid
      end

      it 'accepts empty hash as default value' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:metadata => :hash},
            :attribute_constraints => {:metadata => {:default => {}}}
          }
        )
        expect(testdef).to be_valid
      end

      it 'rejects non-hash default value' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:config => :hash},
            :attribute_constraints => {:config => {:default => ['not', 'a', 'hash']}}
          }
        )
        expect { testdef.save! }.to raise_error(ActiveRecord::RecordInvalid, /must be a Hash/)
      end

      it 'rejects non-array value for required_keys constraint' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:config => :hash},
            :attribute_constraints => {:config => {:required_keys => 'theme'}}
          }
        )
        expect { testdef.save! }.to raise_error(ActiveRecord::RecordInvalid, /must be an array of strings/)
      end

      it 'rejects non-array value for allowed_keys constraint' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:config => :hash},
            :attribute_constraints => {:config => {:allowed_keys => 'theme'}}
          }
        )
        expect { testdef.save! }.to raise_error(ActiveRecord::RecordInvalid, /must be an array of strings/)
      end

      it 'rejects min constraint on hash attribute' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:config => :hash},
            :attribute_constraints => {:config => {:min => 1}}
          }
        )
        expect { testdef.save! }.to raise_error(ActiveRecord::RecordInvalid, /is not applicable to attribute type/)
      end
    end

    context 'Array attribute type' do
      it 'accepts array attribute type' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {:attributes => {:tags => :array}}
        )
        expect(testdef).to be_valid
      end

      it 'accepts array with min_items constraint' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:tags => :array},
            :attribute_constraints => {:tags => {:min_items => 1}}
          }
        )
        expect(testdef).to be_valid
      end

      it 'accepts array with max_items constraint' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:tags => :array},
            :attribute_constraints => {:tags => {:max_items => 10}}
          }
        )
        expect(testdef).to be_valid
      end

      it 'accepts array with unique_items constraint' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:tags => :array},
            :attribute_constraints => {:tags => {:unique_items => true}}
          }
        )
        expect(testdef).to be_valid
      end

      it 'accepts array with all constraints' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:tags => :array},
            :attribute_constraints => {:tags => {:min_items => 1, :max_items => 5, :unique_items => true}}
          }
        )
        expect(testdef).to be_valid
      end

      it 'accepts array default value' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:tags => :array},
            :attribute_constraints => {:tags => {:default => ['untagged']}}
          }
        )
        expect(testdef).to be_valid
      end

      it 'accepts empty array as default value' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:categories => :array},
            :attribute_constraints => {:categories => {:default => []}}
          }
        )
        expect(testdef).to be_valid
      end

      it 'rejects non-array default value' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:tags => :array},
            :attribute_constraints => {:tags => {:default => 'not an array'}}
          }
        )
        expect { testdef.save! }.to raise_error(ActiveRecord::RecordInvalid, /must be an Array/)
      end

      it 'rejects non-integer value for min_items constraint' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:tags => :array},
            :attribute_constraints => {:tags => {:min_items => 'one'}}
          }
        )
        expect { testdef.save! }.to raise_error(ActiveRecord::RecordInvalid, /must be a non-negative integer/)
      end

      it 'rejects negative value for min_items constraint' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:tags => :array},
            :attribute_constraints => {:tags => {:min_items => -1}}
          }
        )
        expect { testdef.save! }.to raise_error(ActiveRecord::RecordInvalid, /must be a non-negative integer/)
      end

      it 'rejects non-integer value for max_items constraint' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:tags => :array},
            :attribute_constraints => {:tags => {:max_items => 'ten'}}
          }
        )
        expect { testdef.save! }.to raise_error(ActiveRecord::RecordInvalid, /must be a non-negative integer/)
      end

      it 'rejects non-boolean value for unique_items constraint' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:tags => :array},
            :attribute_constraints => {:tags => {:unique_items => 'yes'}}
          }
        )
        expect { testdef.save! }.to raise_error(ActiveRecord::RecordInvalid, /must be true or false/)
      end

      it 'rejects min_length constraint on array attribute' do
        testdef = described_class.new(
          :name       => 'test',
          :properties => {
            :attributes            => {:tags => :array},
            :attribute_constraints => {:tags => {:min_length => 3}}
          }
        )
        expect { testdef.save! }.to raise_error(ActiveRecord::RecordInvalid, /is not applicable to attribute type/)
      end
    end
  end
end
