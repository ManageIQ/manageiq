describe GenericObjectDefinition do
  let(:definition) do
    FactoryGirl.create(
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

  it 'property name is unique among attributes, associations and methods' do
    testdef = described_class.new(
      :name       => 'test',
      :properties => {
        :attributes   => {:vms => "float", 'server' => 'localhost'},
        :associations => {'vms' => :strang_model, 'hosts' => :host},
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

  describe '#destroy' do
    let(:generic_object) do
      FactoryGirl.build(:generic_object, :generic_object_definition => definition, :name => 'test')
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
      FactoryGirl.create(:generic_object_definition,
                         :name       => 'test',
                         :properties => { :attributes => {:status => "string"}})
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
      FactoryGirl.create(:generic_object_definition,
                         :name       => 'test',
                         :properties => { :attributes => {:status => "string"}})
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
      FactoryGirl.create(:generic_object_definition,
                         :name       => 'test',
                         :properties => { :methods => %w(method1) })
    end

    it 'adds a new method' do
      definition.add_property_method("add_vms")
      expect(definition.properties).to include(:methods => %w(method1 add_vms))
    end

    it 'does nothing for existing method' do
      definition.add_property_method("method1")
      expect(definition.properties).to include(:methods => %w(method1))
    end
  end

  describe '#delete_property_method' do
    let(:definition) do
      FactoryGirl.create(:generic_object_definition,
                         :name       => 'test',
                         :properties => { :methods => %w(method1) })
    end

    it 'deletes an existing method' do
      definition.delete_property_method(:method1)
      expect(definition.properties).to include(:methods => [])
    end

    it 'does nothing for non-existing method' do
      definition.delete_property_method(:method2)
      expect(definition.properties).to include(:methods => %w(method1))
    end
  end

  describe '#add_property_association' do
    let(:definition) do
      FactoryGirl.create(:generic_object_definition,
                         :name       => 'test',
                         :properties => { :associations => { :vms => 'Vm' } })
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
      definition.add_property_association(:vms, 'vm_or_template')
      expect(definition.properties[:associations]).to include('vms' => 'VmOrTemplate')
    end
  end

  describe '#delete_property_association' do
    let(:definition) do
      FactoryGirl.create(:generic_object_definition,
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
      vm = FactoryGirl.create(:vm)
      go = FactoryGirl.create(:generic_object, :name => 'test', :generic_object_definition => definition)
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
      @options = { :max_number => 10 }
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
      expect { subject }.to raise_error(RuntimeError,
                                        "[attr1, attr2]: not searchable for Generic Object of #{definition.name}")
    end

    it 'finds by associations' do
      vm = []
      3.times { vm << FactoryGirl.create(:vm_vmware) }

      definition.add_property_association(:vms, 'vm')
      @g1.vms = [vm[0], vm[1], vm[2]]
      @g1.save!

      @options = {:vms => [vm[0].id, vm[1].id]}
      expect(subject.size).to eq(1)
      expect(subject.first).to eq(@g1)
    end
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
end
