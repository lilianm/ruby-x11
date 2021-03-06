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
# THIS SOFTWARE IS PROVIDED BY meh ''AS IS'' AND ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
# FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL meh OR
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

module X11; module Xrandr; class Crtc < ID

class Info
	def self.finalizer (pointer)
		proc {
			C::XRRFreeCrtcInfo(pointer)
		}
	end

	def self.get (crtc)
		new(crtc, C::XRRGetCrtcInfo(crtc.display.to_ffi, crtc.resources.to_ffi, crtc.to_ffi)).tap {|info|
			ObjectSpace.define_finalizer info, finalizer(info.to_ffi)
		}
	end

	attr_reader :crtc

	def initialize (crtc, pointer)
		@crtc     = crtc
		@internal = pointer.is_a?(C::XRRCrtcInfo) ? pointer : C::XRRCrtcInfo.new(pointer)
	end

	C::XRRCrtcInfo.layout.members.each {|name|
		define_method name do
			@internal[name]
		end
	}

	def to_ffi
		@internal.pointer
	end
end

end; end; end
