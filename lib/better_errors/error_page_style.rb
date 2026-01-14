module BetterErrors
  module ErrorPageStyle
    extend self

    def compile_css(deploy: false)
      begin
        require "sass-embedded"
      rescue LoadError
        raise LoadError, "The `sass-embedded` gem is required when developing the `better_errors` gem. "\
          "If you're using a release of `better_errors`, the compiled CSS is missing from the released gem"
        # If you arrived here because sass-embedded is not in your project's Gemfile,
        # the issue here is that the release of the better_errors gem
        # is supposed to contain the compiled CSS, but that file is missing from the release.
        # So better_errors is trying to build the CSS on the fly, which requires the sass-embedded gem.
        #
        # If you're developing the better_errors gem locally, and you're running a project
        # that does not have sass-embedded in its bundle, run `rake style:build` in the better_errors
        # project to compile the CSS file.
      end

      style_dir = File.expand_path("style", File.dirname(__FILE__))
      sass_file = "#{style_dir}/main.scss"

      css = Sass
        .compile(
          sass_file,
          style: deploy ? :compressed : :expanded,
          load_paths: [style_dir]
        ).css

      File.write(style_file, css)

      css
    end

    def style_tag(csp_nonce)
      css =
        File.exist?(style_file) ?
          File.read(style_file) :
          compile_css

      "<style type='text/css' nonce='#{csp_nonce}'>\n#{css}\n</style>"
    end

    def remove_style_file
      File.unlink(style_file)
    end

    def style_file = File.expand_path("templates/main.css", File.dirname(__FILE__))
  end
end
