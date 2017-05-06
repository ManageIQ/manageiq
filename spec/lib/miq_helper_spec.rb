# This tests are done in a way that assume the Rails environment for Miq are
# loaded, and that Rails is present to do the comparisons.  Tests that confirm
# that this works when rails is not present us a subprocess to run the
# `lib/miq.rb` file in isolation.
#
# If tests are not passing, check to see if the spec/spec_helper.rb is being
# loaded properly and initailizing the Vmdb::Application.

require 'miq_helper'

describe Miq do
  def without_rails(rb_cmd)
    miq_lib_file = Rails.root.join("lib", "miq_helper.rb")
    `#{Gem.ruby} -e 'require "#{miq_lib_file}"; print #{rb_cmd}'`
  end

  describe "::env" do
    before(:each) do
      Miq.instance_variable_set(:@_env, nil)
    end

    it "equivalent to Rails.root when Rails is present" do
      expect(Miq.env.to_s).to eq(Rails.env.to_s)
    end

    it "equivalent to Rails.root even when Rails is not present" do
      result = without_rails('Miq.env.to_s')
      expect(result).to eq(Rails.env.to_s)
    end

    it "responds to .test?" do
      expect(Miq.env.test?).to be true
      expect(without_rails('Miq.env.test?.inspect')).to eq("true")
    end

    it "responds to .development?" do
      expect(Miq.env.development?).to be false
      expect(without_rails('Miq.env.development?.inspect')).to eq("false")
    end

    it "responds to .production?" do
      expect(Miq.env.production?).to be false
      expect(without_rails('Miq.env.production?.inspect')).to eq("false")
    end
  end

  describe "::root" do
    before(:each) do
      Miq.instance_variable_set(:@_root, nil)
    end

    it "equivalent to Rails.root when Rails is present" do
      expect(Miq.root.to_s).to eq(Rails.root.to_s)
    end

    it "equivalent to Rails.root even when Rails is not present" do
      result = without_rails('Miq.root.to_s')
      expect(result).to eq(Rails.root.to_s)
    end

    it "responds to .join" do
      expected = Rails.root.join('config')
      expect(Miq.root.join('config')).to eq(expected)
      # doing an .inspect here to confirm it is a Pathname
      expect(without_rails('Miq.root.join("config").inspect')).to eq(expected.inspect)
    end
  end
end
