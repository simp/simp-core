## SIMP Core

This is the supermodule for all of the SIMP build materials.

The different releases are tracked on their own branches and the master branch
should generally be ignored.

This will change in the future when we merge the two branches into a single distribution.

## Getting Started
### Project Structure
As you can probably tell, the `master` branch of this project is empty. There are two other branches, `4.2.X` and `5.1.X`. These correspond to RHEL/CentOS 6 and 7, respectively. The `5.1.X` branch will be used throughout this guide, but feel free to substitute back and forth. 
### Setting up your environment 
We suggest installing rvm to manage several versions of ruby at once(taken from [the project's homepage](https://rvm.io)):
```bash
$ gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
$ \curl -sSL https://get.rvm.io | bash -s stable --ruby=1.9.3 --ruby=2.0.0
$ source ~/.rvm/scripts/rvm
```
Because this project is written in Ruby, we use a few key Ruby tools. The first of which is [bundler](http://bundler.io/). Bundler makes it easy to install package dependencies and check versions. It gets this information from a `Gemfile`, which is located in the root of each repo. This file contains all of the gems, or ruby packages, required for the repo to compile. More information on bundler can be found [here](http://bundler.io/rationale.html) and more information on ruby gems can be found [here](http://guides.rubygems.org/what-is-a-gem/).

Install bundler using the following command. It will install this gem for every version of ruby you've installed in rvm, which if you've been following this guide is two (1.9 and 2.0).
```bash
$ rvm all do gem install bundler
```

First, clone the repository using `git clone`:
```bash
$ git clone https://github.com/simp/simp-core.git --branch 5.1.X
$ cd simp-core
```
This will clone the simp-core git repository into a folder named simp-core, then it will `cd` into that directory. Next, the dependencies need to be installed using `bundler`, using the `Gemfile` provided by the repo.
```bash
$ bundle install 
```

You should now have an environment where you can develop. Run `rake -T` or `rake -D` to see what options are available. 

Have fun!
