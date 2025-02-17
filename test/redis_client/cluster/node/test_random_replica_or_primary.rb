# frozen_string_literal: true

require 'testing_helper'
require 'redis_client/cluster/node/testing_topology_mixin'

class RedisClient
  class Cluster
    class Node
      class TestRandomReplicaWithPrimary < TestingWrapper
        include TestingTopologyMixin

        def test_clients_with_redis_client
          got = @test_topology.clients
          got.each_value { |client| assert_instance_of(::RedisClient, client) }
          assert_equal(%w[master slave], got.map { |_, v| v.call('ROLE').first }.uniq.sort)
        end

        def test_clients_with_pooled_redis_client
          test_topology = ::RedisClient::Cluster::Node::RandomReplicaOrPrimary.new(
            @replications,
            @options,
            { timeout: 3, size: 2 },
            @concurrent_worker,
            **TEST_GENERIC_OPTIONS
          )

          got = test_topology.clients
          got.each_value { |client| assert_instance_of(::RedisClient::Pooled, client) }
          assert_equal(%w[master slave], got.map { |_, v| v.call('ROLE').first }.uniq.sort)
        ensure
          test_topology&.clients&.each_value(&:close)
        end

        def test_primary_clients
          got = @test_topology.primary_clients
          got.each_value do |client|
            assert_instance_of(::RedisClient, client)
            assert_equal('master', client.call('ROLE').first)
          end
        end

        def test_replica_clients
          got = @test_topology.replica_clients
          got.each_value do |client|
            assert_instance_of(::RedisClient, client)
            assert_equal('slave', client.call('ROLE').first)
          end
        end

        def test_clients_for_scanning
          got = @test_topology.clients_for_scanning
          got.each_value { |client| assert_instance_of(::RedisClient, client) }
          assert_equal(TEST_SHARD_SIZE, got.size)
        end

        def test_find_node_key_of_replica
          want = 'dummy_key'
          got = @test_topology.find_node_key_of_replica('dummy_key')
          assert_equal(want, got)

          primary_key = @replications.keys.first
          replica_keys = @replications.fetch(primary_key)
          got = @test_topology.find_node_key_of_replica(primary_key)
          assert_includes(replica_keys + [primary_key], got)
        end

        def test_any_primary_node_key
          got = @test_topology.any_primary_node_key
          assert_includes(@replications.keys, got)
        end

        def test_any_replica_node_key
          got = @test_topology.any_replica_node_key
          assert_includes(@replications.values.flatten, got)
        end

        private

        def topology_class
          ::RedisClient::Cluster::Node::RandomReplicaOrPrimary
        end
      end
    end
  end
end
