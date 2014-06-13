require "spec_helper"

describe Vmdb::ConfigurationEncoder do
  let(:password) { "pa$$word" }
  let(:enc_pass) { MiqPassword.encrypt("pa$$word") }
  context ".dump" do
    it "stringifies keys" do
      hash = {:one => {:two => nil}}
      described_class.dump(hash).should == "---\none:\n  two: \n"
    end

    it "to a file descriptor" do
      hash = {:smtp => {:password => password}}
      StringIO.open do |io|
        described_class.dump(hash, io)
        io.rewind
        io.read.should eq("---\nsmtp:\n  password: #{enc_pass}\n")
      end
    end

    context "with passwords" do
      it "in clear text" do
        hash = {:smtp => {:password => password}}
        described_class.dump(hash).should eq("---\nsmtp:\n  password: #{enc_pass}\n")
      end

      it "encrypted" do
        hash = {:smtp => {:password => enc_pass}}
        described_class.dump(hash).should eq("---\nsmtp:\n  password: #{enc_pass}\n")
      end

      it "set to nil" do
        hash = {:smtp => {:password => nil}}
        described_class.dump(hash).should == "---\nsmtp:\n  password: \n"
      end

      it "set to blank" do
        hash = {:smtp => {:password => ""}}
        described_class.dump(hash).should == "---\nsmtp:\n  password: ''\n"
      end

      it "with missing key" do
        hash = {}
        described_class.dump(hash).should ==  "--- {}\n"
      end
    end
  end

  VMDB_CONFIG_STRINGS = <<-YAML
  one:
    two: two
    three:
      four: four
  YAML

  VMDB_CONFIG_SYMBOLIZED = <<-YAML
  :one:
    :two: two
    :three:
      four: four
  YAML

  VMDB_CONFIG_MIXED = <<-YAML
  :one:
    two: two
    :three:
      four: four
  YAML

  VMDB_CONFIG_NUMERICS = <<-YAML
  :1:
    2: two
  3:
    "4":
      5: five
  YAML

  VMDB_CONFIG_DIFFERENT_STRINGS = <<-YAML
  one:
    two: one
    three:
      four: one
  YAML

  VMDB_CONFIG_NUMERICS_SYMBOLIZED_HASH = { :"1" => {:"2" => "two"}, :"3" => {:"4" => {5 => "five"}}}
  VMDB_CONFIG_SYMBOLIZED_HASH = YAML.load(VMDB_CONFIG_SYMBOLIZED)

  shared_examples_for '.load' do
    it "blank should return empty hash" do
      expect(described_class.load(nil)).to eq({})
    end

    context "symbolizes" do
      it "two levels of stringed keys" do
        described_class.load(VMDB_CONFIG_STRINGS).should == VMDB_CONFIG_SYMBOLIZED_HASH
      end

      it "two levels of mixed keys" do
        described_class.load(VMDB_CONFIG_MIXED).should == VMDB_CONFIG_SYMBOLIZED_HASH
      end

      it "numerics" do
        described_class.load(VMDB_CONFIG_NUMERICS).should == VMDB_CONFIG_NUMERICS_SYMBOLIZED_HASH
      end

      it "all hashes for easy merging" do
        string_keyed_hash = described_class.load(VMDB_CONFIG_DIFFERENT_STRINGS)
        symbol_keyed_hash = described_class.load(VMDB_CONFIG_SYMBOLIZED)
        string_keyed_hash.merge(symbol_keyed_hash).should == VMDB_CONFIG_SYMBOLIZED_HASH
      end
    end

    context "will decrypt password field" do
      it "with encrypted" do
        hash = described_class.load("---\r\nsmtp:\r\n  password: #{enc_pass}\r\n")
        password = hash.fetch_path(:smtp, :password)
        password.should == password
      end

      it "with unencrypted" do
        hash = described_class.load("---\r\nsmtp:\r\n  password: #{password}\r\n")
        password = hash.fetch_path(:smtp, :password)
        password.should == password
      end

      it "with custom decryption function" do
        hash = described_class.load("---\r\nsmtp:\r\n password: bad\r\n") do |k, v, h|
          h[k] = "good" if v.present? && k.to_s.in?(%w(password))
        end
        expect(hash.fetch_path(:smtp, :password)).to eq("good")
      end
    end
  end

  context ".load" do
    context "in production" do
      before do
        Rails.stub(:env => ActiveSupport::StringInquirer.new("production"))
      end

      it "will not evaluate ERB" do
        ERB.should_not_receive(:new)
        described_class.load("---\r\nsmtp:\r\n  password: pass\r\n")
      end

      include_examples ".load"
    end

    context "in non-production" do
      it "will evaluate ERB" do
        ERB.should_receive(:new).and_call_original
        described_class.load("---\r\nsmtp:\r\n  password: pass\r\n")
      end

      include_examples ".load"
    end
  end

  context ".stringify" do
    subject { described_class.stringify(@config) }

    it "should not change original hash" do
      @config = {:one => {:two => :three}}

      subject.should == {"one" => {"two" => :three}}
      @config.should == {:one => {:two => :three}}
    end

    it "should handle two layers deep hash" do
      @config = {:one => {:two => {:three => :four}}}
      subject.should == {"one" => {"two" => {:three => :four}}}
    end
  end

  context ".symbolize" do
    subject { described_class.symbolize(@config) }

    it "should not change original hash" do
      @config = {"one"=> {"two"=> "three"}}

      subject.should == {:one => {:two => "three"}}
      @config.should == {"one"=> {"two"=> "three"}}
    end

    it "should handle two layers deep hash" do
      @config = {"one"=> {"two"=> {"three" => "four"}}}
      subject.should == {:one => {:two => {"three" => "four"}}}
    end
  end

  context ".validate!" do
    subject { described_class.validate!(@hash) }

    it "valid" do
      @hash = { "a" => { "b" => "c" } }
      subject.should == { :a => { :b => "c" } }
    end

    it "invalid" do
      @hash = { "a" => "b" }
      lambda { subject }.should raise_error
    end
  end

  it "should encrypt field" do
    expect(password_field_encrypted(password)).to be_encrypted(password)
  end

  it "should decrypt encrypted field" do
    expect(password_field_decrypted(enc_pass)).to eq(password)
  end

  private

  def password_field_encrypted(input)
    described_class.encrypt_password_fields(:smtp => {:password => input}).fetch_path(:smtp, :password)
  end

  def password_field_decrypted(input)
    described_class.decrypt_password_fields(:smtp => {:password => input}).fetch_path(:smtp, :password)
  end
end
