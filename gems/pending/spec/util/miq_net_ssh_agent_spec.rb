require 'util/miq_net_ssh_agent'

describe MiqNetSshAgent do
  before(:each) do
    if File.exist?("test_net_ssh_socket")
      system({"SSH_AGENT_PID" => @agent.pid}, "(ssh-agent -k) &> /dev/null") if @agent
      File.delete("test_net_ssh_socket")
    end
    example_ssh_key = <<-eos
-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEAasdvkMNteq7hjnqNE61ESnEHnaOtHxZffdsQ33R7BXcu9eCH
ncZadHmmfRZgMPQnHGX0NzboVKfdpdF40o+iGQKyy3wKqdgGnTAWqx/hxrsdsdgh
f/g7AABNjoWp1OiTX2Dn99SH9xPQtpdnwGlBmtPplV2wNcKouQwGbwb/u1EHHxnO
aSQk2tvKHRMgroLsyuM5ay7TrK5cip2QTMn9fieHIepH0qd8ETG+1Uf+XmZxhdMN
QsuiSbAAmuU9qwlXh6QOg1spJ97B/ZY6Ci4d5cdBCCtfjGDBm8CzbrfhYVNhGcNx
c3Y43ld6MJoE+hMuBrBSuZyBmf63AAMqJ8KeQwIDAQABAoIBAFMFXBoSWOy1V9z3
IkoY1ilBp5WKRvaPEMCgeCfZIjIG0Nmt5Knbkp2b3A8YWnGQlDHqdYz53t9RHaaU
KdCnJ9vUSYeeeNElMsCwMYVoZvA5Xpv9cw2YOeTrOzssX1VZv9WW1zHd0Srz9N3r
719MgpyK4dZACw6ODeD/gh8+OH5OAN9sVbIGniApHZENxJrZzL22qE2asf8vVfgu
9XNx3WhsdL6ktoeJWLKxTLwVP6xRK/ixvsayUFeMBC4E1+sBuz1z7p27kd8cEC5o
AEHSwF6nr+ix0JctbAYqPVFZi5zFH10WgxyF3asAiQPYrCrY9gT8OQSRDhhKyIXE
rHlLIfkCgYEA+RuY4vsqeU69APFXRCy9s/dcy8tS0Pslq/fq4KsdC4qRu39RjotN
/OXOtVMPRfjTiRHXi/0fvSfyMVgstCtfYpOcoz98tw2AX34AgAH6h57I29rVxk5q
OomgcauRYlmO9ge3429pvECL5EzBbRKwfwuMKHMNetLHdVMc7d165f0CgYEAzdGf
6VMnZkK66XP/RzMvwUwvdhy+vIUjXFMjotQXYcYcLZadiZET7riOSRyVRvlNg0va
CexWtX+0yOZOrXCvLzSpO8Z91VnkHbRhnpy4bvW/qcFpwIvYeaMgr5C1lBHCIvZS
wSojNrdjAbdQoqab9X7Mxj2ubYGxUSSg715wqT8CgYBaY20iT0imI6/o+6lSj3l2
J7eAKxKtybNtptOPF6RVq74dbqFFO77cmPZcTPspxJPdFKBFp18w36G9zeTKq0I9
HpqjkZHLShbej3XW/ODO/Qqc29bd0e4xt2aEWGC0cxKwqzRKTk7rg/A+sqsszK9G
KgZ9VuH5QyokpDfHB6pkcQKBgChsq8PgGTT0llGT/ue1HgQROqEwNCZC4BcaHT21
+oGxr4cktfx3Cjsw9IFXo9o0zQyksUaRrNYpJxDuazWVlFLpPPQIoF5vMWbELwhA
L9lbWzG0U1kGHpaFe73/5ioW8tJ7HvXhmNj+W+vSXXwUzT0CkqW9J61Kc9FEKHfb
TLVxAoGBAM8WKsTfEMxuv5pabGTo8BC1ruz4c5qLJGLGnH4kWJm5o6ippugFsOlK
rDUWive4uLSKi3Fsb2kPw6gHuRGerFN1CBpCENLib3xG5Bd4XhmKZMDxqU2bO0gd
sV1Tr/acrE0aWBkD9RYrR2/UwG1zfXuIJeufdWf8c0SY3X6J7jJN
-----END RSA PRIVATE KEY-----
    eos
    @agent = MiqNetSshAgent.new("test_net_ssh_socket", example_ssh_key)
  end

  after(:each) do
    system({"SSH_AGENT_PID" => @agent.pid}, "(ssh-agent -k) &> /dev/null")
    File.delete("test_net_ssh_socket")
  end

  it "should create agent" do
    expect(@agent.pid).to be_truthy
    expect(@agent.sock).to be_truthy
  end

  it "should preform command" do
    expect(Net::SSH).to receive(:start).with("localhost", "root", :paranoid => false, :forward_agent => true, :agent_socket_factory => Proc).and_return(true)
    @agent.perform_commands("localhost", "root", "ls")
  end

  it "should check connection to all hosts" do
    expect(Net::SSH).to receive(:start).with("localhost", "root", :paranoid => false, :forward_agent => true, :number_of_password_prompts=>0, :agent_socket_factory => Proc).and_return(true)
    @agent.check_connection("localhost", "root", ["1.0.0.1"], "-o 'StrictHostKeyChecking no'")
  end
end
