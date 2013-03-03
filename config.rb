require 'uri'
require 'json'
require 'rest_client'
require 'data_mapper'
require 'nokogiri'
require 'securerandom'
require 'clockwork'

class User
  include DataMapper::Resource
  property :id, Serial 
  property :name, String
  property :readmill_id, String
  property :readmill_token, String
  property :handle, String
  property :twitter_token, String
  property :twitter_secret, String
  property :utc_offset, Integer
end

DataMapper.finalize
DataMapper::Logger.new($stdout, :debug)

DataMapper.setup(:default, (ENV["DATABASE_URL"] || {
  :adapter  => 'mysql',
  :host     => 'localhost',
  :username => 'root' ,
  :password => '',
  :database => 'readingweek'}))
DataMapper.auto_upgrade!  
