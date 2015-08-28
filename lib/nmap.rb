$pingbox_root = "#{File.dirname(__FILE__)}/.." unless $pingbox_root

require 'yaml'
require 'pry'
require "#{$pingbox_root}/lib/pingbox/event_logger"

class Nmap
  attr_accessor :env, :url, :machine_data, :nmap_address, :nmap_dump

  def initialize
    get_env
    load_machine_data
    retrieve_test_case_info
  end

  def get_env
    @env = Ping.env?
    if @env == :production
      @url = "http://ping.techrockstars.com" 
    elsif @env == :development
      @url = "http://192.168.0.124:3000" 
    else 
      @env = :production
      create_env_file(@env.to_s) # production by default
    end
  end

  def create_env_file(env)
    File.open("#{$pingbox_root}/config/env.yml", "w+") { |f| f.write({ ping_box_env: env }.to_yaml) }
  end

  def load_machine_data 
    #create_machine_file unless File.exist?("#{$pingbox_root}/config/machine.yml")
    @machine_data = YAML.load(File.open("#{$pingbox_root}/config/machine.yml"))
  end

  def retrieve_test_case_info
    print "Requesting test case information from server... "

    url = "#{@url}/machine/#{@machine_data[:machine_id]}/test_cases.xml"
    xml_data = Net::HTTP.get_response(URI.parse(url)).body
    test_case_data = XmlSimple.xml_in(xml_data) 

    @nmap_address = test_case_data['nmap-address'].first if test_case_data['id']
    puts "done."
  end

  def gather_nmap_data
    print "Generating nmap... "
    @nmap_dump = `/usr/bin/nmap -sP #{@nmap_address}` if @nmap_address 
    puts "done."
  end

  def transmit_nmap_dump
    data = {
      _method: :put,
      nmap_dump: @nmap_dump
    }

    postData = Net::HTTP.post_form(URI.parse("#{@url}/machine/#{@machine_data[:machine_id]}"), data)

    if postData.code == "200" 
      puts "Nmap transmitted OK."
    else
      puts "Nmap transmission failed.  Status code from server: #{postData.code}"
    end
  end

end


begin
  nmap = Nmap.new
   
  if nmap.nmap_address
    nmap.gather_nmap_data
    nmap.transmit_nmap_dump
  else
    puts "Could not resolve nmap address from server."
  end

rescue Exception => e
  EventLogger.process_exception("Nmap", e)
end
