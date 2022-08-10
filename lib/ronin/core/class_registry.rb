#
# Copyright (c) 2021-2022 Hal Brodigan (postmodern.mod3 at gmail.com)
#
# This file is part of ronin-core.
#
# ronin-core is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
# 
# ronin-core is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Lesser General Public License for more details.
# 
# You should have received a copy of the GNU Lesser General Public License
# along with ronin-core.  If not, see <https://www.gnu.org/licenses/>.
#

module Ronin
  module Core
    #
    # A mixin that adds a class registry to a library:
    #
    # ### Example
    #
    # `lib/ronin/exploits.rb`:
    #
    #     require 'ronin/core/class_registry'
    #     
    #     module Ronin
    #       module Exploits
    #         include Ronin::Core::ClassRegistry
    #     
    #         class_dir "#{__dir__}/classes"
    #       end
    #     end
    #
    # `lib/ronin/exploits/exploit.rb`:
    #
    #     module Ronin
    #       module Exploits
    #         class Exploit
    #     
    #           def self.register(name)
    #             Exploits.register(name,self)
    #           end
    #     
    #         end
    #       end
    #     end
    #
    # `lib/ronin/exploits/my_exploit.rb`:
    #
    #     require 'ronin/exploits/exploit'
    #     
    #     module Ronin
    #       module Exploits
    #         class MyExploit < Exploit
    #     
    #           register 'my_exploit'
    #     
    #         end
    #       end
    #     end
    #
    # @api semipublic
    #
    module ClassRegistry
      class ClassNotFound < RuntimeError
      end

      #
      # Extends {ClassMethods}.
      #
      # @param [Module] namespace
      #   The module that is including {ClassRegistry}.
      #
      def self.included(namespace)
        namespace.extend ClassMethods
      end

      module ClassMethods
        #
        # Gets or sets the class directory path.
        #
        # @param [String, nil] new_dir
        #   The new class directory path.
        #
        # @return [String]
        #   The class directory path.
        # 
        # @raise [NotImplementedError]
        #   The `class_dir` method was not defined in the module.
        #
        # @example
        #   class_dir "#{__dir__}/classes"
        #
        def class_dir(new_dir=nil)
          if new_dir
            @class_dir = new_dir
          else
            @class_dir || raise(NotImplementedError,"#{self} did not define a class_dir")
          end
        end

        #
        # Lists all class files within {#class_dir}.
        #
        # @return [Array<String>]
        #   The list of class paths within {#class_dir}.
        #
        def list_files
          paths = Dir.glob('{**/}*.rb', base: class_dir)
          paths.each { |path| path.chomp!('.rb') }
          return paths
        end

        #
        # The class registry.
        #
        # @return [Hash{String => Class,nil}]
        #   The mapping of class `id` and classes.
        #
        def registry
          @registry ||= {}
        end

        #
        # Registers a class with the registry.
        #
        # @param [String] id
        #   The class `id` to be registered.
        #
        # @param [Class] mod
        #   The class to be registered.
        #
        # @example
        #   Exploits.register('myexploit',MyExploit)
        #
        def register(id,mod)
          registry[id] = mod
        end

        #
        # Finds the path for the class `id`.
        #
        # @param [String] id
        #   The class `id`.
        #
        # @return [String, nil]
        #   The path for the module. If the module file does not exist in
        #   {#class_dir} then `nil` will be returned.
        #
        # @example
        #   Exploits.path_for('my_exploit')
        #   # => "/path/to/lib/ronin/exploits/classes/my_exploit.rb"
        #
        def path_for(id)
          path = File.join(class_dir,"#{id}.rb")

          if File.file?(path)
            return path
          end
        end

        #
        # Loads a class from the {#class_dir}.
        #
        # @param [String] id
        #   The class `id` to load.
        #
        # @return [Class]
        #   The loaded class.
        #
        # @raise [ClassNotFound]
        #   The class file could not be found within {#class_dir}.or has
        #   a file/registered-name mismatch.
        #
        def load_class(id)
          # short-circuit if the module is already loaded
          if (mod = registry[id])
            return mod
          else
            unless (path = path_for(id))
              raise(ClassNotFound,"could not find file for #{id.inspect}")
            end

            previous_entries = registry.keys

            begin
              require path
            rescue LoadError
              raise(ClassNotFound,"could not load file for #{id .inspect}")
            end

            unless (mod = registry[id])
              new_entries = registry.keys - previous_entries

              if new_entries.empty?
                raise(ClassNotFound,"file did not register a class: #{path.inspect}")
              else
                raise(ClassNotFound,"file registered a class with a different id (#{new_entries.map(&:inspect).join(', ')}): #{path.inspect}")
              end
            end

            return mod
          end
        end
      end
    end
  end
end
