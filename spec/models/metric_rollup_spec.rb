require "spec_helper"

describe MetricRollup do
  context "test" do
    it "should not raise an error when a polymorphic reflection is included and references are specified in a query" do
      # TODO: A fix in ActiveRecord will make this test pass
      # expect {
      #   MetricRollup.where(:id=>1000000544893).includes(:resource=>{}, :time_profile=>{}).references(:time_profile=>{}).last
      # }.not_to raise_error

      # TODO: Also, there is a bug that exists in only the manageiq repo and not rails that causes the error "ActiveRecord::ConfigurationError: nil"
      # TODO: instead of the expected "ActiveRecord::EagerLoadPolymorphicError" error.
      expect {
        Tagging.includes(:taggable => {}).where('bogus_table.column = 1').references(:bogus_table => {}).to_a
      }.to raise_error ActiveRecord::EagerLoadPolymorphicError
    end
  end
end

