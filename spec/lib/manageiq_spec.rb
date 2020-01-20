# These tests are done in a way that assume the Rails environment for ManageIQ are
# loaded, and that Rails is present to do the comparisons.  Tests that confirm
# that this works when rails is not present use a subprocess to run the
# `lib/manageiq.rb` file in isolation.
#
# If tests are not passing, check to see if the spec/spec_helper.rb is being
# loaded properly and initailizing the Vmdb::Application.

require 'manageiq'

RSpec.describe ManageIQ do
  def without_rails(rb_cmd)
    miq_lib_file = Rails.root.join("lib", "manageiq.rb")
    `#{Gem.ruby} -e 'require "#{miq_lib_file}"; print #{rb_cmd}'`
  end

  describe ".env" do
    before do
      ManageIQ.instance_variable_set(:@_env, nil)
    end

    it "equivalent to Rails.root when Rails is present" do
      expect(ManageIQ.env.to_s).to eq(Rails.env.to_s)
    end

    it "equivalent to Rails.root even when Rails is not present" do
      result = without_rails('ManageIQ.env.to_s')
      expect(result).to eq(Rails.env.to_s)
    end

    it "responds to .test?" do
      expect(ManageIQ.env.test?).to be true
      expect(without_rails('ManageIQ.env.test?.inspect')).to eq("true")
    end

    it "responds to .development?" do
      expect(ManageIQ.env.development?).to be false
      expect(without_rails('ManageIQ.env.development?.inspect')).to eq("false")
    end

    it "responds to .production?" do
      expect(ManageIQ.env.production?).to be false
      expect(without_rails('ManageIQ.env.production?.inspect')).to eq("false")
    end
  end

  describe ".root" do
    before do
      ManageIQ.instance_variable_set(:@_root, nil)
    end

    it "equivalent to Rails.root when Rails is present" do
      expect(ManageIQ.root.to_s).to eq(Rails.root.to_s)
    end

    it "equivalent to Rails.root even when Rails is not present" do
      result = without_rails('ManageIQ.root.to_s')
      expect(result).to eq(Rails.root.to_s)
    end

    it "responds to .join" do
      expected = Rails.root.join('config')
      expect(ManageIQ.root.join('config')).to eq(expected)
      # doing an .inspect here to confirm it is a Pathname
      expect(without_rails('ManageIQ.root.join("config").inspect')).to eq(expected.inspect)
    end
  end
end
