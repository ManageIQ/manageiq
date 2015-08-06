require "spec_helper"

module MiqAeServiceSpec
  include MiqAeMethodService

  describe MiqAeServiceObject do
    before do
      @object = double('object')
      @service = double('service')
      @service_object = MiqAeServiceObject.new(@object, @service)
    end

    context "#attributes" do
      before do
        @object.stub(:attributes).and_return({
          'true'     => true,
          'false'    => false,
          'time'     => Time.parse('Aug 30, 2013'),
          'symbol'   => :symbol,
          'int'      => 1,
          'float'    => 1.1,
          'string'   => 'hello',
          'array'    => [1,2,3,4],
          'password' => MiqAePassword.new('test')})
      end

      it "obscures passwords" do
        original_attributes = @object.attributes.dup
        attributes = @service_object.attributes
        attributes['password'].should == '********'
        @object.attributes.should == original_attributes
      end
    end

    context "#inspect" do
      it "returns the class, id and name" do
        @object.stub(:object_name).and_return('fred')
        regex = /#<MiqAeMethodService::MiqAeServiceObject:0x(\w+) name:.\"(?<name>\w+)\">/
        match = regex.match(@service_object.inspect)
        match[:name].should eq('fred')
      end
    end
  end
end
