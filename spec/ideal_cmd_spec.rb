
require './spec_helper'

describe 'BaseCmd.run executes subcommand :a' do
  command '/home/jearsh/projects/mkclicmd.rb/spec/testcmd.rb a sdf'
  its(:stdout) { is_expected.to include('subcmd == a? yes') }
end

describe 'BaseCmd.run executes subcommand :a' do
  command '/home/jearsh/projects/mkclicmd.rb/spec/testcmd.rb josh one two three'
  its(:stdout) { is_expected.to include('josh was here') }
end

describe 'BaseCmd.run executes subcommand :b' do
  command '/home/jearsh/projects/mkclicmd.rb/spec/testcmd.rb b c defg'
  its(:stdout) { is_expected.to include('this is subcmd c which is a subcmd of b') }
end











