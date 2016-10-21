describe GenericObject do
  let(:go_object_name) { "load_balancer_1" }
  let(:max_number)     { 100 }
  let(:server_name)    { "test_server" }
  let(:data_read)      { 345.67 }
  let(:s_time)         { Time.now.utc }
  let(:vm1)            { FactoryGirl.create(:vm_vmware) }

  let(:definition) do
    FactoryGirl.create(
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
        :methods      => %w(my_host  some_method)
      }
    )
  end

  let(:go) do
    FactoryGirl.create(
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
        expect(go.s_time).to                    be_same_time_as(s_time).with_precision(2)
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

        expect(go.property_attributes['s_time']).to be_same_time_as(s_time - 2.days).with_precision(2)
        expect(go.property_attributes).to include(
          "flag"       => false,
          "data_read"  => data_read + 100.50,
          "max_number" => max_number + 100,
          "server"     => "#{server_name}_2",
        )
      end

      it "raises an error if any property attribute is not defined" do
        expect { go.property_attributes = {:max_number => max_number + 100, :bad => ''} }.to raise_error(ActiveModel::UnknownAttributeError)
      end
    end

    context "without generic_object_definition" do
      let(:empty_go) { FactoryGirl.build(:generic_object) }

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
    let(:vm2) { FactoryGirl.create(:vm_vmware) }
    let(:go_assoc) do
      FactoryGirl.create(
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
      go_assoc.vms = [vm1, vm2, FactoryGirl.create(:host)]
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
  end

  describe 'property methods' do
    let(:ws)   { double("MiqAeWorkspaceRuntime", :root => {"method_result" => "some_return_value"}) }
    let(:user) { FactoryGirl.create(:user_with_group) }

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
        options = {:attrs => attrs.merge(:param_1 => %w(p1 p2), :param_1_type=>"Array")}
        expect(MiqAeEngine).to receive(:deliver).with(hash_including(options)).and_return(ws)
        go.my_host(%w(p1 p2))
      end

      it 'one hash parameter' do
        options = {:attrs => attrs.merge(:param_1 => {:p1 => 1, :p2 => 2}, :param_1_type=>"Hash")}
        expect(MiqAeEngine).to receive(:deliver).with(hash_including(options)).and_return(ws)
        go.my_host(:p1 => 1, :p2 => 2)
      end
    end

    it 'returns value from automate' do
      allow(MiqAeEngine).to receive(:deliver).and_return(ws)
      expect(go.my_host).to eq("some_return_value")
    end
  end
end
