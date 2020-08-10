#!/usr/bin/env ruby

require 'pry'
require './lib/ideal_cmd.rb'

class BaseCmd
  include IdealCmd
  self.subcommand_file = __FILE__

  register_subcommand('a') do |args|
    puts 'this is subcmd a'
    puts args
  end

  register_subcommand('b') do |args|
    puts 'this is subcmd b'
    puts args
  end

  register_subcommand('c') do |args|
    puts 'this is subcmd c'
    puts args
  end

  no_subcommand do
    puts 'so it runs, at least it does with no subcommand'
  end
end

BaseCmd.run




