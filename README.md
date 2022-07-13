# Cache

To start the server: `iex -S mix`

Examples testcases:
  ```elixir
  Cache.start_link()
  Cache.register_function(fn-> Process.sleep(1000); {:ok, System.os_time(:second)} end, "key", 10000, 1000)
  Cache.get("key")
  ```
  ```bash
  thanhle@local cache % iex -S mix                                   
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

To call from other terminal:
  ```bash
  thanhle@local cache % iex --sname foo -S mix
  Erlang/OTP 25 [erts-13.0] [source] [64-bit] [smp:8:8] [ds:8:8:10] [async-threads:1] [jit] [dtrace]

  Compiling 1 file (.ex)
  Interactive Elixir (1.13.4) - press Ctrl+C to exit (type h() ENTER for help)
  iex(foo@local)1> Cache.start_link
  {:ok, #PID<0.171.0>}
  iex(foo@local)2> Cache.register_function(fn-> Process.sleep(1000); {:ok, System.os_time(:second)} end, "key", 10000, 1000)
  :ok
  iex(foo@local)3>
  ```

  ```bash
  thanhle@local cache % iex --sname bar -S mix
  Erlang/OTP 25 [erts-13.0] [source] [64-bit] [smp:8:8] [ds:8:8:10] [async-threads:1] [jit] [dtrace]

  Interactive Elixir (1.13.4) - press Ctrl+C to exit (type h() ENTER for help)
  iex(bar@local)1> :global.registered_names()  
  []
  iex(bar@local)2> Node.ping :"foo@local"
  :pong
  iex(bar@local)3> :global.registered_names() 
  [Cache]
  iex(bar@local)4> Cache.get "key"
  {:ok, 1657678973}
  iex(bar@local)5> Cache.get "key"
  {:ok, 1657678973}
  iex(bar@local)6> Cache.get "key1"
  {:error, :not_registered}
  ```



To run test: `mix test`
  ```bash
  thanhle@local cache % mix test                  
  ...............

  Finished in 14.4 seconds (0.00s async, 14.4s sync)
  15 tests, 0 failures

  Randomized with seed 305484
  ```



