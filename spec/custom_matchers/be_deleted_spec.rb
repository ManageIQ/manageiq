RSpec.describe "be_deleted" do
  let(:model) { obj.class.name }
  let(:obj) { FactoryBot.create(:user) }

  it "detects deleted" do
    obj.delete
    expect(obj).to be_deleted
  end

  it "fails detecting not deleted" do
    expect { expect(obj).to be_deleted }.to raise_error "expected #{model} to be deleted"
  end

  it "detects exist" do
    expect(obj).not_to be_deleted
  end

  it "fails detecting exist" do
    obj.delete
    expect { expect(obj).not_to be_deleted }.to raise_error "expected #{model} to exist"
  end
end
