#!/usr/bin/env ruby

$:.unshift File.dirname(__FILE__)

include Clockwork

every(1.day, 'send updates', :at => '19:00', :tz => 'UTC', :if => lambda { |t| t.sunday? }) { send_updates }
#every(2.minutes, 'send updates', :if => lambda { |t| t.sunday? }) { send_updates }

require './config.rb'
require 'twitter'
require 'json'
require 'rest_client'

Twitter.configure do |config|
  config.consumer_key = "XRAyuDf44jaGzsvH9eGOJQ"
  config.consumer_secret = "7bLBZu8E150Gcf8jlmT31QUbufQjAvlW8Fh0FVNsNwk"
end

def readmill_client_id
	"e2953a5b47cc8e583f1cedcd5bfdf15a"
end

def readmill_base_url
  "https://api.readmill.com/v2"
end

def seven_days_ago
  (Time.now - 60*60*24*7).iso8601
end

def get_periods(reading_id, u)
  uri = readmill_uri("/readings/#{reading_id}/periods?from=#{seven_days_ago}&order=started_at", u)
  #puts uri
  response = JSON.parse(RestClient.get(uri))
  return response['items']
end

def get_readings(user)
  uri = readmill_uri("/users/#{user.readmill_id}/readings?order=touched_at&states=reading,finished,abandoned&from=#{seven_days_ago}", user)
  #puts uri
  response = JSON.parse(RestClient.get(uri))
  return response['items']
end

def get_highlights(user)
  uri = readmill_uri("/users/#{user.readmill_id}/highlights?order=highlighted_at&from=#{seven_days_ago}&count=100", user)
  #puts uri
  response = JSON.parse(RestClient.get(uri))
  return response['items']
end

def get_me(user)
  uri = readmill_uri("/me.json", user)
  #puts uri
  response = JSON.parse(RestClient.get(uri))
  return response['user']
end


def compile_stats(user)
	readings = get_readings(user)
	time_spent = 0

	return nil if readings.size < 1

	readings.each do |r|
		periods = get_periods(r['reading']['id'], user)
		periods.each {|p| time_spent+=p['period']['duration'].to_i/60}
	end
	hours = time_spent/60
	minutes = time_spent % 60

	return nil if time_spent == 0

	highlights = get_highlights(user)

	time = "#{hours} hour#{'s' if hours > 1}" if hours > 0
	time = time.nil? ? "#{minutes} minutes" : "#{time} and #{minutes} minutes" if minutes > 0
	text = "I've spent #{time} in #{readings.size} book#{'s' if readings.size > 1} this week."

	text = "#{text} And made #{highlights.size} highlight#{'s' if highlights.size > 1}." if highlights.size > 0

	me = get_me(user)
	text = "#{text} Follow me at https://readmill.com/#{me['username']}"
end

def readmill_uri(path, u)
  if path.include?('?')
      uri = "#{readmill_base_url}#{path}&client_id=#{readmill_client_id}&access_token=#{u.readmill_token}"
  else
      uri = "#{readmill_base_url}#{path}?client_id=#{readmill_client_id}&access_token=#{u.readmill_token}"
  end
end

def send_tweet(user, message)
	begin 
		twitter = Twitter::Client.new(
		  :oauth_token => user.twitter_token,
		  :oauth_token_secret => user.twitter_secret
		)
		twitter.update(message)
		puts message
		puts "END OF MESSAGE"
	rescue
		puts "Error tweeting for user #{user.id}"
	end
end

def send_updates
	User.all.each do |u|
		text = compile_stats(u)
		send_tweet(u, text) unless text.nil?
		Kernel.sleep(1)
	end
end