RSpec.describe "ar_order extension" do
  # includes a has_many AND references the has many
  # this introduces a DISTINCT to the query.
  # rails uses limited_ids_for (which calls columns_for_distinct) to run a quick query
  #
  # when we use a virtual attribute in the sort (and the attribute has a descending order)
  # the string munging gives us issues.
  it "supports order when distinct is present for has_many virtual column" do
    expect do
      VmOrTemplate.includes(:disks).references(:disks).order(:last_compliance_status).first
    end.not_to raise_error
  end

  it "supports order when distinct is present for basic column" do
    expect do
      VmOrTemplate.includes(:disks).references(:disks).order(:id).first
    end.not_to raise_error
  end
end
