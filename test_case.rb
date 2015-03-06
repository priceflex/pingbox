#Locks so only one instance runs at at time
exit unless DATA.flock(File::LOCK_NB | File::LOCK_EX)


@@current_path = "#{File.dirname(__FILE__)}"
require 'rubygems'
require 'ap'
require "#{@@current_path}/ping"
require 'net/http'
require 'uri'
require 'json'
require 'xmlsimple'
require 'socket'

# Put this in the cron job
# */1 * * * *  /bin/bash -l -c 'cd /home/stevenprice/code/netdebug &&  ruby test_case.rb'

class TestCase
  def initialize
    get_env
    @machine_data = nil
    @clear_ping_data = false
    #@env= nil
    #@url = ""
    @nmap_address = nil
    @nmap_dump 
    load_machine_data
  end

  def run
    get_work_from_host
    report_to_monitor
    start_work
  end

  def report_to_monitor
    # if @nmap_address is present do a nmap test
    if @nmap_address
      @nmap_dump = `/usr/bin/nmap -sP #{@nmap_address}`
    end
    @ifconfig_dump = `/sbin/ifconfig`
    @ps_aux_dump = `/bin/ps aux`
    @du_sh_dump = `/usr/bin/du -sh /home/pingbox/pingbox/data`
    begin
      @private_ip = Socket.ip_address_list.detect{|intf| intf.ipv4_private?}.ip_address
    rescue
      puts "Error getting ip"
    end

    public_ip
    transmit_monitor

  end

  def transmit_monitor 
    data = {:_method => :put, :ifconfig_dump => @ifconfig_dump, :ps_aux_dump => @ps_aux_dump, :du_sh_dump => @du_sh_dump, :private_ip => @private_ip, :public_ip=> @public_ip, :nmap_dump => @nmap_dump }
    begin
      puts "Transmmitting Data"
      postData = Net::HTTP.post_form(URI.parse("#{@url}/machine/#{@machine_data[:machine_id]}"), data)

      if postData.code == "200" 
        #Maybe output to log or something
        puts "Transmitted Monitor OK"
      end
    rescue
    end
  end

  def public_ip


    if File.exist?("#{@@current_path}/public_ip.yml") 
      @public_ip = YAML.load(File.open("#{@@current_path}/public_ip.yml"))[:public_ip]
    else 
      url = "http://ip.techrockstars.com/?format=xml"
      begin
        xml_data = Net::HTTP.get_response(URI.parse(url)).body
        data = XmlSimple.xml_in(xml_data)
        public_ip = {:public_ip => data["ipaddress"][0]}
        @public_ip = data["ipaddress"][0]

        File.open("#{@@current_path}/public_ip.yml", "w+") {|f| f.write(public_ip.to_yaml) }
      rescue
        @public_ip = "Not available"
      end
    end 

  end


  def transmit_to_database
    # Sends data to glitch.techrockstars.com/data
    # packets => [{ :packets_transmitted => '1', :packets_recieved => '1', :packet_errors => '', :completion_time => '0', :min => "0.016", :average => "0.016", :max => "0.016", :host => "localhost", :time => "2013-02-24 01:18:26.000000000 -08:00"}]

    data = {}
    #url = "http://ping.techrockstars.com/data" 
    #url = "http://glitch.techrockstars.com/data"
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
            FileUtils.rm("#{@@current_path}/#{file}")
          end	
          # Delete all files in the data folder
          #Clear Old Ping Data
          system("find #{@@current_path}/data -maxdepth 1 -name '*.gz' -print0 | xargs -0 rm -f")
        end
        @clear_ping_data = false 
      end
    rescue
    end

  end

  def to_boolean(str)
    str == 'true'
  end

  def get_work_from_host 


    # Send @machine_data[:machine_id] to glitch.techrockstars.com/machine/:machine_id
    # Reply will be the work that it should be preformed
    # "ips" => ["4.2.2.1", "192.168.1.1", "google.com"],
    # "times_per_minute" => "6", # 20max per ip. In this case 6 because of a 3 second wait for non responsiveness
    # "speedtest_urls" => ["https://someawesome-server.com"],
    # 
    # Save response to file work.yml 
    #
    #
    #@ping_times = 6
    #@ping_hosts = ["4.2.2.1", "localhost"]
    #@test_case_id = 1
    #
    #
    #if errors out then load to file
    #

    begin
      puts "Asking server test case"
      url = "#{@url}/machine/#{@machine_data[:machine_id]}/test_cases.xml"
      #url = "http://glitch.techrockstars.com/"
      xml_data = Net::HTTP.get_response(URI.parse(url)).body
      data = XmlSimple.xml_in(xml_data) 

      timeout_in_seconds = 3

      @ping_hosts = data["ping-hosts-addresses"][0].split("\n")
      @ping_times = (60 / timeout_in_seconds) / @ping_hosts.size
      @test_case_id = data["id"][0]["content"].to_i
      @clear_ping_data = to_boolean(data["reset-ping-data"][0]["content"])
      @nmap_address = data["nmap-address"][0]
      create_test_case_file

      puts "Got test from server"
    rescue
      if File.exist?("#{@@current_path}/test_case.yml")
        machine_data= YAML.load(File.open("#{@@current_path}/test_case.yml"))
      else
        FileUtils.touch("#{@@current_path}/test_case.yml")
        machine_data= YAML.load(File.open("#{@@current_path}/test_case.yml"))
      end

      @ping_hosts = machine_data[:ping_hosts]
      @ping_times = machine_data[:ping_times]
      @test_case_id = machine_data[:test_case_id]
      @nmap_address = machine_data[:nmap_address]

    end


  end
  def read_test_case_file

  end

  def create_test_case_file
    test_case = {:ping_hosts => @ping_hosts, :ping_times => @ping_times, :test_case_id=> @test_case_id, :nmap_address => @nmap_address}
    File.open("#{@@current_path}/test_case.yml", "w+") {|f| f.write(test_case.to_yaml) }
  end


  def create_machine_file

    machine_data = {:machine_id => Time.now.to_i }   
    url = "#{@url}/machine"
    @file_data = PingData.new.load_file.to_json
    data = {:system_id => machine_data[:machine_id]}

    postData = Net::HTTP.post_form(URI.parse(url), data)

    # Once a 200 is received then remove records from file
    ap postData
    if postData.code == "200"
      PingData.new.clear_file
      File.open("#{@@current_path}/machine.yml", "w+") {|f| f.write(machine_data.to_yaml) }

      #clear out all ping.yml and test_case.yml file
      %w{ping.yml test_case.yml env.yml public_ip.yml}.each do |file|
        FileUtils.rm("#{@@current_path}/#{file}")
      end
      exit
    end

  end

  def create_env_file(env)
    data = {:ping_box_env => env}
    File.open("#{@@current_path}/env.yml", "w+") {|f| f.write(data.to_yaml) }
  end

  def get_env
    if File.exist?("#{@@current_path}/env.yml")
      @env= YAML.load(File.open("#{@@current_path}/env.yml"))
      if @env[:ping_box_env] == "production"
        @url = "http://ping.techrockstars.com" 
      else
        @url = "http://dev2.techrockstars.com:3000" 
      end
    else
      @env = "production"
      create_env_file("production") #production by default
    end
  end

  def load_machine_data 
    parsed = begin

               if File.exist?("#{@@current_path}/machine.yml")
                 @machine_data= YAML.load(File.open("#{@@current_path}/machine.yml"))
               else
                 create_machine_file
                 @machine_data= YAML.load(File.open("#{@@current_path}/machine.yml"))
               end
             rescue ArgumentError => e  
               puts "Could not open file #{e.message}"
             end
    @machine_data
  end

  def time_first_ping
    @start_time = Time.now
    @ping_data = PingData.new

    ping = Ping.new
    @ping_hosts.each do |ip|
      ping.count(1)
      ping.hostname ip
      ping.ping
    end
    ping.pings.each do |ping|
      data = PingParser.new(ping, @test_case_id)
      @ping_data.save(data)
    end
    #@ping_data.save_file

    sleep 1.5

    @end_time = Time.now
    return @end_time - @start_time
  end

  def start_work
    @ping_times = (50/ time_first_ping).round


    @ping_data = PingData.new

    @ping_times.times do
      ping = Ping.new
      @ping_hosts.each do |ip|
        ping.count(1)
        ping.hostname ip
        ping.ping
      end
      ping.pings.each do |ping|
        data = PingParser.new(ping, @test_case_id)
        @ping_data.save(data)
      end
      sleep 1.5
    end
    @ping_data.save_file  
    puts "Saved Files"

  end
end

tc = TestCase.new
tc.run
tc.transmit_to_database


__END__
DO NOT REMOVE: required for the DATA object above to lock file.
