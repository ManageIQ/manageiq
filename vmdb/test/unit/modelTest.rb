require File.expand_path(File.join(File.dirname(__FILE__), '..', 'test_helper'))

if false
  require "selenium"

  class ModelTest < ActiveSupport::TestCase

    #Change these for your appliance IP and desired test names
    APP_ADDR = "https://192.168.217.130/"
    VM_NAME = "Bob"
    VM_USER = "Joe"
    VM_GROUP = "Steve"
    VM_GUESTAPP = "Solitaire"
    VM_OSNAME = "WinXP"
    VM_OSTYPE = "Windows"
    VM_PATCH = "testpatch"
    HOST_NAME = "Mike"
    HOST_IP = "127.0.0.1"
    REPO_NAME = "Justin"


    #Creates a host and give it an IPaddress
    def self.createHost(name, ip)
      myHost = Host.new(:name => name, :vmm_vendor => 'Microsoft', :hostname => name, :ipaddress => ip)
      myHost.save!
      return myHost
    end

    #Creates a repository and links it to a storage
    def self.createRepository(name, storageid)
      myRepo = Repository.new(:name => name, :storage_id => storageid)
      myRepo.save!
      return myRepo
    end

    #Makes a VM for testing with the bare minimums for creation
    def self.createVM(name)
      myVm = Vm.new(:name => name, :location => name, :vendor => 'VMware', :host_id => '66')
      myVm.save!
      return myVm
    end

    #Creates a user to be used for a VM later
    def self.createAccntUser(accntname)
      myAccnt = Account.new(:name => accntname, :accttype => 'user')
      myAccnt.save!
      return myAccnt
    end

    #Creates a group to be used for a VM later
    def self.createAccntGroup(accntname)
      myAccnt = Account.new(:name => accntname, :accttype => 'group')
      myAccnt.save!
      return myAccnt
    end

    #Creates an application to be used for a VM later
    def self.createGuestApp(ganame)
      myApp = GuestApplication.new(:name => ganame)
      myApp.save!
      return myApp
    end

    #Adds the input account to the input VM account list
    def self.addAccntToVM(vm, account)
      vm.users << account
      vm.save!
    end

    #Adds the input guest application to the input VM application list
    def self.addGuestAppToVM(vm, guestApp)
      vm.guest_applications << guestApp
      vm.save!
    end

    #Creates a win32service to be used for a VM later
    def self.createService(sname)
      myService = SystemService.new(:name => sname, :typename => 'win32_service', :svc_type => 16)
      myService.save!
      return myService
    end

    #Creates an Operating system to be used for a VM later
    def self.createOS(osname, ostype)
      myOS = OperatingSystem.new(:name => osname, :product_name => ostype)
      myOS.save!
      return myOS
    end

    #Creates a patch for use with a VM
    def self.createPatch(pname)
      myPatch = Patch.new(:name => pname)
      myPatch.save!
      return myPatch
    end

    #Adds a patch to a specified VM
    def self.addPatchToVM(vm, pname)
      vm.patches << pname
      vm.save!
    end

    #Adds the given OS to the given VM
    def self.addOSToVM(vm, osname)
      vm.operating_system = osname
      vm.save!
    end

    #Adds the given service to the given VM
    def self.addServiceToVM(vm, service)
      vm.win32_services << service
      vm.save!
    end

    def setup
      @verification_errors = []
      if $selenium
        @selenium = $selenium
      else
        #Starts firefox or ie
        @selenium = Selenium::SeleneseInterpreter.new("localhost", 4444, "*firefox", APP_ADDR, 10000);
        #Note, IE will not work for me (Erik) while on the VPN
        #      @selenium = Selenium::SeleneseInterpreter.new("localhost", 4444, "*iexplore", APP_ADDR, 10000);
        @selenium.start
      end
      @selenium.set_context("info")
    end

    #This test creates a VM, gives it a specific name, OS, users, patches,
    #and makes sure that everything appears in the database as it should, and also
    #on the pages themselves.  It also looks in the report editor to see if the
    #reports are being updated correctly.  Currently, it is only looking for the
    #text, since it is unique enough (aka Bob, Steve, etc), but eventually will
    #need to be upgraded to handle a more general scheme, and will need to be based
    #on rows, so that I can verify that x patch matches up with y VM
    def test_createVM
      puts "Creating a VM"
      #Creates a VM with a name of Bob
      bob = ModelTest.createVM(VM_NAME)
      #Stores the id of bob for use in the appliance URLs
      x = bob.id

      #Logs into the appliance from the browser, and goes to the created VM
      @selenium.open "http://192.168.217.130"
      @selenium.type "user_name", "admin"
      @selenium.type "user_password", "smartvm"
      @selenium.click "login"
      @selenium.wait_for_page_to_load "30000"
      @selenium.open "http://192.168.217.130/vm/show/" + x.to_s
      #Tests to see if Bob is in on the page somewhere
      assert @selenium.is_text_present(VM_NAME)

      #Make sure the name bob has been created in the database
      assert bob.name == VM_NAME

      #Create an account user on the VM bob and make sure it is recognized
      #in the database
      joe = ModelTest.createAccntUser(VM_USER)
      ModelTest.addAccntToVM(bob, joe)
      assert joe.name == VM_USER
      assert_not_nil bob.accounts.find_by_name(VM_USER)

      #Make sure that the user Joe gets recognized on the VM's user page
      @selenium.open "http://192.168.217.130/vm/users/" + x.to_s
      assert @selenium.is_text_present(VM_USER)

      #Create an account group on the VM bob and make sure it is
      #recognized in the database
      steve = ModelTest.createAccntGroup(VM_GROUP)
      ModelTest.addAccntToVM(bob, steve)
      assert_not_nil bob.accounts.find_by_name(VM_GROUP)

      #Make sure that the group Steve gets recognized on the VM's group page
      @selenium.open "http://192.168.217.130/vm/groups/" + x.to_s
      assert @selenium.is_text_present(VM_GROUP)

      #Creates a guest application and adds it to the VM bob.
      #Makes sure it gets recognized in the database
      solitaire = ModelTest.createGuestApp(VM_GUESTAPP)
      ModelTest.addGuestAppToVM(bob, solitaire)
      assert_not_nil bob.guest_applications.find_by_name(VM_GUESTAPP)

      #Opens the application page of the VM bob and makes sure the guest app
      #is present
      @selenium.open "http://192.168.217.130/vm/guest_applications/" + x.to_s
      assert @selenium.is_text_present(VM_GUESTAPP)

      #Makes a Win32 service and makes sure it is in the database and on the
      #VM's page
      sdsr = ModelTest.createService("Suck Down System Resources")
      ModelTest.addServiceToVM(bob, sdsr)
      assert_not_nil bob.win32_services.find_by_name("Suck Down System Resources")
      @selenium.open "http://192.168.217.130/vm/win32services/" + x.to_s
      assert @selenium.is_text_present('Suck Down')

      #Creates an OS for the VM and makes sure it is in the database and present
      #on the VM's page
      windows = ModelTest.createOS(VM_OSTYPE, VM_OSNAME)
      ModelTest.addOSToVM(bob, windows)
      assert_not_nil bob.operating_system.name
      @selenium.open "http://192.168.217.130/vm/show/" + x.to_s + "?display=os_info"
      assert @selenium.is_text_present(VM_OSNAME)

      #Make sure that the VM bob is in the report "VMs: Date Brought Under
      #Management"
      @selenium.open "/report/show"
      @selenium.click "report_9_link"

      #This line is so that the page waits for the report to load before asserting
      #if the text is present or not.  A simple assert text will prove false, as
      #the report doesn't have time to load, and a "wait for x amount of seconds"
      #will cause a timeout
      assert !60.times{ break if (@selenium.is_text_present(bob.name) rescue false); sleep 1 }

      #Makes sure that the OS name appears in the report "VMs: OS Version"
      @selenium.click "report_7_link"
      assert !60.times{ break if (@selenium.is_text_present(windows.name) rescue false); sleep 1 }

      #Creates a patch for the VM, makes sure it appears in the database and on
      #the VM patch page
      testpatch = ModelTest.createPatch(VM_PATCH)
      ModelTest.addPatchToVM(bob, testpatch)
      assert_not_nil bob.patches
      @selenium.open "http://192.168.217.130/vm/patches/" + x.to_s
      assert @selenium.is_text_present(testpatch.name)

      #Makes sure that the patch is shown in the report "Patches: Patches by VM"
      @selenium.open "/report/show"
      @selenium.click "report_20_link"
      assert !60.times{ break if (@selenium.is_text_present(testpatch.name) rescue false); sleep 1 }
    end

    #This test simply creates a host and makes sure that it appears in the database
    #Note this test is not finished
    def test_createHost
      puts "Creating a Host"
      hosttest = ModelTest.createHost(HOST_NAME, HOST_IP)
      assert_not_nil hosttest.name


    end

    #This test simply creates a Repository and makes sure that it appears in the
    #database.  Note this test is not finished
    def test_createRepository
      puts "Creating a Repository"
      x = Storage.find(:first).id
      repotest = ModelTest.createRepository(REPO_NAME, x)
      assert_not_nil repotest.name
    end

    #This test will delete the VM created earlier, and assert that it does not
    #exist in the database anymore or on the page
    def test_deleteVM
      puts "Deleting a VM"
      x = Vm.find_by_name(VM_NAME)
      #The database needs to be raked for the destroy command to execute properly
      x.destroy
      #Make sure it's gone from the page and the database
      @selenium.open "http://192.168.217.130"
      @selenium.type "user_name", "admin"
      @selenium.type "user_password", "smartvm"
      @selenium.click "login"
      @selenium.wait_for_page_to_load "30000"
      @selenium.open "http://192.168.217.130/vm/"
      assert !@selenium.is_text_present(VM_NAME)
      assert_nil Vm.find_by_name(VM_NAME)
    end

    #This test will delete the Host previously created and make sure that it is
    #gone from the database and the page
    def test_deleteHost
      puts "Deleting a Host"
      x = Host.find_by_name(HOST_NAME)
      x.destroy
      #Make sure it's gone from the page and the database
      @selenium.open "http://192.168.217.130"
      @selenium.type "user_name", "admin"
      @selenium.type "user_password", "smartvm"
      @selenium.click "login"
      @selenium.wait_for_page_to_load "30000"
      @selenium.open "http://192.168.217.130/host/"
      assert !@selenium.is_text_present(HOST_NAME)
      assert_nil Host.find_by_name(HOST_NAME)
    end

    #This test will delete the Repository previously created and make sure that
    #it is gone from the database and the page
    def test_deleteRepository
      puts "Deleting a Repository"
      x = Repository.find_by_name(REPO_NAME)
      x.destroy
      #Make sure it's gone from the page and the database
      @selenium.open "http://192.168.217.130"
      @selenium.type "user_name", "admin"
      @selenium.type "user_password", "smartvm"
      @selenium.click "login"
      @selenium.wait_for_page_to_load "30000"
      @selenium.open "http://192.168.217.130/repository/"
      assert !@selenium.is_text_present(REPO_NAME)
      assert_nil Repository.find_by_name(REPO_NAME)
    end

    #Closes selenium
    def teardown
      @selenium.stop unless $selenium
      assert_equal [], @verification_errors
    end


  end

end
