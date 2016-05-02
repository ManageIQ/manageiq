RSpec.describe "FactoryGirl factories", :lint do
  example "linting factories" do
    factories_to_lint = FactoryGirl.factories.reject do |factory|
      factory.name =~ /rr_pending_change/
    end

    FactoryGirl.lint factories_to_lint
  end
end
