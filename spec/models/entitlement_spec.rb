require 'rails_helper'

describe Entitlement do
  describe ".remove_tag_filters_by_name!" do
    let!(:e1) do
      filters = %w(/managed/operations/analysis_failed /managed/here_be_dragons /managed/lolfilter)
      Entitlement.create!(:tag_filters => filters)
    end
    let!(:e2) do
      filters = %w(/managed/operations/analysis_passed /managed/filterz)
      Entitlement.create!(:tag_filters => filters)
    end

    before { Entitlement.remove_tag_filters_by_name!("/managed/here_be_dragons") }

    it "removes the filter without ruining the others" do
      expect(e1.reload.tag_filters).to eq(%w(/managed/operations/analysis_failed /managed/lolfilter))
      expect(e2.reload.tag_filters).to eq(%w(/managed/operations/analysis_passed /managed/filterz))
    end
  end
end
