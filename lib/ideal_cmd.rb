

class CmdArgs
  attr_accessor :cloned_argv, :argv, :argf, :subcmd, :args,
    :subcmd_and_args, :piped_data, :processed_subcmds

  def initialize(argv=nil, piped_in=nil)
    if ! argv.nil?
      @cloned_argv = argv.clone
      @subcmd_and_args = argv
    else
      @cloned_argv = ARGV.clone
      @argv = [].concat(ARGV)
      @subcmd_and_args = [].concat(ARGV)
    end

    if ! piped_in.nil?
      @piped_data = piped_in
    else
      ARGV.clear
      @piped_data = ARGF.read
      ARGV.concat(@argv)
    end

    @argf = ARGF.clone
    @subcmd, *@args = @subcmd_and_args
  end

  # def get_piped_data(piped_in=nil)
  #   @piped_data = piped_in unless piped_in.nil?
  #   @piped_data ||= STDIN.tty? ? nil : Proc.new{
  #       bkup = ARGV.clone
  #       ARGV.clear
  #       data = ARGF.read
  #       ARGV.concat(bkup)
  #     }.call
  # end

  def subcmd_args
    @subcmd_args ||= CmdArgs.new(args, piped_data)
  end

  def processed_subcmds
    @processed_subcmds ||= []
  end

  def next
    processed_subcmds.push(subcmd)
    (@subcmd, *@args) = args
  end
end


