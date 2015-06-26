## SIMP Core

This is the Git [supermodule](https://git-scm.com/book/en/v2/Git-Tools-Submodules)
for all of the SIMP build materials.

The different releases are tracked on their own branches and the master branch
should generally be ignored.

This will change in the future when we merge the two branches into a single
distribution.

## Getting Started

### Project Structure

As you can probably tell, the `master` branch of this project is empty.

There are currently two other branches, `4.2.X` and `5.1.X`. These correspond
to RHEL/CentOS 6 and 7, respectively. The `5.1.X` branch will be used
throughout this guide, but feel free to switch back and forth.

### Setting up your environment

We suggest installing [RVM](https://rvm.io) to make it easy to manage several
versions of ruby at once. Here are some quick commands to get it installed
(taken from the project's [installation page](https://rvm.io/rvm/install)):

```bash
$ gpg2 --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
$ \curl -sSL https://get.rvm.io | bash -s stable --ruby=1.9.3 --ruby=2.1.0
$ source ~/.rvm/scripts/rvm
```

Because this project is primarily written in Ruby, we use a few key Ruby tools.
The Ruby community and this project makes heavy use of Gems, the native Ruby
package.

#### Set the Default Ruby

The latest stable version of Ruby in use by Puppet, at the time of writing, is
Ruby 2.1.0. Therefore, we suggest setting your Ruby default to 2.1.0 so that
your environment will work as expected over time.

```bash
$ rvm use --default 2.1.0
```

After you have done this, you may simply use the following command to switch to
the default Ruby installation:

```bash
$ rvm use default
```

#### Bundler

The next important tool is [Bundler](http://bundler.io/). Bundler makes it easy
to install Gems and their dependencies. It gets this information from the
`Gemfile` found in the root of each repo. The `Gemfile` contains all of the
gems required for working with the repo.  More info on Bundler can be
found [on the Bundler Rationale Page](http://bundler.io/rationale.html) and
more information on Rubygems can be found
[at Rubygems.org](http://guides.rubygems.org/what-is-a-gem/).

Bundler should be installed using the following command. It will install this
Gem for every version of Ruby you've installed in RVM. If you've been following
this guide then this will be 1.9.3 and 2.1.0.

```bash
$ rvm all do gem install bundler
```

#### Preparing to Work

You are now ready to begin working on SIMP!

Clone the repository using `git clone`:

```bash
$ git clone https://github.com/simp/simp-core.git --branch 5.1.X
$ cd simp-core
```

You've now cloned the `simp-core` Git repository into a folder named `simp-core`.

Next, you need to install the dependencies using `bundler`.

```bash
$ bundle install
```

You should now have an environment where you can develop. Run `rake -T` or
`rake -D` to see what options are available.

Have fun!


[![Bitdeli Badge](https://d2weczhvl823v0.cloudfront.net/simp/simp-core/trend.png)](https://bitdeli.com/free "Bitdeli Badge")

