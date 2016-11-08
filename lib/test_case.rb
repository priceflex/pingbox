# Locks so only one instance runs at at time
exit unless DATA.flock(File::LOCK_NB | File::LOCK_EX)

$pingbox_root = "#{File.dirname(__FILE__)}/.." unless $pingbox_root
$config_dir = "#{$pingbox_root}/config"

require 'rubygems'
require 'pry'
require 'fileutils'
require 'ap'
require 'net/http'
require 'uri'
require 'json'
require 'xmlsimple'
require 'socket'
require "#{$pingbox_root}/lib/ping/ping"
require "#{$pingbox_root}/lib/pingbox/cached_ping"
require "#{$pingbox_root}/lib/pingbox/save_to_yaml_file"
require "#{$pingbox_root}/lib/pingbox/save_to_json"
require "#{$pingbox_root}/lib/pingbox/send_to_s3"
require "#{$pingbox_root}/lib/pingbox/event_logger"

# order of events and instance variables within: 
   # initialize
      # @amazon_s3 => SendToS3.new
      # @clear_ping_data => var sent from user's browser

   # get_env => determines whether this is dev/production
      # @env => production/development environment
      # @url => ping.techrockstars.com/192.168.0.124:3000 (production / dev)
      # create_env_file (if it doesn't exist - default to production)

   # load_machine_data => read machine data from machine.yml
      # create_machine_file (if doesn't exist)

   # run => perform monitor/ping tasks
     # get_work_from_server
        # @ping_hosts
        # @ping_times
        # @test_case_id
        # @clear_ping_data
        # @nmap_address
        # create_test_case_file

     # report_to_monitor
        # private_ip
        # public_ip
        # transmit_monitor
     # start_work
        # ping_all_hosts
        # send files to s3!