module IdealCmd
  def self.loading_files
    @loading_files ||= []
  end

  def self.loading_file
    loading_files.last
  end

  def self.included(base)
    base.extend(ClassMethods)
    base.subcommand_file ||= IdealCmd.loading_file
    base.subcommand_file ||= __FILE__
    base.register_global_subcommands
  end

  class Subcommand
    attr_accessor :names, :file, :line, :block
    def initialize(*names, file: nil, line: nil, &block)
      @names, @file, @line, @block = names, file, line, block
    end
  end

  module ClassMethods
    attr_accessor :subcommand, :subcommand_chain
    attr_accessor :let_blocks

    attr_accessor :arg_manager, :all_args, :modifier_args
    attr_accessor :original_args, :usable_args
    attr_accessor :args_with_subcommand, :args_without_subcommand
    attr_accessor :subcommand_arg, :subcommand_file

    def global_subcommands
      {
        [:console] => proc{
          binding.pry
        },

        [:ecmd, :ethis] => proc{
          system('nvim', subcommand_file)
        },

        [:cmds, :scmds, :commands, :subcommands] => proc{
          print_subcommand_list(false)
        },
      }
    end

    def register_global_subcommands
      global_subcommands.each{|cmds,code|
        register_subcommand(*cmds, &code)
      }
      # register_subcommand(:console) { binding.pry }
      # register_subcommand(:ecmd, :ethis) { system(ENV['EDITOR'] || 'nvim', __FILE__) }
      # register_subcommand(:cmds,:scmds,:commands,:subcommands) { print_subcommand_list(false) }
    end

    def args_with_subcommand
      arg_manager.subcmd_and_args
      # [subcommand] + usable_args
    end

    def args_without_subcommand
      arg_manager.args
      # usable_args
    end

    # def args_without_modifiers
    #   args.take_while{|arg| arg[0] != ?@ }
    # end

    def arg_manager
      @arg_manager
    end

    def args
      arg_manager.args
    end

    def piped_data
      arg_manager.piped_data
    end

    def next_arg_manager
      #@next_arg_manager ||= arg_manager.next
      @next_arg_manager ||= arg_manager.subcmd_args
    end

    def pre_run(&block)
      @pre_run_block = block
      self
    end

    def run(arg_mgr=nil)
      if @pre_run_block
        @pre_run_block.call(self)
      end

      if arg_mgr.is_a?(CmdArgs)
        @arg_manager = arg_mgr
      else
        @arg_manager = CmdArgs.new
      end

      ### ArgumentHelper.order.push(Value.new(name: self.name, klass: self, data:
      ###                                     @arg_manager, manager: @arg_manager,
      ###                                     args: @arg_manager.args))

      # @arg_manager = ArgManager.setup(passed_args)

      # @all_args = passed_args
      # @all_args ||= ARGV.clone
      # @usable_args = @all_args.take_while{|arg| arg[0] != ?@ }
      # @modifier_args = @all_args.drop_while{|arg| arg[0] != ?@ }
      # @original_args = @all_args
      @subcommand_arg = arg_manager.subcmd

      @subcommand = subcommand_matcher.match(@subcommand_arg)

      route_args_and_process_command
    end

    def subcommand_proc
      @subcommand.data if @subcommand
    end

    def no_runner_proc
      Proc.new{
        print_subcommand_list
        exit 1
      }
    end

    def runner_type(code=runner)
      {}.tap{|types|
        types.merge!(subcommand_proc.object_id => format('%s (%s)', :subcommand.inspect, @subcommand.name.to_sym.inspect)) if subcommand_proc
        types.merge!(@dynamic_subcommand.object_id => :dynamic_subcommand) if @dynamic_subcommand
        types.merge!(@no_subcommand.object_id => :no_subcommand) if subcommand_proc
      }.fetch(code.object_id, :no_match_print_help_and_subcommand_list)
    end

    def runner
      @runner ||= Proc.new{
        match   = subcommand_proc
        match ||= @dynamic_subcommand if @subcommand_arg
        match ||= @no_subcommand unless @subcommand_arg
        match || no_runner_proc
      }.call
    end

    def route_args_and_process_command
      ProcessList.add(
        object: self,
        runner_type: runner_type,
        runner: runner,
        arg_manager: arg_manager,
        modifiers: modifiers,
        special_modifiers: special_modifiers,
      )

      return runner.call if runner

      ### disabling hooks for now TEMPORARY MAYBE 2020-08-12
      if 0 == 1 # if runner
        block_returned = nil
        hooks_returned = run_with_hooks{
          block_returned = runner.call
          ProcessList.update(return_value: block_returned)
          block_returned = ProcessList.finalize(block_returned)
          # block_returned = extract_and_apply_modifiers(block_returned)
        }
        ProcessList.update(hooks_return_value: hooks_returned)
        ProcessList.finish!
        return block_returned
      end

      puts "Cannot figure out what to do..."
      exit 1
    end

    def let_blocks
      @let_blocks ||= {}
    end

    def let(name, &block)
      let_blocks.merge!(name => block)
      define_singleton_method(name, &block)
    end

    def special_modifier_args
      @special_modifier_args ||= {}
    end

    def modifier_args
      @modifier_args ||= []
    end

    def check_if_has_modifiers
      modifier_args.any? || special_modifier_args.any?
    end

    def has_modifiers
      @has_modifiers ||= check_if_has_modifiers
    end

    def has_modifiers!
      @has_modifiers = check_if_has_modifiers
    end

    def has_modifiers?
      has_modifiers == true
    end

    def extract_special_modifiers
      special_modifiers.keys.each do |mod|
        index = args.index(mod.to_s)
        next if index.nil?

        key = args[index]
        val = args[(index+1)..-1]
        if MainCommand.applied_modifiers.include?(key)
          next
        end
        special_modifier_args.merge!(key => val)

        has_modifiers!

        len = args[index..-1].length
        args.pop(len)
      end
    end

    def extract_modifiers
      args.reverse.take_while{|arg|
        modifiers.keys.map(&:to_s).include?(arg)
      }.tap{|mods|
        break mods if mods.empty?

        mods.each{|mod|
          if MainCommand.applied_modifiers.include?(args.last)
            args.pop
            next
          end
          modifier_args.unshift args.pop
        }

        has_modifiers!
      }
    end

    def extract_and_apply_modifiers(returned)
      extract_special_modifiers
      extract_modifiers

      has_modifiers? ? apply_modifiers(returned) : returned
    end

    def apply_modifiers(returned)
      return returned unless has_modifiers?

      if special_modifier_args.keys.any?
        returned = special_modifier_args.keys.inject(returned) do |retval,smod|
          cmd = special_modifier_args[smod]
          special_modifiers[smod].call(retval, cmd)
        end
      end

      if modifier_args.any?
        returned = modifier_args.inject(returned) do |retval,mod|
          modifiers[mod].call(retval)
        end
      end

      returned
    end

    def error_exit(msg=nil, &block)
      puts format('ERROR: %s', msg) if msg

      block.call if block_given?

      exit 1
    end

    def subcommand_usage_hash
      usages = subcommand_matcher.usages
      w = usages.keys.map(&:length).max + 2
      usages.sort_by{|k,v|
       k
      }.inject({}){|h,(name,usage)|
        h.merge(name => format("   %#{w}s => %s", name, usage))
      }
    end

    def subcommand_usage_list
      usages = subcommand_matcher.usage_groups
      w = usages.flat_map(&:keys).map(&:length).max + 2
      usages.map do |usage|
        usage.map do |name,usage|
          format("   %#{w}s => %s", name, usage)
        end
      end
    end

    def print_subcommand_list(with_error=true)
      if with_error
        puts 'ERROR: Subcommand required.'
        puts
      end
      puts 'Possible subcommands:'
      subcommand_usage_list.each do |list|
        puts
        puts list.sort_by{|item| item[/\S.*/] }
      end
      puts
      # puts <<-MESSAGE.lines.map{|l| l.chomp.sub(/^\s{8}/, '') }
      #   ERROR: Subcommand required.
      #
      #   Possible subcommands:
      #   #{subcommand_usage_list.join("\n")}
      # MESSAGE
    end

    def run_with_hooks(&block)
      @before_hook.call if @before_hook
      block.call
      @after_hook.call if @after_hook
    end

    def current_project
      @current_project ||= Proc.new{
        pwd = Dir.pwd
        possible_projects = ProjectHelper.projects.select{|name,dir|
          pwd.start_with?(dir)
        }

        return if possible_projects.empty?
        name,dir = possible_projects.max_by{|name,dir| dir.length }
        ProjectHelper.project_for(name)
      }.call
    end

    def subcommand_matcher
      NameMatcher.new subcommands
    end

    def subcommand_names
      subcommand_matcher.names
    end

    def subcommand_objects
      @subcommand_objects ||= {}
    end

    def subcommands
      @subcommands ||= {}
    end

    def fallback_runner
      @fallback_runner ||= Proc.new do
        puts <<-MESSAGE.lines.map{|l| l.chomp.sub(/^\s{10}/, '') }
          No handler for the "#{subcommand_arg.inspect}" subcommand.

          These are the possible subcommands:
            #{subcommand_matcher.syntax.values.join("\n  ")}
        MESSAGE
        exit 1
      end
    end

    def before(&block)
      @before_hook = block
    end

    def after(&block)
      @after_hook = block
    end

    def default_handler(&block)
      @no_subcommand = @dynamic_subcommand = block
    end

    def no_subcommand(&block)
      @no_subcommand = block
    end

    def dynamic_subcommand(&block)
      @dynamic_subcommand = block
    end

    def subcommand_handlers
      @subcommand_handlers ||= {}
    end

    def subcommand_tree_for(klass=MainCommand)
      return {} if klass.subcommands.empty?
      usages = klass.subcommand_matcher.usages
      w = usages.keys.max_by(&:length).length + 2
      usage_hash = klass.subcommand_usage_hash
      klass.subcommands.keys.sort.inject({}){|h,name|
        h.merge(name => usage_hash[name])
      }.tap{|tree|
        klass.subcommand_handlers.each do |subcmd,subklass|
          tree[subcmd] = subcommand_tree_for(subklass).merge(_format:
                                                             usage_hash[subcmd])
        end
      }
    end

    def special_modifiers
      @registered_special_modifiers ||= {
        "@each" => Proc.new{|returned,cmd|
          break unless returned.is_a?(Array)
          if not cmd.any?{|arg| arg[/(?<!\\)%s/i] }
            cmd.push '%s'
          end
          gsub = %r{(?<!\\)%s}i
          cmd = cmd.map{|arg| arg.gsub(gsub, '%<arg>s') }
          returned.map{|arg|
            current_command = cmd.map{|item|
              format(item, arg: arg.shellescape)
            }
            system(*current_command)
          }
        },

        "@all" => Proc.new{|returned,cmd|
          break unless returned.is_a?(Array)
          if not cmd.any?{|arg| arg[/(?<!\\)%s/i] }
            cmd.push '%s'
          end
          gsub = %r{(?<!\\)%s}i

          to_add = returned.map(&:shellescape)
          while cmdi = cmd.index('%s')
            cmd[cmdi] = to_add
            cmd = cmd.flatten
          end

          system(*cmd)
        },
      }
    end

    def modifiers
      @registered_modifiers ||= {
        "@vim" => Proc.new{|returned|
          HeroHelper.edit_in_editor *returned.flatten
        },

        "@capture" => Proc.new{|returned|
          tempfile = Tempfile.create('hero')

          case returned
          when String
            IO.write(tempfile.path, returned)
            HeroHelper.edit_in_editor(tempfile.path)
          when Array, Hash
            File.open(tempfile.path, 'w+') {|fd|
              fd.puts returned
            }
            HeroHelper.edit_in_editor(tempfile.path)
          else
            puts format('Not sure how to capture a %s...', returned.class)
          end

          tempfile.delete
          tempfile.close
        },
      }
    end

    def applied_modifiers
      @applied_modifiers ||= []
    end

    def register_special_modifier(*names, &block)
      names.each{|name| special_modifiers.merge!( name.to_s => block ) }
    end

    def register_modifier(*names, &block)
      names.each{|name| modifiers.merge!( name.to_s => block ) }
    end

    def register_subcommand(*names, file: nil, line: nil, &block)
      names.each{|name| subcommands.merge!( name.to_s => block ) }
    end

    def register_subcommand_handler(handler, *names, file: nil)
      original_handler = handler.is_a?(Proc) ? handler.call(self) : handler
      block = Proc.new{
        handler = handler.call(self) if handler.is_a?(Proc)
        handler.send(:run)
      }
      # original_handler.subcommand_file ||= file if file != nil &&
      #   original_handler.respond_to?(:subcommand_file=)
      register_subcommand(*names, &block)
      names.each{|name| subcommand_handlers.merge!( name.to_s =>
                                                   original_handler ) }
    end

    def option_sets
      @option_sets ||= {}
    end

    def load_subcommands_by_prefix(prefix)
      subcmd_filename_pattern = File.join(Dir.home, 'subcommands', format('%s-*', prefix))
      Dir[subcmd_filename_pattern].each do |subcmd|
        IdealCmd.loading_files.push subcmd
        load subcmd
      end
    end


    class OptionSet
      class << self
        def from_name(name)
          new(name)
        end
      end

      attr_accessor :name, :options
      attr_accessor :toggle_options, :value_options_with_defaults,
        :value_options

      def initialize(name)
        @name = name
        @toggle_options = {}
        @value_options_with_defaults = {}
        @value_options = {}
      end

      def add_option(name, *matchers, &block)
      end
    end
  end
