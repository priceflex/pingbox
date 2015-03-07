
@@current_path = "#{File.dirname(__FILE__)}"

require 'pry'
require 'ap'
require 'yaml'
require 'time'
require "#{File.dirname(__FILE__)}/hasher.rb"
require 's3'



#this will parse the ping data
class PingParser
  def initialize(ping_data, test_caseid=0)
    @ping_data = ping_data.split("\n")
    @ping_results = {}
    @ping_replys = []
    @test_case_id = test_caseid
    parse
  end
  def reply_times
    @ping_data
  end
  def ping_replys
    @ping_replys
  end

  def test_case_id
    @test_case_id
  end

  def statistics
    @ping_data.grep(/packets transmitted/).join
  end

  def packets_transmitted
    statistics.split(",").grep(/transmitted/).join.scan(/[\d]/).join
  end

  def packets_received 
    statistics.split(",").grep(/received/).join.scan(/[\d]/).join
  end

  def packet_loss
    statistics.split(",").grep(/loss/).join.scan(/[\d]/).join
  end

  def rounded_time
    Time.at(((time.to_i / 60.0).round * 60.0).to_i)
  end

  def time
    Time.parse(@ping_data.grep(/Time Started/).join.gsub("-----Time Started", ""))
  end

  def host
    @ping_data.grep(/----- Host/).join.gsub("----- Host ", "")
  end

  def packet_errors
    statistics.split(",").grep(/error/).join.scan(/[\d]/).join
  end

  def completion_time
    statistics.split(",").grep(/time/).join.scan(/[\d\.]/).join
  end

  def min
    begin
      rtt.split("=")[1].split("/")[0].scan(/[\d\.]/).join
    rescue
      0
    end
  end

  def max
    begin
      rtt.split("=")[1].split("/")[2].scan(/[\d\.]/).join
    rescue
      0
    end
  end

  def average
    begin
      rtt.split("=")[1].split("/")[1].scan(/[\d\.]/).join
    rescue
      0
    end
  end

  def rtt 
    if @ping_data.grep(/rtt/).join.include? "rtt"
      return @ping_data.grep(/rtt/).join
    else
      return ""
    end
  end

  def parse
    @ping_data.grep(/bytes from/).each do |ping|
      @ping_replys << { 
        :ping_data => ping,
        :ping_id => ping.split.grep(/icmp_req/).join.scan(/[\d]/).join,
        :ping_time_ms => ping.split.grep(/time/).join.scan(/[\d\.]/).join,
        :ping_ttl => ping.split.grep(/ttl/).join.scan(/[\d\.]/).join
      }
    end
    @ping_results = {
      :packets_transmitted => packets_transmitted,
      :packets_received => packets_received,
      :packet_loss => packet_loss,
      :packet_errors => packet_errors,
      :completion_time => completion_time,
      :min => min, 
      :average => average,
      :max => max,
      :host=> host,
      :time => "#{time}",
      :rounded_time => Time.at(((time.to_i / 60.0).round * 60.0).to_i),
      :transmitted_to_database => false,
      :test_case_id => "#{@test_case_id}"
    }

  end

  def results
    @ping_results
  end

  def calculate_averages
    # calculate averages of pings in this file so we don't have to do it when caching.
    puts "ok"

  end
end

class Ping

  def self.env?
    current_path = "#{File.dirname(__FILE__)}"
    if File.exist?("#{current_path}/env.yml")
      @env= YAML.load(File.open("#{current_path}/env.yml"))
      if @env[:ping_box_env] == "production"
        return :production
      else
        return :development
      end
    else
      puts "Enviroment file does not exist. Please create one."
    end
  end

  def initialize(options= {})
    options = {:host => "google.com", :count => 5}.merge(options)
    @pings = []
    @hostname = options[:host] 
    @count = options[:count] 
  end

  def hostname(host)
    @hostname = host 
  end

  def count(times)
    @count= times
  end

  def ping
    @time = Time.now
    @pings << `ping #{@hostname} -c #{@count}` + "-----Time Started #{@time} \n" + "----- Host #{@hostname}" 
  end
  def pings
    @pings
  end
