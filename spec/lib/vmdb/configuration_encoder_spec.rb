describe Vmdb::ConfigurationEncoder do
  let(:password) { "pa$$word" }
  let(:enc_pass) { MiqPassword.encrypt("pa$$word") }

  context ".dump" do
    it "stringifies keys" do
      hash = {:one => {:two => nil}}
      expect(described_class.dump(hash)).to eq("---\none:\n  two: \n")
    end

    it "to a file descriptor" do
      hash = {:smtp => {:password => password}}
      StringIO.open do |io|
        described_class.dump(hash, io)
        io.rewind
        expect(io.read).to eq("---\nsmtp:\n  password: #{enc_pass}\n")
      end
    end

    context "with passwords" do
      it "in clear text" do
        hash = {:smtp => {:password => password}}
        expect(described_class.dump(hash)).to eq("---\nsmtp:\n  password: #{enc_pass}\n")
      end

      it "encrypted" do
        hash = {:smtp => {:password => enc_pass}}
        expect(described_class.dump(hash)).to eq("---\nsmtp:\n  password: #{enc_pass}\n")
      end

      it "set to nil" do
        hash = {:smtp => {:password => nil}}
        expect(described_class.dump(hash)).to eq("---\nsmtp:\n  password: \n")
      end

      it "set to blank" do
        hash = {:smtp => {:password => ""}}
        expect(described_class.dump(hash)).to eq("---\nsmtp:\n  password: ''\n")
      end

      it "with missing key" do
        hash = {}
        expect(described_class.dump(hash)).to eq("--- {}\n")
      end
    end
  end

  let(:vmdb_config_strings) do
  <<-YAML
  one:
    two: two
    three:
      four: four
  YAML
  end


  let(:vmdb_config_symbolized) do
  <<-YAML
  :one:
    :two: two
    :three:
      four: four
  YAML
  end

  let(:vmdb_config_mixed) do
  <<-YAML
  :one:
    two: two
    :three:
      four: four
  YAML
  end

  let(:vmdb_config_numerics) do
  <<-YAML
  :1:
    2: two
  3:
    "4":
      5: five
  YAML
  end

  let(:vmdb_config_different_strings) do
  <<-YAML
  one:
    two: one
    three:
      four: one
  YAML
  end

  shared_examples_for '.load' do
    it "blank should return empty hash" do
      expect(described_class.load(nil)).to eq({})
    end

    context "symbolizes" do
      let(:vmdb_config_numerics_symbolized_hash) { {:"1" => {:"2" => "two"}, :"3" => {:"4" => {5 => "five"}}} }
      let(:vmdb_config_symbolized_hash) { YAML.load(vmdb_config_symbolized) }
      it "two levels of stringed keys" do
        expect(described_class.load(vmdb_config_strings)).to eq(vmdb_config_symbolized_hash)
      end

      it "two levels of mixed keys" do
        expect(described_class.load(vmdb_config_mixed)).to eq(vmdb_config_symbolized_hash)
      end

      it "numerics" do
        expect(described_class.load(vmdb_config_numerics)).to eq(vmdb_config_numerics_symbolized_hash)
      end

      it "all hashes for easy merging" do
        string_keyed_hash = described_class.load(vmdb_config_different_strings)
        symbol_keyed_hash = described_class.load(vmdb_config_symbolized)
        expect(string_keyed_hash.merge(symbol_keyed_hash)).to eq(vmdb_config_symbolized_hash)
      end
    end

    context "will decrypt password field" do
      it "with encrypted" do
        hash = described_class.load("---\r\nsmtp:\r\n  password: #{enc_pass}\r\n")
        password = hash.fetch_path(:smtp, :password)
        expect(password).to eq(password)
      end

      it "with unencrypted" do
        hash = described_class.load("---\r\nsmtp:\r\n  password: #{password}\r\n")
        password = hash.fetch_path(:smtp, :password)
        expect(password).to eq(password)
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
        allow(Rails).to receive_messages(:env => ActiveSupport::StringInquirer.new("production"))
      end

      it "will not evaluate ERB" do
        expect(ERB).not_to receive(:new)
        described_class.load("---\r\nsmtp:\r\n  password: pass\r\n")
      end

      include_examples ".load"
    end

    context "in non-production" do
      it "will evaluate ERB" do
        expect(ERB).to receive(:new).and_call_original
        described_class.load("---\r\nsmtp:\r\n  password: pass\r\n")
      end

      include_examples ".load"
    end
  end

  context ".symbolize!" do
    subject { described_class.symbolize!(@config) }

    it "should handle two layers deep hash" do
      @config = {"one" => {"two" => {"three" => "four"}}}
      expect(subject).to eq({:one => {:two => {"three" => "four"}}})
    end
  end

  context ".validate!" do
    subject { described_class.validate!(@hash) }

    it "valid" do
      @hash = {"a" => {"b" => "c"}}
      expect(subject).to eq({:a => {:b => "c"}})
    end

    it "invalid" do
      @hash = {"a" => "b"}
      expect { subject }.to raise_error(NoMethodError)
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
