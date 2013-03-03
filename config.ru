$:.unshift File.expand_path("../", __FILE__)
$LOAD_PATH.unshift(Dir.getwd)
require 'rubygems'
require 'sinatra'
require './app.rb'


run Sinatra::Application