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
      @url = "http://techrockstars.com:3000" 
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
    url = "#{@url}/machine/#{@machine_data[:machine_id]}/test_cases.xml"
    xml_data = Net::HTTP.get_response(URI.parse(url)).body
    test_case_data = XmlSimple.xml_in(xml_data) 

    @nmap_address = test_case_data['nmap-address'].first if test_case_data['id']
    puts "Got nmap address from server."
  rescue
    test_case_data = YAML.load(File.open("#{$pingbox_root}/config/test_case.yml"))
    @nmap_address = test_case_data[:nmap_address]
    puts "Couldn't resolve nmap address from server.  Using test_case.yml" if @nmap_address
  end

  def gather_nmap_data
    @nmap_dump = `/usr/bin/nmap -sP #{@nmap_address}` if @nmap_address 
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
  # TODO: nmaps need to eventually go through S3 so we still receive this data after
  # the server comes back online. it currently handles server errors properly, but there's no point.
  # the data goes to waste if the server can't receive it.

  puts "Begin network map."
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
