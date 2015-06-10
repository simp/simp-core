## SIMP Core

This is the supermodule for all of the SIMP build materials.

The different releases are tracked on their own branches and the master branch
should generally be ignored.

This will change in the future when we merge the two branches into a single distribution.

## Getting Started

### Project Structure
As you can probably tell, the `master` branch of this project is empty. There are two other branches, `4.2.X` and `5.1.X`. These correspond to RHEL/CentOS 6 and 7, respectively. The `5.1.X` branch will be used throughout this guide, but feel free to switch back and forth.

### Setting up your environment
We suggest installing rvm to make it easy to manage several versions of ruby at once. Here are some quick commands to get it installed (taken from the project's [homepage](https://rvm.io)):
```bash
$ gpg2 --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
$ curl -sSL https://get.rvm.io | bash -s stable --ruby=1.9.3 --ruby=2.0.0
$ source ~/.rvm/scripts/rvm
```
Because this project is written in Ruby, we use a few key Ruby tools. The Ruby community and this project makes heavy use of gems. Gems are essentially packages for Ruby.
The next important tool is [bundler](http://bundler.io/). Bundler makes it easy to install gems and their dependencies. It gets this information from the `Gemfile`found in the root of each repo. This file contains all of the gems, or ruby packages, required for the repo.
More info on bundler can be found [here](http://bundler.io/rationale.html) and more information on ruby gems can be found [here](http://guides.rubygems.org/what-is-a-gem/).

Install bundler using the following command. It will install this gem for every version of ruby you've installed in rvm. If you've been following this guide, it's only two (1.9.3 and 2.0.0).
```bash
$ rvm all do gem install bundler
```

Clone the repository using `git clone`:
```bash
$ git clone https://github.com/simp/simp-core.git --branch 5.1.X
$ cd simp-core
```
You've now cloned the simp-core git repository into a folder named `simp-core`. Next, the dependencies need to be installed using `bundler`, using the `Gemfile` provided by the repo.
```bash
$ bundle install
```

You should now have an environment where you can develop. Run `rake -T` or `rake -D` to see what options are available.

Have fun!
