require 'rubygems'
require 'bundler'

Bundler.require

$LOAD_PATH.unshift(File.dirname(__FILE__) + "/../lib")
require 'redis/stats'
require 'redis/stats/app'