end




class NameMatcher
  attr_accessor :name_map, :names

  def initialize(hash)
    @name_map = hash
    @names = hash.keys
  end

  def name_groups
    @name_map.keys.group_by{|k| @name_map[k] }.values.sort_by{|list| list.sort.first }
  end

  def usage_groups
    name_groups.map do |names|
      names.map{|n| [n, usages[n]] }.to_h
    end
  end

  def grouped_by_values
    @grouped_by_values ||= name_map.map{|k,v|
      [v, names.select{|oname| name_map[oname] == v }]
    }
  end

  def grouped_names
    name_groups.flat_map{|list| list.map{|n| [n,list] } }.to_h
  end

#   def name_groups
#     @name_groups ||= grouped_by_values.inject({}){|h,(k,grouped_names)|
#       grouped_names.map{|name| h.merge!(name => grouped_names) }
#       h
#     }
#   end

  def partials
    @partials ||= names.map{|name| [name, partials_for(name)] }.to_h
  end

  def partials_for(str)
    str.chars.inject([]) do |arr,c|
      arr.push((arr.last || '') + c)
    end
  end

  def uniq_partials
    @uniq_partials ||= names.map{|name|
      other_partials = (names - grouped_names[name]).flat_map{|oname| partials[oname] }.sort.uniq
      other_partials -= [name]
      [name, partials[name] - other_partials]
    }.to_h
  end

  def shortest_partials
    @shortest_partials ||= names.map{|name|
      [name, uniq_partials[name].min_by(&:length)]
    }.to_h
  end

  def usages
    @usages ||= names.map{|name|
      shortest = shortest_partials[name]
      next [name,name] if shortest == name
      [name, format('%s[%s]', name[0,shortest.length], name[(shortest.length)..-1])]
    }.to_h
  end

  def info
    @info ||= name_groups.flat_map{|list|
      list.map{|name|
        [
          name,
          Value.new(
            name: name,
            data: name_map[name],
            similar_names: list,
            partials: partials[name],
            matching_partials: uniq_partials[name],
            shortest_partial: shortest_partials[name],
            syntax: usages[name],
            usage: usages[name],
          )
        ]
      }
    }.to_h
  end

  def match(str)
    found = info.find{|name,info| info.matching_partials.include?(str) }
    found.last if found
  end

  def match_name(str)
    found = info.find{|name,info| info.matching_partials.include?(str) }
    found.first if found
  end

  def match_data(str)
    found = info.find{|name,info| info.matching_partials.include?(str) }
    found.last.data if found
  end
