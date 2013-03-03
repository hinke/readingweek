require 'rubygems'
require 'uri'
require 'sinatra'
require 'json'
require 'rest_client'
require 'data_mapper'
require 'nokogiri'
require "sinatra/cookies"
require 'omniauth'
require 'omniauth-twitter'
require './config.rb'

use Rack::Session::Cookie

use OmniAuth::Builder do
  provider :twitter, 'XRAyuDf44jaGzsvH9eGOJQ', '7bLBZu8E150Gcf8jlmT31QUbufQjAvlW8Fh0FVNsNwk'
end

set :readmill_client_id, "e2953a5b47cc8e583f1cedcd5bfdf15a"
set :readmill_client_secret, "c7ad27561a5df01b105227f482d29bc7"
#set :readmill_redirect, "http://127.0.0.1:9393/callback/readmill"
set :readmill_redirect, "http://rosie-says.herokuapp.com/callback/readmill"

get '/auth/readmill' do
  redirect "http://readmill.com/oauth/authorize?response_type=code&client_id=#{settings.readmill_client_id}&redirect_uri=#{settings.readmill_redirect}&scope=non-expiring"
end

get '/callback/readmill' do
  token_params = {
    :grant_type => 'authorization_code',
    :client_id => settings.readmill_client_id,
    :client_secret => settings.readmill_client_secret,
    :redirect_uri => settings.readmill_redirect,
    :code => params[:code],
    :scope => 'non-expiring'
  }
  
  begin 
    resp = JSON.parse(RestClient.post("https://readmill.com/oauth/token.json", token_params).to_str)
    data = fetch_and_parse("https://api.readmill.com//v2/me.json", resp['access_token'])
  rescue
    redirect '/'
  end

  user = User.first_or_create({ :readmill_id => data['user']['id'] })
  @fullname = data['user']['fullname']
  user.name = data['user']['fullname']
  user.readmill_token = resp['access_token']
  user.save!
  cookies[:readmill_id] = data['user']['id']

  erb :twitter
end

get '/auth/twitter/callback' do
  redirect '/' if cookies[:readmill_id].nil?
  user = User.first({ :readmill_id => cookies[:readmill_id] })
  redirect '/' if user.nil?

  auth = request.env['omniauth.auth']

  redirect '/' if auth.nil?

  begin 
    user.handle = auth[:info][:nickname]
    user.twitter_token = auth[:credentials][:token]
    user.twitter_secret = auth[:credentials][:secret]
    user.save!
    erb :done
  rescue
    redirect '/'
  end
end

def fetch_and_parse(uri, token)
  puts "Fetching and parsing: #{uri} with token #{token}"
  url = "#{uri}?client_id=#{settings.readmill_client_id}"
  url = "#{url}&access_token=#{token}" if token
  content = RestClient.get(url, :accept => :json).to_str
  JSON.parse(content) rescue nil
end

### -- TEMPLATES -- ###

get '/' do
  erb :index
end

get '/auth/failure' do
  redirect '/'
end

get('/fonts/:filename') { send_file("./fonts/#{params[:filename]}") }
get('/images/:filename') { send_file("./images/#{params[:filename]}") }
get('/javascripts/:filename') { send_file("./javascripts/#{params[:filename]}") }
get('/stylesheets/:filename') { send_file("./stylesheets/#{params[:filename]}") }
