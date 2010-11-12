#!/usr/bin/env ruby
require 'rubygems'
require 'net/http'
require 'net/https'
require 'yaml'
require 'nokogiri'
require 'open-uri'

File_Last_Fail = File.join(File.dirname(__FILE__), 'last_fail.yml')
File_Config    = File.join(File.dirname(__FILE__), 'config', 'config.yml')
ResetTimes     = {:down => 4000,
                  :left => 9000}
MaxPerRotation = 3000

class BuildPunisher
  attr_accessor :config
  
  def initialize
    @config = YAML.load_file(File_Config)
  end

  def retrieve_xml
    puts "=== So whos been naughty then? ..."
    url = URI.parse(@config["bamboo"]["failed_rss_url"])
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    req = Net::HTTP::Get.new(url.path + "?" + url.query)
    req.basic_auth @config["bamboo"]["username"], @config["bamboo"]["password"]
    res = http.request(req)
    case res
    when Net::HTTPSuccess, Net::HTTPRedirection
      return Nokogiri::XML.parse(res.body)
    else
      return nil
    end
  end
  
  def reset
    puts "=== Resetting launcher rotation..."
    turn_down(ResetTimes[:down])
    turn_left(ResetTimes[:left])
  end
  
  def fire_at_and_reset(right_time, up_time)
    puts "=== Aim..."
    turn_right(right_time)
    turn_up(up_time)
    puts "===== FIRE!!!"
    fire
    reset
  end
  
  def turn_left(time); rotate("L", time); end
  def turn_right(time); rotate("R", time); end
  def turn_up(time); rotate("U", time); end
  def turn_down(time); rotate("D", time); end
  
  def rotate(direction, time)
    while time > 0
      if time > MaxPerRotation
        iteration_time = MaxPerRotation
      else
        iteration_time = time
      end
      `USBMissileLauncherUtils -#{direction} -S #{iteration_time}`
      time -= MaxPerRotation
    end
  end
  
  def fire
    system("USBMissileLauncherUtils -F")
    sleep 2
  end

end

@bp = BuildPunisher.new

@last_fail = YAML.load_file(File_Last_Fail) || {} rescue {}

failed_builds = @bp.retrieve_xml

last_fail = failed_builds.xpath("//item").first

last_fail_time = Time.parse(last_fail.xpath("pubDate").text)
last_fail_desc = last_fail.xpath("description").text

if @last_fail[:time] != last_fail_time
  puts "===== The build has failed!! Somebody gonna getta hurt real bad..."  
  @bp.reset
  @bp.config["users"].each do |name, positions|
    if last_fail_desc.include?(name)
      puts "===== Oh no! #{name} broke the build! Watch out!!"
      @bp.fire_at_and_reset(positions["right"], positions["up"])
    end
  end
  puts "===== Punishment has been served!!"
  
  File.open(File_Last_Fail, 'w') {|f| f.puts({:time => last_fail_time}.to_yaml) }
else
  puts "===== Phew, no-one needs punishing... FOR NOW!"
end