class TestCase

  def initialize
    @amazon_s3 = SendToS3.new
    @clear_ping_data = false
    get_env
    load_machine_data
  end

  def run
    get_work_from_server
    report_to_monitor
    start_work
  end

  def get_env
    @env = Ping.env?
    if @env == :production
      @url = "http://ping.techrockstars.com" 
    elsif @env == :development
      @url = "http://techrockstars.com:3000" 
    else 
      @env = :production
      create_env_file(@env.to_s) # production by default
    end
    puts "Using #{@env.to_s} environment."
  end

  def create_env_file(env)
    File.open("#{$pingbox_root}/config/env.yml", "w+") { |f| f.write({ ping_box_env: env }.to_yaml) }
  end

  def load_machine_data 
    create_machine_file unless File.exist?("#{$pingbox_root}/config/machine.yml")
    @machine_data = YAML.load(File.open("#{$pingbox_root}/config/machine.yml"))
  end

  def create_machine_file
    # essentially creates a new machine in the database by resetting its "machine_id"
    # to the current time.to_i

    puts "Machine.yml not found.  Making a new one and reassigning this machine's ID on the server."

    machine_data = { :machine_id => Time.now.to_i }   
    url = "#{@url}/machine"
    #@file_data = PingData.new.load_file.to_json

    postData = Net::HTTP.post_form(URI.parse(url), { system_id: machine_data[:machine_id] })

    ap postData

    # Once a 200 is received then remove records from file
    if postData.code == "200"
      PingData.new.clear_file
      File.open("#{$pingbox_root}/config/machine.yml", "w+") {|f| f.write(machine_data.to_yaml) }

      # clear out all ping.yml and test_case.yml file
        # do these get recreated on the next go-around? -EW
      %w{ping.yml test_case.yml env.yml public_ip.yml}.each do |file|
        puts "Removed #{file}" if FileUtils.rm("#{$pingbox_root}/config/#{file}") rescue puts "Can't remove #{file}. Can't find it."
      end

      # why does it need to exit the process after creating this file? -EW
      #exit
    end
  end

  def get_work_from_server
    # Send @machine_data[:machine_id] to glitch.techrockstars.com/machine/:machine_id
    # Reply will be the work that it should be preformed
    # "ips" => ["4.2.2.1", "192.168.1.1", "google.com"],
    # "times_per_minute" => "6", # 20max per ip. In this case 6 because of a 3 second wait for non responsiveness


    begin
      print "Requesting test case information from server... "
      url = "#{@url}/machine/#{@machine_data[:machine_id]}/test_cases.xml"
      xml_data = Net::HTTP.get_response(URI.parse(url)).body
      test_case_data = XmlSimple.xml_in(xml_data) 

      if test_case_data['id']
        timeout_in_seconds = 3

        @name = test_case_data['name'][0]
        @trsla_url = test_case_data['trsla-url'][0]
        @ping_hosts = test_case_data["ping-hosts-addresses"][0].split("\n")
        @ping_times = (60 / timeout_in_seconds) / @ping_hosts.size
        @test_case_id = test_case_data["id"][0]["content"].to_i
        @clear_ping_data = to_boolean(test_case_data["reset-ping-data"][0]["content"])
        @nmap_address = test_case_data["nmap-address"][0]
        create_test_case_file

        puts "done."
      else
        print "\nThe server was unable to provide test case information.  "
        puts "Please check to make sure there has been a test case created for this machine."
        puts "Machine ID: #{@machine_data[:machine_id]}"
      end
    rescue
      puts "\nNo reply from server, using test_case.yml"

      machine_data = if File.exist?("#{$pingbox_root}/config/test_case.yml")
        YAML.load(File.open("#{$pingbox_root}/config/test_case.yml"))
      else
        create_test_case_file
        nil
      end

      if machine_data
        @ping_hosts = machine_data[:ping_hosts]
        @ping_times = machine_data[:ping_times]
        @test_case_id = machine_data[:test_case_id]
        #@nmap_address = machine_data[:nmap_address]
      end
    end
  end

  def report_to_monitor
    # perhaps the monitor should be in it's own file too?
    puts "Gathering monitor data"
    @ifconfig_dump = `/sbin/ifconfig`
    @ps_aux_dump = `/bin/ps aux`
    @du_sh_dump = `/usr/bin/du -sh /home/pingbox/pingbox/data`
    @commit_history = `cd /home/pingbox/pingbox && git -c /home/pingbox/pingbox rev-list HEAD`

    private_ip
    public_ip
    detect_version
    transmit_monitor
  rescue Exception => e
    EventLogger.process_exception("Monitor data fetching", e)
  end

  def detect_version
    commits = @commit_history.split("\n")
    @version = commits.first
  end

  def private_ip
    @private_ip = Socket.ip_address_list.detect{ |intf| intf.ipv4_private? }.ip_address 
  rescue Exception => e
    puts "Error getting private IP: #{e.message}"
    e.backtrace.each { |m| puts "\tfrom #{m}" }
  end

  def public_ip
    if File.exist?("#{$pingbox_root}/config/public_ip.yml") 
      @public_ip = YAML.load(File.open("#{$pingbox_root}/config/public_ip.yml"))[:public_ip]
    else 
      url = "http://ip.techrockstars.com/?format=xml"
      begin
        xml_data = Net::HTTP.get_response(URI.parse(url)).body
        data = XmlSimple.xml_in(xml_data)
        public_ip = { :public_ip => data["ipaddress"][0] }
        @public_ip = data["ipaddress"][0]

        File.open("#{$pingbox_root}/config/public_ip.yml", "w+") {|f| f.write(public_ip.to_yaml) }
      rescue
        @public_ip = "Not available"
      end
    end 
  end

  def transmit_monitor 
    data = {
      :_method        => :put,
      :ifconfig_dump  => @ifconfig_dump,
      :ps_aux_dump    => @ps_aux_dump,
      :du_sh_dump     => @du_sh_dump,
      :private_ip     => @private_ip,
      :public_ip      => @public_ip,
      :nmap_dump      => @nmap_dump,
      :version        => @version
    }

    print "Transmitting monitor... "
    postData = Net::HTTP.post_form(URI.parse("#{@url}/machine/#{@machine_data[:machine_id]}"), data)

    if postData.code == "200" 
      puts "200 OK."
    else
      puts "failed. Status code from server: #{postData.code}"
    end

  rescue Exception => e
    puts "\nError transmitting monitor: #{e.message}"
  end

  def create_test_case_file
    test_case = {
      :name         => @name,
      :trsla_url    => @trsla_url,
      :ping_hosts   => @ping_hosts,
      :ping_times   => @ping_times,
      :test_case_id => @test_case_id,
      :nmap_address => @nmap_address
    }

    File.open("#{$pingbox_root}/config/test_case.yml", "w+") { |f| f.write(test_case.to_yaml) }
  end

  def start_work
    if @ping_hosts
      @ping_data = PingData.new
      minute = Time.now.min

      puts "Hosts: #{@ping_hosts.join(", ")}"
      puts "Pinging..."

      while Time.now.min == minute && Time.now.sec < 50
        ping_all_hosts
      end

      cached_pings = CachedPing.new(@ping_data)
      # SaveToYmlFile.new("cached_pings.yml", cached_pings.calculate_pings)
      SaveToJson.new("pings.json", cached_pings.calculate_pings)
    else
      puts "Nothing to ping. :'("
    end
  end

  def ping_all_hosts
    ping = Ping.new
    threads = []

    @ping_hosts.each do |ip|
      ping.count = 1
      ping.hostname = ip
      ping.perform_ping
    end

    ping.pings.each do |ping|
      data = PingParser.new(ping, @test_case_id)
      @ping_data.save(data)
    end

    sleep 1.5
  end

  def time_first_ping
    start_time = Time.now
    @ping_data = PingData.new
    ping_all_hosts
    end_time = Time.now
    return end_time - start_time
  end

  def transmit_to_database
    # this was the old method for transmitting our data to the database.
    # everything now goes straight to S3.

    @file_data = PingData.new.load_file.to_json
    data = {:packets => @file_data, :machine_id => @machine_data[:machine_id] }
    begin
      postData = Net::HTTP.post_form(URI.parse(@url), data)

      #postData.read_timeout = 500

      # Once a 200 is received then remove records from file
      if postData.code == "200" || @clear_ping_data
        PingData.new.clear_file
        if @clear_ping_data
          # Delete all the env file and the public_ip file
          %w{env.yml public_ip.yml}.each do |file|
            FileUtils.rm("#{$pingbox_root}/config/#{file}")
          end	
          # Delete all files in the data folder
          #Clear Old Ping Data
          system("find #{$pingbox_root}/data -maxdepth 1 -name '*.gz' -print0 | xargs -0 rm -f")
        end
        @clear_ping_data = false 
      end
    rescue
    end
  end

  def to_boolean(str)
    str == 'true'
  end

end

begin
  puts "The current time is #{Time.now}"
  tc = TestCase.new
  tc.run
  puts "Process finished at #{Time.now}"
  puts "test_case.rb process complete.\n\n   -----\n\n"
rescue Exception => e
  EventLogger.process_exception("Test case", e)
  exit 1
end

__END__
DO NOT REMOVE: required for the DATA object above to lock file.
