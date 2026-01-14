require "spec_helper"
require "fileutils"
require "tmpdir"

RSpec.describe BetterErrors::ExceptionHint do
  let(:described_instance) { described_class.new(exception) }

  describe '#hint' do
    subject(:hint) { described_instance.hint }

    context "when the exception is a missing translation" do
      before do
        module I18n; end unless defined?(I18n)

        unless I18n.const_defined?(:MissingTranslationData)
          class I18n::MissingTranslationData < StandardError
            attr_reader :locale, :key, :options

            def initialize(locale:, key:, scope: nil, message: nil)
              @locale = locale
              @key = key
              @options = { scope: scope }
              super(message || "Translation missing: #{locale}.#{key}")
            end
          end
        end
      end

      let(:exception) do
        I18n::MissingTranslationData.new(
          locale: :en,
          key: :text,
          scope: %i[users talk_suggestion_wizards success],
          message: "Translation missing: en.users.talk_suggestion_wizards.success.text"
        )
      end

      around do |example|
        original_root = BetterErrors.application_root
        original_editor = BetterErrors.editor

        Dir.mktmpdir("better-errors") do |root|
          BetterErrors.application_root = root
          BetterErrors.editor = proc { |file, line| "editor://#{file}:#{line}" }

          locale_file = File.join(root, "config/locales/users.en.yml")
          FileUtils.mkdir_p(File.dirname(locale_file))
          File.write(
            locale_file,
            <<~YAML
              en:
                users:
                  talk_suggestion_wizards:
                    success:
                      title: "Success!"
            YAML
          )

          example.run
        end
      ensure
        BetterErrors.application_root = original_root
        BetterErrors.editor = original_editor
      end

      it "includes a link to the closest locale key" do
        expect(hint).to eq(
          "Open locale file: <a href=\"editor://#{BetterErrors.application_root}/config/locales/users.en.yml:4\">"\
          "config/locales/users.en.yml</a>"
        )
      end
    end

    context "when the exception is a NameError" do
      let(:exception) {
        begin
          foo
        rescue NameError => e
          e
        end
      }

      it { is_expected.to eq("`foo` is probably misspelled.") }
    end

    context "when the exception is a NoMethodError" do
      let(:exception) {
        begin
          val.foo
        rescue NoMethodError => e
          e
        end
      }

      context "on `nil`" do
        let(:val) { nil }

        it { is_expected.to eq("Something is `nil` when it probably shouldn't be.") }
      end

      context 'on an unnamed object type' do
        let(:val) { Class.new }

        it { is_expected.to be_nil }
      end

      context "on other values" do
        let(:val) { 42 }

        it {
          is_expected.to match(
            /`foo` is being called on a `(Integer|Fixnum)` object, which might not be the type of object you were expecting./
          )
        }
      end
    end
  end
end
