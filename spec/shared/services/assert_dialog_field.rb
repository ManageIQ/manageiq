module Helpers
  def assert_field(field, clss, attributes)
    expect(field).to be_kind_of clss
    expect(field).to have_attributes(attributes)
  end
end
