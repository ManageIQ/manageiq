require "spec_helper"

describe MiqAePassword do
  let(:plaintext) { "Pl$1nTeXt" }

  before do
    # clear out cached key files
    MiqPassword.key_root = Rails.root.join("certs")
  end

  it "should find v2_key" do
    expect(described_class.v2_key).not_to be_nil
  end

  it "should not find v1_key" do
    expect(described_class.v1_key).to be_false
  end

  it "should not find v0_key" do
    expect(described_class.v1_key).to be_false
  end

  it "should encrypt like miqpassword" do
    expect(MiqPassword.decrypt(described_class.encrypt(plaintext))).to eq(plaintext)
  end

  it "should decrypt miqpassword strings" do
    expect(described_class.decrypt(MiqPassword.encrypt(plaintext))).to eq(plaintext)
  end

  context "with v2_key" do
    subject { described_class.new(plaintext) }

    it "should have hidden to_s" do
      expect(subject.to_s).to eq("********")
    end

    it "should decrypt MiqAePassword" do
      expect(MiqAePassword.decrypt_if_password(subject)).to eq(plaintext)
    end

    it "should decrypt plaintext" do
      expect(MiqAePassword.decrypt_if_password("string")).to eq("string")
    end
  end
end
