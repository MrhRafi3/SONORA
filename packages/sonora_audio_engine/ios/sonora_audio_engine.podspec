#
# Sonora Native Audio Engine Podspec for iOS
#
Pod::Spec.new do |s|
  s.name             = 'sonora_audio_engine'
  s.version          = '0.1.0'
  s.summary          = 'Native C++ audio processing engine for SONORA'
  s.description      = <<-DESC
Real-time DSP, parametric equalizer, and audio analysis engine for SONORA.
                       DESC
  s.homepage         = 'https://github.com/MrhRafi3/SONORA'
  s.license          = { :type => 'Proprietary' }
  s.author           = { 'MrhRafi3' => 'marhrafi7@gmail.com' }

  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'CLANG_CXX_LIBRARY' => 'libc++',
    'HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/../include" "$(PODS_TARGET_SRCROOT)/../src"',
    'USER_HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/../include" "$(PODS_TARGET_SRCROOT)/../src"'
  }
  s.library = 'c++'
end
