require "spec_helper"

describe MiqAePassword do
  let(:plaintext) { "Pl$1nTeXt" }

  before do
    # clear out cached key files
    MiqPassword.key_root = Rails.root.join("certs")
  end

  describe ".v0_key" do
    it "does not have v0_key" do
      expect(described_class.v0_key).to be_false
    end
  end

  describe ".v1_key" do
    it "does not have v1_key" do
      expect(described_class.v1_key).to be_false
    end
  end

  describe ".v2_key" do
    it "should find v2_key" do
      expect(described_class.v2_key).not_to be_nil
    end
  end

  describe "#v2_key" do
    subject { described_class.new(plaintext) }

    it "is hidden to_s" do
      expect(subject.to_s).to eq("********")
    end
  end

  it "produces a key decryptable by MiqPassword" do
    expect(MiqPassword.decrypt(described_class.encrypt(plaintext))).to eq(plaintext)
  end

  describe ".decrypt" do
    it "reads password encrypted by MiqPassword" do
      expect(described_class.decrypt(MiqPassword.encrypt(plaintext))).to eq(plaintext)
    end

    it "throws understandable error" do
      expect { described_class.decrypt("v1:{something}") }.to raise_error("no encryption key v1_key")
    end
  end

  describe ".decrypt_if_password" do
    context "with encrypted password" do
      subject { described_class.new(plaintext) }
      it "decrypts" do
        expect(MiqAePassword.decrypt_if_password(subject)).to eq(plaintext)
      end
    end

    context "with plaintext password" do
      subject { "string" }
      it "decrypts" do
        expect(MiqAePassword.decrypt_if_password(subject)).to eq(subject)
      end
    end
  end
end
