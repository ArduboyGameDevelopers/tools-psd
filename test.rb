require 'psd'
require 'fileutils'

Dir['utils/**/*.rb'].each { |source_file| require_relative source_file }

TRANSPARENT_COLOR = 0xffffffff # white is transparent

file_input = '/Users/weee/Creative Cloud Files/gamedev/Heros/Heros-Basic-16x16.psd'
dir_out = '/Users/weee/dev/projects/arduboy/games/PixelSpaceOdysspy'

def process_layer(layer)
  ImageUtils::make_frame(layer.name, layer.image.to_png, TRANSPARENT_COLOR)
end

def process_group(group)
  puts group.name

  animation = Animation.new group.name
  group.children.each { |child|
    next unless child.is_a? PSD::Node::Layer
    animation.add_frame process_layer(child)
  }

  animation
end

animations = []

PSD.open(file_input) do |psd|
  children = psd.tree.children
  children.each { |child|
    animations.push process_group(child) if child.is_a? PSD::Node::Group
  }
end

file_h = "#{dir_out}/images.h"
file_cpp = "#{dir_out}/images.cpp"

source_h = SourceWriter.new
source_cpp = SourceWriter.new

source_h.println '#ifndef IMAGES_H'
source_h.println '#define IMAGES_H'
source_h.println
source_h.println "#include \"animation.h\""

source_cpp.println "#include <avr/pgmspace.h>"
source_cpp.println "#include \"#{File.basename file_h}\""

animation_defines = []
animation_inializers = []

(0..animations.length-1).each { |animation_index|

  animation = animations[animation_index]
  animation_name = Utils.to_identifier animation.name

  frames = animation.frames
  frames_names = []

  (0..frames.count-1).each { |index|

    frame = frames[index]

    data = []
    frame.data.each { |byte|
      data << "0x#{byte.to_s 16}"
    }

    var_name = Utils.to_identifier "#{animation_name}_#{index}"
    frames_names << var_name

    source_cpp.println
    source_cpp.println "PROGMEM static const unsigned char #{var_name}[] ="
    source_cpp.block_open
    source_cpp.println "#{frame.x}, #{frame.y}, #{frame.width}, #{frame.height},"
    source_cpp.println "#{data.join ', '}"
    source_cpp.block_close ';'
  }

  frames_name = Utils.to_identifier "#{animation_name}_frames"

  source_cpp.println
  source_cpp.println "static const FrameData #{frames_name}[] ="

  source_cpp.block_open
  frames_names.each do |name|
    source_cpp.println "#{name},"
  end
  source_cpp.block_close ';'

  animation_define = "ANIMATION_#{animation_name.upcase}"
  raise "Duplication animation: #{animation_name}" if animation_defines.include? animation_define
  animation_defines << animation_define

  source_h.println
  source_h.println "#define #{animation_define} #{animation_index}"

  animation_inializers << "CreateAnimation(#{frames_name}, #{frames.length})"
}

source_h.println
source_h.println "#define ANIMATIONS_COUNT #{animation_inializers.length}"

source_h.println
source_h.println 'extern const Animation animations[];'

source_cpp.println
source_cpp.println 'const Animation animations[] = '
source_cpp.block_open
animation_inializers.each { |a| source_cpp.println "#{a}," }
source_cpp.block_close ';'

source_h.println
source_h.println '#endif // IMAGES_H'

source_h.write_to_file file_h
source_cpp.write_to_file file_cpp