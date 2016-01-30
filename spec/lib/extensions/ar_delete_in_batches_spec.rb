describe ArDeleteInBatches do
  it "deletes none" do
    expect(VmOrTemplate.delete_in_batches).to eq(0)
  end

  it "runs multiple batches" do
    FactoryGirl.create_list(:vm, 5)

    expect(VmOrTemplate.delete_in_batches(2)).to eq(5)
    expect(VmOrTemplate.count).to eq(0)
  end

  it "short circuits when fewer records is detected" do
    FactoryGirl.create_list(:vm, 1)

    expect(VmOrTemplate.delete_in_batches(2)).to eq(1)
    expect(VmOrTemplate.count).to eq(0)
  end

  it "limits deletions" do
    FactoryGirl.create_list(:vm, 4)

    expect(VmOrTemplate.delete_in_batches(2, 3)).to eq(3)
    expect(VmOrTemplate.count).to eq(1)
  end

  it "supports scopes" do
    FactoryGirl.create_list(:vm, 3, :location => "a")
    FactoryGirl.create_list(:vm, 2, :location => "b")

    expect(VmOrTemplate.where(:location => "a").delete_in_batches(2)).to eq(3)
    expect(VmOrTemplate.count).to eq(2)
  end

  it "supports a block" do
    FactoryGirl.create_list(:vm, 4)

    block_count = 0
    expect(VmOrTemplate.delete_in_batches(2) { |_count, _total| block_count += 1 }).to eq(4)
    expect(VmOrTemplate.count).to eq(0)
    expect(block_count).to eq(2) # called 2 times
  end
end
