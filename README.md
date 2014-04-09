# GitLab ircnotify

GitLab ircnotify is a Ruby + Rack implementation of a simple daemon to tell `ircnotify` about new commits, triggered by a GitLab web hook.

## Install

To install for deployment, be sure to have the `bundler` gem installed, and then you can do:

    RUBY=/path/to/ruby
    $RUBY/bin/bundle install --deployment --binstubs --shebang $RUBY/bin/ruby

You will also need to create a `config.rb` file for your environment.  There is an example provided.
