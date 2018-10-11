require "util/mount/miq_generic_mount_session"
require "util/miq_object_storage"

describe MiqFileStorage do
  def opts_for_nfs
    opts[:uri] = "nfs://example.com/share/path/to/file.txt"
  end

  def opts_for_smb
    opts[:uri]      = "smb://example.com/share/path/to/file.txt"
    opts[:username] = "user"
    opts[:password] = "pass"
  end

  def opts_for_glusterfs
    opts[:uri] = "glusterfs://example.com/share/path/to/file.txt"
  end

  def opts_for_ftp
    opts[:uri] = "ftp://example.com/share/path/to/file.txt"
  end

  def opts_for_swift_without_params
    opts[:uri]      = "swift://example.com/share/path/to/file.txt"
    opts[:username] = "user"
    opts[:password] = "pass"
  end

  def opts_for_swift_with_params
    opts[:uri]      = "swift://example.com/share/path/to/file.txt?region=foo"
    opts[:username] = "user"
    opts[:password] = "pass"
  end

  def opts_for_fakefs
    opts[:uri] = "foo://example.com/share/path/to/file.txt"
  end

  describe ".with_interface_class" do
    let(:opts) { {} }

    shared_examples ".with_interface_class implementation" do |class_name|
      let(:klass) { Object.const_get(class_name) }

      it "instanciates as #{class_name}" do
        interface_instance = described_class.with_interface_class(opts)
        expect(interface_instance.class).to eq(klass)
      end

      it "with a block, passes the instance, and returns the result" do
        instance_double = double(class_name.to_s)
        interface_block = ->(instance) { instance.add }

        expect(klass).to           receive(:new).and_return(instance_double)
        expect(instance_double).to receive(:add).and_return(:foo)

        expect(described_class.with_interface_class(opts, &interface_block)).to eq(:foo)
      end
    end

    context "with a nil uri" do
      it "returns nil" do
        expect(described_class.with_interface_class(opts)).to eq(nil)
      end
    end

    context "with an nfs:// uri" do
      before { opts_for_nfs }

      include_examples ".with_interface_class implementation", "MiqNfsSession"
    end

    context "with an smb:// uri" do
      before { opts_for_smb }

      include_examples ".with_interface_class implementation", "MiqSmbSession"
    end

    context "with an glusterfs:// uri" do
      before { opts_for_glusterfs }

      include_examples ".with_interface_class implementation", "MiqGlusterfsSession"
    end

    context "with an ftp:// uri" do
      before { opts_for_ftp }

      include_examples ".with_interface_class implementation", "MiqFtpStorage"
    end

    context "with an swift:// uri" do
      before { opts_for_swift_with_params }
       include_examples ".with_interface_class implementation", "MiqSwiftStorage"
    end
     context "with an swift:// uri and no query params" do
      before { opts_for_swift_without_params }
       include_examples ".with_interface_class implementation", "MiqSwiftStorage"
    end

    context "with an unknown uri scheme" do
      before { opts_for_fakefs }

      it "raises an MiqFileStorage::InvalidSchemeError" do
        valid_schemes = MiqFileStorage.storage_interface_classes.keys
        error_class   = MiqFileStorage::InvalidSchemeError
        error_message = "foo is not a valid MiqFileStorage uri scheme. Accepted schemes are #{valid_schemes}"

        expect { described_class.with_interface_class(opts) }.to raise_error(error_class).with_message(error_message)
      end
    end
  end

  ##### Interface Methods #####

  describe MiqFileStorage::Interface do
    shared_examples "an interface method" do |method_str, *args|
      subject      { method_str[0] == "#" ? described_class.new : described_class }
      let(:method) { method_str[1..-1] }

      it "raises NotImplementedError" do
        expected_error_message = "MiqFileStorage::Interface#{method_str} is not defined"
        expect { subject.send(method, *args) }.to raise_error(NotImplementedError, expected_error_message)
      end
    end

    shared_examples "upload functionality" do |method|
      let(:local_io)         { IO.pipe.first }
      let(:remote_file_path) { "baz/bar/foo" }
      let(:byte_count)       { 1234 }
      let(:args)             { [local_io, remote_file_path] }

      before do
        subject.instance_variable_set(:@position, 0)
        expect(subject).to receive(:initialize_upload_vars).with(*args).and_call_original
        expect(subject).to receive(:handle_io_block).with(no_args)
        expect(subject).to receive(:mkdir).with("baz/bar")
      end

      it "resets all vars" do
        subject.instance_variable_set(:@position, 10)
        subject.instance_variable_set(:@byte_count, 10)
        allow(subject).to receive(:upload_single)
        allow(subject).to receive(:upload_splits)

        subject.send(method, *args)

        expect(subject.instance_variable_get(:@position)).to be nil
        expect(subject.byte_count).to                        be nil
        expect(subject.remote_file_path).to                  be nil
        expect(subject.source_input).to                      be nil
        expect(subject.input_writer).to                      be nil
      end

      context "without a byte_count" do
        it "calls #upload_single" do
          expect(subject).to receive(:upload_single).with(remote_file_path).once
          expect(subject).to receive(:upload_splits).never
          subject.send(method, *args)
        end
      end

      context "with a byte_count" do
        let(:args) { [local_io, remote_file_path, byte_count] }

        it "calls #upload_splits" do
          expect(subject).to receive(:upload_splits).once
          expect(subject).to receive(:upload_single).never
          subject.send(method, *args)
        end
      end
    end

    describe "#add" do
      include_examples "upload functionality", :add
    end

    describe "#upload" do
      include_examples "upload functionality", :upload
    end

    describe "#mkdir" do
      it_behaves_like "an interface method", "#mkdir", "foo/bar/baz"
    end

    describe "#upload_single" do
      it_behaves_like "an interface method", "#upload_single", "path/to/file"
    end

    describe "#download_single" do
      it_behaves_like "an interface method", "#download_single", "nfs://1.2.3.4/foo", "foo"
    end

    describe ".new_with_opts" do
      it_behaves_like "an interface method", ".new_with_opts", {}
    end

    describe ".uri_scheme" do
      it "returns nil by default" do
        expect(described_class.uri_scheme).to eq(nil)
      end
    end

    describe "#upload_splits" do
      let(:file_name) { "path/to/file" }

      it "uploads multiple files of the byte count size" do
        subject.instance_variable_set(:@position, 0)
        subject.instance_variable_set(:@byte_count, 10)
        subject.instance_variable_set(:@remote_file_path, file_name)

        source_input_stub = double('@source_input')
        allow(subject).to           receive(:source_input).and_return(source_input_stub)
        allow(source_input_stub).to receive(:eof?).and_return(false, false, true)

        expect(subject).to receive(:upload_single).with("#{file_name}.00001")
        expect(subject).to receive(:upload_single).with("#{file_name}.00002")

        subject.send(:upload_splits)
      end
    end

    describe "#initialize_upload_vars (private)" do
      let(:local_io)       { File.open(local_io_str) }
      let(:local_io_str)   { Tempfile.new.path }
      let(:remote_path)    { "/path/to/remote_file" }
      let(:byte_count_int) { 1024 }
      let(:byte_count_str) { "5M" }
      let(:upload_args)    { [] }
      let(:pty_master)     { double("pty_master") }
      let(:pty_slave)      { double("pty_slave") }

      before do
        subject.send(:initialize_upload_vars, *upload_args)
      end
      after { FileUtils.rm_rf local_io_str }

      context "with byte_count passed" do
        let(:upload_args) { [remote_path, byte_count_int] }

        it "assigns @byte_count to the parse value" do
          expect(subject.byte_count).to eq(1024)
        end

        it "assigns @remote_file_path" do
          expect(subject.remote_file_path).to eq("/path/to/remote_file")
        end

        it "assigns @source_input nil (set in #handle_io_block)" do
          expect(subject.source_input).to eq(nil)
        end

        it "assigns @input_writer nil (set in #handle_io_block)" do
          expect(subject.input_writer).to eq(nil)
        end

        context "with local_io as an IO object passed" do
          let(:upload_args) { [local_io, remote_path, byte_count_str] }

          it "assigns @byte_count to the parse value" do
            expect(subject.byte_count).to eq(5.megabytes)
          end

          it "assigns @source_input to the passed value" do
            expect(subject.source_input).to eq(local_io)
          end

          it "@input_writer is nil" do
            expect(subject.input_writer).to eq(nil)
          end
        end

        context "with local_io passed" do
          let(:upload_args) { [local_io_str, remote_path, byte_count_str] }

          it "assigns @byte_count to the parse value" do
            expect(subject.byte_count).to eq(5.megabytes)
          end

          it "assigns @source_input to the passed value" do
            expect(File.identical?(subject.source_input, local_io_str)).to be true
          end

          it "@input_writer is nil" do
            expect(subject.input_writer).to eq(nil)
          end
        end
      end

      context "without byte_count passed" do
        let(:upload_args) { [remote_path] }

        it "@byte_count is nil" do
          expect(subject.byte_count).to eq(nil)
        end

        it "assigns @remote_file_path" do
          expect(subject.remote_file_path).to eq("/path/to/remote_file")
        end

        it "assigns @source_input nil (set in #handle_io_block)" do
          expect(subject.source_input).to eq(nil)
        end

        it "assigns @input_writer nil (set in #handle_io_block)" do
          expect(subject.input_writer).to eq(nil)
        end

        context "with local_io passed" do
          let(:upload_args) { [local_io, remote_path] }

          it "assigns @byte_count to the parse value" do
            expect(subject.byte_count).to eq(nil)
          end

          it "assigns @source_input to the passed value" do
            expect(subject.source_input).to eq(local_io)
          end

          it "@input_writer is nil" do
            expect(subject.input_writer).to eq(nil)
          end
        end

        context "with local_io passed" do
          let(:upload_args) { [local_io_str, remote_path] }

          it "assigns @byte_count to the parse value" do
            expect(subject.byte_count).to eq(nil)
          end

          it "assigns @source_input to the passed value" do
            expect(File.identical?(subject.source_input, local_io_str)).to be true
          end

          it "@input_writer is nil" do
            expect(subject.input_writer).to eq(nil)
          end
        end
      end
    end

    describe "#parse_byte_value (private)" do
      it "returns 2 for '2'" do
        expect(subject.send(:parse_byte_value, "2")).to eq(2)
      end

      it "returns 2048 for '2k'" do
        expect(subject.send(:parse_byte_value, "2k")).to eq(2048)
      end

      it "returns 1536 for '1.5K'" do
        expect(subject.send(:parse_byte_value, "1.5K")).to eq(1536)
      end

      it "returns 3145728 for '3M'" do
        expect(subject.send(:parse_byte_value, "3M")).to eq(3.megabytes)
      end

      it "returns 1073741824 for '1g'" do
        expect(subject.send(:parse_byte_value, "1g")).to eq(1.gigabyte)
      end

      it "returns nil for nil" do
        expect(subject.send(:parse_byte_value, nil)).to eq(nil)
      end

      it "returns 100 for 100 (integer)" do
        expect(subject.send(:parse_byte_value, 100)).to eq(100)
      end
    end

    describe "#handle_io_block" do
      let(:input_writer) { Tempfile.new }
      let(:source_input) { Tempfile.new }

      after do
        input_writer.unlink
        source_input.unlink
      end

      context "with a block" do
        let(:block) { ->(_input_writer) { sleep 0.1 } }

        before do
          expect(File).to receive(:mkfifo)
          expect(File).to receive(:open).and_return(source_input, input_writer)
        end

        it "creates a thread for handling the input IO" do
          thread_count = Thread.list.count
          thread       = subject.send(:handle_io_block, &block)
          expect(Thread.list.count).to eq(thread_count + 1)
          thread.join
        end

        it "closes input_writer" do
          expect(input_writer.closed?).to eq(false)
          thread = subject.send(:handle_io_block, &block)
          thread.join
          expect(input_writer.closed?).to eq(true)
        end
      end

      context "without a block" do
        it "doesn't create a new thread for IO generation" do
          thread_count = Thread.list.count
          nil_result   = subject.send(:handle_io_block)

          expect(nil_result).to        be(nil)
          expect(Thread.list.count).to eq(thread_count)
        end
      end

      context "with a block that causes an error" do
        let(:err_block) { ->(_input_writer) { raise "err-mah-gerd" } }

        before do
          expect(File).to receive(:mkfifo)
          expect(File).to receive(:open).and_return(source_input, input_writer)
        end

        it "does not hang the process and closes the writer" do
          expect(input_writer.closed?).to eq(false)
          thread = subject.send(:handle_io_block, &err_block)
          expect { thread.join }.to raise_error StandardError
          expect(input_writer.closed?).to eq(true)
        end
      end
    end
  end
end
