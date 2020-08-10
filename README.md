
# CLI Test

Basically, I have my own, personal concept of what the idea cli cmd is and how
it is designed.  That is what this project is about.  I have written several
variations of this over the years, but eventually I'll make an overhaul of a
change and get too lazy to revert back to what it was like before.

## Basic Design and Flow

- Build the high-level command.
- Require the ruby lib into ruby file that will be running
- Include the Lib into the class or module with the code for the comman 


## Actual Lib's Flow

- Process arguments
  - Store a frozen version of the original ARGV
  - Store a version of ARGV we will use and modify
  - Check to see if we've been piped any data, if so:
    - dupe the original ARGV (`argv_clone = ARGV.clone`)
    - temporarily clear out the original ARGV (ARGV.clear)
    - read the data piped in (`piped_data = ARGF.read`)
    - reset ARGV args (`ARGV.concat(argv_clone)`)
  - shift the subcommand off of the args list
  - look for the handler that processes the given subcommand (normally is a part of the current file)
    - sometimes it will be in an separate file following a certain naming
      convention. the format, is "[main-cmd][hyphen][subcommand]".
    - For example, if our main command is `video` and we want to convert a
      video file from HD to SD so it will run smoother on older machines.  So
      the filename would be: `video-sd` to run an command that looks like:
      `#> video sd some-hd-file.mkv`




# I HAVE NO IDEA WHAT THIS IS OR WHY IT IS HERE


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

