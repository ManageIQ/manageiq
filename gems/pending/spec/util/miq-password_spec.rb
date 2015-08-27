# encoding: utf-8

require "spec_helper"
require 'util/miq-password'
require 'tempfile'

describe MiqPassword do
  before do
    @old_key_root = MiqPassword.key_root
    MiqPassword.key_root = File.join(GEMS_PENDING_ROOT, "spec/support")
  end

  after do
    # clear legacy keys and reset key_root changes (from specs or before block)
    MiqPassword.key_root = @old_key_root
  end

  MIQ_PASSWORD_CASES = [
    [
      "test",
      "v1:{KSOqhNiOWJbR0lz7v6PTJg==}",
      "v2:{DUb5th63TM+zIB6RhnTtVg==}",
      "xy0OjTrp19xhSxel52NMHw==",
    ], [
      "password",
      "v1:{Wv/+DC0XBqnIbRCIAI+CSQ==}",
      "v2:{gURYNPfZP3cu4+bw9pznMQ==}",
      "yaLmATw79aaeXOiu/297Hw==",
    ], [
      "ca$hcOw",
      "v1:{abvh5pIq6ptkKmBViuE0Yw==}",
      "v2:{Dq/TWvwTfQJDverzajStpA==}",
      "gS2DsdUxA3txmmKUc1vw0Q==",
    ], [
      "Tw45!&zQ",
      "v1:{jNSGHSwQsx36gSNEPD06jA==}",
      "v2:{27X41c6xqCCdVcw4LlQ1Qg==}",
      "5IbEEtGt4/G6nk6YB0Lz8Q==",
    ], [
      "`~!@\#$%^&*()_+-=[]{}\\|;:\"'<>,./?",
      "v1:{ziplwo+PA+gmKTNpJTRQtfRk+nPL2A2g3nnHdRRv86fBjyziiQ1V//g5u+dJ\nRyjl}",
      "v2:{zad43i0dQB+8z45ZYMVmpFcagbt40T0aFddhHlj6YtPgoOJ5N3uBYAp8WwuZQkar}",
      "JilJmiBufmyWjlAGLStE7+KEfwxCzZOS38ZSjH8JXEPCqdeQzWsXEddlqvzL\n0PpW",
    ], [
      "abc\t\n\vzabc",
      "v1:{t8hWgGHCP252inUcPgRK/A==}",
      "v2:{8iZNC6jMX5jtqSXejeLWBA==}",
      "HBfmhrLRwYVE3+DHM2fGuQ==",
    ], [
      "äèíôúñæþß",
      "v1:{gQ/3aP6FayuFJvbpyUkplJ8pnDJ+JI6ZKXAv5PqrRSk=}",
      "v2:{hPJ7QZBjjq9W2UydkaEvjnqM839QQ9FxJNOZT0ugOVk=}",
      "gI04s1uq9whj+UADjZak7m5mK7NywVAznAEf2dEIZJ4=",
    ], [
      # Japanese chars for good morning
      "\343\201\223\343\201\253\343\201\241\343\202\217",
      "v1:{eVFIO7k12XP4lh+ptRd9Sw==}",
      "v2:{efZNQ1asaxeZtemcvhxuMQ==}",
      "noF/l4uF2E6vMFdPENOlng==",
    ], [
      # Chinese for "password"
      "\345\257\206\347\240\201",
      "v1:{VsQ8kvHZ5/w3kshaYgIZZw==}",
      "v2:{tXN4DnLCrre7HVB+2zEbMg==}",
      "UPYMlD0o/uClT/k7XV7GLA==",
    ], [
      # Turkish characters known for encoding issues
      "şŞ",
      "v1:{2QALyJaer8Fvhsmx1z1dBQ==}",
      "v2:{IIdPQA3FbwJv/JmGapatwg==}",
      "Cgs5o1yzQZCgywLsSJnxfw=="
    ]
  ]

  MIQ_PASSWORD_CASES.each do |(pass, enc_v1, enc_v2, enc_v0)|
    context "with #{pass.inspect}" do
      before do
        MiqPassword.add_legacy_key("v0_key", :v0)
        MiqPassword.add_legacy_key("v1_key")
      end

      it(".encrypt")        { expect(MiqPassword.encrypt(pass)).to             be_encrypted(pass) }
      it(".decrypt v1")     { expect(MiqPassword.decrypt(enc_v1)).to           be_decrypted(pass) }
      it(".decrypt erb")    { expect(MiqPassword.decrypt(erberize(enc_v0))).to be_decrypted(pass) }
      it(".decrypt legacy") { expect(MiqPassword.decrypt(enc_v0)).to           be_decrypted(pass) }

      it("#decrypt")        { expect(MiqPassword.new.decrypt(enc_v2)).to           be_decrypted(pass) }
      it("#decrypt v1")     { expect(MiqPassword.new.decrypt(enc_v1)).to           be_decrypted(pass) }
      it("#decrypt v1 erb") { expect(MiqPassword.new.decrypt(erberize(enc_v1))).to be_decrypted(pass) }
      it("#decrypt erb")    { expect(MiqPassword.new.decrypt(erberize(enc_v0))).to be_decrypted(pass) }

      it(".encrypt(.decrypt)") { MiqPassword.decrypt(MiqPassword.encrypt(pass)).should         be_decrypted(pass) }
      it(".encStr/.decrypt")   { MiqPassword.decrypt(MiqPassword.new(pass).encStr).should      be_decrypted(pass) }
      it("#encrypt(#decrypt)") { MiqPassword.new.decrypt(MiqPassword.new.encrypt(pass)).should be_decrypted(pass) }

      it("#try_encrypt (non-encrypted)") { expect(MiqPassword.try_encrypt(pass)).to   be_encrypted(pass) }
      it("#try_encrypt erb")             { expect(MiqPassword.try_encrypt(erberize(enc_v0))).to eq(erberize(enc_v0)) }
      it("#try_encrypt DB_PASSWORD")     do
        enc = erberize(enc_v0, 'DB_PASSWORD')
        expect(MiqPassword.try_encrypt(enc)).to eq(enc)
      end
      it("#try_encrypt (encrypted v1)")  { expect(MiqPassword.try_encrypt(enc_v1)).to eq(enc_v1) }
      it("#try_encrypt (encrypted v2)")  { expect(MiqPassword.try_encrypt(enc_v2)).to eq(enc_v2) }

      it("#try_decrypt")                 { expect(MiqPassword.try_decrypt(enc_v2)).to           be_decrypted(pass) }
      it("#try_decrypt v1")              { expect(MiqPassword.try_decrypt(enc_v1)).to           be_decrypted(pass) }
      it("#try_decrypt v1 erb")          { expect(MiqPassword.try_decrypt(erberize(enc_v1))).to be_decrypted(pass) }
      it("#try_decrypt erb")             { expect(MiqPassword.try_decrypt(erberize(enc_v0))).to be_decrypted(pass) }
      it("#try_decrypt DB_PASSWORD")     { expect(MiqPassword.try_decrypt(erberize(enc_v0, "DB_PASSWORD"))).to be_decrypted(pass) }
      it("#try_decrypt (non-encrypted)") { expect(MiqPassword.try_decrypt(pass)).to             eq(pass) }

      it("#split[ver]")            { expect(MiqPassword.split(enc_v2).first).to           eq("2") }
      it("#split[ver] v1")         { expect(MiqPassword.split(enc_v1).first).to           eq("1") }
      it("#split[ver] erb")        { expect(MiqPassword.split(erberize(enc_v0)).first).to eq("0") }
      it("#split[ver] legacy")     { expect(MiqPassword.split(enc_v0).first).to           be_nil  }
      # bug: currently, split is not smart enough to detect legacy from non-encrypted strings
      it("#split (non-encrypted)") { expect(MiqPassword.split(pass).first).to             be_nil }

      it("#recrypt v2")     { expect(MiqPassword.new.recrypt(enc_v2)).to eq(enc_v2) }
      it("#recrypt v1")     { expect(MiqPassword.new.recrypt(enc_v1)).to eq(enc_v2) }
      it("#recrypt legacy") { expect(MiqPassword.new.recrypt(enc_v0)).to eq(enc_v2) }
    end
  end

  context ".encrypted?" do
    [
      "password",                         # Normal case
      "abcdefghijklmnopqrstuvwxyz123456", # 32 character password will not end in a "=" after Base64 encoding
    ].each do |pass|
      it "with #{pass.inspect}" do
        MiqPassword.encrypted?(pass).should                      be_false
        MiqPassword.encrypted?(MiqPassword.encrypt(pass)).should be_true
      end
    end

    it "should handle blanks" do
      expect(MiqPassword.encrypted?(nil)).to be_false
      expect(MiqPassword.encrypted?("")).to  be_false
    end
  end

  context "encrypting / decrypting blanks" do
    it "should not decrypt blanks" do
      expect(MiqPassword.decrypt(nil)).to     be_nil
      expect(MiqPassword.decrypt("")).to      be_empty
      expect(MiqPassword.decrypt("v1:{}")).to be_empty
      expect(MiqPassword.decrypt("v2:{}")).to be_empty

      expect(MiqPassword.try_decrypt(nil)).to     be_nil
      expect(MiqPassword.try_decrypt("")).to      be_empty
      expect(MiqPassword.try_decrypt("v1:{}")).to be_empty
      expect(MiqPassword.try_decrypt("v2:{}")).to be_empty
    end

    it "should not encrypt blanks" do
      expect(MiqPassword.encrypt(nil)).to be_nil
      expect(MiqPassword.encrypt("")).to  eq("v2:{}")

      expect(MiqPassword.try_encrypt(nil)).to be_nil
      expect(MiqPassword.try_encrypt("")).to  eq("v2:{}")
    end

    it "should not split blanks" do
      expect(MiqPassword.send(:split, "").first).to be_nil
    end

    it "should not recrypt blanks" do
      expect(MiqPassword.new.recrypt(nil)).to be_nil
      expect(MiqPassword.new.recrypt("")).to  be_empty
    end

    it "should fail on recrypt bad password" do
      expect { MiqPassword.new.recrypt("v2:{55555}") }.to raise_error(MiqPassword::MiqPasswordError)
    end

    it "should decrypt passwords with newlines" do
      expect(MiqPassword.decrypt("v2:{zad43i0dQB+8z45ZYMVmpFcagbt40T0aFddhHlj6YtPgoOJ5N3uBYAp8WwuZ\nQkar}")).to(
        eq("`~!@\#$%^&*()_+-=[]{}\\|;:\"'<>,./?")
      )
    end
  end

  context "with missing v1_key" do
    it "should report decent error when decryption with missing an encryption key" do
      expect {
        described_class.decrypt("v1:{KSOqhNiOWJbR0lz7v6PTJg==}")
      }.to raise_error(MiqPassword::MiqPasswordError, /can not decrypt.*v1_key/)
    end
  end

  context ".md5crypt" do
    it "with an unencrypted string" do
      expect(MiqPassword.md5crypt("password")).to eq("$1$miq$Ho9GNOzRsxMpJSsgwG/y01")
    end

    it "with an encrypted string" do
      MiqPassword.add_legacy_key("v1_key")
      expect(MiqPassword.md5crypt("v1:{Wv/+DC0XBqnIbRCIAI+CSQ==}")).to eq("$1$miq$Ho9GNOzRsxMpJSsgwG/y01")
    end
  end

  context ".sysprep_crypt" do
    it "with an unencrypted string" do
      expect(MiqPassword.sysprep_crypt("password")).to eq(
        "cABhAHMAcwB3AG8AcgBkAEEAZABtAGkAbgBpAHMAdAByAGEAdABvAHIAUABhAHMAcwB3AG8AcgBkAA==")
    end

    it "with an encrypted string" do
      MiqPassword.add_legacy_key("v1_key")
      expect(MiqPassword.sysprep_crypt("v1:{Wv/+DC0XBqnIbRCIAI+CSQ==}")).to eq(
        "cABhAHMAcwB3AG8AcgBkAEEAZABtAGkAbgBpAHMAdAByAGEAdABvAHIAUABhAHMAcwB3AG8AcgBkAA==")
    end
  end

  it ".sanitize_string" do
    MiqPassword.sanitize_string!("some :password: v1:{XAWlcAlViNwB} and another :password: v2:{egr+hObB}").should eq(
      "some :password: ******** and another :password: ********")
  end

  it ".sanitize_string!" do
    x = "some :password: v1:{XAWlcAlViNwBkJYjH35Rbw==} and another :password: v2:{egr+hObBeS+OC/hBDYnwgg==}"
    MiqPassword.sanitize_string!(x)
    expect(x).to eq("some :password: ******** and another :password: ********")
  end

  context ".key_root / .key_root=" do
    it "defaults key_root" do
      expect(ENV).to receive(:[]).with("KEY_ROOT").and_return("/certs")
      MiqPassword.key_root = nil
      expect(MiqPassword.key_root).to eq("/certs")
    end

    it "overrides key_root" do
      expect(ENV).not_to receive(:[])
      MiqPassword.key_root = "/abc"
      expect(MiqPassword.key_root).to eq("/abc")
    end

    it "clears all_keys" do
      v0 = MiqPassword.add_legacy_key("v0_key", :v0)
      v1 = MiqPassword.add_legacy_key("v1_key")
      v2 = MiqPassword.v2_key

      expect(MiqPassword.all_keys).to match_array([v2, v1, v0])

      MiqPassword.key_root = nil

      expect(Kernel).to receive(:warn).with(/v2_key doesn't exist/)
      expect(MiqPassword.all_keys).to be_empty
    end
  end

  describe ".clear_keys" do
    it "removes legacy keys from all_keys" do
      v0 = MiqPassword.add_legacy_key("v0_key", :v0)
      v1 = MiqPassword.add_legacy_key("v1_key")
      v2 = MiqPassword.v2_key

      expect(MiqPassword.all_keys).to match_array([v2, v1, v0])

      MiqPassword.clear_keys

      v2 = MiqPassword.v2_key
      expect(MiqPassword.all_keys).to match_array([v2])
    end
  end

  context ".v2_key" do
    it "when missing" do
      MiqPassword.key_root = "."
      expect(Kernel).to receive(:warn).with(/v2_key doesn't exist/)
      expect(MiqPassword.v2_key).not_to be
    end

    it "when present" do
      expect(MiqPassword.v2_key.to_s).to eq "5ysYUd3Qrjj7DDplmEJHmnrFBEPS887JwOQv0jFYq2g="
    end
  end

  describe ".add_legacy_key" do
    let(:v0_key)  { CryptString.new(nil, "AES-128-CBC", "9999999999999999", "5555555555555555") }
    let(:v1_key)  { MiqPassword.generate_symmetric }

    it "ignores bad key filename" do
      expect(MiqPassword.all_keys.size).to eq(1)
      MiqPassword.add_legacy_key("some_bogus_name")
      expect(MiqPassword.all_keys.size).to eq(1)
    end

    it "supports raw key" do
      expect(MiqPassword.all_keys.size).to eq(1)
      MiqPassword.add_legacy_key(v1_key)
      expect(MiqPassword.all_keys.size).to eq(2)
    end

    it "supports absolute path" do
      with_key do |dir, filename|
        MiqPassword.add_legacy_key("#{dir}/#{filename}")
      end
      expect(MiqPassword.all_keys.size).to eq(2)
    end

    it "supports root_key path (also warns if v2 key not found)" do
      with_key do |dir, filename|
        MiqPassword.key_root = dir
        # NOTE: no v2_key in this key_root
        expect(Kernel).to receive(:warn).with(/doesn't exist/)
        expect(MiqPassword.all_keys.size).to eq(0)
        MiqPassword.add_legacy_key(filename)
        expect(MiqPassword.all_keys.size).to eq(1)
      end
    end
  end

  private

  def with_key
    Dir.mktmpdir('test-key-root') do |d|
      MiqPassword.generate_symmetric.store("#{d}/my-key")
      yield d, "my-key"
    end
  end

  def erberize(password, passmethod = "MiqPassword")
    "<%= #{passmethod}.decrypt(\"#{password}\") %>"
  end
end
