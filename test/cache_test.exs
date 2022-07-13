defmodule CacheTest do
  use ExUnit.Case
  doctest Cache

  test "get register_function" do
    start_supervised(Cache)
    assert Cache.register_function(fn-> Process.sleep(1000); {:ok, System.os_time(:second)} end, "key", 10000, 1000) == :ok
  end

  test "register_function with {:error, :already_registered}" do
    start_supervised(Cache)
    Cache.register_function(fn-> Process.sleep(1000); {:ok, System.os_time(:second)} end, "key", 10000, 1000)
    assert Cache.register_function(fn-> Process.sleep(1000); {:ok, System.os_time(:second)} end, "key", 10000, 1000) == {:error, :already_registered}
  end

  test "register_function fun/1" do
    start_supervised(Cache)
    assert Cache.register_function(fn x -> Process.sleep(1000); {:ok, System.os_time(x)} end, "key", 10000, 10000) == {:error, :unexpected_value}
  end

  test "register_function ttl not integer" do
    start_supervised(Cache)
    assert Cache.register_function(fn -> Process.sleep(1000); {:ok, System.os_time(:second)} end, "key", "10000", 10000) == {:error, :unexpected_value}
  end

  test "register_function refresh_interval not integer" do
    start_supervised(Cache)
    assert Cache.register_function(fn -> Process.sleep(1000); {:ok, System.os_time(:second)} end, "key", 10000, "10000") == {:error, :unexpected_value}
  end

  test "register_function ttl < 0" do
    start_supervised(Cache)
    assert Cache.register_function(fn -> Process.sleep(1000); {:ok, System.os_time(:second)} end, "key", -1, 10000) == {:error, :unexpected_value}
  end

  test "register_function refresh_interval < 0" do
    start_supervised(Cache)
    assert Cache.register_function(fn -> Process.sleep(1000); {:ok, System.os_time(:second)} end, "key", 10000, -1) == {:error, :unexpected_value}
  end

  test "register_function frefresh_interval = ttl" do
    start_supervised(Cache)
    assert Cache.register_function(fn -> Process.sleep(1000); {:ok, System.os_time()} end, "key", 10000, 10000) == {:error, :unexpected_value}
  end

  test "register_function frefresh_interval > ttl" do
    start_supervised(Cache)
    assert Cache.register_function(fn -> Process.sleep(1000); {:ok, System.os_time()} end, "key", 10000, 100000) == {:error, :unexpected_value}
  end

  test "get with return value with 1 key" do
    start_supervised(Cache)
    Cache.register_function(fn-> Process.sleep(1000); {:ok, System.os_time(:second)} end, "key", 10000, 1000)
    assert Cache.get("key") == {:ok, System.os_time(:second)}
  end

  test "get no existed key" do
    start_supervised(Cache)
    Cache.register_function(fn-> Process.sleep(1000); {:ok, System.os_time(:second)} end, "key", 10000, 1000)
    assert Cache.get("key1") == {:error, :not_registered}
  end

  test "get timeout key" do
    start_supervised(Cache)
    Cache.register_function(fn-> Process.sleep(6000); {:ok, System.os_time(:second)} end, "key", 10000, 1000)
    assert Cache.get("key", 5000) == {:error, :timeout}
  end

  test "get waiting key" do
    start_supervised(Cache)
    Cache.register_function(fn-> Process.sleep(6000); {:ok, System.os_time(:second)} end, "key", 10000, 1000)
    assert Cache.get("key") == {:ok, System.os_time(:second)}
  end

  test "get with return value 100_000 keys" do
    start_supervised(Cache)
    Enum.map(1..100_000, &(Cache.register_function(fn -> Process.sleep(1000); {:ok, System.os_time(:second)} end, &1, 10000, 1)))
    assert Cache.get(100) == {:ok, System.os_time(:second)}
  end
end
