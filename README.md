# Cache

To start the server: `iex -S mix run`

Examples testcases:
  ```elixir
  Cache.start_link()
  Cache.register_function(fn-> Process.sleep(1000); {:ok, System.os_time(:second)} end, "key", 10000, 1000)
  Cache.get("key")
  ```
  ```bash
  thanhle@local cache % iex -S mix run                                   
  Erlang/OTP 25 [erts-13.0] [source] [64-bit] [smp:8:8] [ds:8:8:10] [async-threads:1] [jit] [dtrace]

  Interactive Elixir (1.13.4) - press Ctrl+C to exit (type h() ENTER for help)
  iex(1)> Cache.start_link()
  {:ok, #PID<0.153.0>}
  iex(2)> Cache.register_function(fn-> Process.sleep(1000); {:ok, System.os_time(:second)} end, "key", 10000, 1000)
  :ok
  iex(3)> Cache.get("key")
  {:ok, 1657623904}
  iex(4)> 
  ```

To run test: `mix test`
  ```bash
  thanhle@local cache % mix test                  
  ...............

  Finished in 14.4 seconds (0.00s async, 14.4s sync)
  15 tests, 0 failures

  Randomized with seed 305484
  ```


Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/cache>.
