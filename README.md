  #   require "dry/cli"
  #
  #   module Foo
  #     module Commands
  #       extend Dry::CLI::Registry
  #
  #       class Hello < Dry::CLI::Command
  #         def call(*)
  #           puts "hello"
  #         end
  #       end
  #
  #       register "hello", Hello
  #       before "hello", -> { puts "I'm about to say.." }
  #     end
  #   end

