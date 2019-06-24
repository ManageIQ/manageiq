describe "ar_order extension" do
  it "supports order when distinct is present for basic column" do
    expect do
      VmOrTemplate.includes(:disks).references(:disks).order(:id).first
    end.not_to raise_error
  end
end
