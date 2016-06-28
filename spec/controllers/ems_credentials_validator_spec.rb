describe EmsCredentialsValidator do
  before(:each) do
    @object = EmsMiddlewareController.new
  end
      it "hawkular invalid credentials" do
        @object.instance_variable_set(:@edit, :new => {})
        @object.instance_variable_set(:@_params, :type => "hawkular")
        middleware_provider = FactoryGirl.create(:ems_hawkular)
        resoponse = @object.create_validation_object middleware_provider
        expect(resoponse[:result]).to be_falsey
      end
end
