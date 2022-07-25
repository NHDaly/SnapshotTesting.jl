using SnapshotTesting
using Test

const expected = joinpath(@__DIR__, "expected")

# SnapshotTesting.test_snapshot(expected, "test1", regenerate = true) do dir
#     write(joinpath(dir, "a"), "hello")
# end

@testset "basic" begin
    SnapshotTesting.test_snapshot(expected, "test1") do dir
        write(joinpath(dir, "a"), "hello")
    end
end

mutable struct CountFailuresTestSet <: Test.AbstractTestSet
    failures::Int
end
CountFailuresTestSet() = CountFailuresTestSet(0)
Test.record(s::CountFailuresTestSet, ::Test.Fail) = s.failures += 1
Test.record(::CountFailuresTestSet, ::Any) = nothing
# Nested testset constructor just returns the parent
CountFailuresTestSet(::String) = Test.get_testset()::CountFailuresTestSet
Test.record(::CountFailuresTestSet, ::Any) = nothing
Test.finish(::CountFailuresTestSet) = nothing

function test_failing_testset(f::Function)
    t = CountFailuresTestSet()
    Test.push_testset(t)
    try
        f()
    finally
        Test.pop_testset()
    end
    return t
end

@testset "different files" begin
    t = test_failing_testset() do
        SnapshotTesting.test_snapshot(expected, "test1", allow_additions=false) do dir
            write(joinpath(dir, "a"), "this file is different")
        end
    end
    @test t.failures == 1
end

@testset "missing files" begin
    t = test_failing_testset() do
        SnapshotTesting.test_snapshot(expected, "test1", allow_additions=false) do dir
        end
    end
    @test t.failures == 1
end


@testset "extra_files" begin
    SnapshotTesting.test_snapshot(expected, "test1") do dir
        write(joinpath(dir, "a"), "hello")
        write(joinpath(dir, "b"), "this file is ignored")
    end

    t = test_failing_testset() do
        SnapshotTesting.test_snapshot(expected, "test1", allow_additions=false) do dir
            write(joinpath(dir, "a"), "hello")
            write(joinpath(dir, "b"), "this file is not ignored!")
        end
    end
    @test t.failures == 1

    t = test_failing_testset() do
        SnapshotTesting.test_snapshot(expected, "test1", allow_additions=false) do dir
            write(joinpath(dir, "a"), "this one is different")
            write(joinpath(dir, "b"), "this file is not ignored!")
            write(joinpath(dir, "c"), "neither is this one")
        end
    end
    @test t.failures == 3
end
