#!/usr/bin/env ruby

require '/home/jearsh/projects/mkclicmd.rb/lib/ideal_cmd.rb'

class BaseCmd
  include IdealCmd

  register_subcommand(:a) {
    puts 'subcmd == a? yes'
    puts "args = #{args.inspect}"
  }

  register_subcommand(:josh) {
    puts 'josh was here'
    puts "args = #{args.inspect}"
  }
end

class BSubcmds
  include IdealCmd

  register_subcommand(:c) {
    puts 'this is subcmd c which is a subcmd of b'
  }
end

# registering subcmd b
BaseCmd.register_subcommand_handler(BSubcmds, :b)

BaseCmd.run

