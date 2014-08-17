require 'set'

module CocoaPodsKeys
  class KeyMaster

    attr_accessor :name, :interface, :implementation

    def initialize(keyring)
      @keys = keyring.keychain_data
      @name = keyring.name + 'Keys'
      @used_indexes = Set.new
      @indexed_keys = {}
      @data = generate_data
      @interface = generate_interface
      @implementation = generate_implementation
    end

    def generate_data
      data = `head -c 10000 /dev/random | base64 | head -c 10000`
      length = data.length

      @keys.each do |key, value|
        @indexed_keys[key] = []

        value.chars.each_with_index do |char, char_index|
          loop do

            index = rand data.length
            unless @used_indexes.include?(index)
              data[index] = char

              @used_indexes << index
              @indexed_keys[key][char_index] = index
              break
            end

          end
        end
      end

      data
    end

    def generate_interface
      erb = <<-SOURCE
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@interface <%= @name %> : NSObject

<% @keys.each do |key, value| %>

- (NSString *)<%= key %>;

<% end %>

@end

SOURCE

      render_erb(erb)
    end

    def generate_implementation
      require 'digest'

      erb = <<-SOURCE
#import "<%= @name %>.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation <%= @name %>

#pragma clang diagnostic pop

+ (BOOL)resolveInstanceMethod:(SEL)name {
  NSString *key = NSStringFromSelector(name);
  NSString * (*implementation)(<%= name %> *, SEL) = NULL;
<% @keys.each do |key, value| %>
  if ([key isEqualToString:@"<%= key %>"]) {
    implementation = _podKeys<%= Digest::MD5.hexdigest(key) %>;
  }
<% end %>

  if (!implementation) {
    return [super resolveInstanceMethod:name];
  }

  class_addMethod([self class], name, (IMP)implementation, "@@:");
  return YES;
}

<% @keys.each do |key, value| %>

static NSString *_podKeys<%= Digest::MD5.hexdigest(key) %>(<%= name %> *self, SEL _cmd) {
  char cString[<%= key_data_arrays[key].length %>] = { <%= key_data_arrays[key] %> };
  return [NSString stringWithCString:cString encoding:NSUTF8StringEncoding];
}

<% end %>

static char <%= name %>Data[10000] = "<%= @data %>";

@end

SOURCE

      render_erb(erb)
    end

    private def render_erb(erb)
      require 'erb'
      ERB.new(erb).result(binding)
    end

    private def key_data_arrays
      Hash[@indexed_keys.map {|key, value| [key, value.map { |i| name + "Data[#{i}]" }.join(', ')]}]
    end

  end
end