end


class Value
  attr_reader :to_h

  def initialize(hash)
    @to_h = {}
    merge(hash)
  end

  def merge(hash)
    self.tap{|this|
      @to_h.merge!(hash)
      hash.each{|k,v|
        define_singleton_method(k){ v }

        define_singleton_method("#{k}="){|new_v|
          @to_h.merge!(k => new_v)
          define_singleton_method(k){ new_v }
        }
      }
    }
  end
  alias_method :update, :merge

  def delete(k)
    self.tap{|this|
      @to_h.delete(k)
      instance_eval(format("undef %s", k)) if respond_to?(k)
      instance_eval(format("undef %s=", k)) if respond_to?(k.to_s + ?=)
    }
  end
  alias_method :unset, :delete

  def set(k, v)
    merge(k => v)
  end

  def get(k)
    to_h[k]
  end

  def has?(k)
    respond_to?(k)
  end

  def method_missing(name, *args)
    super unless @to_h.respond_to?(name)

    @to_h.send(name, *args)
  end

  def [](key)
    get(key)
  end

  def []=(key,val)
    val.tap{
      @to_h.merge! key => val
      define_singleton_method(key){ val }
    }
  end
end

class ProcessList
  class ProcessInfo < Value; end

  class << self
    def list
      @list ||= []
    end

    def running
      @running ||= []
    end

    def current
      @current = running[-1]
    end

    def finished
      @finished ||= []
    end

    def add(opts={})
      opts.merge! id: list.length, status: :running
      new_process = ProcessInfo.new(opts)
      list.push new_process
      running.push new_process
    end

    def update(opts={})
      current.update(opts)
    end

    def finalize(return_value=nil)
      finalized_process = ProcessFinalizer.finalize(current, return_value)
      finalized_process.return_value.tap{|retval|
        current.update(modified_return_value: retval,
                         # finalized_process.info.return_value,
                       status: :finished)
      }
    end

    def finish!
      finished.push running.pop
    end
  end

  class ProcessFinalizer
    class << self
      def finalize(info, return_value)
        new(info, return_value).tap(&:finalize)
      end
    end

    attr_accessor :info, :return_value
    attr_reader :object
    def initialize(info, return_value)
      @info, @return_value = info, return_value
      @object = info.object
    end

    def finalize
      info.update(
        return_value: return_value,
        status: :finalizing,
      )

      process_modifiers
      process_special_modifiers

      @info.update(return_value: @return_value)
    end

    def process_modifiers
      found = object.modifiers.map{|mod,block|
        args = ArgumentHelper.modifiers.map(&:first)
        index = args.rindex(mod)
        next if index.nil?

        arg_name, opts = arg_info = ArgumentHelper.modifiers.delete_at(index)
        [
          mod,
          Value.new(
            name: mod,
            block: block,
            info: arg_info,
            arg_name: arg_name,
            opts: opts,
          )
        ]
      }.compact.to_h

      @return_value = found.inject(@return_value){|retval,(name,handler)|
        handler.block.call(retval,*handler.opts)
      }
      @info.update(return_value: @return_value)
      @return_value
    end

    def process_special_modifiers
      found = object.special_modifiers.map{|mod,block|
        args = ArgumentHelper.modifiers.map(&:first)
        index = args.rindex(mod)
        next if index.nil?

        arg_name, opts = arg_info = ArgumentHelper.modifiers.delete_at(index)
        [
          mod,
          Value.new(
            name: mod,
            block: block,
            info: arg_info,
            arg_name: arg_name,
            opts: opts,
          )
        ]
      }.compact.to_h

      @return_value = found.inject(@return_value){|retval,(name,handler)|
        handler.block.call(retval, opts)
      }
      @info.update(return_value: @return_value)
      @return_value
    end
  end
end







