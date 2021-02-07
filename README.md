# Grouper

Isolates groups of process subtrees together for configuration and name
registration purposes.

* Do you struggle with Elixir's global namespace for process names?
* Do all of your tests run synchronously because of this collisions?
* Do you mutate your application environment during tests?

If the above problems sounds familiar, `Grouper` might be for you.

## Usage

Simply start your `GenServer`s like this:

    GenServer.start_link(mod, arg, name: {:via, Grouper.Registry})

And access configuration like this:

    Grouper.Config.get(:key)

In tests, scripts and IEX; initialize a group with:

    {:ok, _} = Grouper.start_link()

Or run a single function in its own group like this:

    Grouper.exec!(&MyApp.my_task/0)

During normal application runtime, each application gets its own namespace
for processes and has isolated config.

During tests, however, each test can get its own group with isolated naming
and configuration. This makes it trivial to run all of your tests
asynchronously, eliminates the need to use global config for things like
mocking, and prevents config mutations in different tests from interfering
with each other.

Scripts and IEX can similarly benefit from group isolation with a single
command, thereby rounding out behavior to be identical in all common
execution environments.

## Migration

For convenience, the OTP config environment is loaded into the config for
you, simplifying migration from older, global configuration. This can be
suppressed if desired (see `Grouper.Config.suppress_otp_env/1` for
details).

## Installation

This package is [available in Hex](https://hex.pm/packages/grouper). The package
can be installed by adding `grouper` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:grouper, "~> 0.1.0"}
  ]
end
```

Documentation is generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). The docs can
be found at [https://hexdocs.pm/grouper](https://hexdocs.pm/grouper).