end


#stores a large array of ping requests
class PingData
  def initialize
    @all_data = []
    @file_data = ""
  end

  def read
    @all_data
  end

  def total_pings
    @all_data
  end

  def failed_pings
    @failed_pings ||= @all_data.select{|a| a.packet_loss =="100"}
  end
  def successful_pings 
    @successful_pings ||= @all_data.select{|a| a.packet_loss =="0"}
  end

  def successful_find_by_host(host_name)
    #@successful_find_by_host ||= successful_pings.select{|a| a.host == host_name}
    successful_pings.select{|a| a.host == host_name}
  end

  def failed_find_by_host(host_name)
    #@failed_find_by_host ||= failed_pings.select{|a| a.host == host_name}
    failed_pings.select{|a| a.host == host_name}
  end

  def find_by_host_name(host_name)
    @all_data.select{|a| a.host == host_name}
  end


  def sort_by_host(hosts)
    hosts.group_by {|p| p.host}
    # returns ["google.com", PingParser{:average => "12.00" ....}]
  end

  def sort_and_cache(host_pings)
    host_pings.group_by { |p| p.rounded_time }.to_a.map{|a| { :time => a[0], :average => a[1].map(&:average).map(&:to_i).inject {|sum, x| sum + x} / a[1].size, :count => a[1].size }}
  end


  def load_file 
    parsed = begin
               if File.exist?("#{@@current_path}/ping.yml")
                 @file_data = YAML.load(File.open("#{@@current_path}/ping.yml"))
               else
                 FileUtils.touch("#{@@current_path}/ping.yml")
                 @file_data = YAML.load(File.open("#{@@current_path}/ping.yml"))
               end
             rescue ArgumentError => e  
               puts "Could not open file #{e.message}"
             end
    @file_data
  end

  def clear_file
    data = nil
    File.open("#{@@current_path}/ping.yml", "w+") {|f| f.write(data.to_yaml) }
  end

  def save_staging_file
    File.open("#{@@current_path}/ping.yml", "w+") {|f| f.write(@all_data.map(&:results).to_yaml) }
  end
  def sha_ping_file
    @hash_file_name = Hasher.new("#{@@current_path}/ping.yml").hashsum
  end
  def zip_ping_file
    system("gzip -9 #{@@current_path}/ping.yml")
    FileUtils.mv "#{@@current_path}/ping.yml.gz", "#{@@current_path}/data/#{@hash_file_name}.gz"
  end
  def sent_all_files_to_s3
    s3_service = S3::Service.new(
      :access_key_id     => ENV['ec2_access_key_id'],
      :secret_access_key => ENV['ec2_secret_access_key']
    )
    begin

      if Ping.env? == :production
        @bucket = "pingbox-data"
      else
        @bucket = "pingbox-data-dev"
      end

      bucket = s3_service.buckets.find("#{@bucket}")


      # Copy to S3
      puts "Uploading file to s3"
      # found_object.destroy
      Dir.glob("#{@@current_path}/data/*.gz") do |file|
        new_object = bucket.objects.build("#{File.basename(file)}")
        new_object.content = open("#{file}")
        new_object.save
        if new_object.exists?
          FileUtils.rm(file)
        end
      end
      puts "Sent all data to s3"
    rescue
      puts "Error Sending to S3"
    end
  end

  def save_file
    #    save_staging_file
    #    sha_ping_file
    #    zip_ping_file
    #    puts "Saving to S3"
    #    SendToS3.send_files

    #    sent_all_files_to_s3


    #load_file
    #if @file_data 
    #@file_data.concat(@all_data.map(&:results))
    #File.open("#{@@current_path}/ping.yml", "w+") {|f| f.write(@file_data.to_yaml) }
    #else
    #File.open("#{@@current_path}/ping.yml", "w+") {|f| f.write(@all_data.map(&:results).to_yaml) }
    #end

  end

  def save(data)
    @all_data << (data)
  end

end


