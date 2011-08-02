#--
# Copyleft meh. [http://meh.paranoid.pk | meh@paranoici.org]
# 
# Redistribution and use in source and binary forms, with or without modification, are
# permitted provided that the following conditions are met:
# 
#    1. Redistributions of source code must retain the above copyright notice, this list of
#       conditions and the following disclaimer.
# 
#    2. Redistributions in binary form must reproduce the above copyright notice, this list
#       of conditions and the following disclaimer in the documentation and/or other materials
#       provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY <COPYRIGHT HOLDER> ''AS IS'' AND ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
# FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
# ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
# 
# The views and conclusions contained in the software and documentation are those of the
# authors and should not be interpreted as representing official policies, either expressed
# or implied.
#++

module X11; class Event

Events << nil

class Helper
  def self.inherited (klass)
    Events << klass
  end

  def self.attribute (which=nil)
    @attribute = which.to_s.to_sym if which
  end

  def self.attach_method (meth, &block)
    return unless block

    class_eval {
      define_method(meth, &block)
    }
  end

  def self.manage (name, *args)
    if name.is_a?(Array)
      original, new = name[0, 2]
    else
      original, new = [name] * 2
    end

    args.flatten!

    case args.size
    when 0
      attach_method(new) {
        struct[@attribute][original]
      }

      attach_method("#{new}=") {|x|
        struct[@attribute][original] = x
      }
    when 1
      if args.first.is_a?(Class)
        attach_method(new) {
          args.first.new(struct[@attribute][original])
        }

        attach_method("#{new}=") {|x|
          struct[@attribute][original] = x.to_c
        }
      else
        manage([original, new], args.first, nil)
      end
    when 2
      attach_method(new) {
        self.instance_exec(struct[@attribute][original], &args[0])
      } if args[0]

      attach_method("#{new}=") {|x|
        struct[attribute][original] = self.instance_exec(x, &args[1])
      } if args[1]
    end
  end

  def initialize (struct)
    @struct = struct
  end

  def struct
    @struct
  end

  alias to_c struct
end

Window = [lambda {|w|
  X11::Window.new(self.display, w)
}, lambda(&:to_c)]

module Common
  def self.included (klass)
    klass.class_eval {
      manage :serial
      manage [:send_event, :send_event?]
      manage :display, Display
      manage :window, Window
    }
  end
end

end; end