module PasswordMixin
  extend ActiveSupport::Concern

  included do
    encrypt_column(:password) if self.columns_hash.include?("password")
  end

  module ClassMethods
    def encrypt_column(column)
      # Given a column of "password", create 4 instance methods:
      #   password            : Get the password in plain text
      #   password=           : Set the password in plain text
      #   password_encrypted  : Get the password in cryptext
      #   password_encrypted= : Set the password in cryptext

      mod = generated_methods_for_password_mixin

      mod.send(:define_method, column) do
        val = self.send("#{column}_encrypted")
        val.blank? ? val : MiqPassword.decrypt(val)
      end

      mod.send(:define_method, "#{column}=") do |val|
        val = MiqPassword.try_encrypt(val) unless val.blank?
        self.send("#{column}_encrypted=", val)
      end

      mod.send(:define_method, "#{column}_encrypted") do
        read_attribute(column)
      end

      mod.send(:define_method, "#{column}_encrypted=") do |val|
        write_attribute(column, val)
      end
    end

    private

    def generated_methods_for_password_mixin
      @generated_methods_for_password_mixin ||= begin
        mod = const_set(:GeneratedMethodsForPasswordMixin, Module.new)
        include mod
        mod
      end
    end
  end
end
