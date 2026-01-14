require "cgi"

module BetterErrors
  class ExceptionHint
    def initialize(exception)
      @exception = exception
    end

    def hint
      case exception.class.to_s
      when "NoMethodError"
        /\Aundefined method `(?<method>[^']+)' for (?<val>[^:]+):(?<klass>\w+)/.match(exception.message) do |match|
          if match[:val] == "nil"
            return CGI.escapeHTML("Something is `nil` when it probably shouldn't be.")
          elsif !match[:klass].start_with? "0x"
            return CGI.escapeHTML(
              "`#{match[:method]}` is being called on a `#{match[:klass]}` object, "\
              "which might not be the type of object you were expecting."
            )
          end
        end
      when "NameError"
        /\Aundefined local variable or method `(?<method>[^']+)' for/.match(exception.message) do |match|
          return CGI.escapeHTML("`#{match[:method]}` is probably misspelled.")
        end
      when "I18n::MissingTranslationData"
        locale = exception.try(:locale)
        key = exception.try(:key)
        scope = exception.try(:options)&.fetch(:scope, nil)

        locale, key = locale_and_key_from_message(locale, key, exception.message)
        return unless locale && key

        key_parts = translation_key_parts(key, scope)
        return if key_parts.empty?

        namespace = key_parts.first.to_s
        return if namespace.empty?

        root = BetterErrors.application_root
        return unless root

        relative_path = "config/locales/#{namespace}.#{locale}.yml"
        file_path = File.join(root, relative_path)
        return unless File.exist?(file_path)

        line =
          line_for_translation_key(
            file_path,
            [locale.to_s] + key_parts
          ) || 1

        editor_url = BetterErrors.editor.url(file_path, line)

        return "Open locale file: <a href=\"#{CGI.escapeHTML(editor_url)}\">#{CGI.escapeHTML(relative_path)}</a>"
      end
    end

    private

    attr_reader :exception

    def locale_and_key_from_message(locale, key, message)
      return [locale, key] if locale && key

      if message.to_s =~ /Translation missing:\s+([^.]+)\.(.+)\z/
        locale ||= Regexp.last_match(1)
        key ||= Regexp.last_match(2)
      end

      [locale, key]
    end

    def translation_key_parts(key, scope)
      key_string = key.to_s
      return [] if key_string.empty?

      if key_string.include?(".")
        key_string.split(".")
      else
        Array(scope).map(&:to_s) + [key_string]
      end
    end

    def line_for_translation_key(file_path, key_parts)
      key_lines = yaml_key_lines(file_path)
      return if key_lines.empty?

      key_parts
        .length
        .downto(1)
        .each do |length|

        candidate = key_parts.first(length).join(".")
        return key_lines[candidate] if key_lines.key?(candidate)
      end

      nil
    end

    def yaml_key_lines(file_path)
      stack = []
      key_lines = {}

      File.readlines(file_path).each_with_index do |line, index|
        key = yaml_key_from_line(line)
        next unless key

        indent = line[/\A[ \t]*/].to_s.length

        while stack.any? && indent <= stack.last[:indent]
          stack.pop
        end

        stack << { key: key, indent: indent }
        path = stack.map { _1[:key] }.join(".")
        key_lines[path] ||= index + 1
      end

      key_lines
    end

    def yaml_key_from_line(line)
      stripped = line.lstrip
      return if stripped.empty? || stripped.start_with?("#", "-")

      match =
        line.match(
          /\A[ \t]*(?:"(?<dq>[^"]+)"|'(?<sq>[^']+)'|(?<plain>[^:#\s][^:]*?)):\s*(?:#.*)?\z/
        )
      return unless match

      (match[:dq] || match[:sq] || match[:plain]).strip
    end
  end
end
